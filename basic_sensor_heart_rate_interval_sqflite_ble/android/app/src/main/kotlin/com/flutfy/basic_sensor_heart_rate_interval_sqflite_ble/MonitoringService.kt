package com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service yang menjaga proses tetap hidup selama pemantauan, sehingga
 * pembacaan sensor, penyimpanan SQLite, dan pengiriman batch BLE tetap berjalan
 * saat aplikasi di-background atau layar watch mati.
 *
 * Service ini sengaja **tidak** memuat logika pemantauan; logika tetap di Dart
 * (lihat HeartRatePage) yang terus dieksekusi karena (1) FlutterEngine Activity
 * tidak di-destroy saat layar mati dan (2) PARTIAL_WAKE_LOCK menjaga CPU aktif.
 *
 * Mulai/stop dikontrol dari Dart lewat MethodChannel di MainActivity.
 */
class MonitoringService : Service() {

    companion object {
        private const val TAG = "HR-FGS"
        private const val CHANNEL_ID = "hr_monitoring"
        private const val NOTIF_ID = 1001
        private const val WAKELOCK_TAG = "hr:monitoring"
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        acquireWakeLock()
        Log.d(TAG, "foreground service dimulai")
        // START_STICKY: jika sistem membunuh service saat sumber daya menipis,
        // sistem mencoba membuat ulang (tanpa intent terakhir).
        return START_STICKY
    }

    private fun startAsForeground() {
        createChannel()
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Pemantauan detak jantung aktif")
            .setContentText("Merekam & mengirim data ke ponsel di latar belakang")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        when {
            // API 34+: wajib menyertakan tipe foreground service saat start.
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
            // API 30–33: tipe connectedDevice sudah tersedia.
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
            else -> startForeground(NOTIF_ID, notification)
        }
    }

    private fun createChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Pemantauan Detak Jantung",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { description = "Indikator bahwa pemantauan sedang berjalan." },
            )
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onDestroy() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (e: Exception) {
            Log.e(TAG, "release wakelock", e)
        }
        wakeLock = null
        Log.d(TAG, "foreground service dihentikan")
        super.onDestroy()
    }
}
