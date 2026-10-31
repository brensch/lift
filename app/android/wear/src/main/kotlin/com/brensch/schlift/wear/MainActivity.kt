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
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
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
                onFix = { completedSetId, reps, weight -> sendFix(completedSetId, reps, weight) },
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

    private fun hasExerciseSessionHeartRatePermission(): Boolean =
        if (Build.VERSION.SDK_INT >= 36) {
            hasReadHeartRatePermission()
        } else {
            hasBodySensorsPermission()
        }

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

    /** A tap in the fix window: [reps] for the set just done. */
    private fun sendFix(
        completedSetId: String,
        reps: Int,
        weight: Float,
    ) {
        val workoutId = WearDataRepository.snapshot.value?.workoutId ?: return
        send(
            Wearable.WearIntent
                .newBuilder()
                .setEditCompletedSet(
                    Wearable.EditCompletedSetIntent
                        .newBuilder()
                        .setWorkoutId(workoutId)
                        .setCompletedSetId(completedSetId)
                        .setReps(reps)
                        .setActualWeight(weight)
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
                                .setEffort(action.effort)
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
    onFix: (String, Int, Float) -> Unit,
    setWorkoutKeepScreenOn: (Boolean) -> Unit,
    isAmbientMode: Boolean,
) {
    val snapshot by WearDataRepository.snapshot.collectAsState()
    val latestBpm by WearDataRepository.latestBpm.collectAsState()
    val nowTick by produceState(initialValue = System.currentTimeMillis() / 1000) {
        while (true) {
            value = System.currentTimeMillis() / 1000
            delay(1000)
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
            onFix = onFix,
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
    onFix: (String, Int, Float) -> Unit,
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

    // The fix window: for a few seconds after a set ends, each tap on the big
    // button takes a rep off it (and holds the window open), whichever device
    // logged it. The reps shown are the watch's own until the phone answers.
    val lastDone = if (data.hasLastDone()) data.lastDone else null
    var fixReps by remember(lastDone?.completedSetId) { mutableStateOf(lastDone?.reps ?: 0) }
    var lastFixTapMs by remember(lastDone?.completedSetId) { mutableLongStateOf(0L) }
    val fixWindowEndMs =
        lastDone?.let { maxOf(it.endedAt * 1000L, lastFixTapMs) + FIX_WINDOW_MS } ?: 0L
    val fineNowMs by produceState(
        initialValue = WearDataRepository.synchronizedNowUnixMillis(),
        fixWindowEndMs,
    ) {
        while (WearDataRepository.synchronizedNowUnixMillis() < fixWindowEndMs) {
            value = WearDataRepository.synchronizedNowUnixMillis()
            delay(100)
        }
        value = WearDataRepository.synchronizedNowUnixMillis()
    }
    val inFixWindow =
        lastDone != null &&
            data.state != WorkoutOuterClass.WorkoutState.WORKOUT_STATE_LIFTING &&
            fineNowMs < fixWindowEndMs
    var showPlates by remember(data.workoutId) { mutableStateOf(false) }
    // The fix window's bar, animated rather than redrawn on a tick so it drains
    // smoothly; a tap restarts it from full.
    val windowLeft = remember(lastDone?.completedSetId) { Animatable(0f) }
    LaunchedEffect(fixWindowEndMs) {
        val leftMs = fixWindowEndMs - WearDataRepository.synchronizedNowUnixMillis()
        if (leftMs <= 0L) {
            windowLeft.snapTo(0f)
            return@LaunchedEffect
        }
        windowLeft.snapTo(leftMs.toFloat() / FIX_WINDOW_MS)
        windowLeft.animateTo(0f, tween(durationMillis = leftMs.toInt(), easing = LinearEasing))
    }

    val lifting = data.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_LIFTING
    val resting =
        data.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_RESTING ||
            data.state == WorkoutOuterClass.WorkoutState.WORKOUT_STATE_YAPPING
    val yapping = resting && restTimer.countingUp
    val primary =
        action(Wearable.WearActionType.WEAR_ACTION_TYPE_COMPLETE_SET)
            ?: action(Wearable.WearActionType.WEAR_ACTION_TYPE_START_SET)

    val stageColor =
        when {
            card.firstTime -> WearPalette.FirstTime
            lifting -> WearPalette.Lifting
            yapping -> WearPalette.Yapping
            resting -> WearPalette.Resting
            else -> WearPalette.Ready
        }
    val face =
        SplitFace(
            label =
                when {
                    yapping -> card.yappingLabel.ifEmpty { card.stateLabel }
                    else -> card.stateLabel
                },
            labelColor =
                when {
                    card.firstTime || lifting -> WearPalette.LiftingInk
                    yapping -> WearPalette.YappingInk
                    resting -> WearPalette.Resting
                    else -> WearPalette.ReadyInk
                },
            timer =
                when {
                    card.firstTime -> ""
                    lifting -> deriveLiftingTimer(data)
                    resting -> restTimer.text
                    else -> ""
                },
            bpm = latestBpm,
            elapsed = elapsedText,
            clock = java.text.SimpleDateFormat("H:mm", java.util.Locale.getDefault()).format(java.util.Date(nowTick * 1000L)),
            exercise = card.exerciseName,
            position = card.setLine,
            weight = card.weightText.ifEmpty { card.setText },
            unit = card.unitText,
            upNext = if (data.nextUpEmoji.isEmpty()) "" else "next ${data.nextUpEmoji}",
            reps = if (inFixWindow) "$fixReps" else card.repsText,
            // The button names the stage; in the fix window, what a tap does.
            cue =
                when {
                    inFixWindow -> lastDone!!.cue
                    yapping -> card.yappingLabel.ifEmpty { card.stateLabel }
                    else -> card.stateLabel
                },
            buttonColor = if (inFixWindow) WearPalette.Fix else stageColor,
            buttonInk =
                when {
                    inFixWindow || (lifting && !card.firstTime) -> WearPalette.Text
                    else -> WearPalette.OnDark
                },
            window = if (inFixWindow) windowLeft.value else 0f,
            hasPlates = card.platesText.isNotEmpty(),
        )

    PlateDialog(card = card, show = showPlates && !isAmbientMode, onDismiss = { showPlates = false })
    when {
        isAmbientMode -> {
            AmbientScreen(face = face)
        }

        else -> {
            SplitScreen(
                face = face,
                enabled = inFixWindow || (primary != null && !isActionPending),
                onTap = {
                    if (inFixWindow && lastDone != null) {
                        fixReps = (fixReps - 1).coerceAtLeast(0)
                        lastFixTapMs = WearDataRepository.synchronizedNowUnixMillis()
                        onFix(lastDone.completedSetId, fixReps, lastDone.actualWeight)
                    } else {
                        primary?.let(fire)
                    }
                },
                onWeight = { showPlates = true },
            )
        }
    }
}

/** How long after a set ends a tap on the big button takes a rep off it. */
private const val FIX_WINDOW_MS = 3000L
