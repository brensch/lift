package com.brensch.lift.wear

import android.Manifest
import android.annotation.SuppressLint
import android.content.ComponentCallbacks2
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.wear.ambient.AmbientLifecycleObserver
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.HourglassBottom
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.LocalTextStyle
import androidx.wear.compose.material.Picker
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.rememberPickerState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import workout.v1.Wearable

private val WearBodyFontFamily = FontFamily(
    Font(R.font.manrope_variable, weight = FontWeight.Normal),
    Font(R.font.manrope_variable, weight = FontWeight.Medium),
    Font(R.font.manrope_variable, weight = FontWeight.SemiBold),
    Font(R.font.manrope_variable, weight = FontWeight.Bold),
)

private val WearDisplayFontFamily = FontFamily(
    Font(R.font.space_grotesk_variable, weight = FontWeight.Medium),
    Font(R.font.space_grotesk_variable, weight = FontWeight.Bold),
)

// Match mobile app workout state accents:
// Lifting/Warmup pink: 0xFFEC4899
// Resting blue: 0xFF3B82F6
// Yapping orange: 0xFFF97316
private val MobileLiftingPink = Color(0xFFEC4899)
private val MobileRestingBlue = Color(0xFF3B82F6)
private val MobileYappingOrange = Color(0xFFF97316)
private const val LiftWearTag = "LiftWear"

class MainActivity : ComponentActivity() {
    private val scope = kotlinx.coroutines.CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var uiHeartbeatJob: kotlinx.coroutines.Job? = null
    private lateinit var heartRateStreamer: HeartRateStreamer
    private lateinit var exerciseSessionManager: WearExerciseSessionManager
    private var heartRatePermissionRequestInFlight = false
    private var workoutPermissionRequestInFlight = false
    private var heartRatePermissionRequestedOnce = false
    private var workoutPermissionRequestedOnce = false
    private var keepScreenOnForWorkout = false

    private val ambientCallback = object : AmbientLifecycleObserver.AmbientLifecycleCallback {
        override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) {
            logLifecycleEvent("ambient onEnter", "details=$ambientDetails")
        }

        override fun onExitAmbient() {
            logLifecycleEvent("ambient onExit")
        }

