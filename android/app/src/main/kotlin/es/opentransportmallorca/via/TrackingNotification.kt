package es.opentransportmallorca.via

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import kotlin.math.roundToInt

internal object TrackingNotification {
    const val CHANNEL_ID = "bus_tracking"
    const val NOTIFICATION_ID = 0x56494131 // "VIA1", clear of the reminder ids
    private const val PROGRESS_MAX = 100
    private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

    data class Content(
        val title: String,
        val body: String?,
        val subtitle: String?,
        val chip: String?,
        val progress: Double?,
        val stopLabel: String,
        val channelName: String,
        val channelDescription: String,
    ) {
        companion object {
            fun fromMap(map: Map<*, *>) = Content(
                title = map["title"] as String,
                body = map["body"] as String?,
                subtitle = map["subtitle"] as String?,
                chip = map["chip"] as String?,
                progress = (map["progress"] as Number?)?.toDouble(),
                stopLabel = map["stopLabel"] as String,
                channelName = map["channelName"] as String,
                channelDescription = map["channelDescription"] as String,
            )
        }
    }

    @Volatile
    var current: Content? = null

    fun post(context: Context, content: Content) {
        context.getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, build(context, content))
    }

    fun build(context: Context, content: Content): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ensureChannel(context, content)
            Notification.Builder(context, CHANNEL_ID)
        } else {
            // No channels before Android 8: default priority and no defaults
            // set is the same quiet-but-visible combination
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_DEFAULT)
        }
        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(content.title)
            .setContentText(content.body)
            .setSubText(content.subtitle)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(openAppIntent(context))
            .setDeleteIntent(actionIntent(context, TrackingActionReceiver.ACTION_DISMISSED))
            .addAction(
                Notification.Action.Builder(
                    null as Icon?,
                    content.stopLabel,
                    actionIntent(context, TrackingActionReceiver.ACTION_STOP),
                ).build()
            )

        // Foreground service notifications are otherwise held back for up to
        // ten seconds, which is most of the wait for the first fix.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }

        val progress = content.progress?.coerceIn(0.0, 1.0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            builder.addExtras(Bundle().apply {
                putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
            })
            content.chip?.let { builder.setShortCriticalText(it) }
            val style = Notification.ProgressStyle()
                .setProgressTrackerIcon(Icon.createWithResource(context, R.drawable.ic_tracker_bus))
            if (progress == null) {
                style.setProgressIndeterminate(true)
            } else {
                style.setProgress((progress * PROGRESS_MAX).roundToInt())
            }
            builder.setStyle(style)
        } else if (progress == null) {
            builder.setProgress(0, 0, true)
        } else {
            builder.setProgress(PROGRESS_MAX, (progress * PROGRESS_MAX).roundToInt(), false)
        }

        return builder.build()
    }

    /**
     * Creates the channel, or renames it after a language change.
     *
     * Default importance with the sound and vibration removed, not low:
     * low counts as silent, and the lock screen hides silent notifications by
     * default. Importance is fixed once a channel exists, hence a new id.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    private fun ensureChannel(context: Context, content: Content) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            content.channelName,
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = content.channelDescription
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun actionIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, TrackingActionReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
