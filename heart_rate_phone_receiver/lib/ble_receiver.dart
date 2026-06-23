import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'heart_rate_database.dart';
import 'models/heart_rate_reading.dart';

/// Status koneksi central (phone) ke watch.
enum ReceiverStatus { idle, scanning, connecting, connected, error }

/// Penerima BLE: phone berperan sebagai **central**.
///
/// Alurnya: minta izin → scan perangkat yang mengiklankan service record watch
/// → connect → minta MTU besar → subscribe karakteristik record → setiap
/// notifikasi JSON di-parse menjadi [HeartRateReading], disimpan ke SQLite, dan
/// dipancarkan lewat [onReading] agar UI bisa menampilkannya.
class BleReceiver {
  BleReceiver._();

  static final BleReceiver instance = BleReceiver._();

  // Kontrol foreground service native (lihat MainActivity.kt). Harus sama
  // dengan nama channel di sisi Android.
  static const _serviceChannel = MethodChannel('hr_receiver/service');

  // Harus identik dengan UUID di MainActivity.kt pada project watch.
  static final Guid recordServiceUuid =
      Guid('0000a100-0000-1000-8000-00805f9b34fb');
  static final Guid recordCharUuid =
      Guid('0000a101-0000-1000-8000-00805f9b34fb');
  // Karakteristik ACK: phone menulis konfirmasi setelah menyimpan batch.
  static final Guid ackCharUuid =
      Guid('0000a102-0000-1000-8000-00805f9b34fb');

  // Opcode pada byte pertama tiap notifikasi (sama dengan watch).
  static const _opStart = 0x01;
  static const _opData = 0x02;
  static const _opEnd = 0x03;

  // Buffer perakitan batch yang datang berchunk.
  final List<int> _rxBuffer = [];

  // Metrik penerimaan per batch (untuk evaluasi pada paper).
  int _rxFrames = 0; // jumlah frame (START + DATA… + END) batch berjalan
  final Stopwatch _rxStopwatch = Stopwatch(); // waktu START → END

  final _db = HeartRateDatabase.instance;

  /// Status koneksi terkini untuk indikator UI.
  final ValueNotifier<ReceiverStatus> status =
      ValueNotifier(ReceiverStatus.idle);

  /// Pesan tambahan (nama/alamat perangkat atau pesan error).
  final ValueNotifier<String?> message = ValueNotifier(null);

  /// Dipancarkan untuk setiap **batch** record yang berhasil diterima & disimpan
  /// (urut terlama→terbaru). UI memperbarui daftar dalam satu kali update per
  /// batch, bukan per record.
  final _readingsController =
      StreamController<List<HeartRateReading>>.broadcast();
  Stream<List<HeartRateReading>> get onReadings => _readingsController.stream;

  /// Dipanggil setiap satu **batch** selesai diterima & disimpan ke database;
  /// nilainya adalah jumlah record dalam batch tersebut.
  final _batchController = StreamController<int>.broadcast();
  Stream<int> get onBatch => _batchController.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _ackChar; // untuk menulis ACK ke watch
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<List<int>>? _valueSub;

  /// Minta izin Bluetooth, scan watch, lalu connect & subscribe.
  Future<void> start() async {
    final ok = await _ensurePermissions();
    if (!ok) {
      _setError('Izin Bluetooth ditolak');
      return;
    }
    if (await FlutterBluePlus.isSupported == false) {
      _setError('Perangkat tidak mendukung Bluetooth');
      return;
    }
    // Tunggu Bluetooth menyala (atau minta user menyalakannya).
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      _setError('Nyalakan Bluetooth lalu coba lagi');
      return;
    }

    // Jaga proses tetap hidup di background / layar mati selama menerima.
    await _startService();

