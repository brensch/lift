package com.lift.lift.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Picker
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.rememberPickerState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import workout.v1.Wearable

class MainActivity : ComponentActivity() {
    private val scope = kotlinx.coroutines.CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var heartRateStreamer: HeartRateStreamer
    private lateinit var exerciseSessionManager: WearExerciseSessionManager

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { _ ->
            ensureCompanionSessionIfNeeded()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        heartRateStreamer = HeartRateStreamer(applicationContext)
        exerciseSessionManager = WearExerciseSessionManager(applicationContext)

        maybeRequestRuntimePermissions()

        setContent {
            WearApp(
                onAction = { action -> sendAction(action) },
                heartRateStreamer = heartRateStreamer,
                exerciseSessionManager = exerciseSessionManager,
                ensurePermissions = { maybeRequestRuntimePermissions() },
            )
        }
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
            permissionLauncher.launch(missing.toTypedArray())
        }
    }

    private fun ensureCompanionSessionIfNeeded() {
        val snapshot = WearDataRepository.snapshot.value ?: return
        if (snapshot.workoutId.isBlank()) return
        if (snapshot.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) return
        heartRateStreamer.start(snapshot.workoutId)
        exerciseSessionManager.ensureSessionActive()
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
                        .setCompletedAt(System.currentTimeMillis() / 1000)
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
    val latestBpm by heartRateStreamer.latestBpm.collectAsState()

    if (snapshot == null) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text("Waiting for phone", color = Color.White)
        }
        return
    }

    val data = snapshot!!
    val currentSet = if (data.youCard.hasDisplaySet()) data.youCard.displaySet else null
    val completeTemplate = data.actionsList.firstOrNull {
        it.type == Wearable.WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET
    }
    val isLiftingCompleteMode =
        data.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_LIFTING &&
            currentSet != null &&
            completeTemplate != null
    val primaryAction = data.actionsList.firstOrNull {
        it.style == Wearable.WearActionStyle.WEAR_ACTION_STYLE_PRIMARY
    } ?: data.actionsList.firstOrNull()
    val secondaryAction = data.actionsList.firstOrNull {
        it.style == Wearable.WearActionStyle.WEAR_ACTION_STYLE_SECONDARY
    }

    DisposableEffect(data.workoutId, data.state) {
        val shouldStream = data.workoutId.isNotEmpty() &&
            data.state != workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE
        if (shouldStream) {
            ensurePermissions()
            heartRateStreamer.start(data.workoutId)
            exerciseSessionManager.ensureSessionActive()
        } else {
            heartRateStreamer.stop()
            exerciseSessionManager.endSessionIfActive()
        }
        onDispose {
            heartRateStreamer.stop()
            exerciseSessionManager.endSessionIfActive()
        }
    }

    val hrColor = heartRateColor(latestBpm)
    val startLabel = buildStartLabel(primaryAction, currentSet)
    val maxReps = currentSet?.targetReps ?: 0
    val pickerState = rememberPickerState(
        initialNumberOfOptions = (maxReps + 1).coerceAtLeast(1),
        initiallySelectedOption = maxReps.coerceAtLeast(0),
    )

    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF090B10)),
    ) {
        Column(
            modifier = Modifier
                .weight(0.5f)
                .fillMaxHeight()
                .padding(start = 8.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.End,
        ) {
            MidLineText(data.youCard.stateLabel, Color.White)
            if (data.youCard.timerText.isNotEmpty()) {
                MidLineText(data.youCard.timerText, Color(0xFF93C5FD))
            }
            if (currentSet != null) {
                MidLineText(
                    "${currentSet.targetReps}x${currentSet.targetWeight.toInt()}",
                    Color(0xFFD8B4FE),
                )
            }
            if (data.hasGroupCard()) {
                MidLineText("G ${data.groupCard.stateLabel}", Color(0xFF86EFAC))
            }
            MidLineText("T ${data.elapsedText}", Color(0xFFCBD5E1))
            MidLineText(
                if (latestBpm != null) "HR ${latestBpm!!.toInt()}" else "HR --",
                hrColor,
            )
        }

        Spacer(modifier = Modifier.width(0.dp))

        Column(
            modifier = Modifier
                .weight(0.5f)
                .fillMaxHeight(),
            verticalArrangement = Arrangement.Center,
        ) {
            if (!isLiftingCompleteMode) {
                Button(
                    onClick = { if (primaryAction != null) onAction(primaryAction) },
                    enabled = primaryAction != null,
                    modifier = Modifier.fillMaxSize(),
                    shape = RoundedCornerShape(0.dp),
                ) {
                    Text(
                        text = startLabel,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        fontSize = 18.sp,
                    )
                }
            } else {
                Box(modifier = Modifier.fillMaxSize()) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .fillMaxWidth()
                            .fillMaxHeight(0.5f),
                        contentAlignment = Alignment.Center,
                    ) {
                        Picker(
                            modifier = Modifier
                                .fillMaxWidth()
                                .fillMaxHeight(0.7f),
                            state = pickerState,
                            gradientRatio = 0.1f,
                            contentDescription = "Completed reps picker",
                            option = { index ->
                                Text(
                                    text = index.toString(),
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier.fillMaxWidth(),
                                    fontSize = if (index == pickerState.selectedOption) 38.sp else 24.sp,
                                    color = if (index == pickerState.selectedOption) Color.White else Color(0xFF9CA3AF),
                                )
                            },
                        )
                    }
                    Button(
                        onClick = {
                            val set = currentSet
                            val template = completeTemplate
                            if (set != null && template != null) {
                                val action = template.toBuilder()
                                    .setSetId(set.id)
                                    .setReps(pickerState.selectedOption)
                                    .setActualWeight(
                                        if (template.actualWeight > 0f) template.actualWeight else set.targetWeight,
                                    )
                                    .build()
                                onAction(action)
                            }
                        },
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .fillMaxWidth()
                            .fillMaxHeight(0.5f),
                        shape = RoundedCornerShape(0.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(start = 10.dp, top = 8.dp),
                            contentAlignment = Alignment.TopStart,
                        ) {
                            Text(
                                text = "Completed\nreps",
                                fontSize = 15.sp,
                                textAlign = TextAlign.Start,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MidLineText(text: String, color: Color) {
    Text(
        text = text,
        color = color,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        textAlign = TextAlign.End,
        modifier = Modifier.fillMaxWidth(),
        fontSize = 17.sp,
    )
}

private fun heartRateColor(bpm: Float?): Color {
    if (bpm == null || bpm <= 0f) return Color(0xFF94A3B8)
    return when {
        bpm < 110f -> Color(0xFF22C55E)
        bpm < 140f -> Color(0xFFFACC15)
        bpm < 165f -> Color(0xFFF97316)
        else -> Color(0xFFEF4444)
    }
}

private fun buildStartLabel(
    primaryAction: Wearable.WearAction?,
    currentSet: workout.v1.WorkoutOuterClass.ProposedSet?,
): String {
    if (primaryAction == null) return "Action"
    if (primaryAction.type != Wearable.WearActionType.WEAR_ACTION_TYPE_START_SET || currentSet == null) {
        return primaryAction.label
    }
    val exerciseName = formatExerciseName(currentSet.exercise.name)
    return "Start ${currentSet.targetReps}x${currentSet.targetWeight.toInt()} $exerciseName"
}

private fun formatExerciseName(raw: String): String {
    return raw
        .removePrefix("EXERCISE_")
        .lowercase()
        .split('_')
        .joinToString(" ") { part -> part.replaceFirstChar { it.uppercase() } }
}
