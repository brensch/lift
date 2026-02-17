package com.lift.lift.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
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
    private lateinit var exerciseSessionManager: WearExerciseSessionManager

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { grants ->
            val denied = grants.filterValues { granted -> !granted }.keys
            if (denied.isEmpty()) {
                WearDebugLog.add("Permissions granted")
                ensureCompanionSessionIfNeeded()
            } else {
                WearDebugLog.add("Permissions denied: ${denied.joinToString()}")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        heartRateStreamer = HeartRateStreamer(applicationContext)
        exerciseSessionManager = WearExerciseSessionManager(applicationContext)
        WearDebugLog.add("Watch app started")

        maybeRequestRuntimePermissions()

        setContent {
            MaterialTheme {
                WearApp(
                    onAction = { action -> sendAction(action) },
                    heartRateStreamer = heartRateStreamer,
                    exerciseSessionManager = exerciseSessionManager,
                    ensurePermissions = { maybeRequestRuntimePermissions() },
                )
            }
        }
    }

    private fun ensureCompanionSessionIfNeeded() {
        val snapshot = WearDataRepository.snapshot.value ?: return
        if (snapshot.workoutId.isBlank()) return
        if (snapshot.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) return
        heartRateStreamer.start(snapshot.workoutId)
        exerciseSessionManager.ensureSessionActive()
    }

    private fun maybeRequestRuntimePermissions() {
        val requiredPermissions = mutableListOf(
            Manifest.permission.BODY_SENSORS,
            Manifest.permission.ACTIVITY_RECOGNITION,
        ).apply {
            if (Build.VERSION.SDK_INT >= 36) {
                add("android.permission.health.READ_HEART_RATE")
            }
        }
        val missing = requiredPermissions.filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            WearDebugLog.add("Requesting perms: ${missing.joinToString()}")
            permissionLauncher.launch(missing.toTypedArray())
        } else {
            WearDebugLog.add("Runtime perms already granted")
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
                val sent = WearTransport.sendToPhone(
                    this@MainActivity,
                    WearTransport.WEAR_TO_PHONE_PATH,
                    envelope.toByteArray(),
                )
                if (sent == 0) {
                    throw IllegalStateException("No connected phone node")
                }
            }.onFailure { error ->
                Log.e("LiftWear", "Failed to send action to phone", error)
                WearDebugLog.add("Action send failed: ${error.message ?: error.javaClass.simpleName}")
                Toast.makeText(
                    this@MainActivity,
                    "Phone not connected",
                    Toast.LENGTH_SHORT,
                ).show()
            }
        }
    }
}