    _setStatus(ReceiverStatus.scanning, 'Mencari watch…');

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) return;
      // Ambil hasil pertama yang cocok lalu langsung connect.
      final result = results.first;
      _stopScan();
      _connect(result.device);
    }, onError: (Object e) => _setError(e.toString()));

    try {
      await FlutterBluePlus.startScan(
        withServices: [recordServiceUuid],
        timeout: const Duration(seconds: 20),
      );
    } catch (e) {
      _setError('Gagal memulai scan: $e');
    }
  }

  /// Putuskan koneksi dan hentikan scan.
  Future<void> stop() async {
    await _stopScan();
    await _valueSub?.cancel();
    _valueSub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    await _stopService();
    _setStatus(ReceiverStatus.idle, null);
  }

  /// Tulis [bytes] ke folder Downloads publik lewat MediaStore (tanpa izin
  /// khusus, Android 10+). Mengembalikan nama file bila sukses, atau null.
  Future<String?> saveToDownloads(
    String name,
    String mime,
    Uint8List bytes,
  ) async {
    try {
      return await _serviceChannel.invokeMethod<String>('saveToDownloads', {
        'name': name,
        'mime': mime,
        'bytes': bytes,
      });
    } on PlatformException catch (e) {
      debugPrint('[RX] saveToDownloads gagal: ${e.message}');
      return null;
    }
  }

  /// Mulai foreground service agar penerimaan tetap berjalan saat app di
  /// background / layar mati.
  Future<void> _startService() async {
    try {
      await _serviceChannel.invokeMethod('startService');
    } on PlatformException catch (e) {
      debugPrint('[RX] startService gagal: ${e.message}');
    }
  }

  /// Hentikan foreground service.
  Future<void> _stopService() async {
    try {
      await _serviceChannel.invokeMethod('stopService');
    } on PlatformException catch (_) {
      // Menghentikan service yang sudah berhenti tidak masalah.
    }
  }

  Future<void> _stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    if (FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;
    _setStatus(ReceiverStatus.connecting, device.platformName.isEmpty
        ? device.remoteId.str
        : device.platformName);

    _connStateSub?.cancel();
    _connStateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _setStatus(ReceiverStatus.idle, 'Watch terputus');
      }
    });

    try {
      // License.nonprofit: penggunaan non-komersial/edukasi sesuai lisensi
      // flutter_blue_plus.
      await device.connect(
        timeout: const Duration(seconds: 15),
        license: License.nonprofit,
      );
      // MTU besar agar JSON record tidak terpotong saat notifikasi.
      try {
        await device.requestMtu(512);
      } catch (_) {
        // Sebagian perangkat menolak; biarkan pakai MTU default.
      }
      await _subscribe(device);
    } catch (e) {
      _setError('Gagal connect: $e');
    }
  }

  Future<void> _subscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    BluetoothCharacteristic? recordChar;
    _ackChar = null;
    for (final service in services) {
      if (service.uuid != recordServiceUuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid == recordCharUuid) recordChar = c;
        if (c.uuid == ackCharUuid) _ackChar = c;
      }
    }

    if (recordChar == null) {
      _setError('Karakteristik record tidak ditemukan');
      return;
    }

    await recordChar.setNotifyValue(true);
    _valueSub?.cancel();
    _valueSub = recordChar.onValueReceived.listen(
      _handleValue,
      onError: (Object e) => _setError(e.toString()),
    );

    _setStatus(ReceiverStatus.connected, device.platformName.isEmpty
        ? device.remoteId.str
        : device.platformName);
  }

  /// Tangani satu notifikasi BLE. Watch mengirim batch ber-frame: byte pertama
  /// adalah opcode (START/DATA/END), sisanya potongan JSON. Frame DATA dirangkai
  /// di [_rxBuffer]; saat END diterima, buffer di-decode sebagai JSON **array**
  /// `[{bpm, accuracy, time}, ...]`, disimpan satu transaksi, lalu tiap record
  /// dipancarkan lewat [onReading].
  Future<void> _handleValue(List<int> value) async {
    if (value.isEmpty) return;
    final op = value.first;
    switch (op) {
      case _opStart:
        _rxBuffer.clear();
        _rxFrames = 1;
        _rxStopwatch
          ..reset()
          ..start();
      case _opData:
        _rxBuffer.addAll(value.sublist(1));
        _rxFrames++;
      case _opEnd:
        _rxFrames++;
        _rxStopwatch.stop();
        await _flushBuffer();
      default:
        debugPrint('[RX] opcode tidak dikenal: $op');
    }
  }

  /// Tulis ACK (jumlah record yang tersimpan) ke karakteristik ACK di watch.
  Future<void> _sendAck(int count) async {
    final ack = _ackChar;
    if (ack == null) return;
    try {
      await ack.write(utf8.encode('$count'), withoutResponse: false);
      debugPrint('[RX] ACK terkirim: $count record');
    } catch (e) {
      debugPrint('[RX] gagal kirim ACK: $e');
    }
  }

  /// Rakit isi [_rxBuffer] menjadi daftar record, simpan, lalu pancarkan.
  Future<void> _flushBuffer() async {
    if (_rxBuffer.isEmpty) return;
    final bytes = List<int>.from(_rxBuffer);
    _rxBuffer.clear();
    try {
      final text = utf8.decode(bytes);
      final list = (jsonDecode(text) as List).cast<dynamic>();
      final readings = <HeartRateReading>[
        for (final item in list)
          () {
            final map = (item as Map).cast<String, dynamic>();
            return HeartRateReading(
              bpm: (map['bpm'] as num).toDouble(),
              accuracy: (map['accuracy'] as num?)?.toInt() ?? 0,
              time: DateTime.fromMillisecondsSinceEpoch(
                (map['time'] as num?)?.toInt() ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }(),
      ];
      if (readings.isEmpty) return;
      // Simpan satu batch dalam satu transaksi, lalu ambil kembali dengan id.
      final insertSw = Stopwatch()..start();
      await _db.insertReadings(readings);
      insertSw.stop();
      // Baris metrik CSV (tarik dengan: flutter logs | grep HR-METRIC, atau
      // adb logcat). Kolom: event,records,bytes,frames,reassembly_ms,insert_ms
      debugPrint(
        'HR-METRIC,rx_batch,${readings.length},${bytes.length},$_rxFrames,'
        '${_rxStopwatch.elapsedMilliseconds},${insertSw.elapsedMilliseconds}',
      );
      // Kirim ACK ke watch (jumlah record tersimpan) agar watch menandai data
      // terkirim. Tanpa ACK, watch akan mengirim ulang batch ini nanti.
      await _sendAck(readings.length);
      _readingsController.add(readings);
      _batchController.add(readings.length);
    } catch (e) {
      debugPrint('[RX] gagal parse batch: $e');
    }
  }

  Future<bool> _ensurePermissions() async {
    // Android 12+: scan & connect. Android lama: lokasi untuk scan.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      // Android 13+: notifikasi untuk foreground service.
      Permission.notification,
    ].request();
    // Cukup selama scan & connect diberikan (lokasi hanya relevan di Android lama).
    return (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
        (statuses[Permission.bluetoothConnect]?.isGranted ?? false);
  }

  void _setStatus(ReceiverStatus s, String? msg) {
    status.value = s;
    message.value = msg;
  }

  void _setError(String msg) {
    status.value = ReceiverStatus.error;
    message.value = msg;
    debugPrint('[RX] error: $msg');
  }

  void dispose() {
    _readingsController.close();
    _batchController.close();
  }
}
