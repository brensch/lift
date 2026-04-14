package com.brensch.schlift.wear

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
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Person
import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
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
import androidx.compose.runtime.mutableLongStateOf
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.isUnspecified
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.CircularProgressIndicator
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

@Composable
fun AutoResizingText(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    fontSize: TextUnit = 16.sp,
    fontWeight: FontWeight? = null,
    fontFamily: FontFamily? = null,
    textAlign: TextAlign? = null,
    overflow: TextOverflow = TextOverflow.Clip,
    maxLines: Int = Int.MAX_VALUE,
    minFontSize: TextUnit = 8.sp,
) {
    var currentFontSize by remember(text) { mutableStateOf(fontSize) }
    var readyToDraw by remember(text) { mutableStateOf(false) }

    Text(
        text = text,
        modifier = modifier.drawWithContent {
            if (readyToDraw) drawContent()
        },
        color = color,
        fontSize = currentFontSize,
        fontWeight = fontWeight,
        fontFamily = fontFamily,
        textAlign = textAlign,
        overflow = overflow,
        softWrap = maxLines > 1,
        maxLines = maxLines,
        onTextLayout = { textLayoutResult ->
            if (textLayoutResult.hasVisualOverflow && currentFontSize > minFontSize) {
                currentFontSize = (currentFontSize.value * 0.9f).sp
            } else {
                readyToDraw = true
            }
        }
    )
}

// Match mobile app workout state accents:
// Lifting/Warmup green: 0xFF16A34A
// Resting blue: 0xFF3B82F6
// Yapping pink: 0xFFEC4899
private val MobileLiftingGreen = Color(0xFF16A34A)
private val MobileRestingBlue = Color(0xFF3B82F6)
private val MobileYappingPink = Color(0xFFEC4899)
private const val SchliftWearTag = "SchliftWear"

class MainActivity : ComponentActivity() {
    private val scope = kotlinx.coroutines.CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var uiHeartbeatJob: kotlinx.coroutines.Job? = null
    private var heartRatePermissionRequestInFlight = false
    private var workoutPermissionRequestInFlight = false
    private var keepScreenOnForWorkout = false
    private var isAmbientMode by mutableStateOf(false)

    private val ambientCallback = object : AmbientLifecycleObserver.AmbientLifecycleCallback {
        override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) {
            logLifecycleEvent("ambient onEnter", "details=$ambientDetails")
            isAmbientMode = true
        }

        override fun onExitAmbient() {
            logLifecycleEvent("ambient onExit")
            isAmbientMode = false
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
            Log.i(SchliftWearTag, "Heart-rate permission result=$result")
            if (hasHeartRatePermissions()) {
                maybeRequestRuntimePermissions()
            } else {
                Log.w(SchliftWearTag, "Required heart-rate permissions still missing after request")
            }
        }

