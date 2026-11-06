package com.nemanjapejic.commonplace

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
import android.util.Log

/**
 * Keeps Commonplace running while it makes notes, so leaving the app (back to
 * Instagram, say) doesn't freeze it halfway through sending a video to the
 * AI. Android shows a quiet "Making your note" notification for as long as
 * this runs; the Dart side stops it as soon as the queue is empty.
 */
class NoteWorkService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: getString(R.string.making_notes)
        val notification = notification(this, text)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(ID, notification)
            }
            running = true
            if (stopRequested) {
                // Asked to stop before it had started: Android requires the
                // startForeground() call above first, or it ends the app.
                stopRequested = false
                stopSelf()
            }
        } catch (e: Exception) {
            // Started while in the background on Android 12+, or over the
            // daily data-sync allowance: notes continue while the app is open.
            Log.w(TAG, "Couldn't keep running in the background", e)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    /** The app was swiped away: the work went with it. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
    }

    /** Android 15 caps data-sync work per day; give way when asked. */
    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }

    companion object {
        private const val TAG = "NoteWorkService"
        private const val ID = 4201
        private const val CHANNEL = "notes_in_progress"
        private const val EXTRA_TEXT = "text"

        /** startForeground() has been called; stopping is safe. */
        @Volatile private var running = false

        /** Stop as soon as the start has gone through. */
        @Volatile private var stopRequested = false

        fun start(context: Context, text: String) {
            stopRequested = false
            val intent = Intent(context, NoteWorkService::class.java).putExtra(EXTRA_TEXT, text)
            try {
                context.startForegroundService(intent)
            } catch (e: Exception) {
                Log.w(TAG, "Couldn't start background work", e)
            }
        }

        fun stop(context: Context) {
            if (running) {
                context.stopService(Intent(context, NoteWorkService::class.java))
            } else {
                stopRequested = true
            }
        }

        private fun notification(context: Context, text: String): Notification {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL,
                        context.getString(R.string.making_notes_channel),
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply { setShowBadge(false) },
                )
            }
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            return Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(text)
                .setContentText(context.getString(R.string.making_notes_detail))
                .setContentIntent(open)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setProgress(0, 0, true)
                .build()
        }
    }
}
