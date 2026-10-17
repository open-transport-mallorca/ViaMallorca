package es.opentransportmallorca.via

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/**
 * Keeps the app process running while a bus is tracked with the app
 * in the background
 */
class TrackingService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())

    /** A trip that never sent its close message must not drain the battery */
    private val timeout = Runnable {
        onEvent?.invoke(EVENT_DISMISSED)
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ViaMallorca:tracking")
            .apply {
                setReferenceCounted(false)
                acquire(MAX_DURATION_MS)
            }
        handler.postDelayed(timeout, MAX_DURATION_MS)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // startForegroundService() obliges us to call startForeground(), so
        // fall back to a bare notification rather than skip it
        val content = TrackingNotification.current ?: TrackingNotification.Content(
            title = applicationInfo.loadLabel(packageManager).toString(),
            body = null,
            subtitle = null,
            chip = null,
            progress = null,
            stopLabel = "",
            channelName = applicationInfo.loadLabel(packageManager).toString(),
            channelDescription = "",
        )
        val notification = TrackingNotification.build(this, content)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                TrackingNotification.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(TrackingNotification.NOTIFICATION_ID, notification)
        }
        // Not sticky: restarted without the Dart side, it would have nothing
        // to show.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(timeout)
        wakeLock?.release()
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        const val EVENT_STOP_REQUESTED = "onStopRequested"
        const val EVENT_DISMISSED = "onDismissed"
        private const val MAX_DURATION_MS = 3 * 60 * 60 * 1000L

        @Volatile
        var isRunning = false
            private set

        /** Forwards notification events to Dart; set while an engine is attached */
        var onEvent: ((String) -> Unit)? = null

        fun start(context: Context) {
            val intent = Intent(context, TrackingService::class.java)
            // Before Android 8 there are no background start limits, so a
            // plain start is enough; startForeground() still runs either way.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TrackingService::class.java))
        }
    }
}

class TrackingActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_STOP -> TrackingService.onEvent?.invoke(TrackingService.EVENT_STOP_REQUESTED)
            // Android 14+ lets users swipe away even a foreground service's
            // notification. Read that as "stop following in the background",
            // not "stop tracking"
            ACTION_DISMISSED -> TrackingService.onEvent?.invoke(TrackingService.EVENT_DISMISSED)
            else -> return
        }
        TrackingService.stop(context)
    }

    companion object {
        const val ACTION_STOP = "es.opentransportmallorca.via.tracking.STOP"
        const val ACTION_DISMISSED = "es.opentransportmallorca.via.tracking.DISMISSED"
    }
}
