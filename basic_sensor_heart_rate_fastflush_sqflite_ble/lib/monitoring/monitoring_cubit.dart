import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble_peripheral.dart';
import '../heart_rate_database.dart';
import '../models/heart_rate_reading.dart';
import 'monitoring_state.dart';

/// Mengelola seluruh logika pemantauan detak jantung (watch): izin, pembacaan
/// sensor, penyimpanan SQLite, hitung mundur, dan pengiriman batch BLE.
///
/// Widget hanya menampilkan [MonitoringState] dan memanggil method di sini —
/// tidak ada logika bisnis di layer UI.
class MonitoringCubit extends Cubit<MonitoringState> {
  MonitoringCubit() : super(const MonitoringState.initial()) {
    _ble.status.addListener(_onBleChanged);
    _ble.message.addListener(_onBleChanged);
    _loadHistory();
  }

  // Harus sama dengan nama channel di MainActivity.kt.
  static const _channel = EventChannel('heart_rate/stream');

  final _db = HeartRateDatabase.instance;
  final _ble = BlePeripheral.instance;

  StreamSubscription<dynamic>? _sensorSub;
  Timer? _logTimer; // menyimpan 1 pembacaan tiap detik
  Timer? _intervalTimer; // mengirim batch tiap N detik

  // Akumulator sampel accelerometer selama jendela satu detik. Yang disimpan
  // hanya statistik magnitude agar database/payload tetap ringkas.
  double _accelMagnitudeSum = 0;
  double _accelMagnitudeSquaredSum = 0;
  int _accelSampleCount = 0;

  /// Irama pengiriman yang tersedia (detik).
  static const intervals = <int>[15, 30];

  void _onBleChanged() {
    emit(
      state.copyWith(
        bleStatus: _ble.status.value,
        bleMessage: _ble.message.value,
      ),
    );
  }

  /// Ambil riwayat + jumlah belum terkirim dari SQLite saat aplikasi dibuka.
  Future<void> _loadHistory() async {
    final readings = await _db.getReadings();
    final unsent = await _db.countUnsynced();
    if (isClosed) return;
    emit(state.copyWith(history: readings, unsentCount: unsent));
  }

  /// Ubah irama pengiriman (hanya relevan sebelum mulai).
  void changeInterval(int seconds) {
    emit(state.copyWith(flushSeconds: seconds));
  }

