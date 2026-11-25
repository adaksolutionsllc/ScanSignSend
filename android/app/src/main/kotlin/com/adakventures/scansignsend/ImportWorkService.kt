package com.adakventures.scansignsend

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat

/**
 * Keeps the app running while a long import job straightens pages, so that
 * leaving the app or locking the phone does not freeze it (plan 1.3.2, J5).
 * The work itself runs in Dart; this service only holds a foreground
 * notification with the progress.
 *
 * Type dataSync (local file processing) on Android 14+, none below.
 * mediaProcessing is not used: Android 16 rejected it with "Starting FGS
 * with type none" even with the type and permission declared (1.3.2 build
 * 27, emulator API 36), so the job had no service at all.
 *
 * Started while the app is in front (Android doesn't allow it from the
 * background) and stopped when the job ends or pauses. stopWithTask: swiping the app away from Recents ends the Flutter
 * engine and the job, so the service goes too; the job shows as paused on
 * the next start.
 *
 * No notification permission is asked: without it, Android 13+ lists the
 * job in the running-apps panel instead of the notification shade.
 */
class ImportWorkService : Service() {

    companion object {
        private const val CHANNEL_ID = "import_jobs"
        private const val NOTIFICATION_ID = 7301
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_DONE = "done"
        private const val EXTRA_TOTAL = "total"

        fun begin(context: Context, title: String, text: String, done: Int, total: Int) {
            val intent = Intent(context, ImportWorkService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_DONE, done)
                .putExtra(EXTRA_TOTAL, total)
            try {
                androidx.core.content.ContextCompat.startForegroundService(context, intent)
            } catch (e: Exception) {
                // Not allowed now (e.g. the app is no longer in front): the
                // job still runs while the app is open.
                android.util.Log.w("ImportWorkService", "start: $e")
            }
        }

        fun progress(context: Context, title: String, text: String, done: Int, total: Int) {
            try {
                NotificationManagerCompat.from(context)
                    .notify(NOTIFICATION_ID, notification(context, title, text, done, total))
            } catch (e: SecurityException) {
                // No notification permission: nothing to update.
            }
        }

        fun end(context: Context) {
            context.stopService(Intent(context, ImportWorkService::class.java))
        }

        private fun notification(
            context: Context, title: String, text: String, done: Int, total: Int,
        ): Notification {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(NotificationManager::class.java)
                if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                    // The channel name is the app's own name: no extra
                    // text to translate.
                    manager.createNotificationChannel(
                        NotificationChannel(
                            CHANNEL_ID,
                            context.applicationInfo.loadLabel(context.packageManager),
                            NotificationManager.IMPORTANCE_LOW,
                        ),
                    )
                }
            }
            val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val tap = open?.let {
                PendingIntent.getActivity(
                    context, 0, it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle(title)
                .setContentText(text)
                .setProgress(total.coerceAtLeast(1), done.coerceIn(0, total.coerceAtLeast(1)), total < 1)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setContentIntent(tap)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val note = notification(
            this,
            intent?.getStringExtra(EXTRA_TITLE) ?: "",
            intent?.getStringExtra(EXTRA_TEXT) ?: "",
            intent?.getIntExtra(EXTRA_DONE, 0) ?: 0,
            intent?.getIntExtra(EXTRA_TOTAL, 0) ?: 0,
        )
        val type = if (Build.VERSION.SDK_INT >= 34) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, note, type)
        } catch (e: Exception) {
            android.util.Log.w("ImportWorkService", "foreground: $e")
            stopSelf()
        }
        return START_NOT_STICKY
    }

    // Android 15+: the dataSync time (6 h a day) ran out.
    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }
}
