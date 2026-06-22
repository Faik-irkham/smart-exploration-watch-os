package com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        // Harus sama dengan nama channel di sisi Dart (lihat lib/).
        private const val HEART_RATE_CHANNEL = "heart_rate/stream"
        private const val BLE_METHOD_CHANNEL = "heart_rate/ble"
        private const val BLE_STATUS_CHANNEL = "heart_rate/ble/status"
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        bleServer?.stop()
        bleServer = null
        super.onDestroy()
    }
}

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

        val registered =
            manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        Log.d(TAG, "registerListener heart rate => $registered")
        if (!registered) {
            events?.error(
                "REGISTER_FAILED",
                "Gagal mengaktifkan sensor. Pastikan izin Sensor tubuh diizinkan " +
                    "dan mode hemat daya mati.",
                null,
            )
        }
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

/**
 * GATT server + BLE advertiser. Watch berperan sebagai **peripheral** yang
 * mengiklankan sebuah custom service berisi karakteristik "record" (notify).
 * Setiap pembacaan valid dikirim sebagai JSON `{bpm, accuracy, time}` lewat
 * notifikasi, sehingga aplikasi di smartphone bisa membangun ulang database
 * SQLite yang isinya identik dengan watch (lengkap dengan timestamp asli).
 *
 * Aplikasi phone tinggal scan service ini, connect, lalu subscribe ke
 * karakteristik record untuk menerima data.
 */
class HeartRateBleServer(private val context: Context) {

    companion object {
        private const val TAG = "HR-BLE"
        // Tag khusus metrik. Baris CSV bisa ditarik dengan:
        //   adb logcat -s HR-METRIC:I
        // Kolom: event,records,bytes,frames,mtu,duration_ms,throughput_Bps
        private const val METRIC_TAG = "HR-METRIC"

        // Custom UUID (128-bit) untuk service & karakteristik record. Harus
        // sama dengan yang dipakai aplikasi phone saat scan/subscribe.
        val RECORD_SERVICE_UUID: UUID = UUID.fromString("0000a100-0000-1000-8000-00805f9b34fb")
        val RECORD_CHAR_UUID: UUID = UUID.fromString("0000a101-0000-1000-8000-00805f9b34fb")
        // Client Characteristic Configuration Descriptor (untuk enable notify).
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        // Opcode pada byte pertama tiap notifikasi, agar phone bisa merangkai
        // batch yang dipecah menjadi beberapa chunk.
        private const val OP_START: Byte = 0x01 // awal batch baru
        private const val OP_DATA: Byte = 0x02  // potongan data JSON
        private const val OP_END: Byte = 0x03   // akhir batch
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var recordChar: BluetoothGattCharacteristic? = null

    // Perangkat yang sudah meng-enable notify (boleh menerima notifikasi).
    private val subscribers = mutableSetOf<BluetoothDevice>()
    private var advertising = false

    // Pengiriman batch dengan flow-control: chunk berikutnya dikirim setelah
    // onNotificationSent dari chunk sebelumnya.
    private val sendQueue = ArrayDeque<ByteArray>()
    private var sending = false
    private var negotiatedMtu = 23 // default ATT MTU sebelum dinegosiasikan

    // Metrik per batch (untuk evaluasi pada paper).
    private var batchRecords = 0       // jumlah record dalam batch berjalan
    private var batchPayloadBytes = 0  // ukuran payload JSON (tanpa header/opcode)
    private var batchFrames = 0        // total frame (START + DATA… + END)
    private var batchStartNs = 0L      // waktu mulai mengirim frame pertama

    private var statusSink: EventChannel.EventSink? = null

    val statusHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            statusSink = events
            // Kirim status terkini begitu Dart mulai mendengarkan.
            emit(if (isConnected()) "connected" else if (advertising) "advertising" else "idle")
        }

