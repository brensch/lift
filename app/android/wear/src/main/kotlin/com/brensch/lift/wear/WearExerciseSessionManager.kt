package com.brensch.lift.wear

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class WearExerciseSessionManager(private val context: Context) {
    private val exerciseClient = HealthServices.getClient(context).exerciseClient
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var ensureJob: Job? = null

    @Volatile
    private var active = false

    fun ensureSessionActive() {
        if (active) return
        if (ensureJob?.isActive == true) return
        ensureJob = scope.launch {
            while (isActive && !active) {
                runCatching {
                    val config = ExerciseConfig.builder(ExerciseType.STRENGTH_TRAINING)
                        .setIsGpsEnabled(false)
                        .build()
                    exerciseClient.startExerciseAsync(config).await()
                    active = true
                    Log.i("LiftWear", "Exercise session started")
                }.onFailure {
                    Log.e("LiftWear", "Failed to start exercise session", it)
                }
                if (!active) {
                    delay(5000)
                }
            }
        }
    }

    fun endSessionIfActive() {
        ensureJob?.cancel()
        ensureJob = null
        if (!active) return
        scope.launch {
            runCatching {
                exerciseClient.endExerciseAsync().await()
                Log.i("LiftWear", "Exercise session ended")
            }.onFailure {
                Log.e("LiftWear", "Failed to end exercise session", it)
            }
            active = false
        }
    }

    private fun logPermissionStatus() {
        val bodySensors = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.BODY_SENSORS,
        ) == PackageManager.PERMISSION_GRANTED
        val activityRecognition = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.ACTIVITY_RECOGNITION,
        ) == PackageManager.PERMISSION_GRANTED
        val readHeartRate = ContextCompat.checkSelfPermission(
            context,
            "android.permission.health.READ_HEART_RATE",
        ) == PackageManager.PERMISSION_GRANTED
        Log.i(
            "LiftWear",
            "Permissions body=$bodySensors activity=$activityRecognition readHr=$readHeartRate",
        )
    }
}
