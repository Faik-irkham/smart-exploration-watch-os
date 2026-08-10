import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'heart_rate_database.dart';
import 'models/heart_rate_reading.dart';
import 'utils/crc32.dart';

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
  static final Guid recordServiceUuid = Guid(
    '0000a100-0000-1000-8000-00805f9b34fb',
  );
  static final Guid recordCharUuid = Guid(
    '0000a101-0000-1000-8000-00805f9b34fb',
  );
  // Karakteristik ACK: phone menulis konfirmasi setelah menyimpan batch.
  static final Guid ackCharUuid = Guid('0000a102-0000-1000-8000-00805f9b34fb');

  // Opcode pada byte pertama tiap notifikasi (sama dengan watch):
  //   START = 0x01 | batch_id(4) | expected_frames(2) | payload_length(4)
  //   DATA  = 0x02 | seq(2) | potongan JSON
  //   END   = 0x03 | crc32(4)
  static const _opStart = 0x01;
  static const _opData = 0x02;
  static const _opEnd = 0x03;
  static const _dataHeader = 3;

  // Buffer perakitan batch yang datang berchunk.
  final List<int> _rxBuffer = [];

  // Metrik penerimaan per batch (untuk evaluasi pada paper).
  int _rxFrames = 0; // jumlah frame (START + DATA… + END) batch berjalan
  final Stopwatch _rxStopwatch = Stopwatch(); // waktu START → END

  // Pengenal batch berjalan, dibaca dari frame START dan dikembalikan di dalam
  // ACK. Bernilai -1 bila END diterima tanpa START.
  int _rxBatchId = -1;

  // Percobaan connect selama sesi berjalan, untuk metrik keandalan tautan.
  int _connectAttempts = 0;
  int _connectFailures = 0;

  // Kelengkapan batch berjalan, diumumkan frame START lalu diperiksa saat END.
  int _rxExpectedFrames = 0;
  int _rxPayloadLength = 0;
  int _rxNextSeq = 0;
  // Diset bila ada frame DATA yang hilang atau datang tidak berurutan.
  bool _rxSeqBroken = false;

  final _db = HeartRateDatabase.instance;

  /// Status koneksi terkini untuk indikator UI.
  final ValueNotifier<ReceiverStatus> status = ValueNotifier(
    ReceiverStatus.idle,
  );

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
    _setStatus(
      ReceiverStatus.connecting,
      device.platformName.isEmpty ? device.remoteId.str : device.platformName,
    );

    _connStateSub?.cancel();
    _connStateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _setStatus(ReceiverStatus.idle, 'Watch terputus');
      }
    });

    _connectAttempts++;
    final connectSw = Stopwatch()..start();
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
      _logConnect(connectSw, 'ok');
    } catch (e) {
      _connectFailures++;
      _logConnect(connectSw, 'fail');
      _setError('Gagal connect: $e');
    }
  }

  /// Kolom: event,attempt,failures,result,duration_ms
  void _logConnect(Stopwatch sw, String result) {
    sw.stop();
    debugPrint(
      'HR-METRIC,connect,$_connectAttempts,$_connectFailures,$result,'
      '${sw.elapsedMilliseconds}',
    );
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

    _setStatus(
      ReceiverStatus.connected,
      device.platformName.isEmpty ? device.remoteId.str : device.platformName,
    );
  }

  /// Tangani satu notifikasi BLE. Watch mengirim batch ber-frame: byte pertama
  /// adalah opcode (START/DATA/END). Frame DATA dirangkai di [_rxBuffer]; saat
  /// END diterima, kelengkapannya diperiksa, buffer di-decode sebagai objek
  /// `{device, records}`, disimpan satu transaksi, lalu dipancarkan lewat
  /// [onReadings].
  Future<void> _handleValue(List<int> value) async {
    if (value.isEmpty) return;
    final op = value.first;
    switch (op) {
      case _opStart:
        _rxBuffer.clear();
        _rxFrames = 1;
        _rxNextSeq = 0;
        _rxSeqBroken = false;
        _rxBatchId = value.length >= 5 ? _readUint(value, 1, 4) : -1;
        _rxExpectedFrames = value.length >= 7 ? _readUint(value, 5, 2) : 0;
        _rxPayloadLength = value.length >= 11 ? _readUint(value, 7, 4) : 0;
        _rxStopwatch
          ..reset()
          ..start();
      case _opData:
        _rxFrames++;
        if (value.length < _dataHeader) {
          _rxSeqBroken = true;
          break;
        }
        // Nomor urut membuat frame yang hilang atau tertukar bisa dideteksi
        // sebelum payload dirangkai, bukan menunggu JSON gagal di-parse.
        final seq = _readUint(value, 1, 2);
        if (seq != _rxNextSeq) {
          debugPrint('[RX] frame tidak berurutan: seq=$seq, harusnya $_rxNextSeq');
          _rxSeqBroken = true;
        }
        _rxNextSeq = seq + 1;
        _rxBuffer.addAll(value.sublist(_dataHeader));
      case _opEnd:
        _rxFrames++;
        _rxStopwatch.stop();
        await _flushBuffer(
          crc: value.length >= 5 ? _readUint(value, 1, 4) : null,
        );
      default:
        debugPrint('[RX] opcode tidak dikenal: $op');
    }
  }

  /// Periksa kelengkapan batch yang baru dirangkai.
  ///
  /// Mengembalikan `null` bila batch utuh, atau nama cacatnya untuk dipakai
  /// sebagai `status` NACK. Pemeriksaan berlapis: nomor urut menangkap frame
  /// yang hilang/tertukar, panjang payload menangkap frame yang terpotong, dan
  /// CRC32 menangkap isi yang berubah meski panjangnya kebetulan cocok.
  String? _inspectBatch(List<int> bytes, int? crc, int batchId) {
    if (batchId < 0) return 'no_start';
    // Buffer kosong berarti seluruh frame DATA hilang; tanpa cabang ini batch
    // itu lewat tanpa ACK dan watch menunggu timeout sia-sia.
    if (bytes.isEmpty) return 'missing_frames';
    if (_rxSeqBroken) return 'missing_frames';
    if (_rxExpectedFrames > 0 && _rxNextSeq != _rxExpectedFrames) {
      return 'missing_frames';
    }
    if (_rxPayloadLength > 0 && bytes.length != _rxPayloadLength) {
      return 'length_mismatch';
    }
    if (crc != null && crc32(bytes) != crc) return 'crc_mismatch';
    return null;
  }

  /// Baca bilangan bulat big-endian sepanjang [length] byte mulai dari [offset].
  static int _readUint(List<int> frame, int offset, int length) {
    var value = 0;
    for (var i = 0; i < length; i++) {
      value = (value << 8) | (frame[offset + i] & 0xFF);
    }
    return value;
  }

  /// Tulis ACK `{batch_id, expected, stored, status}` ke karakteristik ACK di
  /// watch. [status] selain `ok` berfungsi sebagai NACK, sehingga watch tidak
  /// perlu menunggu timeout.
  Future<void> _sendAck({
    required int batchId,
    required int expected,
    required int stored,
    String status = 'ok',
  }) async {
    final ack = _ackChar;
    if (ack == null) return;
    final payload = jsonEncode({
      'batch_id': batchId,
      'expected': expected,
      'stored': stored,
      'status': status,
    });
    try {
      await ack.write(utf8.encode(payload), withoutResponse: false);
      debugPrint('[RX] ACK terkirim: $payload');
    } catch (e) {
      debugPrint('[RX] gagal kirim ACK: $e');
    }
  }

  /// Rakit isi [_rxBuffer] menjadi daftar record, simpan, lalu pancarkan.
  Future<void> _flushBuffer({int? crc}) async {
    // Ambil dan lepas keadaan batch berjalan secara sinkron, sebelum await
    // pertama — kalau tidak, START batch berikutnya yang datang saat
    // penyimpanan masih berlangsung bisa tertimpa.
    final bytes = List<int>.from(_rxBuffer);
    final batchId = _rxBatchId;
    _rxBuffer.clear();
    _rxBatchId = -1;

    // Periksa kelengkapan sebelum menyentuh payload: batch yang cacat ditolak
    // lewat NACK agar watch mengirim ulang tanpa menunggu timeout.
    final defect = _inspectBatch(bytes, crc, batchId);
    if (defect != null) {
      debugPrint('[RX] batch $batchId ditolak: $defect');
      await _sendAck(
        batchId: batchId,
        expected: 0,
        stored: 0,
        status: defect,
      );
      return;
    }

    try {
      final text = utf8.decode(bytes);
      final decoded = jsonDecode(text);
      // Payload v2 berbentuk objek {device, records}; bentuk array adalah
      // format lama yang masih diterima agar rekaman lama tetap bisa diputar.
      final list = decoded is Map
          ? (decoded['records'] as List).cast<dynamic>()
          : (decoded as List).cast<dynamic>();
      final deviceId = decoded is Map ? decoded['device'] as String? : null;
      final readings = <HeartRateReading>[
        for (final item in list)
          () {
            final map = (item as Map).cast<String, dynamic>();
            return HeartRateReading(
              deviceId: deviceId,
              recordId: (map['rid'] as num?)?.toInt(),
              bpm: (map['bpm'] as num).toDouble(),
              accuracy: (map['accuracy'] as num?)?.toInt() ?? 0,
              time: DateTime.fromMillisecondsSinceEpoch(
                (map['time'] as num?)?.toInt() ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
              accelMagnitudeMean: (map['accelMagnitudeMean'] as num?)
                  ?.toDouble(),
              accelMagnitudeStd: (map['accelMagnitudeStd'] as num?)?.toDouble(),
              accelSampleCount: (map['accelSampleCount'] as num?)?.toInt() ?? 0,
            );
          }(),
      ];
      if (readings.isEmpty) return;
      // Simpan satu batch dalam satu transaksi, lalu ambil kembali dengan id.
      final insertSw = Stopwatch()..start();
      final stored = await _db.insertReadings(readings);
      insertSw.stop();
      // Delay ujung-ke-ujung: selisih antara waktu sampel diambil di watch dan
      // saat tersimpan di ponsel. Record tertua menunjukkan berapa lama data
      // tertahan di antrean, yang terbaru mendekati latensi jalur normal.
      final now = DateTime.now();
      var oldestDelayMs = 0;
      var newestDelayMs = 0;
      for (final r in readings) {
        final delay = now.difference(r.time).inMilliseconds;
        if (delay > oldestDelayMs) oldestDelayMs = delay;
        if (newestDelayMs == 0 || delay < newestDelayMs) newestDelayMs = delay;
      }
      // Baris metrik CSV (tarik dengan: flutter logs | grep HR-METRIC, atau
      // adb logcat). Kolom: event,batch_id,records,stored,bytes,frames,
      // reassembly_ms,insert_ms,oldest_delay_ms,newest_delay_ms
      debugPrint(
        'HR-METRIC,rx_batch,$batchId,${readings.length},$stored,${bytes.length},'
        '$_rxFrames,${_rxStopwatch.elapsedMilliseconds},'
        '${insertSw.elapsedMilliseconds},$oldestDelayMs,$newestDelayMs',
      );
      // Konfirmasi ke watch agar record ditandai terkirim. Tanpa ACK yang
      // cocok, watch mengirim ulang batch ini nanti.
      await _sendAck(
        batchId: batchId,
        expected: readings.length,
        stored: stored,
        // Tanpa START batch tidak bisa diidentifikasi — minta kiriman ulang.
        status: batchId < 0 ? 'no_start' : 'ok',
      );
      _readingsController.add(readings);
      _batchController.add(readings.length);
    } catch (e) {
      debugPrint('[RX] gagal parse batch: $e');
      // NACK: beri tahu watch sekarang juga supaya tidak menunggu timeout.
      await _sendAck(
        batchId: batchId,
        expected: 0,
        stored: 0,
        status: 'parse_error',
      );
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
