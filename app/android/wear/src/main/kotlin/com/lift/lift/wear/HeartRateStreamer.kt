package com.lift.lift.wear

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import workout.v1.Wearable

class HeartRateStreamer(private val context: Context) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val heartRateSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile
    private var workoutId: String? = null

    fun start(workoutId: String) {
        this.workoutId = workoutId
        val sensor = heartRateSensor ?: return
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    fun stop() {
        workoutId = null
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val activeWorkoutId = workoutId ?: return
        val bpm = event?.values?.firstOrNull() ?: return
        val sample = Wearable.HeartRateSample.newBuilder()
            .setSampledAt(System.currentTimeMillis())
            .setBpm(bpm)
            .setAvailability(Wearable.HeartRateAvailability.HEART_RATE_AVAILABILITY_AVAILABLE)
            .build()

        val batch = Wearable.WearSensorBatch.newBuilder()
            .setWorkoutId(activeWorkoutId)
            .addHeartRateSamples(sample)
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
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
