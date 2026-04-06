package com.brensch.schlift.wear

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import workout.v1.Wearable

class HeartRateStreamer(private val context: Context) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val heartRateSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val pendingSamples = mutableListOf<Wearable.HeartRateSample>()
    private val pendingLock = Any()
    private var flushJob: Job? = null

    @Volatile
    private var workoutId: String? = null

    fun start(workoutId: String) {
        if (this.workoutId == workoutId && flushJob?.isActive == true) return
        stop()
        this.workoutId = workoutId
        if (!hasRequiredPermissions()) {
            Log.w("SchliftWear", "Heart rate permissions missing, skipping sensor start")
            return
        }
        val sensor = heartRateSensor
        if (sensor == null) {
            Log.w("SchliftWear", "No heart rate sensor available on this watch")
            return
        }
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        flushJob = scope.launch {
            while (isActive) {
                delay(5000)
                flushPending()
            }
        }
    }

    fun stop() {
        flushPending()
        workoutId = null
        flushJob?.cancel()
        flushJob = null
        WearDataRepository.updateLatestBpm(null)
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        workoutId ?: return
        val bpm = event?.values?.firstOrNull() ?: return
        val sample = Wearable.HeartRateSample.newBuilder()
            .setSampledAt(System.currentTimeMillis())
            .setBpm(bpm)
            .setAvailability(Wearable.HeartRateAvailability.HEART_RATE_AVAILABILITY_AVAILABLE)
            .build()
        synchronized(pendingLock) {
            pendingSamples.add(sample)
        }
        WearDataRepository.updateLatestBpm(bpm)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun hasRequiredPermissions(): Boolean {
        val bodySensorsGranted = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.BODY_SENSORS,
        ) == PackageManager.PERMISSION_GRANTED
        val readHeartRateGranted = ContextCompat.checkSelfPermission(
            context,
            "android.permission.health.READ_HEART_RATE",
        ) == PackageManager.PERMISSION_GRANTED
        return bodySensorsGranted || readHeartRateGranted
    }

    private fun flushPending() {
        val activeWorkoutId = workoutId ?: return
        val samples = synchronized(pendingLock) {
            if (pendingSamples.isEmpty()) {
                return
            }
            pendingSamples.toList().also { pendingSamples.clear() }
        }

        val batch = Wearable.WearSensorBatch.newBuilder()
            .setWorkoutId(activeWorkoutId)
            .addAllHeartRateSamples(samples)
            .build()

        val envelope = Wearable.WearToPhoneEnvelope.newBuilder()
            .setSensorBatch(batch)
            .build()

        scope.launch {
            runCatching {
                WearTransport.sendToPhone(
                    context,
                    WearTransport.WEAR_TO_PHONE_PATH,
                    envelope.toByteArray(),
                )
            }
                .onFailure {
                    Log.e("SchliftWear", "Failed to send HR batch", it)
                }
        }
    }
}
