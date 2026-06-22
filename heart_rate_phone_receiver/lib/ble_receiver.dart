import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'heart_rate_database.dart';

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

  // Harus identik dengan UUID di MainActivity.kt pada project watch.
  static final Guid recordServiceUuid =
      Guid('0000a100-0000-1000-8000-00805f9b34fb');
  static final Guid recordCharUuid =
      Guid('0000a101-0000-1000-8000-00805f9b34fb');

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

  /// Dipancarkan untuk **setiap** record yang berhasil diterima & disimpan,
  /// agar UI bisa menambahkannya ke daftar secara real-time.
  final _readingController = StreamController<HeartRateReading>.broadcast();
  Stream<HeartRateReading> get onReading => _readingController.stream;

  /// Dipanggil setiap satu **batch** selesai diterima & disimpan ke database;
  /// nilainya adalah jumlah record dalam batch tersebut.
  final _batchController = StreamController<int>.broadcast();
  Stream<int> get onBatch => _batchController.stream;

  BluetoothDevice? _device;
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
    _setStatus(ReceiverStatus.idle, null);
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
    for (final service in services) {
      if (service.uuid != recordServiceUuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid == recordCharUuid) recordChar = c;
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
      for (final r in readings) {
        _readingController.add(r);
      }
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
    _readingController.close();
    _batchController.close();
  }
}
