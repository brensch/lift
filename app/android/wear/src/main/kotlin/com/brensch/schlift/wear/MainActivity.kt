package com.brensch.schlift.wear

import android.Manifest
import android.annotation.SuppressLint
import android.content.ComponentCallbacks2
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.core.content.ContextCompat
import androidx.wear.ambient.AmbientLifecycleObserver
import androidx.wear.compose.material.LocalTextStyle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import workout.v1.Wearable
import workout.v1.WorkoutOuterClass

private const val SCHLIFT_WEAR_TAG = "SchliftWear"

class MainActivity : ComponentActivity() {
    private val scope = kotlinx.coroutines.CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var uiHeartbeatJob: kotlinx.coroutines.Job? = null
    private var heartRatePermissionRequestInFlight = false
    private var workoutPermissionRequestInFlight = false
    private var keepScreenOnForWorkout = false
    private var isAmbientMode by mutableStateOf(false)

    // Bumped by the system's own ambient update (about once a minute), which
    // redraws the dimmed face even if the tick's timer slept through.
    private var ambientUpdates by mutableIntStateOf(0)

    private val ambientCallback =
        object : AmbientLifecycleObserver.AmbientLifecycleCallback {
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
                ambientUpdates += 1
            }
        }
    private val ambientObserver = AmbientLifecycleObserver(this, ambientCallback)

    @SuppressLint("InvalidFragmentVersionForActivityResult")
    private val heartRatePermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            heartRatePermissionRequestInFlight = false
            Log.i(SCHLIFT_WEAR_TAG, "Heart-rate permission result=$result")
            if (hasHeartRatePermissions()) {
                maybeRequestRuntimePermissions()
            } else {
                Log.w(SCHLIFT_WEAR_TAG, "Required heart-rate permissions still missing after request")
            }
        }

    @SuppressLint("InvalidFragmentVersionForActivityResult")
    private val workoutPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            workoutPermissionRequestInFlight = false
            Log.i(SCHLIFT_WEAR_TAG, "Workout permission result=$result")
            if (hasWorkoutPermissions()) {
                ensureCompanionSessionIfNeeded()
            } else {
                Log.w(SCHLIFT_WEAR_TAG, "Required workout permissions still missing after request")
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
                if (snapshot.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) return@collect
                ensureCompanionSessionIfNeeded()
            }
        }

        setContent {
            WearApp(
                onAction = { action -> sendAction(action) },
                onTapSet = { setId -> sendTap(setId) },
                setWorkoutKeepScreenOn = { enabled -> setWorkoutKeepScreenOn(enabled) },
                isAmbientMode = isAmbientMode,
                ambientUpdates = ambientUpdates,
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
                Log.d(SCHLIFT_WEAR_TAG, "Snapshot request not delivered", it)
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

    /**
     * Hardware keys never act on the face. A focused clickable (a set circle,
     * the rep circle) takes Enter or D-pad centre as a tap, so a crown or
     * button press could log a set; only touches may. The keys still reach
     * the system, which handles its own buttons first.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode in ACTIVATING_KEYS) {
            Log.d(SCHLIFT_WEAR_TAG, "Ignored key ${KeyEvent.keyCodeToString(event.keyCode)} action=${event.action}")
            return true
        }
        return super.dispatchKeyEvent(event)
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
        Log.i(SCHLIFT_WEAR_TAG, "Starting UI heartbeat")
        uiHeartbeatJob =
            scope.launch {
                while (true) {
                    runCatching {
                        WearTransport.sendToPhone(
                            this@MainActivity,
                            WearTransport.WEAR_TO_PHONE_UI_HEARTBEAT_PATH,
                            ByteArray(0),
                        )
                    }.onFailure {
                        Log.d(SCHLIFT_WEAR_TAG, "UI heartbeat not delivered", it)
                    }
                    if (WearDataRepository.snapshot.value == null) {
                        runCatching {
                            WearTransport.sendToPhone(
                                this@MainActivity,
                                WearTransport.WEAR_TO_PHONE_SNAPSHOT_REQUEST_PATH,
                                ByteArray(0),
                            )
                        }.onFailure {
                            Log.d(SCHLIFT_WEAR_TAG, "Snapshot request not delivered", it)
                        }
                    }
                    delay(3000)
                }
            }
    }

    private fun stopUiHeartbeat() {
        if (uiHeartbeatJob != null) {
            Log.i(SCHLIFT_WEAR_TAG, "Stopping UI heartbeat")
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
        Log.i(SCHLIFT_WEAR_TAG, "Workout keep-screen-on set to $enabled")
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

    private fun hasHeartRatePermissions(): Boolean = hasBodySensorsPermission() || hasReadHeartRatePermission()

    private fun hasPostNotificationsPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

    private fun hasBodySensorsPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.BODY_SENSORS,
        ) == PackageManager.PERMISSION_GRANTED

    private fun hasReadHeartRatePermission(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            "android.permission.health.READ_HEART_RATE",
        ) == PackageManager.PERMISSION_GRANTED

    private fun requiredWorkoutPermissions(): List<String> = listOf(Manifest.permission.ACTIVITY_RECOGNITION)

    private fun hasWorkoutPermissions(): Boolean =
        requiredWorkoutPermissions().all { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }

    private fun requestHeartRatePermissionsIfNeeded(): Boolean {
        if (hasHeartRatePermissions()) return true
        if (heartRatePermissionRequestInFlight) return false
        heartRatePermissionRequestInFlight = true
        Log.i(SCHLIFT_WEAR_TAG, "Requesting heart-rate permissions: ${requiredHeartRatePermissions()}")
        heartRatePermissionLauncher.launch(requiredHeartRatePermissions().toTypedArray())
        return false
    }

    private fun requestWorkoutPermissionsIfNeeded(): Boolean {
        if (hasWorkoutPermissions()) return true
        if (workoutPermissionRequestInFlight) return false
        workoutPermissionRequestInFlight = true
        Log.i(SCHLIFT_WEAR_TAG, "Requesting workout permissions: ${requiredWorkoutPermissions()}")
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
            SCHLIFT_WEAR_TAG,
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
            Log.d(SCHLIFT_WEAR_TAG, "ensureCompanionSessionIfNeeded skipped: missing heart-rate permission")
            return
        }
        val snapshot =
            WearDataRepository.snapshot.value ?: run {
                Log.d(SCHLIFT_WEAR_TAG, "ensureCompanionSessionIfNeeded skipped: no snapshot yet")
                return
            }
        if (snapshot.workoutId.isBlank()) {
            Log.d(SCHLIFT_WEAR_TAG, "ensureCompanionSessionIfNeeded skipped: blank workoutId")
            return
        }
        if (snapshot.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) {
            Log.d(SCHLIFT_WEAR_TAG, "ensureCompanionSessionIfNeeded skipped: workout already done")
            return
        }
        Log.i(
            SCHLIFT_WEAR_TAG,
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

    /** A tap on a set circle: the phone does what a tap there does. */
    private fun sendTap(setId: String) {
        val workoutId = WearDataRepository.snapshot.value?.workoutId ?: return
        send(
            Wearable.WearIntent
                .newBuilder()
                .setTapSet(
                    Wearable.TapSetIntent
                        .newBuilder()
                        .setWorkoutId(workoutId)
                        .setSetId(setId)
                        .setTappedAt(System.currentTimeMillis() / 1000)
                        .build(),
                ).build(),
        )
    }

    private fun sendAction(action: Wearable.WearAction) {
        val workoutId = WearDataRepository.snapshot.value?.workoutId ?: return

        val intent =
            when (action.type) {
                Wearable.WearActionType.WEAR_ACTION_TYPE_START_SET -> {
                    Wearable.WearIntent
                        .newBuilder()
                        .setStartSet(
                            Wearable.StartSetIntent
                                .newBuilder()
                                .setWorkoutId(workoutId)
                                .setSetId(action.setId)
                                .setStartedAt(System.currentTimeMillis() / 1000)
                                .build(),
                        ).build()
                }

                Wearable.WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET -> {
                    Wearable.WearIntent
                        .newBuilder()
                        .setCompleteSet(
                            Wearable.CompleteSetIntent
                                .newBuilder()
                                .setWorkoutId(workoutId)
                                .setSetId(action.setId)
                                .setReps(action.reps)
                                .setActualWeight(action.actualWeight)
                                .setCompletedAt(System.currentTimeMillis() / 1000)
                                .build(),
                        ).build()
                }

                Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT -> {
                    Wearable.WearIntent
                        .newBuilder()
                        .setEndWorkout(
                            Wearable.EndWorkoutIntent
                                .newBuilder()
                                .setWorkoutId(workoutId)
                                .build(),
                        ).build()
                }

                else -> {
                    return
                }
            }
        send(intent)
    }

    /** Stamp [unsent] with an id and the time, and send it to the phone. */
    private fun send(unsent: Wearable.WearIntent) {
        val intent =
            unsent
                .toBuilder()
                .setIntentId(
                    java.util.UUID
                        .randomUUID()
                        .toString(),
                ).setSentAt(System.currentTimeMillis() / 1000)
                .build()

        scope.launch {
            runCatching {
                val sent =
                    WearTransport.sendToPhone(
                        this@MainActivity,
                        WearTransport.WEAR_TO_PHONE_INTENT_PATH,
                        intent.toByteArray(),
                    )
                if (sent == 0) {
                    throw IllegalStateException("No connected phone node")
                }
            }.onFailure { error ->
                Log.e(SCHLIFT_WEAR_TAG, "Failed to send action to phone", error)
                Toast
                    .makeText(
                        this@MainActivity,
                        "Phone not connected",
                        Toast.LENGTH_SHORT,
                    ).show()
            }
        }
    }

    private fun logLifecycleEvent(
        event: String,
        extra: String? = null,
    ) {
        val suffix = extra?.takeIf { it.isNotBlank() }?.let { " $it" } ?: ""
        Log.i(
            SCHLIFT_WEAR_TAG,
            "Activity $event$suffix taskId=$taskId finishing=$isFinishing changingConfig=$isChangingConfigurations " +
                "lifecycle=${lifecycle.currentState}",
        )
    }

    private fun trimMemoryLevelName(level: Int): String =
        when (level) {
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

@Composable
private fun WearApp(
    onAction: (Wearable.WearAction) -> Unit,
    onTapSet: (String) -> Unit,
    setWorkoutKeepScreenOn: (Boolean) -> Unit,
    isAmbientMode: Boolean,
    ambientUpdates: Int,
) {
    val snapshot by WearDataRepository.snapshot.collectAsState()
    val latestBpm by WearDataRepository.latestBpm.collectAsState()
    // Every second; dimmed, once a minute, on the minute rest turns over.
    val nowTick by produceState(
        initialValue = System.currentTimeMillis() / 1000,
        isAmbientMode,
        snapshot?.restUntil,
        ambientUpdates,
    ) {
        while (true) {
            value = System.currentTimeMillis() / 1000
            delay(if (isAmbientMode) ambientDelayMs(snapshot) else 1000L)
        }
    }
    LaunchedEffect(snapshot) {
        Log.d(
            SCHLIFT_WEAR_TAG,
            "WearApp snapshot update present=${snapshot != null} " +
                "workoutId=${snapshot?.workoutId ?: ""} state=${snapshot?.state} actions=${snapshot?.actionsList?.size ?: 0}",
        )
    }
    val endWorkoutAction =
        snapshot?.actionsList?.firstOrNull {
            it.type == Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT
        }
    // A workout is on screen until ALL_DONE has been ended on either device;
    // after that the watch is idle again.
    val showsWorkout =
        snapshot?.let {
            it.workoutId.isNotBlank() &&
                (it.state != WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE || endWorkoutAction != null)
        } ?: false
    LaunchedEffect(showsWorkout, snapshot?.workoutId) {
        Log.d(
            SCHLIFT_WEAR_TAG,
            "WearApp keep-screen-on effect keepOn=$showsWorkout workoutId=${snapshot?.workoutId ?: ""} " +
                "state=${snapshot?.state} hasEndAction=${endWorkoutAction != null}",
        )
        setWorkoutKeepScreenOn(showsWorkout)
    }
    DisposableEffect(Unit) {
        onDispose { setWorkoutKeepScreenOn(false) }
    }

    CompositionLocalProvider(
        LocalTextStyle provides
            TextStyle(
                fontFamily = WearBodyFontFamily,
                fontWeight = FontWeight.Medium,
            ),
    ) {
        val data = snapshot
        if (data == null || !showsWorkout) {
            IdleScreen()
            return@CompositionLocalProvider
        }
        WorkoutScreens(
            data = data,
            latestBpm = latestBpm,
            nowTick = nowTick,
            isAmbientMode = isAmbientMode,
            onAction = onAction,
            onTapSet = onTapSet,
        )
    }
}

// Picks the screen for a snapshot and gates taps: one action per snapshot,
// re-enabled by the next snapshot or after 2 s if none arrives.
@Composable
private fun WorkoutScreens(
    data: Wearable.WearWorkoutSnapshot,
    latestBpm: Float?,
    nowTick: Long,
    isAmbientMode: Boolean,
    onAction: (Wearable.WearAction) -> Unit,
    onTapSet: (String) -> Unit,
) {
    val restTimer =
        remember(data.workoutId, data.restUntil, data.youCard.timerText, nowTick) {
            deriveRestTimer(data)
        }
    val elapsedText =
        remember(data.workoutId, data.workoutStartTime, data.elapsedText, nowTick) {
            deriveElapsedText(data)
        }
    // Track which snapshot the action was sent on. When emittedAt changes, the phone has
    // acknowledged the action and we are in a new phase — clear pending immediately in the
    // same composition pass rather than via a LaunchedEffect (which fires after composition,
    // causing the button to remain greyed for one extra frame).
    var pendingActionEmittedAt by remember(data.workoutId) { mutableLongStateOf(-1L) }
    var pendingActionStartedAtMs by remember(data.workoutId) { mutableLongStateOf(0L) }
    // Safety timeout: the button re-enables 2s after a tap even if no fresh snapshot
    // arrives (phone dropped the intent, watch offline, etc.). Normal reply is <500ms,
    // so 2s is ample. nowTick recomposes this screen once a second, so the timeout is seen.
    val isActionPending =
        pendingActionEmittedAt == data.emittedAt &&
            pendingActionEmittedAt >= 0L &&
            (System.currentTimeMillis() - pendingActionStartedAtMs) < 2000L
    val fire: (Wearable.WearAction) -> Unit = { action ->
        if (!isActionPending) {
            pendingActionEmittedAt = data.emittedAt
            pendingActionStartedAtMs = System.currentTimeMillis()
            onAction(action)
        }
    }
    val tapSet: (String) -> Unit = { setId ->
        if (!isActionPending) {
            pendingActionEmittedAt = data.emittedAt
            pendingActionStartedAtMs = System.currentTimeMillis()
            onTapSet(setId)
        }
    }

    // When the local rest countdown expires, request a fresh snapshot immediately
    // rather than waiting up to 3 s for the next heartbeat, so the screen moves on
    // the moment the timer hits 0:00.
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
            Log.d(SCHLIFT_WEAR_TAG, "Rest-expiry snapshot request not delivered", it)
        }
    }

    val card = data.youCard

    fun action(type: Wearable.WearActionType): Wearable.WearAction? = data.actionsList.firstOrNull { it.type == type }

    if (data.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_ALL_DONE) {
        DoneScreen(
            summary = if (data.hasCompletionSummary()) data.completionSummary else null,
            label = "All done",
            endWorkout = action(Wearable.WearActionType.WEAR_ACTION_TYPE_END_WORKOUT),
            enabled = !isActionPending,
            onAction = fire,
        )
        return
    }

    var showPlates by remember(data.workoutId) { mutableStateOf(false) }

    val lifting = data.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_LIFTING
    val resting =
        data.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_RESTING ||
            data.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_YAPPING
    val yapping = resting && restTimer.countingUp
    val primary =
        action(Wearable.WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET)
            ?: action(Wearable.WearActionType.WEAR_ACTION_TYPE_START_SET)

    // The rest drains the band from the end of the last set to restUntil,
    // animated rather than redrawn on the tick so it moves smoothly.
    val restStartMs = data.lastSetEndedAt * 1000L
    val restUntilMs = data.restUntil.toLong() * 1000L
    val draining = resting && !yapping && restStartMs in 1 until restUntilMs
    val bandFill = remember(data.workoutId) { Animatable(1f) }
    // Dimmed, the band is never drawn draining: no animation to pay for.
    LaunchedEffect(draining, restStartMs, restUntilMs, isAmbientMode) {
        if (isAmbientMode) return@LaunchedEffect
        val leftMs = restUntilMs - WearDataRepository.synchronizedNowUnixMillis()
        if (!draining || leftMs <= 0L) {
            bandFill.snapTo(if (draining) 0f else 1f)
            return@LaunchedEffect
        }
        bandFill.snapTo(leftMs.toFloat() / (restUntilMs - restStartMs))
        bandFill.animateTo(0f, tween(durationMillis = leftMs.toInt(), easing = LinearEasing))
    }

    val stageColor =
        when {
            card.firstTime -> WearPalette.FirstTime
            lifting -> WearPalette.Lifting
            yapping -> WearPalette.Yapping
            resting -> WearPalette.Resting
            else -> WearPalette.Ready
        }
    // The set the rep circle stands for: the one in hand.
    val inHand =
        data.circlesList.firstOrNull { it.state == Wearable.WearCircleState.WEAR_CIRCLE_STATE_LIFTING }
            ?: data.circlesList.firstOrNull { it.state == Wearable.WearCircleState.WEAR_CIRCLE_STATE_NEXT }
    // Dimmed (always-on), the same face in grey on black. It is redrawn about
    // once a minute, so rest is counted in minutes and nothing ticks seconds.
    val dim = isAmbientMode
    val rest = if (dim && resting) ambientRest(data) else null
    val face =
        WearFace(
            circles = data.circlesList,
            upNext = data.upNextText,
            label = if (yapping) card.yappingLabel.ifEmpty { card.stateLabel } else card.stateLabel,
            timer =
                when {
                    dim -> rest?.minutes ?: ""
                    card.firstTime -> ""
                    lifting -> deriveLiftingTimer(data)
                    resting -> restTimer.text
                    else -> ""
                },
            stageColor = if (dim) WearPalette.Ambient else stageColor,
            // Resting drains to the stage colour washed toward the panel.
            trackColor =
                when {
                    dim -> WearPalette.Ambient
                    draining -> lerp(stageColor, WearPalette.Panel, 0.6f)
                    else -> stageColor
                },
            bandInk =
                when {
                    dim -> WearPalette.AmbientText
                    lifting && !card.firstTime -> WearPalette.Text
                    else -> WearPalette.OnDark
                },
            bandFill = if (draining && !dim) bandFill.value else 1f,
            exercise = card.exerciseName,
            position = card.setLine,
            weight = card.weightText.ifEmpty { card.setText },
            unit = card.unitText,
            reps = card.repsText,
            repState = inHand?.state ?: Wearable.WearCircleState.WEAR_CIRCLE_STATE_PENDING,
            bpm = latestBpm,
            // Dimmed, when rest ends in place of a ticking length.
            elapsed = if (dim) rest?.until ?: "" else elapsedText,
            clock = java.text.SimpleDateFormat("H:mm", java.util.Locale.getDefault()).format(java.util.Date(nowTick * 1000L)),
            hasPlates = card.platesText.isNotEmpty(),
        )

    PlateDialog(card = card, show = showPlates && !isAmbientMode, onDismiss = { showPlates = false })
    FaceScreen(
        face = face,
        colors = if (dim) DimColors else LitColors,
        enabled = !dim && !isActionPending,
        onTapSet = tapSet,
        onRep = {
            when {
                inHand != null -> tapSet(inHand.setId)
                else -> primary?.let(fire)
            }
        },
        onWeight = { showPlates = true },
    )
}

/** Keys that would press a focused clickable. */
private val ACTIVATING_KEYS =
    setOf(
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_NUMPAD_ENTER,
        KeyEvent.KEYCODE_DPAD_CENTER,
        KeyEvent.KEYCODE_SPACE,
        KeyEvent.KEYCODE_STEM_PRIMARY,
        KeyEvent.KEYCODE_STEM_1,
        KeyEvent.KEYCODE_STEM_2,
        KeyEvent.KEYCODE_STEM_3,
    )
