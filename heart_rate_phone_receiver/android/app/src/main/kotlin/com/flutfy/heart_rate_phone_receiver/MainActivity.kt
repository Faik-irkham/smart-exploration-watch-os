package com.flutfy.heart_rate_phone_receiver

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        // Harus sama dengan nama channel di sisi Dart (BleReceiver).
        private const val SERVICE_CHANNEL = "hr_receiver/service"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                        val mime = call.argument<String>("mime")
                            ?: "application/octet-stream"
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
            Log.e("RX-EXPORT", "saveToDownloads", e)
            null
        }
    }
}
