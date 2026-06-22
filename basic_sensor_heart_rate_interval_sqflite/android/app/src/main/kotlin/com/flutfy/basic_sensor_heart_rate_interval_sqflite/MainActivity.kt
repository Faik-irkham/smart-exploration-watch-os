package com.flutfy.basic_sensor_heart_rate_interval_sqflite

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    companion object {
        // Harus sama dengan nama channel di sisi Dart (lihat lib/main.dart)
        private const val HEART_RATE_CHANNEL = "heart_rate/stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HEART_RATE_CHANNEL)
            .setStreamHandler(HeartRateStreamHandler(applicationContext))
    }
}

/**
 * Membaca sensor TYPE_HEART_RATE dan men-stream-kan setiap pembacaan ke Flutter
 * lewat EventChannel. Listener didaftarkan saat Dart mulai mendengarkan stream,
 * dan dilepas saat stream dibatalkan agar hemat baterai.
 *
 * Pada mode interval, sisi Dart hanya mengaktifkan stream sebentar setiap N menit
 * untuk mengambil satu pembacaan, lalu membatalkannya kembali.
 */
class HeartRateStreamHandler(
    private val context: Context,
) : EventChannel.StreamHandler, SensorEventListener {

    private var sensorManager: SensorManager? = null
    private var heartRateSensor: Sensor? = null
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
        manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(this)
        sensorManager = null
        heartRateSensor = null
        eventSink = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_HEART_RATE) return
        val bpm = event.values.firstOrNull() ?: return
        eventSink?.success(
            mapOf(
                "bpm" to bpm,
                // 0 = tidak bisa dipercaya, 1 = rendah, 2 = sedang, 3 = tinggi
                "accuracy" to event.accuracy,
            ),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Tidak perlu ditangani; nilai accuracy dikirim bersama setiap pembacaan.
    }
}
