package com.adakventures.scansignsend

import android.app.backup.BackupAgent
import android.app.backup.BackupDataInput
import android.app.backup.BackupDataOutput
import android.app.backup.FullBackupDataOutput
import android.content.Context
import android.os.ParcelFileDescriptor

/**
 * Makes Android Auto Backup (Google Drive) and device-to-device transfer
 * opt-in, following the "Include in device backup" switch in Settings.
 *
 * Backup rules in XML are static, so they can't follow a user setting. With
 * `android:fullBackupOnly="true"` the system calls [onFullBackup] for both
 * cloud backup and device transfer. When the user hasn't opted in, it writes
 * nothing, so the next backup holds no app data at all. When they have, the
 * default implementation backs up according to data_extraction_rules.xml /
 * backup_rules.xml, which also require client-side encryption for the cloud.
 */
class AppBackupAgent : BackupAgent() {

    override fun onFullBackup(data: FullBackupDataOutput) {
        if (isEnabled(this)) super.onFullBackup(data)
    }

    // Key/value backup is unused: fullBackupOnly routes everything through
    // onFullBackup above.
    override fun onBackup(
        oldState: ParcelFileDescriptor?,
        data: BackupDataOutput?,
        newState: ParcelFileDescriptor?,
    ) {}

    override fun onRestore(
        data: BackupDataInput?,
        appVersionCode: Int,
        newState: ParcelFileDescriptor?,
    ) {}

    companion object {
        private const val PREFS = "device_backup"
        private const val KEY_ENABLED = "enabled"

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_ENABLED, false)

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ENABLED, enabled)
                .commit()
        }
    }
}
