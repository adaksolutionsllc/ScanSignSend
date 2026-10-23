/// The categories every install has. Their keys are stored in
/// `Documents.category`, so they are permanent: rename the display string,
/// never the key. User-created categories are stored as `u:<id>`.
enum BuiltInCategory {
  tax('tax'),
  money('money'),
  insurance('insurance'),
  medical('medical'),
  home('home'),
  work('work'),
  school('school'),
  idTravel('id_travel'),
  legal('legal'),
  bills('bills');

  const BuiltInCategory(this.key);
  final String key;

  static BuiltInCategory? fromKey(String? key) {
    for (final c in values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

/// `u:<id>` for a user category.
String userCategoryKey(int id) => 'u:$id';

/// The id in a `u:<id>` key, or null for a built-in key (or null).
int? userCategoryId(String? key) =>
    key != null && key.startsWith('u:') ? int.tryParse(key.substring(2)) : null;
