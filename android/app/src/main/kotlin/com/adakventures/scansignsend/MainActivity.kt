package com.adakventures.scansignsend

import android.app.backup.BackupManager
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import com.google.android.gms.auth.blockstore.StoreBytesData
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so the
// biometric prompt can attach to a FragmentActivity — otherwise authenticate()
// throws no_fragment_activity at runtime.
class MainActivity : FlutterFragmentActivity() {

    private companion object {
        const val PRIVACY_CHANNEL = "com.scansignsend/privacy"
        const val BACKUP_CHANNEL = "com.scansignsend/backup"
        const val ENTITLEMENT_CHANNEL = "com.scansignsend/entitlement"
        const val FREE_USED_KEY = "com.adakventures.scansignsend.freeDocumentsUsed"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(DocumentScannerPlugin())

        // FLAG_SECURE blanks the window in the recents thumbnail and blocks
        // screenshots / screen recording. Driven from Dart by the Biometric App
        // Lock setting — see PrivacyScreenService.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRIVACY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // "Include in device backup" (Settings). Stored natively because
        // AppBackupAgent runs in a process without a Flutter engine.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apply" -> {
                        val include = call.argument<Boolean>("include") ?: false
                        if (AppBackupAgent.isEnabled(this) != include) {
                            AppBackupAgent.setEnabled(this, include)
                            BackupManager(this).dataChanged()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Free-allowance counter in Google Play services Block Store, which
        // survives uninstall/reinstall when the user's Google Backup is on,
        // so reinstalling doesn't reset the free documents. One number,
        // nothing about the user; kept on the device (no cloud backup).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ENTITLEMENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                val client = Blockstore.getClient(this)
                when (call.method) {
                    "getFreeUsed" -> {
                        val request = RetrieveBytesRequest.Builder()
                            .setKeys(listOf(FREE_USED_KEY))
                            .build()
                        client.retrieveBytes(request)
                            .addOnSuccessListener { response ->
                                val bytes = response.blockstoreDataMap[FREE_USED_KEY]?.bytes
                                result.success(bytes?.let { String(it).toIntOrNull() } ?: 0)
                            }
                            .addOnFailureListener { result.success(0) }
                    }
                    "setFreeUsed" -> {
                        val value = call.argument<Int>("value") ?: 0
                        val data = StoreBytesData.Builder()
                            .setBytes(value.toString().toByteArray())
                            .setKey(FREE_USED_KEY)
                            .setShouldBackupToCloud(false)
                            .build()
                        client.storeBytes(data)
                            .addOnSuccessListener { result.success(true) }
                            .addOnFailureListener { result.success(false) }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
