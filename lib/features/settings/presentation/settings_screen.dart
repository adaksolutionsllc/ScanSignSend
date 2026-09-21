import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/utils/router.dart';
import '../../../shared/widgets/paywall_screen.dart';
import '../../../shared/widgets/text_edit_dialog.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/l10n_ext.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepo = ref.watch(profileRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: FutureBuilder<UserProfileData>(
        future: profileRepo.getOrCreate(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return ListView(
            children: [
              _SectionHeader(context.l10n.settingsSectionProfile),
              _ProfileField(
                label: context.l10n.settingsFullName,
                value: profile.fullName,
                onSave: (v) => profileRepo
                    .update(UserProfileCompanion(fullName: Value(v))),
              ),
              _ProfileField(
                label: context.l10n.settingsEmail,
                value: profile.email,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(email: Value(v))),
              ),
              _ProfileField(
                label: context.l10n.settingsPhone,
                value: profile.phone,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(phone: Value(v))),
              ),
              _ProfileField(
                label: context.l10n.settingsAddress,
                value: profile.address,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(address: Value(v))),
              ),
              _ProfileField(
                label: context.l10n.settingsCity,
                value: profile.city,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(city: Value(v))),
              ),
              _ProfileField(
                label: context.l10n.settingsState,
                value: profile.state,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(state: Value(v))),
              ),
              _ProfileField(
                label: context.l10n.settingsZip,
                value: profile.zip,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(zip: Value(v))),
              ),
              _ProfileField(
                label: context.l10n.settingsCompany,
                value: profile.company,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(company: Value(v))),
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
                    final available =
                        await ref.read(biometricServiceProvider).isAvailable();
                    if (!available) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                context.l10n.settingsNoBiometrics),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  await profileRepo.update(
                      UserProfileCompanion(biometricLockEnabled: Value(v)));
                },
              ),
              _SectionHeader(context.l10n.settingsSectionAi),
              SwitchListTile(
                title: Text(context.l10n.settingsAiDetection),
                subtitle: Text(
                    context.l10n.settingsAiDetectionSubtitle),
                value: profile.aiEnhancedDetection,
                onChanged: (v) => profileRepo.update(
                    UserProfileCompanion(aiEnhancedDetection: Value(v))),
              ),
              _SectionHeader(context.l10n.settingsSectionPurchase),
              if (!profile.isPurchased)
                ListTile(
                  leading: const Icon(Icons.workspace_premium,
                      color: Color(0xFF1A73E8)),
                  title: Text(context.l10n.settingsUnlockFullAccess),
                  subtitle: Text(context.l10n.settingsUnlockSubtitle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PaywallScreen()),
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
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.settingsCheckingPurchases)),
  );
  try {
    final restored = await ref.read(iapServiceProvider).restore();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(restored
            ? l10n.settingsRestored
            : l10n.settingsNoPreviousPurchase),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsRestoreFailed('$e'))),
    );
  }
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

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
    required this.onSave,
  });
  final String label;
  final String value;
  final Future<void> Function(String) onSave;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value.isEmpty ? context.l10n.settingsTapToSet : value),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => TextEditDialog(
            title: context.l10n.settingsEditLabel(label),
            initialValue: value,
            hint: label,
          ),
        );
        if (result != null) await onSave(result);
      },
    );
  }
}
