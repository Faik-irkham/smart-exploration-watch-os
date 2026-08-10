import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/heart_rate_reading.dart';

/// Status BLE dari sisi native (watch berperan sebagai peripheral).
enum BleStatus { idle, advertising, connected, error }

/// Hasil satu percobaan pengiriman batch beserta konfirmasinya.
class BatchAckResult {
  const BatchAckResult({
    required this.batchId,
    required this.expected,
    this.ok = false,
    this.stored = 0,
    this.status = 'timeout',
    this.ackLatency,
  });

  /// Pengenal batch yang dikirim di frame START.
  final int batchId;

  /// Jumlah record yang dikirim watch.
  final int expected;

  /// `true` hanya bila ponsel mengonfirmasi batch **ini** tersimpan.
  final bool ok;

  /// Jumlah record yang baru tersimpan di ponsel.
  final int stored;

  /// `ok`, `parse_error`, `no_start`, `timeout`, atau `not_sent`.
  final String status;

  /// Waktu dari permintaan kirim sampai ACK yang cocok diterima.
  final Duration? ackLatency;

  /// Record yang ternyata sudah ada di ponsel sebelumnya.
  int get duplicates => ok ? expected - stored : 0;
}

/// Jembatan ke BLE GATT server native (lihat MainActivity.kt).
///
/// Watch berperan sebagai **peripheral / GATT server** yang mengiklankan
/// Heart Rate Service standar (0x180D). Aplikasi di smartphone cukup berperan
/// sebagai **central** biasa: melakukan scan, connect, lalu subscribe ke
/// karakteristik Heart Rate Measurement (0x2A37). Setiap watch mengambil satu
/// pembacaan baru, nilainya dikirim sebagai notifikasi BLE ke smartphone.
///
/// Karena Flutter tidak punya plugin peripheral yang andal, seluruh logika
/// advertising + GATT server diimplementasikan native (Kotlin) dan dikontrol
/// dari Dart lewat MethodChannel; status koneksi dikirim balik lewat
/// EventChannel.
class BlePeripheral {
  BlePeripheral._();

  static final BlePeripheral instance = BlePeripheral._();

  // Harus sama dengan nama channel di MainActivity.kt.
  static const _method = MethodChannel('heart_rate/ble');
  static const _statusChannel = EventChannel('heart_rate/ble/status');
  static const _ackChannel = EventChannel('heart_rate/ble/ack');

  // Aliran ACK dari ponsel, berisi JSON {batch_id, expected, stored, status}.
  // ACK yang tidak bisa di-parse jadi map kosong agar tidak pernah cocok
  // dengan batch mana pun.
  Stream<Map<String, dynamic>>? _ackStream;
  Stream<Map<String, dynamic>> get _acks =>
      _ackStream ??= _ackChannel.receiveBroadcastStream().map((event) {
        try {
          final decoded = jsonDecode(event as String);
          if (decoded is Map) return decoded.cast<String, dynamic>();
        } catch (_) {
          // Ditangani sama seperti ACK yang bentuknya tak dikenal.
        }
        debugPrint('[HR-BLE] ACK tidak dikenali: $event');
        return <String, dynamic>{};
      }).asBroadcastStream();

  // Di-seed dari epoch detik agar tetap menaik walau aplikasi dimulai ulang,
  // sehingga ACK sesi sebelumnya tidak pernah cocok. Dibatasi 32 bit karena
  // frame START membawanya sebagai uint32.
  int _nextBatchId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  int _takeBatchId() {
    final id = _nextBatchId & 0xFFFFFFFF;
    _nextBatchId = id + 1;
    return id;
  }

  /// Status koneksi terkini, dipakai UI untuk menampilkan indikator.
  final ValueNotifier<BleStatus> status = ValueNotifier(BleStatus.idle);

  /// Pesan tambahan (mis. alamat perangkat yang terhubung atau pesan error).
  final ValueNotifier<String?> message = ValueNotifier(null);

  StreamSubscription<dynamic>? _statusSub;

  void _ensureListening() {
    _statusSub ??= _statusChannel.receiveBroadcastStream().listen(
      (event) {
        final data = (event as Map).cast<String, dynamic>();
        final state = data['state'] as String?;
        message.value = data['message'] as String?;
        status.value = switch (state) {
          'advertising' => BleStatus.advertising,
          'connected' => BleStatus.connected,
          'error' => BleStatus.error,
          _ => BleStatus.idle,
        };
        debugPrint('[HR-BLE] state=$state message=${message.value}');
      },
      onError: (Object err) {
        status.value = BleStatus.error;
        message.value = err is PlatformException ? err.message : err.toString();
      },
    );
  }

  /// Mulai mengiklankan Heart Rate Service agar smartphone bisa menemukan dan
  /// terhubung ke watch.
  Future<void> start() async {
    _ensureListening();
    try {
      await _method.invokeMethod('startAdvertising');
    } on PlatformException catch (e) {
      status.value = BleStatus.error;
      message.value = e.message;
    }
  }

