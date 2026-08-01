import 'package:scan_sign_send/core/db/app_database.dart';

enum DocumentStatus { draft, pressed, fillable, template }

extension DocumentStatusX on String {
  DocumentStatus toDocumentStatus() => switch (this) {
        'pressed' => DocumentStatus.pressed,
        'fillable' => DocumentStatus.fillable,
        'template' => DocumentStatus.template,
        _ => DocumentStatus.draft,
      };
}

extension DocumentDataX on Document {
  DocumentStatus get statusEnum => status.toDocumentStatus();
}
