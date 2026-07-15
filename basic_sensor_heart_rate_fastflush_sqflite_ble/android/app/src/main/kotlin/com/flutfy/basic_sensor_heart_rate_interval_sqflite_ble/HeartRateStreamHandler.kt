package com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Membaca sensor TYPE_HEART_RATE dan men-stream-kan setiap pembacaan ke Flutter
 * lewat EventChannel. Listener didaftarkan saat Dart mulai mendengarkan stream,
 * dan dilepas saat stream dibatalkan agar hemat baterai.
 */
class HeartRateStreamHandler(
    private val context: Context,
) : EventChannel.StreamHandler, SensorEventListener {

    companion object {
        private const val TAG = "HR"
    }

    private var sensorManager: SensorManager? = null
    private var heartRateSensor: Sensor? = null
    private var accelerometerSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager = manager

        val sensor = manager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        if (sensor == null) {
            events?.error(
                "NO_SENSOR",
                "Sensor heart rate tidak tersedia di perangkat ini",
                null,
            )
            return
        }
        heartRateSensor = sensor

        val heartRateRegistered =
            manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        Log.d(TAG, "registerListener heart rate => $heartRateRegistered")
        if (!heartRateRegistered) {
            events?.error(
                "REGISTER_FAILED",
                "Gagal mengaktifkan sensor. Pastikan izin Sensor tubuh diizinkan " +
                    "dan mode hemat daya mati.",
                null,
            )
        }

        // Accelerometer diminta sekitar 25 Hz (40.000 mikrodetik). Sampel mentah
        // diringkas per detik di Dart agar database dan payload BLE tidak membesar
        // 25 kali. Android memberikan nilai dalam m/s².
        accelerometerSensor = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val accelerometerRegistered = accelerometerSensor?.let {
            manager.registerListener(this, it, 40_000)
        } ?: false
        Log.d(TAG, "registerListener accelerometer 25Hz => $accelerometerRegistered")
    }

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(this)
        sensorManager = null
        heartRateSensor = null
        accelerometerSensor = null
        eventSink = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        when (event.sensor.type) {
            Sensor.TYPE_HEART_RATE -> {
                val bpm = event.values.firstOrNull() ?: return
                eventSink?.success(
                    mapOf(
                        "type" to "heart_rate",
                        "bpm" to bpm,
                        // -1 = no contact, 0 = unreliable, 1..3 = low..high.
                        "accuracy" to event.accuracy,
                    ),
                )
            }
            Sensor.TYPE_ACCELEROMETER -> {
                if (event.values.size < 3) return
                eventSink?.success(
                    mapOf(
                        "type" to "accelerometer",
                        "x" to event.values[0],
                        "y" to event.values[1],
                        "z" to event.values[2],
                    ),
                )
            }
            else -> Unit
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Tidak perlu ditangani; nilai accuracy dikirim bersama setiap pembacaan.
    }
}