@Composable
private fun WearApp(
    onAction: (Wearable.WearAction) -> Unit,
    heartRateStreamer: HeartRateStreamer,
    exerciseSessionManager: WearExerciseSessionManager,
    ensurePermissions: () -> Unit,
) {
    val snapshot by WearDataRepository.snapshot.collectAsState()
    val debugLines by WearDebugLog.lines.collectAsState()

    DisposableEffect(snapshot?.workoutId, snapshot?.state) {
        val shouldStream = snapshot?.workoutId?.isNotEmpty() == true &&
            snapshot?.state != workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE
        if (shouldStream) {
            ensurePermissions()
            WearDebugLog.add("Workout active; enabling HR/session")
            heartRateStreamer.start(snapshot!!.workoutId)
            exerciseSessionManager.ensureSessionActive()
        } else {
            WearDebugLog.add("Workout inactive; disabling HR/session")
            heartRateStreamer.stop()
            exerciseSessionManager.endSessionIfActive()
        }
        onDispose {
            heartRateStreamer.stop()
            exerciseSessionManager.endSessionIfActive()
        }
    }

    if (snapshot == null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 14.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            TimeText()
            Text("LIFT", style = MaterialTheme.typography.title2)
            Spacer(modifier = Modifier.height(6.dp))
            Text("Waiting for phone", style = MaterialTheme.typography.caption2)
            Spacer(modifier = Modifier.height(8.dp))
            DebugPanel(lines = debugLines)
        }
        return
    }

    val data = snapshot!!
    val repActions = data.actionsList.filter {
        it.style == Wearable.WearActionStyle.WEAR_ACTION_STYLE_REP_OPTION
    }
    val mainActions = data.actionsList.filter {
        it.style != Wearable.WearActionStyle.WEAR_ACTION_STYLE_REP_OPTION
    }

    ScalingLazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 8.dp),
        contentPadding = PaddingValues(top = 2.dp, bottom = 8.dp),
    ) {
        item {
            StatusPanel(
                label = data.youCard.sideLabel.ifEmpty { "YOU" },
                state = data.youCard.stateLabel,
                timer = data.youCard.timerText,
                setText = if (data.youCard.hasDisplaySet()) {
                    val set = data.youCard.displaySet
                    "${set.targetWeight.toInt()}kg x ${set.targetReps}"
                } else {
                    ""
                },
                accent = Color(0xFF4ADE80),
            )
        }

        if (data.hasGroupCard()) {
            item {
                StatusPanel(
                    label = data.groupCard.sideLabel.ifEmpty { "GROUP" },
                    state = data.groupCard.stateLabel,
                    timer = data.groupCard.timerText,
                    setText = if (data.groupCard.hasDisplaySet()) {
                        val set = data.groupCard.displaySet
                        "${set.targetWeight.toInt()}kg x ${set.targetReps}"
                    } else {
                        data.groupCard.header
                    },
                    accent = Color(0xFF60A5FA),
                )
            }
        }

        item {
            Chip(
                onClick = {},
                enabled = false,
                label = { Text("Elapsed ${data.elapsedText}") },
                colors = ChipDefaults.secondaryChipColors(),
            )
        }

        if (repActions.isNotEmpty()) {
            item {
                Text(
                    "LOG REPS",
                    style = MaterialTheme.typography.caption2,
                    modifier = Modifier.padding(start = 6.dp, top = 4.dp),
                )
            }
            items(repActions) { action ->
                Button(
                    onClick = { onAction(action) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(action.label)
                }
            }
        }

        if (mainActions.isNotEmpty()) {
            item {
                Text(
                    "ACTIONS",
                    style = MaterialTheme.typography.caption2,
                    modifier = Modifier.padding(start = 6.dp, top = 4.dp),
                )
            }
        }
        items(mainActions) { action ->
            Button(
                onClick = { onAction(action) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(action.label)
            }
        }

        item {
            DebugPanel(lines = debugLines)
        }
    }
}

@Composable
private fun DebugPanel(lines: List<String>) {
    val recent = lines.takeLast(6).asReversed()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = MaterialTheme.colors.surface,
                shape = RoundedCornerShape(12.dp),
            )
            .border(
                width = 1.dp,
                color = Color(0xFFF59E0B).copy(alpha = 0.45f),
                shape = RoundedCornerShape(12.dp),
            )
            .padding(horizontal = 8.dp, vertical = 6.dp),
    ) {
        Text("DEBUG", color = Color(0xFFF59E0B), style = MaterialTheme.typography.caption3)
        if (recent.isEmpty()) {
            Text("No logs yet", style = MaterialTheme.typography.caption3)
            return
        }
        for (line in recent) {
            Text(
                line,
                style = MaterialTheme.typography.caption3,
                maxLines = 3,
                overflow = TextOverflow.Clip,
            )
        }
    }
}

@Composable
private fun StatusPanel(
    label: String,
    state: String,
    timer: String,
    setText: String,
    accent: Color,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = MaterialTheme.colors.surface,
                shape = RoundedCornerShape(14.dp),
            )
            .border(
                width = 1.dp,
                color = accent.copy(alpha = 0.45f),
                shape = RoundedCornerShape(14.dp),
            )
            .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, color = accent, style = MaterialTheme.typography.caption3)
            if (timer.isNotEmpty()) {
                Text(timer, style = MaterialTheme.typography.caption1)
            }
        }
        Spacer(modifier = Modifier.height(2.dp))
        Text(state, style = MaterialTheme.typography.title3)
        if (setText.isNotEmpty()) {
            Spacer(modifier = Modifier.height(2.dp))
            Text(setText, style = MaterialTheme.typography.caption2)
        }
    }
}
