import 'package:flutter/widgets.dart';

import '../../core/models/field_model.dart';
import '../../core/utils/l10n_ext.dart';

/// Full, translated name of a field type ("Checkbox", "Radio button" …).
String fieldTypeName(BuildContext context, FieldType type) {
  final l10n = context.l10n;
  return switch (type) {
    FieldType.text => l10n.fieldTypeText,
    FieldType.date => l10n.fieldTypeDate,
    FieldType.checkbox => l10n.fieldTypeCheckbox,
    FieldType.radio => l10n.fieldTypeRadio,
    FieldType.initials => l10n.fieldTypeInitials,
    FieldType.signature => l10n.fieldTypeSignature,
  };
}

/// Short label for the editor toolbar, where six buttons share one row.
String fieldTypeShortName(BuildContext context, FieldType type) {
  final l10n = context.l10n;
  return switch (type) {
    FieldType.text => l10n.fieldTypeText,
    FieldType.date => l10n.fieldTypeDate,
    FieldType.checkbox => l10n.fieldTypeCheckShort,
    FieldType.radio => l10n.fieldTypeRadioShort,
    FieldType.initials => l10n.fieldTypeInitials,
    FieldType.signature => l10n.fieldTypeSignShort,
  };
}
