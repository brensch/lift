package com.brensch.lift.wear

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import workout.v1.Wearable

class PhoneMessageListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d("LiftWear", "Wear message received path=${messageEvent.path} bytes=${messageEvent.data.size}")
        if (messageEvent.path == WearTransport.PHONE_TO_WEAR_LAUNCH_PATH) {
            Log.i("LiftWear", "Phone requested watch activity launch")
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            runCatching { startActivity(intent) }
                .onFailure { Log.e("LiftWear", "Failed to launch watch activity from phone request", it) }
            return
        }
        if (messageEvent.path != WearTransport.PHONE_TO_WEAR_PATH) {
            super.onMessageReceived(messageEvent)
            return
        }

        runCatching {
            val envelope = Wearable.PhoneToWearEnvelope.parseFrom(messageEvent.data)
            if (envelope.hasSnapshot()) {
                val snapshot = envelope.snapshot
                Log.d(
                    "LiftWear",
                    "Parsed phone snapshot workoutId=${snapshot.workoutId} state=${snapshot.state} actions=${snapshot.actionsList.size}",
                )
                WearDataRepository.updateSnapshot(envelope.snapshot)
            }
        }
            .onFailure { Log.e("LiftWear", "Failed to parse phone message envelope", it) }
    }
}
