import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

/// Applies the "Include in device backup" setting to what the OS backs up.
///
/// - iOS: sets `isExcludedFromBackup` on the Documents directory, which holds
///   the database, scanned pages, signatures and exports. The flag covers the
///   directory's contents, including files created later.
/// - Android: the manifest routes Auto Backup and device-to-device transfer
///   through `AppBackupAgent`, which contributes nothing unless this flag is
///   on (and cloud backup additionally requires end-to-end encryption).
///
/// The setting's source of truth is `UserProfile.includeInDeviceBackup`; this
/// only mirrors it to the platform. It's idempotent and runs at every launch,
/// so the flag is re-asserted even if the OS or a restore ever reset it.
class BackupService {
  static const _channel = MethodChannel('com.scansignsend/backup');

  Future<void> apply(bool include) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      await _channel.invokeMethod<void>('apply', {
        'include': include,
        'path': docs.path,
      });
    } on MissingPluginException {
      // Tests / unsupported platforms: nothing to apply.
    } catch (e) {
      // Never block the app over this; the next launch re-applies it.
      debugPrint('BackupService.apply failed: $e');
    }
  }
}
