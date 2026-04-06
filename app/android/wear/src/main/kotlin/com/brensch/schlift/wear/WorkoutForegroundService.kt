package com.brensch.schlift.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status

class WorkoutForegroundService : Service() {
    private lateinit var heartRateStreamer: HeartRateStreamer
    private lateinit var exerciseSessionManager: WearExerciseSessionManager

    override fun onCreate() {
        super.onCreate()
        heartRateStreamer = HeartRateStreamer(applicationContext)
        exerciseSessionManager = WearExerciseSessionManager(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopWorkoutTracking()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START, ACTION_UPDATE, null -> {
                val workoutLabel = intent?.getStringExtra(EXTRA_WORKOUT_LABEL).orEmpty()
                val stateLabel = intent?.getStringExtra(EXTRA_STATE_LABEL).orEmpty()
                val workoutId = intent?.getStringExtra(EXTRA_WORKOUT_ID).orEmpty()
                val activeWorkout = intent?.getBooleanExtra(EXTRA_ACTIVE_WORKOUT, false) == true
                startWorkoutForeground(buildNotification(workoutLabel, stateLabel))
                syncWorkoutTracking(workoutId, activeWorkout)
                return START_STICKY
            }

            else -> return START_NOT_STICKY
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopWorkoutTracking()
        super.onDestroy()
    }

    private fun startWorkoutForeground(notification: Notification) {
        createNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
            )
        } else {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, 0)
        }
    }

    private fun buildNotification(workoutLabel: String, stateLabel: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val launchPendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = if (workoutLabel.isNotBlank()) workoutLabel else "Workout in progress"
        val content = when {
            stateLabel.isNotBlank() -> stateLabel
            else -> "Tracking workout and heart rate"
        }
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(launchPendingIntent)
        val ongoingStatus = Status.Builder()
            .addTemplate(content)
            .build()
        OngoingActivity.Builder(
            this,
            NOTIFICATION_ID,
            notificationBuilder,
        ).apply {
            setAnimatedIcon(Icon.createWithResource(this@WorkoutForegroundService, R.drawable.ic_ongoing_workout))
            setStaticIcon(Icon.createWithResource(this@WorkoutForegroundService, R.drawable.ic_ongoing_workout))
            setTouchIntent(launchPendingIntent)
            setStatus(ongoingStatus)
        }.build().apply(this)
        return notificationBuilder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Workout tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Ongoing workout tracking on Wear OS"
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "workout_tracking"
        private const val NOTIFICATION_ID = 1001
        private const val EXTRA_WORKOUT_LABEL = "extra_workout_label"
        private const val EXTRA_STATE_LABEL = "extra_state_label"
        private const val EXTRA_WORKOUT_ID = "extra_workout_id"
        private const val EXTRA_ACTIVE_WORKOUT = "extra_active_workout"
        private const val ACTION_START = "com.brensch.schlift.wear.action.START_WORKOUT_FOREGROUND"
        private const val ACTION_UPDATE = "com.brensch.schlift.wear.action.UPDATE_WORKOUT_FOREGROUND"
        private const val ACTION_STOP = "com.brensch.schlift.wear.action.STOP_WORKOUT_FOREGROUND"

        fun startOrUpdate(
            context: Context,
            workoutLabel: String,
            stateLabel: String,
            workoutId: String,
            activeWorkout: Boolean,
        ) {
            val intent = Intent(context, WorkoutForegroundService::class.java).apply {
                action = if (activeWorkout) ACTION_START else ACTION_UPDATE
                putExtra(EXTRA_WORKOUT_LABEL, workoutLabel)
                putExtra(EXTRA_STATE_LABEL, stateLabel)
                putExtra(EXTRA_WORKOUT_ID, workoutId)
                putExtra(EXTRA_ACTIVE_WORKOUT, activeWorkout)
            }
            if (activeWorkout) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, WorkoutForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private fun syncWorkoutTracking(workoutId: String, activeWorkout: Boolean) {
        if (!activeWorkout || workoutId.isBlank()) {
            Log.i("SchliftWear", "Stopping workout tracking active=$activeWorkout workoutId=$workoutId")
            stopWorkoutTracking()
            return
        }
        Log.i("SchliftWear", "Foreground service tracking workoutId=$workoutId")
        heartRateStreamer.start(workoutId)
        exerciseSessionManager.ensureSessionActive()
    }

    private fun stopWorkoutTracking() {
        heartRateStreamer.stop()
        exerciseSessionManager.endSessionIfActive()
        WearDataRepository.updateLatestBpm(null)
    }
}