  /// Tulis [bytes] ke folder Downloads publik lewat MediaStore (tanpa izin
  /// khusus, Android 10+). Mengembalikan nama file bila sukses, atau null.
  Future<String?> saveToDownloads(
    String name,
    String mime,
    Uint8List bytes,
  ) async {
    try {
      return await _method.invokeMethod<String>('saveToDownloads', {
        'name': name,
        'mime': mime,
        'bytes': bytes,
      });
    } on PlatformException catch (e) {
      debugPrint('[HR-BLE] saveToDownloads gagal: ${e.message}');
      return null;
    }
  }

  /// Mulai foreground service agar pemantauan tetap berjalan saat app di
  /// background / layar mati. Aman dipanggil berulang.
  Future<void> startService() async {
    try {
      await _method.invokeMethod('startService');
    } on PlatformException catch (e) {
      debugPrint('[HR-BLE] startService gagal: ${e.message}');
    }
  }

  /// Hentikan foreground service.
  Future<void> stopService() async {
    try {
      await _method.invokeMethod('stopService');
    } on PlatformException catch (_) {
      // Menghentikan service yang sudah berhenti tidak masalah.
    }
  }

  /// Hentikan advertising dan tutup GATT server.
  Future<void> stop() async {
    try {
      await _method.invokeMethod('stopAdvertising');
    } on PlatformException catch (_) {
      // Abaikan; menghentikan sesuatu yang sudah berhenti tidak apa-apa.
    }
    status.value = BleStatus.idle;
    message.value = null;
  }

  /// Kirim satu **batch** record ke smartphone yang sedang subscribe.
  ///
  /// Dikirim sebagai JSON array `[{bpm, accuracy, time}, ...]` agar phone bisa
  /// membangun ulang database SQLite yang isinya identik dengan watch. Native
  /// memecah payload menjadi beberapa notifikasi (chunk) dengan flow-control,
  /// lalu phone merangkainya kembali.
  ///
  /// Mengembalikan `true` jika native menerima permintaan kirim (ada perangkat
  /// terhubung dan tidak ada batch lain yang sedang dikirim).
  ///
  /// [batchId] dibawa frame START dan dikembalikan ponsel di dalam ACK.
  Future<bool> sendBatch(
    List<HeartRateReading> readings, {
    required int batchId,
  }) async {
    if (readings.isEmpty) return false;
    final json = jsonEncode([
      for (final r in readings)
        {
          'bpm': r.bpm,
          'accuracy': r.accuracy,
          // epoch milliseconds, sama seperti penyimpanan di SQLite.
          'time': r.time.millisecondsSinceEpoch,
        }
    ]);
    try {
      final ok = await _method.invokeMethod<bool>('sendBatch', {
        'json': json,
        // Jumlah record dikirim agar native bisa mencatat metrik per batch.
        'count': readings.length,
        'batchId': batchId,
      });
      return ok ?? false;
    } on PlatformException catch (_) {
      // Jika belum ada yang terhubung, native akan mengabaikan dengan aman.
      return false;
    }
  }

  /// Kirim batch lalu **tunggu ACK yang cocok** dari ponsel.
  ///
  /// Batch diberi `batch_id` unik yang dibawa frame START; ACK hanya diterima
  /// bila membawa `batch_id` yang sama **dan** `status == "ok"`.
  ///
  /// Hasilnya `ok == false` bila konfirmasi tidak datang dalam [timeout], agar
  /// pemanggil membiarkan record belum terkirim untuk dikirim ulang nanti.
  Future<BatchAckResult> sendBatchAndAwaitAck(
    List<HeartRateReading> readings, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final batchId = _takeBatchId();
    final expected = readings.length;
    if (readings.isEmpty) {
      return BatchAckResult(
        batchId: batchId,
        expected: 0,
        status: 'not_sent',
      );
    }

    final completer = Completer<BatchAckResult>();
    final elapsed = Stopwatch()..start();

    void finish(BatchAckResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    // Berlangganan ACK sebelum mengirim agar tidak ada yang terlewat.
    final sub = _acks.listen((ack) {
      final id = (ack['batch_id'] as num?)?.toInt();
      if (id != batchId) {
        // ACK basi: milik batch lain, mis. yang sudah kedaluwarsa.
        debugPrint('[HR-BLE] ACK diabaikan (batch $id ≠ $batchId)');
        return;
      }
      final status = (ack['status'] as String?) ?? 'ok';
      finish(BatchAckResult(
        batchId: batchId,
        expected: expected,
        ok: status == 'ok',
        stored: (ack['stored'] as num?)?.toInt() ?? 0,
        status: status,
        ackLatency: elapsed.elapsed,
      ));
    });
    final timer = Timer(timeout, () {
      finish(BatchAckResult(
        batchId: batchId,
        expected: expected,
        status: 'timeout',
      ));
    });

    final sent = await sendBatch(readings, batchId: batchId);
    if (!sent) {
      finish(BatchAckResult(
        batchId: batchId,
        expected: expected,
        status: 'not_sent',
      ));
    }

    final result = await completer.future;
    await sub.cancel();
    timer.cancel();
    elapsed.stop();

    // Metrik per batch untuk evaluasi (lihat docs/EXPERIMENT.md §4).
    // Kolom: event,batch_id,expected,stored,duplicates,status,ack_latency_ms
    debugPrint(
      'HR-METRIC,tx_ack,$batchId,$expected,${result.stored},'
      '${result.duplicates},${result.status},'
      '${result.ackLatency?.inMilliseconds ?? ''}',
    );
    return result;
  }
}
