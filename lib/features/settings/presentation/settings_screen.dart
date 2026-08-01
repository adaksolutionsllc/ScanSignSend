import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/utils/router.dart';
import '../../../shared/widgets/paywall_screen.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepo = ref.watch(profileRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<UserProfileData>(
        future: profileRepo.getOrCreate(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return ListView(
            children: [
              _SectionHeader('My Profile'),
              _ProfileField(
                label: 'Full Name',
                value: profile.fullName,
                onSave: (v) => profileRepo
                    .update(UserProfileCompanion(fullName: Value(v))),
              ),
              _ProfileField(
                label: 'Email',
                value: profile.email,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(email: Value(v))),
              ),
              _ProfileField(
                label: 'Phone',
                value: profile.phone,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(phone: Value(v))),
              ),
              _ProfileField(
                label: 'Address',
                value: profile.address,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(address: Value(v))),
              ),
              _ProfileField(
                label: 'City',
                value: profile.city,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(city: Value(v))),
              ),
              _ProfileField(
                label: 'State',
                value: profile.state,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(state: Value(v))),
              ),
              _ProfileField(
                label: 'ZIP',
                value: profile.zip,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(zip: Value(v))),
              ),
              _ProfileField(
                label: 'Company',
                value: profile.company,
                onSave: (v) =>
                    profileRepo.update(UserProfileCompanion(company: Value(v))),
              ),
              _SectionHeader('Signatures'),
              ListTile(
                leading: const Icon(Icons.draw_outlined),
                title: const Text('Manage Signatures'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.signaturesManager),
              ),
              _SectionHeader('Security'),
              SwitchListTile(
                title: const Text('Biometric App Lock'),
                subtitle: const Text('Require Face ID / fingerprint on launch'),
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
                          const SnackBar(
                            content: Text(
                                'No biometrics enrolled on this device. Set up Face ID / fingerprint first.'),
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
              _SectionHeader('AI Detection (v1.1)'),
              SwitchListTile(
                title: const Text('Enhanced AI Detection'),
                subtitle: const Text(
                    'Uses on-device model for smarter field recognition'),
                value: profile.aiEnhancedDetection,
                onChanged: (v) => profileRepo.update(
                    UserProfileCompanion(aiEnhancedDetection: Value(v))),
              ),
              _SectionHeader('Purchase'),
              if (!profile.isPurchased)
                ListTile(
                  leading: const Icon(Icons.workspace_premium,
                      color: Color(0xFF1A73E8)),
                  title: const Text('Unlock Full Access'),
                  subtitle: const Text('One-time purchase — see price'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PaywallScreen()),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore Purchase'),
                onTap: () => _restore(context, ref),
              ),
              if (profile.isPurchased)
                const ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Full Access Unlocked'),
                  subtitle: Text('Thank you for your purchase!'),
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
  messenger.showSnackBar(
    const SnackBar(content: Text('Checking for previous purchases…')),
  );
  try {
    final restored = await ref.read(iapServiceProvider).restore();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(restored
            ? 'Full access restored. Thank you!'
            : 'No previous purchase found on this account.'),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Restore failed: $e')),
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
      subtitle: Text(value.isEmpty ? 'Tap to set' : value),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final ctrl = TextEditingController(text: value);
        try {
          final result = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Edit $label'),
              content: TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(hintText: label),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    child: const Text('Save')),
              ],
            ),
          );
          if (result != null) await onSave(result);
        } finally {
          ctrl.dispose();
        }
      },
    );
  }
}
