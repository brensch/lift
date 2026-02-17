package com.lift.lift.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import workout.v1.Wearable

class MainActivity : ComponentActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var heartRateStreamer: HeartRateStreamer

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { _ -> }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        heartRateStreamer = HeartRateStreamer(applicationContext)

        maybeRequestHeartRatePermission()

        setContent {
            MaterialTheme {
                WearApp(
                    onAction = { action -> sendAction(action) },
                    heartRateStreamer = heartRateStreamer,
                )
            }
        }
    }

    private fun maybeRequestHeartRatePermission() {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.BODY_SENSORS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            permissionLauncher.launch(Manifest.permission.BODY_SENSORS)
        }
    }

    private fun sendAction(action: Wearable.WearAction) {
        val workoutId = WearDataRepository.snapshot.value?.workoutId ?: return

        val intent = when (action.type) {
            Wearable.WearActionType.WEAR_ACTION_TYPE_START_SET -> {
                Wearable.WearIntent.newBuilder().setStartSet(
                    Wearable.StartSetIntent.newBuilder()
                        .setWorkoutId(workoutId)
                        .setSetId(action.setId)
                        .build(),
                ).build()
            }

            Wearable.WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET -> {
                Wearable.WearIntent.newBuilder().setCompleteSet(
                    Wearable.CompleteSetIntent.newBuilder()
                        .setWorkoutId(workoutId)
                        .setSetId(action.setId)
                        .setReps(action.reps)
                        .setActualWeight(action.actualWeight)
                        .build(),
                ).build()
            }

            Wearable.WearActionType.WEAR_ACTION_TYPE_SKIP_WARMUP -> {
                Wearable.WearIntent.newBuilder().setSkipWarmup(
                    Wearable.SkipWarmupIntent.newBuilder()
                        .setWorkoutId(workoutId)
                        .setSetId(action.setId)
                        .build(),
                ).build()
            }

            Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT -> {
                Wearable.WearIntent.newBuilder().setEndWorkout(
                    Wearable.EndWorkoutIntent.newBuilder()
                        .setWorkoutId(workoutId)
                        .build(),
                ).build()
            }

            else -> return
        }.toBuilder()
            .setIntentId(java.util.UUID.randomUUID().toString())
            .setSentAt(System.currentTimeMillis() / 1000)
            .build()

        val envelope = Wearable.WearToPhoneEnvelope.newBuilder()
            .setIntent(intent)
            .build()

        scope.launch {
            runCatching {
                WearTransport.sendToPhone(
                    this@MainActivity,
                    WearTransport.WEAR_TO_PHONE_PATH,
                    envelope.toByteArray(),
                )
            }
        }
    }
}

@Composable
private fun WearApp(
    onAction: (Wearable.WearAction) -> Unit,
    heartRateStreamer: HeartRateStreamer,
) {
    val snapshot by WearDataRepository.snapshot.collectAsState()

    DisposableEffect(snapshot?.workoutId, snapshot?.state) {
        val shouldStream = snapshot?.workoutId?.isNotEmpty() == true &&
            snapshot?.state != workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE
        if (shouldStream) {
            heartRateStreamer.start(snapshot!!.workoutId)
        } else {
            heartRateStreamer.stop()
        }
        onDispose { heartRateStreamer.stop() }
    }

    if (snapshot == null) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            TimeText()
            Text("Waiting for phone")
        }
        return
    }

    val data = snapshot!!

    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp),
        contentPadding = PaddingValues(vertical = 12.dp),
    ) {
        item { TimeText() }
        item { Text("${data.youCard.sideLabel}: ${data.youCard.stateLabel}") }
        if (data.youCard.timerText.isNotEmpty()) {
            item { Text(data.youCard.timerText) }
        }
        if (data.youCard.hasDisplaySet()) {
            val set = data.youCard.displaySet
            item { Text("${set.targetWeight.toInt()}kg x ${set.targetReps}") }
        }

        if (data.hasGroupCard()) {
            item { Text("${data.groupCard.sideLabel}: ${data.groupCard.stateLabel}") }
            if (data.groupCard.timerText.isNotEmpty()) {
                item { Text(data.groupCard.timerText) }
            }
        }

        item { Text("Elapsed ${data.elapsedText}") }

        items(data.actionsList) { action ->
            Button(onClick = { onAction(action) }) {
                Text(action.label)
            }
        }
    }
}