        override fun onUpdateAmbient() {
            logLifecycleEvent("ambient onUpdate")
        }
    }
    private val ambientObserver = AmbientLifecycleObserver(this, ambientCallback)

    @SuppressLint("InvalidFragmentVersionForActivityResult")
    private val heartRatePermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            heartRatePermissionRequestInFlight = false
            Log.i(LiftWearTag, "Heart-rate permission result=$result")
            if (hasHeartRatePermissions()) {
                maybeRequestRuntimePermissions()
            } else {
                Log.w(LiftWearTag, "Required heart-rate permissions still missing after request")
            }
        }

    @SuppressLint("InvalidFragmentVersionForActivityResult")
    private val workoutPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            workoutPermissionRequestInFlight = false
            Log.i(LiftWearTag, "Workout permission result=$result")
            if (hasWorkoutPermissions()) {
                ensureCompanionSessionIfNeeded()
            } else {
                Log.w(LiftWearTag, "Required workout permissions still missing after request")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logLifecycleEvent(
            "onCreate",
            "saved=${savedInstanceState != null} intentFlags=0x${intent?.flags?.toString(16) ?: "0"}",
        )
        lifecycle.addObserver(ambientObserver)
        heartRateStreamer = HeartRateStreamer(applicationContext)
        exerciseSessionManager = WearExerciseSessionManager(applicationContext)

        setContent {
            WearApp(
                onAction = { action -> sendAction(action) },
                heartRateStreamer = heartRateStreamer,
                exerciseSessionManager = exerciseSessionManager,
                ensurePermissions = { maybeRequestRuntimePermissions() },
                setWorkoutKeepScreenOn = { enabled -> setWorkoutKeepScreenOn(enabled) },
            )
        }
    }

    override fun onStart() {
        super.onStart()
        logLifecycleEvent("onStart")
    }

    override fun onResume() {
        super.onResume()
        logLifecycleEvent("onResume")
        startUiHeartbeat()
        maybeRequestRuntimePermissions()
    }

    override fun onPause() {
        logLifecycleEvent("onPause")
        stopUiHeartbeat()
        super.onPause()
    }

    override fun onStop() {
        logLifecycleEvent("onStop")
        super.onStop()
    }

    override fun onDestroy() {
        logLifecycleEvent("onDestroy")
        setWorkoutKeepScreenOn(false)
        stopUiHeartbeat()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        logLifecycleEvent(
            "onNewIntent",
            "flags=0x${intent.flags.toString(16)} action=${intent.action}",
        )
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        logLifecycleEvent("onUserLeaveHint")
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        logLifecycleEvent("onWindowFocusChanged", "hasFocus=$hasFocus")
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        logLifecycleEvent("onTrimMemory", "level=$level(${trimMemoryLevelName(level)})")
    }

    private fun startUiHeartbeat() {
        if (uiHeartbeatJob?.isActive == true) return
        Log.i(LiftWearTag, "Starting UI heartbeat")
        uiHeartbeatJob = scope.launch {
            while (true) {
                runCatching {
                    WearTransport.sendToPhone(
                        this@MainActivity,
                        WearTransport.WEAR_TO_PHONE_UI_HEARTBEAT_PATH,
                        ByteArray(0),
                    )
                }.onFailure {
                    Log.d(LiftWearTag, "UI heartbeat not delivered", it)
                }
                delay(3000)
            }
        }
    }

    private fun stopUiHeartbeat() {
        if (uiHeartbeatJob != null) {
            Log.i(LiftWearTag, "Stopping UI heartbeat")
        }
        uiHeartbeatJob?.cancel()
        uiHeartbeatJob = null
    }

    private fun setWorkoutKeepScreenOn(enabled: Boolean) {
        if (keepScreenOnForWorkout == enabled) return
        keepScreenOnForWorkout = enabled
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        Log.i(LiftWearTag, "Workout keep-screen-on set to $enabled")
    }

    private fun requiredHeartRatePermissions(): List<String> {
        val required = mutableListOf<String>()
        if (!hasHeartRatePermissions()) {
            required += Manifest.permission.BODY_SENSORS
        }
        if (Build.VERSION.SDK_INT >= 36 && !hasReadHeartRatePermission()) {
            required += "android.permission.health.READ_HEART_RATE"
        }
        return required.distinct()
    }

    private fun hasHeartRatePermissions(): Boolean {
        return hasBodySensorsPermission() || hasReadHeartRatePermission()
    }

    private fun hasBodySensorsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.BODY_SENSORS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasReadHeartRatePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            "android.permission.health.READ_HEART_RATE",
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasExerciseSessionHeartRatePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= 36) {
            hasReadHeartRatePermission()
        } else {
            hasBodySensorsPermission()
        }
    }

    private fun requiredWorkoutPermissions(): List<String> {
        return listOf(Manifest.permission.ACTIVITY_RECOGNITION)
    }

    private fun hasWorkoutPermissions(): Boolean {
        return requiredWorkoutPermissions().all { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestHeartRatePermissionsIfNeeded(): Boolean {
        if (hasHeartRatePermissions()) return true
        if (heartRatePermissionRequestInFlight || heartRatePermissionRequestedOnce) return false
        heartRatePermissionRequestedOnce = true
        heartRatePermissionRequestInFlight = true
        Log.i(LiftWearTag, "Requesting heart-rate permissions: ${requiredHeartRatePermissions()}")
        heartRatePermissionLauncher.launch(requiredHeartRatePermissions().toTypedArray())
        return false
    }

    private fun requestWorkoutPermissionsIfNeeded(): Boolean {
        if (hasWorkoutPermissions()) return true
        if (workoutPermissionRequestInFlight || workoutPermissionRequestedOnce) return false
        workoutPermissionRequestedOnce = true
        workoutPermissionRequestInFlight = true
        Log.i(LiftWearTag, "Requesting workout permissions: ${requiredWorkoutPermissions()}")
        workoutPermissionLauncher.launch(requiredWorkoutPermissions().toTypedArray())
        return false
    }

    private fun maybeRequestRuntimePermissions(): Boolean {
        Log.d(
            LiftWearTag,
            "maybeRequestRuntimePermissions hr=${hasHeartRatePermissions()} workout=${hasWorkoutPermissions()} " +
                "hrReqInFlight=$heartRatePermissionRequestInFlight workoutReqInFlight=$workoutPermissionRequestInFlight",
        )
        if (!requestHeartRatePermissionsIfNeeded()) return false
        requestWorkoutPermissionsIfNeeded()
        ensureCompanionSessionIfNeeded()
        return true
    }

    private fun ensureCompanionSessionIfNeeded() {
        if (!hasHeartRatePermissions()) {
            Log.d(LiftWearTag, "ensureCompanionSessionIfNeeded skipped: missing heart-rate permission")
            return
        }
        val snapshot = WearDataRepository.snapshot.value ?: run {
            Log.d(LiftWearTag, "ensureCompanionSessionIfNeeded skipped: no snapshot yet")
            return
        }
        if (snapshot.workoutId.isBlank()) {
            Log.d(LiftWearTag, "ensureCompanionSessionIfNeeded skipped: blank workoutId")
            return
        }
        if (snapshot.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) {
            Log.d(LiftWearTag, "ensureCompanionSessionIfNeeded skipped: workout already done")
            return
        }
        Log.i(
            LiftWearTag,
            "ensureCompanionSessionIfNeeded starting HR/session for workoutId=${snapshot.workoutId} state=${snapshot.state}",
        )
        heartRateStreamer.start(snapshot.workoutId)
        if (hasWorkoutPermissions() && hasExerciseSessionHeartRatePermission()) {
            exerciseSessionManager.ensureSessionActive()
        } else {
            Log.d(
                LiftWearTag,
                "Exercise session not started workoutPerm=${hasWorkoutPermissions()} sessionHrPerm=${hasExerciseSessionHeartRatePermission()}",
            )
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
                Log.e(LiftWearTag, "Failed to send action to phone", error)
                Toast.makeText(
                    this@MainActivity,
                    "Phone not connected",
                    Toast.LENGTH_SHORT,
                ).show()
            }
        }
    }

    private fun logLifecycleEvent(event: String, extra: String? = null) {
        val suffix = extra?.takeIf { it.isNotBlank() }?.let { " $it" } ?: ""
        Log.i(
            LiftWearTag,
            "Activity $event$suffix taskId=$taskId finishing=$isFinishing changingConfig=$isChangingConfigurations " +
                "lifecycle=${lifecycle.currentState}",
        )
    }

    private fun trimMemoryLevelName(level: Int): String {
        return when (level) {
            ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN -> "UI_HIDDEN"
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE -> "RUNNING_MODERATE"
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW -> "RUNNING_LOW"
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL -> "RUNNING_CRITICAL"
            ComponentCallbacks2.TRIM_MEMORY_BACKGROUND -> "BACKGROUND"
            ComponentCallbacks2.TRIM_MEMORY_MODERATE -> "MODERATE"
            ComponentCallbacks2.TRIM_MEMORY_COMPLETE -> "COMPLETE"
            else -> "UNKNOWN"
        }
    }
}
@Composable
private fun WearApp(
    onAction: (Wearable.WearAction) -> Unit,
    heartRateStreamer: HeartRateStreamer,
    exerciseSessionManager: WearExerciseSessionManager,
    ensurePermissions: () -> Boolean,
    setWorkoutKeepScreenOn: (Boolean) -> Unit,
) {
    val snapshot by WearDataRepository.snapshot.collectAsState()
    val latestBpm by heartRateStreamer.latestBpm.collectAsState()
    val currentClock by produceState(initialValue = formatNowClock()) {
        while (true) {
            value = formatNowClock()
            delay(1000)
        }
    }
    LaunchedEffect(snapshot) {
        Log.d(
            LiftWearTag,
            "WearApp snapshot update present=${snapshot != null} " +
                "workoutId=${snapshot?.workoutId ?: ""} state=${snapshot?.state} actions=${snapshot?.actionsList?.size ?: 0}",
        )
    }
    LaunchedEffect(snapshot != null, snapshot?.workoutId, snapshot?.state, snapshot?.actionsList?.size) {
        val hasEndWorkoutAction = snapshot?.actionsList?.any {
            it.type == Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT
        } == true
        val keepOn = snapshot?.let {
            it.workoutId.isNotBlank() &&
                (it.state != workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE || hasEndWorkoutAction)
        } ?: false
        Log.d(
            LiftWearTag,
            "WearApp keep-screen-on effect keepOn=$keepOn workoutId=${snapshot?.workoutId ?: ""} " +
                "state=${snapshot?.state} hasEndAction=$hasEndWorkoutAction",
        )
        setWorkoutKeepScreenOn(keepOn)
    }
    DisposableEffect(Unit) {
        onDispose { setWorkoutKeepScreenOn(false) }
    }

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
    val completionSummary = if (data.hasCompletionSummary()) data.completionSummary else null
    val hasEndWorkoutAction = data.actionsList.any {
        it.type == Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT
    }
    var isStreaming by remember(data.workoutId) { mutableStateOf(false) }
    // Cleanup only when this workout leaves composition (workout swap/unmount).
    DisposableEffect(data.workoutId) {
        Log.d(LiftWearTag, "WearApp enter workout composition workoutId=${data.workoutId}")
        onDispose {
            Log.d(LiftWearTag, "WearApp dispose workout composition workoutId=${data.workoutId}")
            heartRateStreamer.stop()
            exerciseSessionManager.endSessionIfActive()
        }
    }

    // Explicit lifecycle: start for active workout, stop when it reaches ALL_DONE.
    LaunchedEffect(data.workoutId, data.state, hasEndWorkoutAction) {
        // Keep session active while waiting on explicit End Workout action.
        val shouldStream = data.workoutId.isNotEmpty() &&
            (data.state != workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE ||
                hasEndWorkoutAction)
        Log.d(
            LiftWearTag,
            "WearApp stream effect workoutId=${data.workoutId} state=${data.state} " +
                "hasEndAction=$hasEndWorkoutAction shouldStream=$shouldStream isStreaming=$isStreaming",
        )
        if (shouldStream && !isStreaming) {
            ensurePermissions()
            heartRateStreamer.start(data.workoutId)
            isStreaming = true
        } else if (!shouldStream && isStreaming) {
            heartRateStreamer.stop()
            exerciseSessionManager.endSessionIfActive()
            isStreaming = false
        }
    }

    val hrColor = heartRateColor(latestBpm)
    val exerciseName = formatExerciseName(currentSet?.exercise?.name ?: "")
    val isAmrap = currentSet?.isAmrap ?: false
    val repsWeightText = if (currentSet != null) {
        if (isAmrap) "AMRAPx${currentSet.targetWeight.toInt()}" else "${currentSet.targetReps}x${currentSet.targetWeight.toInt()}"
    } else ""
    val weightOnlyText = if (currentSet != null) "x${currentSet.targetWeight.toInt()}" else ""
    val startButtonTitle = if (currentSet != null) {
        "Start\n$exerciseName"
    } else {
        "Start"
    }
    val completeButtonText = "Complete\n$exerciseName"
    val isResting = data.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_RESTING
    val maxReps = if (isAmrap) 30 else (currentSet?.targetReps ?: 0)
    val repOptionMax = if (isAmrap) 30 else (maxReps * 2).coerceAtLeast(0)
    val repOptionCount = (repOptionMax + 1).coerceAtLeast(1)
    val initialReps = if (isAmrap) (currentSet?.targetReps ?: 0).coerceAtMost(30) else maxReps.coerceAtLeast(0)
    val pickerState = rememberPickerState(
        initialNumberOfOptions = repOptionCount,
        initiallySelectedOption = initialReps,
        repeatItems = false,
    )
    LaunchedEffect(repOptionCount, initialReps) {
        pickerState.scrollToOption(initialReps)
        // Wear Picker can land a few pixels off before first layout settles.
        // Re-apply after a frame so the selected row starts centered.
        withFrameNanos { }
        pickerState.scrollToOption(initialReps)
    }
    val selectedReps = pickerState.selectedOption.coerceIn(0, repOptionMax)
    val stateAccentColor = watchStateAccentColor(data.youCard.stateLabel)
    val timerColor = when {
        data.youCard.timerText.isNotEmpty() && stateAccentColor != null -> stateAccentColor
        isResting -> Color(0xFF86EFAC)
        else -> Color.White
    }
    val buttonBackgroundColor = stateAccentColor ?: Color.White
    val buttonContentColor = if (stateAccentColor != null) Color.White else Color.Black
    val buttonMutedContentColor = if (stateAccentColor != null) {
        Color.White.copy(alpha = 0.6f)
    } else {
        Color(0xFF6B7280)
    }

    CompositionLocalProvider(
        LocalTextStyle provides TextStyle(
            fontFamily = WearBodyFontFamily,
            fontWeight = FontWeight.Medium,
        ),
    ) {
        if (data.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE &&
            completionSummary != null) {
            WorkoutCompleteScreen(
                summary = completionSummary,
                onPrimary = if (primaryAction != null) ({ onAction(primaryAction) }) else null,
                primaryLabel = primaryAction?.label ?: "Done",
            )
            return@CompositionLocalProvider
        }
        Row(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
        ) {
        Column(
            modifier = Modifier
                .weight(0.5f)
                .fillMaxHeight()
                .padding(start = 8.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.End,
        ) {
            if (data.youCard.timerText.isNotEmpty()) {
                Text(
                    text = data.youCard.timerText,
                    color = timerColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                    fontSize = 34.sp,
                    fontFamily = WearDisplayFontFamily,
                    fontWeight = FontWeight.Bold,
                )
            }
            Text(
                text = data.youCard.stateLabel,
                color = stateAccentColor ?: Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
                fontSize = 19.sp,
                fontFamily = WearDisplayFontFamily,
                fontWeight = FontWeight.Medium,
            )
            if (data.youCard.timerText.isNotEmpty()) {
                StatLine(
                    text = currentClock,
                    icon = Icons.Filled.AccessTime,
                    color = Color(0xFFE5E7EB),
                    fontSizeSp = 18,
                )
            }
            StatLine(
                text = data.elapsedText,
                icon = Icons.Filled.HourglassBottom,
                color = Color(0xFFCBD5E1),
                fontSizeSp = 19,
            )
            StatLine(
                text = if (latestBpm != null) "${latestBpm!!.toInt()}" else "--",
                icon = Icons.Filled.Favorite,
                color = hrColor,
                fontSizeSp = 21,
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
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = buttonBackgroundColor,
                        contentColor = buttonContentColor,
                    ),
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(start = 10.dp, end = 6.dp),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.Start,
                        ) {
                            Text(
                                text = startButtonTitle,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                                textAlign = TextAlign.Start,
                                modifier = Modifier.fillMaxWidth(),
                                fontSize = 18.sp,
                                fontFamily = WearDisplayFontFamily,
                                fontWeight = FontWeight.Bold,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = repsWeightText,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                textAlign = TextAlign.Start,
                                modifier = Modifier.fillMaxWidth(),
                                fontSize = 24.sp,
                                fontFamily = WearDisplayFontFamily,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            } else {
                Button(
                    onClick = {
                        val set = currentSet
                        val template = completeTemplate
                        if (set != null && template != null) {
                            val action = template.toBuilder()
                                .setSetId(set.id)
                                .setReps(selectedReps)
                                .setActualWeight(
                                    if (template.actualWeight > 0f) template.actualWeight else set.targetWeight,
                                )
                                .build()
                            onAction(action)
                        }
                    },
                    modifier = Modifier.fillMaxSize(),
                    shape = RoundedCornerShape(0.dp),
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = buttonBackgroundColor,
                        contentColor = buttonContentColor,
                    ),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(start = 10.dp, end = 0.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.Start,
                    ) {
                        Text(
                            text = completeButtonText,
                            color = buttonContentColor,
                            fontSize = 18.sp,
                            textAlign = TextAlign.Start,
                            fontFamily = WearDisplayFontFamily,
                            fontWeight = FontWeight.Bold,
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.Start,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                modifier = Modifier
                                    .width(40.dp)
                                    .height(94.dp)
                                    .border(
                                        width = 1.dp,
                                        color = buttonContentColor.copy(alpha = 0.45f),
                                        shape = RoundedCornerShape(6.dp),
                                    )
                                    .padding(horizontal = 2.dp, vertical = 1.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                Picker(
                                    modifier = Modifier.fillMaxSize(),
                                    state = pickerState,
                                    gradientRatio = 0f,
                                    contentDescription = "Completed reps picker",
                                    option = { index: Int ->
                                        val isSelected = index == pickerState.selectedOption
                                        Box(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .height(18.dp),
                                            contentAlignment = Alignment.CenterEnd,
                                        ) {
                                            Text(
                                                text = index.toString(),
                                                textAlign = TextAlign.End,
                                                fontSize = 14.sp,
                                                color = if (isSelected) Color.Transparent else buttonMutedContentColor,
                                                fontFamily = WearDisplayFontFamily,
                                                fontWeight = FontWeight.Medium,
                                                lineHeight = 14.sp,
                                            )
                                        }
                                    },
                                )
                                Text(
                                    text = selectedReps.toString(),
                                    color = buttonContentColor,
                                    textAlign = TextAlign.End,
                                    fontSize = 40.sp,
                                    fontFamily = WearDisplayFontFamily,
                                    fontWeight = FontWeight.Bold,
                                    lineHeight = 40.sp,
                                    modifier = Modifier
                                        .align(Alignment.CenterEnd)
                                        .padding(end = 1.dp),
                                )
                            }
                            Spacer(modifier = Modifier.width(0.dp))
                            Text(
                                text = weightOnlyText,
                                color = buttonContentColor,
                                fontSize = 28.sp,
                                textAlign = TextAlign.Start,
                                fontFamily = WearDisplayFontFamily,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
            }
        }
    }
}
}

@Composable
private fun WorkoutCompleteScreen(
    summary: Wearable.WearCompletionSummary,
    onPrimary: (() -> Unit)?,
    primaryLabel: String,
) {
    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        Column(
            modifier = Modifier
                .weight(2f)
                .fillMaxHeight()
                .padding(start = 8.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.End,
        ) {
            Text(
                text = "Complete",
                color = Color.White,
                fontSize = 26.sp,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
                fontFamily = WearDisplayFontFamily,
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(6.dp))
            CompletionMetric(label = "Time", value = summary.durationText)
            CompletionMetric(label = "Sets", value = summary.completedWorkingSets.toString())
            CompletionMetric(label = "Vol", value = "${summary.totalVolumeLb}lb")
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Button(
                onClick = { onPrimary?.invoke() },
                enabled = onPrimary != null,
                modifier = Modifier.fillMaxSize(),
                shape = RoundedCornerShape(0.dp),
                colors = ButtonDefaults.buttonColors(
                    backgroundColor = Color.White,
                    contentColor = Color.Black,
                ),
            ) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Text(
                        text = primaryLabel,
                        textAlign = TextAlign.Start,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth(),
                        fontSize = 16.sp,
                        fontFamily = WearDisplayFontFamily,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}

@Composable
private fun CompletionMetric(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 1.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = Color(0xFF9CA3AF),
            fontSize = 13.sp,
        )
        Text(
            text = value,
            color = Color.White,
            fontSize = 18.sp,
            fontFamily = WearDisplayFontFamily,
            fontWeight = FontWeight.Bold,
        )
    }
}
@Composable
private fun StatLine(
    text: String,
    icon: ImageVector,
    color: Color,
    fontSizeSp: Int,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            color = color,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f),
            fontSize = fontSizeSp.sp,
        )
        Spacer(modifier = Modifier.width(4.dp))
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
        )
    }
}

private fun formatNowClock(): String {
    return LocalTime.now().format(DateTimeFormatter.ofPattern("h:mm a"))
}

private fun watchStateAccentColor(stateLabel: String?): Color? {
    return when (stateLabel) {
        "Lifting", "Warmup" -> MobileLiftingPink
        "Resting" -> MobileRestingBlue
        "Yapping" -> MobileYappingOrange
        else -> null
    }
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

private fun formatExerciseName(raw: String): String {
    return raw
        .removePrefix("EXERCISE_")
        .lowercase()
        .split('_')
        .joinToString(" ") { part -> part.replaceFirstChar { it.uppercase() } }
}
