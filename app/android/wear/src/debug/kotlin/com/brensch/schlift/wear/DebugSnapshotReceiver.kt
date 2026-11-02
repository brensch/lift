package com.brensch.schlift.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Base64
import android.util.Log
import workout.v1.Wearable

/**
 * Debug builds only: takes a WearWorkoutSnapshot over adb, as the phone
 * would send it, so the face can be shown (and screenshotted for the
 * stores) on an emulator with no phone paired.
 *
 *     adb shell am broadcast -n com.brensch.schlift.debug/com.brensch.schlift.wear.DebugSnapshotReceiver \
 *       --es snapshot <base64 WearWorkoutSnapshot> [--ef bpm 132]
 *
 * An emulator has no heart-rate sensor: `bpm` stands in for its reading.
 */
class DebugSnapshotReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (intent.hasExtra("bpm")) {
            WearDataRepository.updateLatestBpm(intent.getFloatExtra("bpm", 0f))
        }
        val encoded = intent.getStringExtra("snapshot") ?: return
        runCatching {
            val snapshot = Wearable.WearWorkoutSnapshot.parseFrom(Base64.decode(encoded, Base64.DEFAULT))
            WearDataRepository.updateSnapshot(context, snapshot)
        }.onFailure { Log.e("SchliftWear", "Bad debug snapshot", it) }
    }
}
