import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/text_edit_dialog.dart';

/// Settings → My Details: the user's own details, which PreFill fills
/// matching form fields with. All optional, saved only on this device.
class MyDetailsScreen extends ConsumerStatefulWidget {
  const MyDetailsScreen({super.key});

  @override
  ConsumerState<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends ConsumerState<MyDetailsScreen> {
  // Created once — see fill_mode_screen.dart on streams built in build().
  late final Stream<UserProfileData> _profileStream = ref
      .read(profileRepositoryProvider)
      .watch();

  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSectionProfile)),
      body: StreamBuilder<UserProfileData>(
        stream: _profileStream,
        builder: (context, snapshot) {
          final p = snapshot.data;
          if (p == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.phone_iphone,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.myDetailsNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              _Header(l10n.myDetailsGroupName),
              _text(
                l10n.detailFirstName,
                p.firstName,
                (v) => UserProfileCompanion(firstName: v),
              ),
              _text(
                l10n.detailMiddleName,
                p.middleName,
                (v) => UserProfileCompanion(middleName: v),
              ),
              _text(
                l10n.detailLastName,
                p.lastName,
                (v) => UserProfileCompanion(lastName: v),
              ),
              _Header(l10n.myDetailsGroupContact),
              _text(
                l10n.settingsEmail,
                p.email,
                (v) => UserProfileCompanion(email: v),
              ),
              _text(
                l10n.settingsPhone,
                p.phone,
                (v) => UserProfileCompanion(phone: v),
              ),
              _Header(l10n.myDetailsGroupAddress),
              _text(
                l10n.detailAddress1,
                p.address,
                (v) => UserProfileCompanion(address: v),
              ),
              _text(
                l10n.detailAddress2,
                p.address2,
                (v) => UserProfileCompanion(address2: v),
              ),
              _text(
                l10n.settingsCity,
                p.city,
                (v) => UserProfileCompanion(city: v),
              ),
              _text(
                l10n.detailState,
                p.state,
                (v) => UserProfileCompanion(state: v),
              ),
              _text(l10n.detailZip, p.zip, (v) => UserProfileCompanion(zip: v)),
              _text(
                l10n.detailCountry,
                p.country,
                (v) => UserProfileCompanion(country: v),
              ),
              _Header(l10n.myDetailsGroupWork),
              _text(
                l10n.settingsCompany,
                p.company,
                (v) => UserProfileCompanion(company: v),
              ),
              _text(
                l10n.detailJobTitle,
                p.jobTitle,
                (v) => UserProfileCompanion(jobTitle: v),
              ),
              _Header(l10n.myDetailsGroupPersonal),
              _dateOfBirth(context, p.dateOfBirth),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    l10n.myDetailsDelete,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _text(
    String label,
    String value,
    UserProfileCompanion Function(Value<String>) companion,
  ) {
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
        if (result != null) await _repo.update(companion(Value(result)));
      },
    );
  }

  Widget _dateOfBirth(BuildContext context, DateTime? dob) {
    final l10n = context.l10n;
    final shown = dob == null
        ? l10n.settingsTapToSet
        : DateFormat(
            l10n.dateFormatInput,
            Localizations.localeOf(context).toString(),
          ).format(dob);
    return ListTile(
      title: Text(l10n.detailDateOfBirth),
      subtitle: Text(shown),
      trailing: dob == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.clear),
              onPressed: () => _repo.update(
                const UserProfileCompanion(dateOfBirth: Value(null)),
              ),
            ),
      onTap: () async {
        final now = DateTime.now();
        // Opens on the year grid around 30 years back, as for birth-date
        // fields in fill mode.
        final picked = await showDatePicker(
          context: context,
          initialDate: dob ?? DateTime(now.year - 30, now.month),
          initialDatePickerMode: DatePickerMode.year,
          firstDate: DateTime(1900),
          lastDate: now,
        );
        if (picked == null) return;
        await _repo.update(UserProfileCompanion(dateOfBirth: Value(picked)));
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.myDetailsDelete),
        content: Text(l10n.myDetailsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok == true) await _repo.clearDetails();
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
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
