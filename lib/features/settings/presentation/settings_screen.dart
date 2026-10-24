import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/app_lock_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/category_hints.dart';
import '../../../core/services/document_sorter.dart';
import '../../../core/services/field_hints.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/on_device_ai_service.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/services/review_prompt_service.dart';
import '../../../core/utils/router.dart';
import '../../../shared/widgets/ai_sort_status.dart';
import '../../../shared/widgets/paywall_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Watched, not read once: every switch and profile edit writes the row and
  // relies on this stream to redraw. A one-shot read left the switches stuck.
  // Created once — see fill_mode_screen.dart on streams built in build().
  late final Stream<UserProfileData> _profileStream = ref
      .read(profileRepositoryProvider)
      .watch();

  @override
  Widget build(BuildContext context) {
    final profileRepo = ref.watch(profileRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: StreamBuilder<UserProfileData>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return ListView(
            children: [
              _SectionHeader(context.l10n.settingsSectionProfile),
              // The details PreFill fills forms with, on their own screen.
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(
                  [
                        profile.firstName,
                        profile.lastName,
                      ].where((s) => s.isNotEmpty).join(' ').isNotEmpty
                      ? [
                          profile.firstName,
                          profile.lastName,
                        ].where((s) => s.isNotEmpty).join(' ')
                      : context.l10n.settingsSectionProfile,
                ),
                subtitle: Text(context.l10n.settingsMyDetailsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.myDetails),
              ),
              _SectionHeader(context.l10n.settingsSectionSignatures),
              ListTile(
                leading: const Icon(Icons.draw_outlined),
                title: Text(context.l10n.settingsManageSignatures),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.signaturesManager),
              ),
              _SectionHeader(context.l10n.settingsSectionSecurity),
              SwitchListTile(
                title: Text(context.l10n.settingsBiometricLock),
                subtitle: Text(context.l10n.settingsBiometricLockSubtitle),
                value: profile.biometricLockEnabled,
                onChanged: (v) async {
                  // Never let the user enable a lock they can't satisfy —
                  // verify the device actually supports biometrics first.
                  if (v) {
                    final available = await ref
                        .read(biometricServiceProvider)
                        .isAvailable();
                    if (!available) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.settingsNoBiometrics),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  await profileRepo.update(
                    UserProfileCompanion(biometricLockEnabled: Value(v)),
                  );
                },
              ),
              // Opt-in: documents stay on this device unless the user asks for
              // them to be part of the phone's own backup.
              SwitchListTile(
                title: Text(context.l10n.settingsBackupTitle),
                subtitle: Text(
                  Platform.isIOS
                      ? context.l10n.settingsBackupSubtitleIos
                      : context.l10n.settingsBackupSubtitleAndroid,
                ),
                value: profile.includeInDeviceBackup,
                onChanged: (v) async {
                  await profileRepo.update(
                    UserProfileCompanion(includeInDeviceBackup: Value(v)),
                  );
                  await ref.read(backupServiceProvider).apply(v);
                },
              ),
              _SectionHeader(context.l10n.settingsSectionLibrary),
              const _AutoSortTile(),
              _SectionHeader(context.l10n.settingsSectionDetection),
              // Detection learns from the user's own field edits, on this device
              // only; this is the way to start over.
              ListTile(
                leading: const Icon(Icons.auto_fix_off_outlined),
                title: Text(context.l10n.settingsForgetLearned),
                subtitle: Text(context.l10n.settingsForgetLearnedSubtitle),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final done = context.l10n.settingsForgetLearnedDone;
                  await ref.read(fieldHintRepositoryProvider).clear();
                  await ref.read(categoryHintRepositoryProvider).clear();
                  messenger.showSnackBar(SnackBar(content: Text(done)));
                },
              ),
              _SectionHeader(context.l10n.settingsSectionPurchase),
              if (!profile.isPurchased)
                ListTile(
                  leading: const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFF1A73E8),
                  ),
                  title: Text(context.l10n.settingsUnlockFullAccess),
                  subtitle: Text(context.l10n.settingsUnlockSubtitle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(context.l10n.settingsRestorePurchase),
                onTap: () => _restore(context, ref),
              ),
              if (profile.isPurchased)
                ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text(context.l10n.settingsFullAccessUnlocked),
                  subtitle: Text(context.l10n.settingsThankYou),
                ),
              _SectionHeader(context.l10n.settingsSectionSupport),
              // The whole tour again, on demand.
              ListTile(
                leading: const Icon(Icons.slideshow_outlined),
                title: Text(context.l10n.settingsTour),
                subtitle: Text(context.l10n.settingsTourSubtitle),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (c) =>
                        OnboardingScreen(onDone: () => Navigator.of(c).pop()),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(context.l10n.settingsRateApp),
                subtitle: Text(context.l10n.settingsRateAppSubtitle),
                onTap: () => _rate(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _restore(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  // Resolve both the messenger and the strings up front: everything after the
  // await runs past an async gap, where reading `context` is unsafe.
  final l10n = context.l10n;
  final unavailable = iapErrorText(
    context,
    const IapException(IapFailure.unavailable),
  );
  final failed = iapErrorText(
    context,
    const IapException(IapFailure.purchaseFailed),
  );
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.settingsCheckingPurchases)),
  );
  try {
    final restored = await ref
        .read(appLockProvider.notifier)
        .whileExternal(ref.read(iapServiceProvider).restore);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          restored ? l10n.settingsRestored : l10n.settingsNoPreviousPurchase,
        ),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e is IapException && e.failure == IapFailure.unavailable
              ? unavailable
              : failed,
        ),
      ),
    );
  }
}

/// Opens the store listing. Always the listing, never the in-app rating
/// sheet: the OS may silently ignore that, which would make this row dead.
/// The store is another app, so the lock re-arms as for any app switch.
Future<void> _rate(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.l10n.settingsRateAppFailed;
  final opened = await ref.read(reviewPromptServiceProvider).openStoreListing();
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// "Sort documents automatically", with a line saying how this phone sorts
/// (its own AI model, or keywords and why).
class _AutoSortTile extends ConsumerStatefulWidget {
  const _AutoSortTile();

  @override
  ConsumerState<_AutoSortTile> createState() => _AutoSortTileState();
}

class _AutoSortTileState extends ConsumerState<_AutoSortTile> {
  bool? _enabled;
  OnDeviceAiStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await DocumentSorter.isEnabled();
    final status = await ref
        .read(onDeviceAiServiceProvider)
        .status(refresh: true);
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _status = status;
      });
    }
  }

  Future<void> _set(bool v) async {
    setState(() => _enabled = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(DocumentSorter.enabledKey, v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final status = _status;
    return SwitchListTile(
      secondary: const Icon(Icons.label_outline),
      title: Text(context.l10n.settingsAutoSortTitle),
      subtitle: enabled == null || status == null
          ? null
          : Text(
              enabled
                  ? aiSortMessage(context.l10n, status)
                  : context.l10n.aiSortOff,
            ),
      value: enabled ?? true,
      onChanged: enabled == null ? null : _set,
    );
  }
}
