package com.lift.lift.wear

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
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
        val sensor = heartRateSensor
        if (sensor == null) {
            WearDebugLog.add("HR sensor unavailable")
            return
        }
        WearDebugLog.add("HR start workout=$workoutId sensor=${sensor.name}")
        val registered = sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        WearDebugLog.add("HR listener registered=$registered")
        flushJob = scope.launch {
            while (isActive) {
                delay(5000)
                flushPending()
            }
        }
    }

    fun stop() {
        flushPending()
        if (workoutId != null) {
            WearDebugLog.add("HR stop")
        }
        workoutId = null
        flushJob?.cancel()
        flushJob = null
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
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

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
                    Log.e("LiftWear", "Failed to send HR batch", it)
                    WearDebugLog.add("HR batch send failed: ${it.message ?: it.javaClass.simpleName}")
                }
        }
    }
}
