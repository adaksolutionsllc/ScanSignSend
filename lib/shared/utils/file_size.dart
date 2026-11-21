import 'package:intl/intl.dart';

/// "640 KB", "2.1 MB": a file size for people, with [locale]'s decimal mark.
String formatFileSize(int bytes, String locale) {
  if (bytes < 1000 * 1000) {
    return '${NumberFormat('#,##0', locale).format((bytes / 1000).ceil())} KB';
  }
  return '${NumberFormat('#,##0.0', locale).format(bytes / 1000 / 1000)} MB';
}