  /// Minta izin BODY_SENSORS (+ Bluetooth & notifikasi) lalu mulai pemantauan.
  Future<void> requestAndStart() async {
    final status = await Permission.sensors.request();
    debugPrint('[HR] Status izin sensor: $status');
    if (isClosed) return;
    emit(state.copyWith(lastStatusName: status.name));

    if (status.isGranted || status.isLimited) {
      emit(state.copyWith(permanentlyDenied: false, denied: false));
      // Izin Bluetooth (Android 12+) untuk advertising & melayani GATT, serta
      // izin notifikasi (Android 13+) untuk notifikasi foreground service.
      await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.notification,
      ].request();
      _start();
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      emit(state.copyWith(permanentlyDenied: true, denied: false));
    } else {
      emit(state.copyWith(permanentlyDenied: false, denied: true));
    }
  }

  /// Mulai mode pemantauan: sensor menyala terus, tiap detik satu pembacaan
  /// valid disimpan ke SQLite, dan tiap interval seluruh data yang belum
  /// terkirim dikirim ke smartphone sebagai satu batch.
  void _start() {
    emit(
      state.copyWith(
        running: true,
        error: null,
        latestBpm: 0,
        latestAccuracy: 0,
        untilSync: Duration(seconds: state.flushSeconds),
      ),
    );

    // Jaga proses tetap hidup di background / layar mati.
    _ble.startService();
    // Mulai mengiklankan agar smartphone bisa terhubung.
    _ble.start();

    // Sensor dibaca terus-menerus selama sesi (tidak dilepas tiap siklus).
    _sensorSub = _channel.receiveBroadcastStream().listen(
      (event) {
        final data = (event as Map).cast<String, dynamic>();
        if (data['type'] == 'accelerometer') {
          final x = (data['x'] as num?)?.toDouble();
          final y = (data['y'] as num?)?.toDouble();
          final z = (data['z'] as num?)?.toDouble();
          if (x == null || y == null || z == null) return;
          final magnitude = math.sqrt(x * x + y * y + z * z);
          _accelMagnitudeSum += magnitude;
          _accelMagnitudeSquaredSum += magnitude * magnitude;
          _accelSampleCount++;
          return;
        }
        final bpm = (data['bpm'] as num?)?.toDouble() ?? 0;
        final accuracy = (data['accuracy'] as num?)?.toInt() ?? 0;
        if (isClosed) return;
        emit(
          state.copyWith(
            latestBpm: bpm > 0 ? bpm : state.latestBpm,
            latestAccuracy: accuracy,
            error: null,
          ),
        );
      },
      onError: (Object err) {
        final message = err is PlatformException
            ? (err.message ?? 'Gagal membaca sensor')
            : err.toString();
        if (isClosed) return;
        emit(state.copyWith(error: message));
      },
    );

    // Tiap detik: simpan pembacaan valid + perbarui hitung mundur.
    _logTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    // Tiap irama flush: kirim batch ke phone.
    _intervalTimer = Timer.periodic(
      Duration(seconds: state.flushSeconds),
      (_) => _flush(),
    );
  }

  /// Hentikan pemantauan.
  void stop() {
    _cancelTimersAndStream();
    _ble.stop();
    _ble.stopService();
    emit(state.copyWith(running: false, untilSync: Duration.zero));
  }

  /// Lepas semua timer dan subscription sensor.
  void _cancelTimersAndStream() {
    _logTimer?.cancel();
    _logTimer = null;
    _intervalTimer?.cancel();
    _intervalTimer = null;
    _sensorSub?.cancel();
    _sensorSub = null;
    _resetAccelerometerWindow();
  }

  void _resetAccelerometerWindow() {
    _accelMagnitudeSum = 0;
    _accelMagnitudeSquaredSum = 0;
    _accelSampleCount = 0;
  }

  /// Dijalankan tiap detik saat mode aktif.
  Future<void> _onTick() async {
    if (!state.running) return;

    // Ambil snapshot statistik lalu langsung reset jendela agar sampel yang
    // masuk saat operasi SQLite berlangsung menjadi bagian detik berikutnya.
    final accelCount = _accelSampleCount;
    final accelSum = _accelMagnitudeSum;
    final accelSquaredSum = _accelMagnitudeSquaredSum;
    _resetAccelerometerWindow();
    final accelMean = accelCount > 0 ? accelSum / accelCount : null;
    final accelVariance = accelCount > 0
        ? math.max(0.0, accelSquaredSum / accelCount - accelMean! * accelMean)
        : null;
    final accelStd = accelVariance == null ? null : math.sqrt(accelVariance);

    // Perbarui hitung mundur ke pengiriman berikutnya.
    final next = state.untilSync - const Duration(seconds: 1);
    emit(state.copyWith(untilSync: next.isNegative ? Duration.zero : next));

    // Simpan satu pembacaan valid per detik.
    if (state.latestBpm > 0) {
      final saved = await _db.insertReading(
        HeartRateReading(
          bpm: state.latestBpm,
          accuracy: state.latestAccuracy,
          time: DateTime.now(),
          accelMagnitudeMean: accelMean,
          accelMagnitudeStd: accelStd,
          accelSampleCount: accelCount,
        ),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          history: [saved, ...state.history],
          unsentCount: state.unsentCount + 1,
        ),
      );
    }
  }

  /// Kirim seluruh record yang belum terkirim sebagai satu batch. Hanya record
  /// yang berhasil diterima native (ada phone terhubung) yang ditandai terkirim
  /// — sisanya menunggu interval berikutnya (store-and-forward).
  Future<void> _flush() async {
    if (state.flushing) return;
    final pending = await _db.getUnsynced();
    if (isClosed) return;
    // Selalu reset hitung mundur, ada data atau tidak.
    emit(state.copyWith(untilSync: Duration(seconds: state.flushSeconds)));
    if (pending.isEmpty) return;

    emit(state.copyWith(flushing: true));
    // Tandai terkirim hanya setelah ponsel mengonfirmasi (ACK). Jika tidak ada
    // ACK, record dibiarkan belum terkirim untuk dikirim ulang nanti.
    final ok = await _ble.sendBatchAndAwaitAck(pending);
    if (ok) {
      final ids = [
        for (final r in pending)
          if (r.id != null) r.id!,
      ];
      await _db.markSynced(ids);
    }
    final unsent = await _db.countUnsynced();
    if (isClosed) return;
    emit(state.copyWith(flushing: false, unsentCount: unsent));
  }

  /// Hapus seluruh riwayat dari database dan dari UI.
  Future<void> clearHistory() async {
    await _db.clearReadings();
    if (isClosed) return;
    emit(state.copyWith(history: const [], unsentCount: 0));
  }

  /// Ekspor seluruh riwayat sebagai CSV ke folder Downloads. Mengembalikan nama
  /// file bila sukses.
  Future<String?> exportCsv() async {
    final csv = await _db.toCsv();
    final name = 'watch_hr_${_timestamp()}.csv';
    return _ble.saveToDownloads(
      name,
      'text/csv',
      Uint8List.fromList(utf8.encode(csv)),
    );
  }

  /// Ekspor salinan file database (.db) ke folder Downloads.
  Future<String?> exportDb() async {
    final bytes = await _db.fileBytes();
    final name = 'watch_hr_${_timestamp()}.db';
    return _ble.saveToDownloads(name, 'application/octet-stream', bytes);
  }

  static String _timestamp() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  @override
  Future<void> close() {
    _cancelTimersAndStream();
    _ble.status.removeListener(_onBleChanged);
    _ble.message.removeListener(_onBleChanged);
    _ble.stop();
    _ble.stopService();
    return super.close();
  }
}