        override fun onCancel(arguments: Any?) {
            statusSink = null
        }
    }

    fun isConnected(): Boolean = subscribers.isNotEmpty()

    private fun emit(state: String, message: String? = null) {
        mainHandler.post {
            statusSink?.success(mapOf("state" to state, "message" to message))
        }
    }

    @SuppressLint("MissingPermission")
    fun start() {
        val adapter = bluetoothManager.adapter
        if (adapter == null || !adapter.isEnabled) {
            emit("error", "Bluetooth tidak aktif")
            return
        }
        if (adapter.bluetoothLeAdvertiser == null) {
            emit("error", "Perangkat tidak mendukung BLE advertising")
            return
        }
        if (gattServer == null) {
            try {
                openGattServer()
            } catch (e: SecurityException) {
                emit("error", "Izin Bluetooth belum diberikan")
                Log.e(TAG, "openGattServer", e)
                return
            }
        }
        startAdvertising(adapter.bluetoothLeAdvertiser)
    }

    @SuppressLint("MissingPermission")
    private fun openGattServer() {
        val server = bluetoothManager.openGattServer(context, gattServerCallback) ?: run {
            emit("error", "Gagal membuka GATT server")
            return
        }
        gattServer = server

        val service = BluetoothGattService(
            RECORD_SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY,
        )
        val characteristic = BluetoothGattCharacteristic(
            RECORD_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            // Notify-only: tidak butuh izin read/write pada karakteristik itu sendiri.
            0,
        )
        val cccd = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE,
        )
        characteristic.addDescriptor(cccd)
        service.addCharacteristic(characteristic)
        server.addService(service)
        recordChar = characteristic
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising(adv: BluetoothLeAdvertiser) {
        if (advertising) return
        advertiser = adv

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTimeout(0) // tanpa batas waktu; berhenti manual lewat stop()
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        // Paket utama: service UUID agar mudah difilter oleh aplikasi ponsel.
        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(RECORD_SERVICE_UUID))
            .build()

        // Nama perangkat ditaruh di scan response agar tidak melebihi 31 byte.
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .build()

        try {
            adv.startAdvertising(settings, data, scanResponse, advertiseCallback)
        } catch (e: SecurityException) {
            emit("error", "Izin BLUETOOTH_ADVERTISE belum diberikan")
            Log.e(TAG, "startAdvertising", e)
        }
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (e: SecurityException) {
            Log.e(TAG, "stopAdvertising", e)
        }
        advertiser = null
        advertising = false

        try {
            gattServer?.close()
        } catch (e: SecurityException) {
            Log.e(TAG, "closeGattServer", e)
        }
        gattServer = null
        recordChar = null
        subscribers.clear()
        sendQueue.clear()
        sending = false
        emit("idle")
    }

    /**
     * Kirim satu **batch** (JSON array `[{bpm, accuracy, time}, ...]`) ke
     * perangkat yang sedang subscribe. Payload dipecah menjadi beberapa chunk
     * berukuran sesuai MTU, masing-masing diawali opcode (START/DATA/END) agar
     * phone bisa merangkainya kembali. Chunk dikirim satu per satu dengan
     * flow-control lewat [onNotificationSent].
     *
     * Mengembalikan `true` bila ada perangkat terhubung dan batch di-antrekan.
     */
    fun sendBatch(json: String, count: Int = 0): Boolean {
        if (subscribers.isEmpty() || recordChar == null) return false
        val bytes = json.toByteArray(Charsets.UTF_8)
        // Sisakan ruang untuk header ATT (3 byte) dan opcode (1 byte).
        val chunkSize = (negotiatedMtu - 3 - 1).coerceAtLeast(18)

        sendQueue.clear()
        sendQueue.add(byteArrayOf(OP_START))
        var i = 0
        while (i < bytes.size) {
            val end = minOf(i + chunkSize, bytes.size)
            val frame = ByteArray(end - i + 1)
            frame[0] = OP_DATA
            System.arraycopy(bytes, i, frame, 1, end - i)
            sendQueue.add(frame)
            i = end
        }
        sendQueue.add(byteArrayOf(OP_END))

        // Catat metrik batch; durasi diukur saat frame pertama benar-benar dikirim.
        batchRecords = count
        batchPayloadBytes = bytes.size
        batchFrames = sendQueue.size
        batchStartNs = 0L

        Log.d(TAG, "sendBatch ${bytes.size} byte dalam ${sendQueue.size} frame (mtu=$negotiatedMtu)")
        if (!sending) sendNextFrame()
        return true
    }

    /** Kirim satu frame dari antrean ke semua subscriber. */
    @SuppressLint("MissingPermission")
    private fun sendNextFrame() {
        val characteristic = recordChar
        val server = gattServer
        val frame = sendQueue.poll()
        if (frame == null || characteristic == null || server == null) {
            // Antrean habis → batch selesai terkirim. Catat metrik bila sebelumnya
            // memang ada pengiriman berjalan (batchStartNs sudah diset).
            if (sending && batchStartNs > 0L) {
                val durationMs = (System.nanoTime() - batchStartNs) / 1_000_000.0
                val throughput = if (durationMs > 0) {
                    (batchPayloadBytes * 1000.0 / durationMs).toLong()
                } else 0L
                Log.i(
                    METRIC_TAG,
                    "tx_batch,$batchRecords,$batchPayloadBytes,$batchFrames," +
                        "$negotiatedMtu,${"%.1f".format(durationMs)},$throughput",
                )
                batchStartNs = 0L
            }
            sending = false
            return
        }
        // Tandai awal pengiriman pada frame pertama batch.
        if (batchStartNs == 0L) batchStartNs = System.nanoTime()
        sending = true
        characteristic.value = frame
        for (device in subscribers.toList()) {
            try {
                server.notifyCharacteristicChanged(device, characteristic, false)
            } catch (e: SecurityException) {
                Log.e(TAG, "notifyCharacteristicChanged", e)
            }
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            advertising = true
            Log.d(TAG, "advertising dimulai")
            emit(if (isConnected()) "connected" else "advertising", "menunggu koneksi")
        }

        override fun onStartFailure(errorCode: Int) {
            advertising = false
            Log.e(TAG, "advertising gagal: $errorCode")
            emit("error", "Advertising gagal (kode $errorCode)")
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            device ?: return
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "perangkat terhubung: ${device.address}")
                    emit("connected", device.address)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "perangkat terputus: ${device.address}")
                    subscribers.remove(device)
                    // Hentikan pengiriman batch yang sedang berjalan.
                    sendQueue.clear()
                    sending = false
                    negotiatedMtu = 23
                    emit(if (advertising) "advertising" else "idle", "perangkat terputus")
                }
            }
        }

        override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
            // Simpan MTU hasil negosiasi central agar chunk batch dibuat optimal.
            negotiatedMtu = mtu
            Log.d(TAG, "MTU dinegosiasikan: $mtu")
        }

        override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
            // Flow-control: kirim chunk berikutnya setelah yang sebelumnya tuntas.
            sendNextFrame()
        }

        @SuppressLint("MissingPermission")
        override fun onDescriptorWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            descriptor: BluetoothGattDescriptor?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            if (device != null && descriptor?.uuid == CCCD_UUID && value != null) {
                // value == ENABLE_NOTIFICATION_VALUE (0x01, 0x00) → subscribe.
                val enable = value.isNotEmpty() && value[0].toInt() != 0
                if (enable) {
                    subscribers.add(device)
                    emit("connected", device.address)
                } else {
                    subscribers.remove(device)
                }
                Log.d(TAG, "CCCD write enable=$enable dari ${device.address}")
            }
            if (responseNeeded) {
                try {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        android.bluetooth.BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value,
                    )
                } catch (e: SecurityException) {
                    Log.e(TAG, "sendResponse", e)
                }
            }
        }
    }
}
