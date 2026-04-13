package com.brensch.schlift.wear

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import workout.v1.Wearable

class PhoneMessageListenerService : WearableListenerService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d("SchliftWear", "Wear message received path=${messageEvent.path} bytes=${messageEvent.data.size}")
        if (messageEvent.path == WearTransport.PHONE_TO_WEAR_LAUNCH_PATH) {
            Log.i("SchliftWear", "Phone requested watch activity launch")
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            runCatching { startActivity(intent) }
                .onFailure { Log.e("SchliftWear", "Failed to launch watch activity from phone request", it) }
            return
        }
        if (messageEvent.path == WearTransport.PHONE_TO_WEAR_CLOCK_SYNC_PATH) {
            val requestId = messageEvent.data.decodeToString()
            val payload = "$requestId:${System.currentTimeMillis()}".toByteArray()
            scope.launch {
                runCatching {
                    WearTransport.sendToPhone(this@PhoneMessageListenerService, WearTransport.WEAR_TO_PHONE_CLOCK_SYNC_PATH, payload)
                }.onFailure {
                    Log.e("SchliftWear", "Failed clock sync reply", it)
                }
            }
            return
        }
        if (messageEvent.path == WearTransport.PHONE_TO_WEAR_SENSOR_BATCH_ACK_PATH) {
            runCatching {
                val ack = Wearable.WearSensorBatchAck.parseFrom(messageEvent.data)
                WearSensorBatchOutbox.acknowledge(this, ack)
            }.onFailure {
                Log.e("SchliftWear", "Failed to parse sensor batch ack", it)
            }
            return
        }
        if (messageEvent.path != WearTransport.PHONE_TO_WEAR_SNAPSHOT_PATH) {
            super.onMessageReceived(messageEvent)
            return
        }

        runCatching {
            val snapshot = Wearable.WearWorkoutSnapshot.parseFrom(messageEvent.data)
            Log.d(
                "SchliftWear",
                "Parsed phone snapshot workoutId=${snapshot.workoutId} state=${snapshot.state} actions=${snapshot.actionsList.size}",
            )
            WearDataRepository.updateSnapshot(this, snapshot)
            val hasEndWorkoutAction = snapshot.actionsList.any {
                it.type == Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT
            }
            val activeWorkout = snapshot.workoutId.isNotBlank() &&
                (snapshot.state != workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE || hasEndWorkoutAction)
            if (activeWorkout) {
                WorkoutForegroundService.startOrUpdate(
                    this,
                    workoutLabel = "Workout in progress",
                    stateLabel = snapshot.youCard.stateLabel,
                    workoutId = snapshot.workoutId,
                    activeWorkout = true,
                    allowStartForeground = false,
                )
            } else {
                WorkoutForegroundService.stop(this)
            }
            WearSensorBatchOutbox.flush(this)
        }
            .onFailure { Log.e("SchliftWear", "Failed to parse phone snapshot", it) }
    }
}