    @SuppressLint("InvalidFragmentVersionForActivityResult")
    private val workoutPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            workoutPermissionRequestInFlight = false
            Log.i(SchliftWearTag, "Workout permission result=$result")
            if (hasWorkoutPermissions()) {
                ensureCompanionSessionIfNeeded()
            } else {
                Log.w(SchliftWearTag, "Required workout permissions still missing after request")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logLifecycleEvent(
            "onCreate",
            "saved=${savedInstanceState != null} intentFlags=0x${intent?.flags?.toString(16) ?: "0"}",
        )
        lifecycle.addObserver(ambientObserver)

        // When a snapshot with an active workout arrives while the foreground
        // service isn't running yet, start it. Skips once running — after that,
        // PhoneMessageListenerService handles ongoing updates.
        scope.launch {
            WearDataRepository.snapshot.collect { snapshot ->
                if (WorkoutForegroundService.isRunning()) return@collect
                if (snapshot == null) return@collect
                if (snapshot.workoutId.isBlank()) return@collect
                if (snapshot.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) return@collect
                ensureCompanionSessionIfNeeded()
            }
        }

        setContent {
            WearApp(
                onAction = { action -> sendAction(action) },
                setWorkoutKeepScreenOn = { enabled -> setWorkoutKeepScreenOn(enabled) },
                isAmbientMode = isAmbientMode,
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
        scope.launch {
            runCatching {
                WearTransport.sendToPhone(
                    this@MainActivity,
                    WearTransport.WEAR_TO_PHONE_SNAPSHOT_REQUEST_PATH,
                    ByteArray(0),
                )
            }.onFailure {
                Log.d(SchliftWearTag, "Snapshot request not delivered", it)
            }
        }
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
        Log.i(SchliftWearTag, "Starting UI heartbeat")
        uiHeartbeatJob = scope.launch {
            while (true) {
                runCatching {
                    WearTransport.sendToPhone(
                        this@MainActivity,
                        WearTransport.WEAR_TO_PHONE_UI_HEARTBEAT_PATH,
                        ByteArray(0),
                    )
                }.onFailure {
                    Log.d(SchliftWearTag, "UI heartbeat not delivered", it)
                }
                if (WearDataRepository.snapshot.value == null) {
                    runCatching {
                        WearTransport.sendToPhone(
                            this@MainActivity,
                            WearTransport.WEAR_TO_PHONE_SNAPSHOT_REQUEST_PATH,
                            ByteArray(0),
                        )
                    }.onFailure {
                        Log.d(SchliftWearTag, "Snapshot request not delivered", it)
                    }
                }
                delay(3000)
            }
        }
    }

    private fun stopUiHeartbeat() {
        if (uiHeartbeatJob != null) {
            Log.i(SchliftWearTag, "Stopping UI heartbeat")
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
        Log.i(SchliftWearTag, "Workout keep-screen-on set to $enabled")
    }

    private fun requiredHeartRatePermissions(): List<String> {
        val required = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasPostNotificationsPermission()) {
            required += Manifest.permission.POST_NOTIFICATIONS
        }
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

    private fun hasPostNotificationsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
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
        if (heartRatePermissionRequestInFlight) return false
        heartRatePermissionRequestInFlight = true
        Log.i(SchliftWearTag, "Requesting heart-rate permissions: ${requiredHeartRatePermissions()}")
        heartRatePermissionLauncher.launch(requiredHeartRatePermissions().toTypedArray())
        return false
    }

    private fun requestWorkoutPermissionsIfNeeded(): Boolean {
        if (hasWorkoutPermissions()) return true
        if (workoutPermissionRequestInFlight) return false
        workoutPermissionRequestInFlight = true
        Log.i(SchliftWearTag, "Requesting workout permissions: ${requiredWorkoutPermissions()}")
        workoutPermissionLauncher.launch(requiredWorkoutPermissions().toTypedArray())
        return false
    }

    // Called from onResume and from the permission launcher callbacks. Always
    // re-checks current grant state from the system instead of trusting a
    // sticky "have we asked yet" flag — that flag was preventing re-prompts
    // and also blocking the FGS start path when the user granted permission
    // via system settings out-of-band.
    private fun maybeRequestRuntimePermissions(): Boolean {
        Log.d(
            SchliftWearTag,
            "maybeRequestRuntimePermissions hr=${hasHeartRatePermissions()} workout=${hasWorkoutPermissions()} " +
                "hrReqInFlight=$heartRatePermissionRequestInFlight workoutReqInFlight=$workoutPermissionRequestInFlight",
        )
        val hrGranted = requestHeartRatePermissionsIfNeeded()
        val workoutGranted = requestWorkoutPermissionsIfNeeded()
        if (hrGranted) {
            // Even if workout permission is still missing, HR streaming can begin.
            ensureCompanionSessionIfNeeded()
        }
        return hrGranted && workoutGranted
    }

    private fun ensureCompanionSessionIfNeeded() {
        if (!hasHeartRatePermissions()) {
            Log.d(SchliftWearTag, "ensureCompanionSessionIfNeeded skipped: missing heart-rate permission")
            return
        }
        val snapshot = WearDataRepository.snapshot.value ?: run {
            Log.d(SchliftWearTag, "ensureCompanionSessionIfNeeded skipped: no snapshot yet")
            return
        }
        if (snapshot.workoutId.isBlank()) {
            Log.d(SchliftWearTag, "ensureCompanionSessionIfNeeded skipped: blank workoutId")
            return
        }
        if (snapshot.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) {
            Log.d(SchliftWearTag, "ensureCompanionSessionIfNeeded skipped: workout already done")
            return
        }
        Log.i(
            SchliftWearTag,
            "ensureCompanionSessionIfNeeded starting HR/session for workoutId=${snapshot.workoutId} state=${snapshot.state}",
        )
        WorkoutForegroundService.startOrUpdate(
            this,
            workoutLabel = "Workout in progress",
            stateLabel = snapshot.youCard.stateLabel,
            workoutId = snapshot.workoutId,
            activeWorkout = true,
        )
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

        scope.launch {
            runCatching {
                val sent = WearTransport.sendToPhone(
                    this@MainActivity,
                    WearTransport.WEAR_TO_PHONE_INTENT_PATH,
                    intent.toByteArray(),
                )
                if (sent == 0) {
                    throw IllegalStateException("No connected phone node")
                }
            }.onFailure { error ->
                Log.e(SchliftWearTag, "Failed to send action to phone", error)
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
            SchliftWearTag,
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
    setWorkoutKeepScreenOn: (Boolean) -> Unit,
    isAmbientMode: Boolean,
) {
    val snapshot by WearDataRepository.snapshot.collectAsState()
    val latestBpm by WearDataRepository.latestBpm.collectAsState()
    val currentClock by produceState(initialValue = formatNowClock()) {
        while (true) {
            value = formatNowClock()
            delay(1000)
        }
    }
    val nowTick by produceState(initialValue = System.currentTimeMillis() / 1000) {
        while (true) {
            value = System.currentTimeMillis() / 1000
            delay(1000)
        }
    }
    LaunchedEffect(snapshot) {
        Log.d(
            SchliftWearTag,
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
            SchliftWearTag,
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
            AutoResizingText("Waiting for phone", color = Color.White)
        }
        return
    }

    val data = snapshot!!
    val hasEndWorkoutAction = data.actionsList.any {
        it.type == Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT
    }
    val liveYouTimerText = remember(data.workoutId, data.state, data.activeStartedAt, data.restUntil, data.lastRestEnd, hasEndWorkoutAction, nowTick) {
        deriveYouTimerText(data)
    }
    val liveElapsedText = remember(data.workoutId, data.workoutStartTime, data.state, nowTick, isAmbientMode) {
        deriveElapsedText(data, hideSeconds = isAmbientMode)
    }
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
    // Track which snapshot the action was sent on. When emittedAt changes, the server has
    // acknowledged the action and we are in a new phase — clear pending immediately in the
    // same composition pass rather than via a LaunchedEffect (which fires after composition,
    // causing the button to remain greyed for one extra frame).
    var pendingActionEmittedAt by remember(data.workoutId) { mutableLongStateOf(-1L) }
    var pendingActionStartedAtMs by remember(data.workoutId) { mutableLongStateOf(0L) }
    // Safety timeout: the button re-enables 2s after a tap even if no fresh snapshot
    // arrives (phone dropped the intent, watch offline, etc.). Normal reply is <500ms,
    // so 2s is ample and avoids the old 8s "stuck grey" window users complained about.
    val isActionPending = pendingActionEmittedAt == data.emittedAt &&
        pendingActionEmittedAt >= 0L &&
        (System.currentTimeMillis() - pendingActionStartedAtMs) < 2000L

    // When the local rest countdown expires, request a fresh snapshot immediately
    // rather than waiting up to 3 s for the next heartbeat. This ensures the button
    // re-enables at the exact moment the timer hits 0:00, with no visible delay.
    val restRequestContext = LocalContext.current
    LaunchedEffect(data.workoutId, data.restUntil) {
        val restUntilMs = data.restUntil.toLong() * 1000L
        if (restUntilMs <= 0L) return@LaunchedEffect
        val delayMs = restUntilMs - WearDataRepository.synchronizedNowUnixMillis()
        if (delayMs > 0L) delay(delayMs)
        runCatching {
            WearTransport.sendToPhone(
                restRequestContext,
                WearTransport.WEAR_TO_PHONE_SNAPSHOT_REQUEST_PATH,
                ByteArray(0),
            )
        }.onFailure {
            Log.d(SchliftWearTag, "Rest-expiry snapshot request not delivered", it)
        }
    }

    val hrColor = heartRateColor(latestBpm)
    val nextUpText: String? = data.nextUpEmoji.takeIf { it.isNotEmpty() }
    val exerciseName = formatExerciseName(currentSet?.exercise?.name ?: "")
    val groupProgressText = formatGroupProgress(data.youCard)
    val setsLeftText = formatSetsLeft(data.youCard)
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
    val repOptionMax = 100
    val repOptionCount = repOptionMax + 1
    val initialReps = (currentSet?.targetReps ?: 0).coerceIn(0, repOptionMax)
    val pickerState = rememberPickerState(
        initialNumberOfOptions = repOptionCount,
        initiallySelectedOption = initialReps,
        repeatItems = false,
    )
    LaunchedEffect(initialReps) {
        pickerState.scrollToOption(initialReps)
        // Wear Picker can land a few pixels off before first layout settles.
        // Re-apply after a frame so the selected row starts centered.
        withFrameNanos { }
        pickerState.scrollToOption(initialReps)
    }
    val selectedReps = pickerState.selectedOption.coerceIn(0, repOptionMax)
    val stateAccentColor = watchStateAccentColor(data.youCard.stateLabel)
    val timerColor = when {
        liveYouTimerText.isNotEmpty() && stateAccentColor != null -> stateAccentColor
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
            if (!isAmbientMode && liveYouTimerText.isNotEmpty()) {
                AutoResizingText(
                    text = liveYouTimerText,
                    color = timerColor,
                    maxLines = 1,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                    fontSize = 34.sp,
                    fontFamily = WearDisplayFontFamily,
                    fontWeight = FontWeight.Bold,
                )
            }
            AutoResizingText(
                text = data.youCard.stateLabel,
                color = stateAccentColor ?: Color.White,
                maxLines = 1,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
                fontSize = 19.sp,
                fontFamily = WearDisplayFontFamily,
                fontWeight = FontWeight.Medium,
            )
            if (liveYouTimerText.isNotEmpty()) {
                StatLine(
                    text = currentClock,
                    icon = Icons.Filled.AccessTime,
                    color = Color(0xFFE5E7EB),
                    fontSizeSp = 18,
                )
            }
            StatLine(
                text = liveElapsedText,
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
            if (nextUpText != null) {
                StatLine(
                    text = nextUpText,
                    icon = Icons.Filled.Person,
                    color = Color(0xFF9CA3AF),
                    fontSizeSp = 18,
                )
            }
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
                    onClick = {
                        if (primaryAction != null && !isActionPending) {
                            pendingActionEmittedAt = data.emittedAt
                            pendingActionStartedAtMs = System.currentTimeMillis()
                            onAction(primaryAction)
                        }
                    },
                    enabled = primaryAction != null && !isActionPending,
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
                                    AutoResizingText(
                                        text = startButtonTitle,
                                        maxLines = 2,
                                        textAlign = TextAlign.Start,
                                        modifier = Modifier.fillMaxWidth(),
                                        fontSize = 18.sp,
                                        fontFamily = WearDisplayFontFamily,
                                        fontWeight = FontWeight.Bold,
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    AutoResizingText(
                                        text = repsWeightText,
                                        maxLines = 1,
                                        textAlign = TextAlign.Start,
                                        modifier = Modifier.fillMaxWidth(),
                                        fontSize = 24.sp,
                                        fontFamily = WearDisplayFontFamily,
                                        fontWeight = FontWeight.Bold,
                                    )
                                    if (groupProgressText.isNotEmpty()) {
                                        Spacer(modifier = Modifier.height(6.dp))
                                        AutoResizingText(
                                            text = groupProgressText,
                                            maxLines = 1,
                                            textAlign = TextAlign.Start,
                                            modifier = Modifier.fillMaxWidth(),
                                            fontSize = 16.sp,
                                            fontFamily = WearDisplayFontFamily,
                                            fontWeight = FontWeight.Medium,
                                        )
                                        if (setsLeftText.isNotEmpty()) {
                                            AutoResizingText(
                                                text = setsLeftText,
                                                maxLines = 1,
                                                textAlign = TextAlign.Start,
                                                modifier = Modifier.fillMaxWidth(),
                                                fontSize = 12.sp,
                                                fontFamily = WearBodyFontFamily,
                                                fontWeight = FontWeight.Medium,
                                                color = buttonContentColor.copy(alpha = 0.72f),
                                            )
                                        }
                                    }
                                }
                    }
                }
            } else {
                Button(
                    onClick = {
                        if (isActionPending) return@Button
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
                            pendingActionEmittedAt = data.emittedAt
                            pendingActionStartedAtMs = System.currentTimeMillis()
                            onAction(action)
                        }
                    },
                    enabled = !isActionPending,
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
                                AutoResizingText(
                                    text = completeButtonText,
                                    color = buttonContentColor,
                                    fontSize = 18.sp,
                                    textAlign = TextAlign.Start,
                                    fontFamily = WearDisplayFontFamily,
                                    fontWeight = FontWeight.Bold,
                                    maxLines = 2,
                                )
                                Spacer(modifier = Modifier.height(6.dp))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.Start,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .width(44.dp)
                                            .height(36.dp)
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(buttonBackgroundColor)
                                            .border(
                                                width = 1.dp,
                                                color = buttonContentColor.copy(alpha = 0.45f),
                                                shape = RoundedCornerShape(6.dp),
                                            ),
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
                                                        .height(24.dp),
                                                    contentAlignment = Alignment.Center,
                                                ) {
                                                    Text(
                                                        text = index.toString(),
                                                        textAlign = TextAlign.Center,
                                                        fontSize = if (isSelected) 20.sp else 12.sp,
                                                        color = if (isSelected) buttonContentColor else buttonMutedContentColor,
                                                        fontFamily = WearDisplayFontFamily,
                                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                                        lineHeight = 24.sp,
                                                    )
                                                }
                                            },
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(0.dp))
                                    AutoResizingText(
                                        text = weightOnlyText,
                                        color = buttonContentColor,
                                        fontSize = 28.sp,
                                        textAlign = TextAlign.Start,
                                        fontFamily = WearDisplayFontFamily,
                                        fontWeight = FontWeight.Bold,
                                        maxLines = 1,
                                    )
                                }
                                if (groupProgressText.isNotEmpty()) {
                                    Spacer(modifier = Modifier.height(6.dp))
                                    AutoResizingText(
                                        text = groupProgressText,
                                        color = buttonContentColor,
                                        maxLines = 1,
                                        textAlign = TextAlign.Start,
                                        modifier = Modifier.fillMaxWidth(),
                                        fontSize = 16.sp,
                                        fontFamily = WearDisplayFontFamily,
                                        fontWeight = FontWeight.Medium,
                                    )
                                    if (setsLeftText.isNotEmpty()) {
                                        AutoResizingText(
                                            text = setsLeftText,
                                            color = buttonContentColor.copy(alpha = 0.72f),
                                            maxLines = 1,
                                            textAlign = TextAlign.Start,
                                            modifier = Modifier.fillMaxWidth(),
                                            fontSize = 12.sp,
                                            fontFamily = WearBodyFontFamily,
                                            fontWeight = FontWeight.Medium,
                                        )
                                    }
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
            AutoResizingText(
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
                AutoResizingText(
                    text = primaryLabel,
                    textAlign = TextAlign.Start,
                    maxLines = 2,
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
        AutoResizingText(
            text = label,
            color = Color(0xFF9CA3AF),
            fontSize = 13.sp,
            maxLines = 1,
        )
        AutoResizingText(
            text = value,
            color = Color.White,
            fontSize = 18.sp,
            fontFamily = WearDisplayFontFamily,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
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
        AutoResizingText(
            text = text,
            color = color,
            maxLines = 1,
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

private fun formatGroupProgress(card: Wearable.WearStatusCard): String {
    val current = card.currentGroupSet
    val total = card.totalGroupSets
    if (current <= 0 || total <= 0) return ""
    return "$current/$total"
}

private fun formatSetsLeft(card: Wearable.WearStatusCard): String {
    val current = card.currentGroupSet
    val total = card.totalGroupSets
    if (current <= 0 || total <= 0) return ""
    val remaining = (total - current + 1).coerceAtLeast(0)
    return if (remaining == 1) "1 set left" else "$remaining sets left"
}

private fun deriveElapsedText(snapshot: Wearable.WearWorkoutSnapshot, hideSeconds: Boolean = false): String {
    val startTime = snapshot.workoutStartTime.toLong()
    if (startTime <= 0L) return snapshot.elapsedText
    val currentApiNowMs = WearDataRepository.synchronizedNowUnixMillis()
    val elapsed = ((currentApiNowMs - (startTime * 1000L)).coerceAtLeast(0L) / 1000L).toInt()
    return if (hideSeconds) {
        formatElapsedDurationNoSeconds(elapsed)
    } else {
        formatElapsedDuration(elapsed)
    }
}

private fun deriveYouTimerText(snapshot: Wearable.WearWorkoutSnapshot): String {
    val currentApiNowMs = WearDataRepository.synchronizedNowUnixMillis()
    return when (snapshot.state) {
        workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_LIFTING -> {
            val activeStartedAt = snapshot.activeStartedAt.toLong()
            if (activeStartedAt <= 0L) {
                snapshot.youCard.timerText
            } else {
                formatDuration(
                    ((currentApiNowMs - (activeStartedAt * 1000L)).coerceAtLeast(0L) / 1000L).toInt(),
                )
            }
        }

        workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_RESTING -> {
            val restUntil = snapshot.restUntil.toLong()
            val restUntilMs = restUntil * 1000L
            when {
                restUntil <= 0L -> snapshot.youCard.timerText
                snapshot.youCard.stateLabel == "Yapping" || restUntilMs <= currentApiNowMs ->
                    formatDuration(((currentApiNowMs - restUntilMs).coerceAtLeast(0L) / 1000L).toInt())
                else ->
                    formatDuration(((restUntilMs - currentApiNowMs).coerceAtLeast(0L) / 1000L).toInt())
            }
        }

        workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_READY -> {
            val lastRestEnd = snapshot.lastRestEnd.toLong()
            if (snapshot.youCard.stateLabel != "Yapping" || lastRestEnd <= 0L) {
                snapshot.youCard.timerText
            } else {
                formatDuration(((currentApiNowMs - (lastRestEnd * 1000L)).coerceAtLeast(0L) / 1000L).toInt())
            }
        }

        else -> snapshot.youCard.timerText
    }
}

private fun formatDuration(totalSeconds: Int): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%d:%02d".format(minutes, seconds)
}

private fun formatElapsedDuration(totalSeconds: Int): String {
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        "%d:%02d:%02d".format(hours, minutes, seconds)
    } else {
        "%d:%02d".format(minutes, seconds)
    }
}

private fun formatElapsedDurationNoSeconds(totalSeconds: Int): String {
    val totalMinutes = totalSeconds / 60
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) {
        "%d:%02d".format(hours, minutes)
    } else {
        "%d min".format(minutes)
    }
}

private fun watchStateAccentColor(stateLabel: String?): Color? {
    return when (stateLabel) {
        "Lifting", "Warmup" -> MobileLiftingGreen
        "Resting" -> MobileRestingBlue
        "Yapping" -> MobileYappingPink
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
