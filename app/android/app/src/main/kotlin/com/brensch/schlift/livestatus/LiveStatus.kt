package com.brensch.schlift.livestatus

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import com.brensch.schlift.R

// / The workout at one stage, as the channel sends it (`now` or `then`): the
// / words, the stage's colour, and the stage's clock (a moment it counts up
// / from, or down to; 0 for none). The iPhone's Live Activity is drawn from
// / the same thing (`ios/LiveStatus/LiveStatusAttributes.swift`).
data class LiveStatusPhase(
    val title: String,
    val body: String,
    val stage: String,
    val color: Int,
    val clockMs: Long,
    val countDown: Boolean,
    // The stage as a letter, drawn as the notification's icon ("L" for
    // lifting); empty for the app's own mark.
    val glyph: String = "",
) {
    fun into(intent: Intent): Intent =
        intent
            .putExtra("glyph", glyph)
            .putExtra("title", title)
            .putExtra("body", body)
            .putExtra("stage", stage)
            .putExtra("color", color)
            .putExtra("clockMs", clockMs)
            .putExtra("countDown", countDown)

    companion object {
        // / A phase as the channel sends it; null when there is none.
        fun from(map: Map<*, *>?): LiveStatusPhase? {
            val title = map?.get("title") as? String ?: return null
            return LiveStatusPhase(
                title = title,
                body = map["detail"] as? String ?: "",
                stage = map["stage"] as? String ?: "",
                color = (map["color"] as? Number ?: 0).toInt(),
                clockMs = (map["clockMs"] as? Number ?: 0).toLong(),
                countDown = map["countDown"] as? Boolean ?: false,
                glyph = map["glyph"] as? String ?: "",
            )
        }

        fun from(intent: Intent): LiveStatusPhase? {
            val title = intent.getStringExtra("title") ?: return null
            return LiveStatusPhase(
                title = title,
                body = intent.getStringExtra("body").orEmpty(),
                stage = intent.getStringExtra("stage").orEmpty(),
                color = intent.getIntExtra("color", 0),
                clockMs = intent.getLongExtra("clockMs", 0),
                countDown = intent.getBooleanExtra("countDown", false),
                glyph = intent.getStringExtra("glyph").orEmpty(),
            )
        }
    }
}

// / The live status on Android: the live workout as a notification that
// / stays up. On Android 16 and later it is a Live Update (pinned to the top
// / of the shade and the lock screen, with a chip in the status bar), before
// / that an ordinary ongoing one. Its clock ticks by itself. A rest's end is
// / handed over by an alarm, so the status moves on with nothing of the app
// / running. Dart drives it over "schlift/live_status"
// / (`lib/services/live_status.dart`); the iPhone's is `ios/LiveStatus/`.
object LiveStatus {
    private const val CHANNEL = "workout_live_status"
    private const val ID = 2
    private const val AFTER_REST = 3

    fun show(
        context: Context,
        channelName: String,
        content: LiveStatusPhase,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java)
        // Seen, never heard: default importance keeps it out of the silent
        // pile, and it has no sound or buzz of its own.
        val channel =
            NotificationChannel(CHANNEL, channelName, NotificationManager.IMPORTANCE_DEFAULT).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
        manager.createNotificationChannel(channel)

        val open =
            PendingIntent.getActivity(
                context,
                0,
                context.packageManager.getLaunchIntentForPackage(context.packageName),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val builder =
            Notification
                .Builder(context, CHANNEL)
                .setSmallIcon(icon(context, content.glyph))
                .setContentTitle(content.title)
                .setContentText(content.body)
                .setColor(content.color)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setAutoCancel(false)
                .setCategory(Notification.CATEGORY_WORKOUT)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setContentIntent(open)
        if (content.clockMs > 0) {
            builder
                .setWhen(content.clockMs)
                .setShowWhen(true)
                .setUsesChronometer(true)
                .setChronometerCountDown(content.countDown)
        } else {
            builder.setShowWhen(false)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            // Ask to be a Live Update. The SDK this builds against has the
            // behaviour but not yet the setter: it is this extra
            // (NotificationCompat.EXTRA_REQUEST_PROMOTED_ONGOING).
            builder.addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
            // The chip says the stage until there is a clock to show.
            if (content.clockMs <= 0) builder.setShortCriticalText(content.stage)
        }
        manager.notify(ID, builder.build())
    }

    // / At `atMs` (a rest's end) the status becomes `content`.
    fun showAt(
        context: Context,
        channelName: String,
        atMs: Long,
        content: LiveStatusPhase,
    ) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val intent = handOver(context, content.into(Intent().putExtra("channel", channelName)))
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, intent)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, intent)
        }
    }

    // / The notification's small icon: the stage's letter, drawn bold and
    // / filling the square, or the app's mark when there is none. Android
    // / keeps only an icon's shape and colours it itself, so the letter is
    // / drawn in white on nothing.
    private fun icon(
        context: Context,
        glyph: String,
    ): Icon {
        if (glyph.isBlank()) return Icon.createWithResource(context, R.drawable.ic_stat_schlift)
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                typeface = wordFace(context)
                textAlign = Paint.Align.CENTER
                textSize = size * 1.05f
            }
        // Centred on the letter's own ink, not its line box.
        val bounds = Rect()
        paint.getTextBounds(glyph, 0, glyph.length, bounds)
        Canvas(bitmap).drawText(glyph, size / 2f, size / 2f - bounds.exactCenterY(), paint)
        return Icon.createWithBitmap(bitmap)
    }

    // / The app's own face for words (Space Grotesk Bold), from the fonts the
    // / Flutter app bundles; the system's bold if it can't be read.
    private var face: Typeface? = null

    private fun wordFace(context: Context): Typeface =
        face ?: try {
            Typeface.createFromAsset(
                context.assets,
                "flutter_assets/assets/google_fonts/SpaceGrotesk-Bold.ttf",
            )
        } catch (e: RuntimeException) {
            Typeface.DEFAULT_BOLD
        }.also { face = it }

    // / Nothing is waiting to replace the status any more.
    fun cancelPending(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(handOver(context, Intent()))
    }

    fun cancel(context: Context) {
        cancelPending(context)
        context.getSystemService(NotificationManager::class.java).cancel(ID)
    }

    private fun handOver(
        context: Context,
        extras: Intent,
    ): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            AFTER_REST,
            Intent(context, LiveStatusReceiver::class.java).putExtras(extras),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

// / The rest ran out: the status moves on to what the alarm carried.
class LiveStatusReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val content = LiveStatusPhase.from(intent) ?: return
        LiveStatus.show(context, intent.getStringExtra("channel").orEmpty(), content)
    }
}
