import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/heart_rate_reading.dart';

/// Status BLE dari sisi native (watch berperan sebagai peripheral).
enum BleStatus { idle, advertising, connected, error }

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
  /// terhubung), sehingga pemanggil bisa menandai record sebagai terkirim.
  Future<bool> sendBatch(List<HeartRateReading> readings) async {
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
      });
      return ok ?? false;
    } on PlatformException catch (_) {
      // Jika belum ada yang terhubung, native akan mengabaikan dengan aman.
      return false;
    }
  }
}
