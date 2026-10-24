import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/models/document_category.dart';
import '../../core/services/category_repository.dart';
import '../../core/services/document_sorter.dart';
import '../../core/utils/l10n_ext.dart';
import 'text_edit_dialog.dart';

/// Display name for a category key: a built-in one in the app's language, or
/// the name the user gave theirs. Null key → "No category".
String categoryLabel(
  AppLocalizations l10n,
  String? key,
  Map<int, String> userNames,
) {
  final builtIn = BuiltInCategory.fromKey(key);
  if (builtIn != null) return builtInCategoryLabel(l10n, builtIn);
  final id = userCategoryId(key);
  if (id != null && userNames[id] != null) return userNames[id]!;
  return l10n.categoryNone;
}

String builtInCategoryLabel(AppLocalizations l10n, BuiltInCategory c) =>
    switch (c) {
      BuiltInCategory.tax => l10n.categoryTax,
      BuiltInCategory.money => l10n.categoryMoney,
      BuiltInCategory.insurance => l10n.categoryInsurance,
      BuiltInCategory.medical => l10n.categoryMedical,
      BuiltInCategory.home => l10n.categoryHome,
      BuiltInCategory.work => l10n.categoryWork,
      BuiltInCategory.school => l10n.categorySchool,
      BuiltInCategory.idTravel => l10n.categoryIdTravel,
      BuiltInCategory.legal => l10n.categoryLegal,
      BuiltInCategory.bills => l10n.categoryBills,
    };

IconData categoryIcon(String? key) => switch (BuiltInCategory.fromKey(key)) {
  BuiltInCategory.tax => Icons.request_quote_outlined,
  BuiltInCategory.money => Icons.account_balance_outlined,
  BuiltInCategory.insurance => Icons.health_and_safety_outlined,
  BuiltInCategory.medical => Icons.medical_services_outlined,
  BuiltInCategory.home => Icons.home_outlined,
  BuiltInCategory.work => Icons.work_outline,
  BuiltInCategory.school => Icons.school_outlined,
  BuiltInCategory.idTravel => Icons.badge_outlined,
  BuiltInCategory.legal => Icons.gavel_outlined,
  BuiltInCategory.bills => Icons.receipt_long_outlined,
  null => key == null ? Icons.label_off_outlined : Icons.label_outline,
};

/// Asks for a new category's name and creates it. Returns its key, or null
/// when cancelled.
Future<String?> createCategory(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final repo = ref.read(categoryRepositoryProvider);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => TextEditDialog(
      title: l10n.categoryNew,
      initialValue: '',
      hint: l10n.categoryNameHint,
    ),
  );
  if (name == null || name.trim().isEmpty) return null;
  return repo.create(name);
}

/// The "Change category" sheet for [docs] (one document, or a selection).
/// The choice counts as the user's own: automatic sorting won't change it.
Future<void> showCategorySheet(
  BuildContext context,
  WidgetRef ref,
  List<Document> docs,
) async {
  if (docs.isEmpty) return;
  final sorter = ref.read(documentSorterProvider);
  final current = docs.length == 1 ? docs.single.category : null;
  final auto =
      docs.length == 1 &&
      !docs.single.categoryManual &&
      docs.single.category != null;

  final picked = await showModalBottomSheet<(String?,)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CategorySheet(current: current, auto: auto),
  );
  if (picked == null) return;
  for (final d in docs) {
    await sorter.setByUser(d, picked.$1);
  }
}

class _CategorySheet extends ConsumerWidget {
  const _CategorySheet({required this.current, required this.auto});
  final String? current;
  final bool auto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final users =
        ref.watch(_userCategoriesProvider).valueOrNull ??
        const <UserCategory>[];

    Widget option(String? key, String label) {
      final selected = key == current;
      return ListTile(
        leading: Icon(categoryIcon(key)),
        title: Text(label),
        trailing: selected ? const Icon(Icons.check) : null,
        selected: selected,
        onTap: () => Navigator.pop(context, (key,)),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                l10n.categoryChange,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: auto ? Text(l10n.categorySortedAutomatically) : null,
            ),
            for (final c in BuiltInCategory.values)
              option(c.key, builtInCategoryLabel(l10n, c)),
            for (final u in users)
              ListTile(
                leading: Icon(categoryIcon(userCategoryKey(u.id))),
                title: Text(u.name),
                selected: userCategoryKey(u.id) == current,
                onTap: () => Navigator.pop(context, (userCategoryKey(u.id),)),
                trailing: _UserCategoryMenu(category: u),
              ),
            option(null, l10n.categoryNone),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.categoryNew),
              onTap: () async {
                final key = await createCategory(context, ref);
                if (key != null && context.mounted) {
                  Navigator.pop(context, (key,));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Rename / delete for one of the user's own categories.
class _UserCategoryMenu extends ConsumerWidget {
  const _UserCategoryMenu({required this.category});
  final UserCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final repo = ref.read(categoryRepositoryProvider);
    return PopupMenuButton<String>(
      tooltip: l10n.libraryMoreTooltip,
      onSelected: (v) async {
        if (v == 'rename') {
          final name = await showDialog<String>(
            context: context,
            builder: (_) => TextEditDialog(
              title: l10n.categoryRename,
              initialValue: category.name,
              hint: l10n.categoryNameHint,
            ),
          );
          if (name != null && name.trim().isNotEmpty) {
            await repo.rename(category.id, name);
          }
        } else {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.categoryDelete),
              content: Text(l10n.categoryDeleteBody(category.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.actionDelete),
                ),
              ],
            ),
          );
          if (ok == true) await repo.delete(category.id);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l10n.categoryRename)),
        PopupMenuItem(value: 'delete', child: Text(l10n.categoryDelete)),
      ],
    );
  }
}

final _userCategoriesProvider = StreamProvider<List<UserCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchUserCategories(),
);

/// The user's categories by id, for labels.
final userCategoryNamesProvider = Provider<Map<int, String>>((ref) {
  final list = ref.watch(_userCategoriesProvider).valueOrNull ?? const [];
  return {for (final c in list) c.id: c.name};
});
