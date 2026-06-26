package com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Activity Flutter yang mendaftarkan channel komunikasi ke native:
 * - [HeartRateStreamHandler] untuk streaming sensor,
 * - [HeartRateBleServer] untuk BLE peripheral (GATT + advertising),
 * - [MonitoringService] untuk menjaga proses hidup di background.
 */
class MainActivity : FlutterActivity() {
    companion object {
        // Harus sama dengan nama channel di sisi Dart (lihat lib/).
        private const val HEART_RATE_CHANNEL = "heart_rate/stream"
        private const val BLE_METHOD_CHANNEL = "heart_rate/ble"
        private const val BLE_STATUS_CHANNEL = "heart_rate/ble/status"
        private const val BLE_ACK_CHANNEL = "heart_rate/ble/ack"
    }

    private var bleServer: HeartRateBleServer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Sensor detak jantung (sama seperti versi tanpa BLE).
        EventChannel(messenger, HEART_RATE_CHANNEL)
            .setStreamHandler(HeartRateStreamHandler(applicationContext))

        // BLE peripheral: watch mengiklankan data ke smartphone.
        val server = HeartRateBleServer(applicationContext)
        bleServer = server
        EventChannel(messenger, BLE_STATUS_CHANNEL).setStreamHandler(server.statusHandler)
        EventChannel(messenger, BLE_ACK_CHANNEL).setStreamHandler(server.ackHandler)
        MethodChannel(messenger, BLE_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    server.start()
                    result.success(null)
                }
                "stopAdvertising" -> {
                    server.stop()
                    result.success(null)
                }
                "sendBatch" -> {
                    val json = call.argument<String>("json")
                    val count = call.argument<Int>("count") ?: 0
                    val accepted = json != null && server.sendBatch(json, count)
                    result.success(accepted)
                }
                "isConnected" -> result.success(server.isConnected())
                "startService" -> {
                    ContextCompat.startForegroundService(
                        this,
                        Intent(this, MonitoringService::class.java),
                    )
                    result.success(null)
                }
                "stopService" -> {
                    stopService(Intent(this, MonitoringService::class.java))
                    result.success(null)
                }
                "saveToDownloads" -> {
                    val name = call.argument<String>("name")
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    val bytes = call.argument<ByteArray>("bytes")
                    result.success(
                        if (name == null || bytes == null) null
                        else saveToDownloads(name, mime, bytes),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Tulis [bytes] ke folder Downloads publik lewat MediaStore (Android 10+,
     * tanpa izin runtime). Mengembalikan nama file bila sukses, atau null.
     */
    private fun saveToDownloads(name: String, mime: String, bytes: ByteArray): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return null
            resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return null
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            name
        } catch (e: Exception) {
            Log.e("HR-EXPORT", "saveToDownloads", e)
            null
        }
    }

    override fun onDestroy() {
        bleServer?.stop()
        bleServer = null
        super.onDestroy()
    }
}
