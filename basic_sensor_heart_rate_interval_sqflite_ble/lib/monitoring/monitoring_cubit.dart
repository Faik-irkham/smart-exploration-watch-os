import 'dart:async';
import 'dart:convert';

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
  Timer? _intervalTimer; // mengirim batch tiap N menit

  // Status BLE sebelumnya, untuk mendeteksi transisi ke `connected`.
  BleStatus _lastBleStatus = BleStatus.idle;

  // Berapa kali backlog yang sama sudah dicoba dikirim tanpa dikonfirmasi.
  // Direset setiap kali satu batch berhasil di-ACK.
  int _flushAttempt = 0;

  // Saat tautan pulih; dipakai mengukur berapa lama backlog butuh waktu
  // sampai benar-benar tersimpan di ponsel.
  DateTime? _reconnectedAt;

  // Apakah sensor mengirim nilai baru sejak record terakhir ditulis.
  bool _sensorUpdated = false;

  /// Interval pengiriman yang tersedia (menit).
  static const intervals = <int>[3, 5];

  void _onBleChanged() {
    final status = _ble.status.value;
    emit(state.copyWith(
      bleStatus: status,
      bleMessage: _ble.message.value,
    ));

    // Begitu ponsel tersambung kembali, kirim backlog tanpa menunggu interval
    // berikutnya — kalau tidak, pemulihan selalu selebar interval (3–5 menit).
    final reconnected =
        status == BleStatus.connected && _lastBleStatus != BleStatus.connected;
    _lastBleStatus = status;
    if (reconnected && state.running) {
      debugPrint('[HR] tersambung kembali — mengirim backlog');
      _reconnectedAt = DateTime.now();
      unawaited(_flush());
    }
  }

  /// Ambil riwayat + jumlah belum terkirim dari SQLite saat aplikasi dibuka.
  Future<void> _loadHistory() async {
    final readings = await _db.getReadings();
    final unsent = await _db.countUnsynced();
    if (isClosed) return;
    emit(state.copyWith(history: readings, unsentCount: unsent));
  }

  /// Ubah interval pengiriman (hanya relevan sebelum mulai).
  void changeInterval(int minutes) {
    emit(state.copyWith(intervalMinutes: minutes));
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
    // Kedua build eksperimen tampak identik di layar. Penanda ini membuat versi
    // yang berjalan tercatat di log tiap sesi, sehingga tidak perlu mengandalkan
    // ingatan tentang APK mana yang terakhir dipasang.
    debugPrint(
      'HR-METRIC,session_start,ack_validation=${BlePeripheral.ackValidation},'
      'interval_min=${state.intervalMinutes}',
    );
    emit(state.copyWith(
      running: true,
      error: null,
      latestBpm: 0,
      latestAccuracy: 0,
      untilSync: Duration(minutes: state.intervalMinutes),
    ));

    // Jaga proses tetap hidup di background / layar mati.
    _ble.startService();
    // Mulai mengiklankan agar smartphone bisa terhubung.
    _ble.start();

    // Sensor dibaca terus-menerus selama sesi (tidak dilepas tiap siklus).
    _sensorSub = _channel.receiveBroadcastStream().listen(
      (event) {
        final data = (event as Map).cast<String, dynamic>();
        final bpm = (data['bpm'] as num?)?.toDouble() ?? 0;
        final accuracy = (data['accuracy'] as num?)?.toInt() ?? 0;
        // Hanya nilai BPM yang benar-benar baru dihitung sebagai pembacaan
        // segar; event yang cuma membawa perubahan akurasi tidak.
        if (bpm > 0) _sensorUpdated = true;
        if (isClosed) return;
        emit(state.copyWith(
          latestBpm: bpm > 0 ? bpm : state.latestBpm,
          latestAccuracy: accuracy,
          error: null,
        ));
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
    // Tiap interval: kirim batch ke phone.
    _intervalTimer = Timer.periodic(
      Duration(minutes: state.intervalMinutes),
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
  }

  /// Dijalankan tiap detik saat mode aktif.
  Future<void> _onTick() async {
    if (!state.running) return;

    // Perbarui hitung mundur ke pengiriman berikutnya.
    final next = state.untilSync - const Duration(seconds: 1);
    emit(state.copyWith(untilSync: next.isNegative ? Duration.zero : next));

    // Simpan satu pembacaan valid per detik.
    if (state.latestBpm > 0) {
      final fresh = _sensorUpdated;
      _sensorUpdated = false;
      final saved = await _db.insertReading(
        HeartRateReading(
          bpm: state.latestBpm,
          accuracy: state.latestAccuracy,
          time: DateTime.now(),
          fresh: fresh,
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(
        history: [saved, ...state.history],
        unsentCount: state.unsentCount + 1,
      ));
    }
  }

  /// Kirim seluruh record yang belum terkirim sebagai satu batch. Hanya record
  /// yang berhasil diterima native (ada phone terhubung) yang ditandai terkirim
  /// — sisanya menunggu interval berikutnya (store-and-forward).
  Future<void> _flush() async {
    if (state.flushing) return;
    // Tandai sibuk sebelum await pertama. Kalau tidak, flush dari timer dan
    // flush dari rekoneksi bisa sama-sama lolos penjaga di atas lalu berebut
    // mengirim batch yang sama.
    emit(state.copyWith(flushing: true));

    final pending = await _db.getUnsynced();
    if (isClosed) return;
    // Selalu reset hitung mundur, ada data atau tidak.
    emit(state.copyWith(untilSync: Duration(minutes: state.intervalMinutes)));
    if (pending.isEmpty) {
      emit(state.copyWith(flushing: false));
      return;
    }

    // Tandai terkirim hanya bila ponsel mengonfirmasi batch **ini**; selain itu
    // record dibiarkan belum terkirim untuk dikirim ulang nanti.
    final ack = await _ble.sendBatchAndAwaitAck(
      pending,
      deviceId: await _db.deviceId(),
    );
    _flushAttempt++;
    if (ack.ok) {
      final ids = [for (final r in pending) if (r.id != null) r.id!];
      await _db.markSynced(ids);
    } else {
      debugPrint(
        '[HR] batch ${ack.batchId} tidak dikonfirmasi (${ack.status}); '
        '${pending.length} record menunggu kiriman berikutnya',
      );
    }
    final unsent = await _db.countUnsynced();

    // Waktu pemulihan diukur sampai backlog yang tertahan berhasil
    // dikonfirmasi. Sengaja tidak menunggu `unsent == 0`: sensor terus menulis
    // satu record per detik, jadi selalu ada sisa baru yang lahir selama
    // transfer berlangsung dan syarat itu nyaris tidak pernah terpenuhi.
    int? recoveryMs;
    if (_reconnectedAt != null && ack.ok) {
      recoveryMs = DateTime.now().difference(_reconnectedAt!).inMilliseconds;
      _reconnectedAt = null;
    }

    // Kolom: event,batch_id,attempt,pending,stored,duplicates,status,
    //        ack_latency_ms,backlog_after,recovery_ms
    debugPrint(
      'HR-METRIC,flush,${ack.batchId},$_flushAttempt,${pending.length},'
      '${ack.stored},${ack.duplicates},${ack.status},'
      '${ack.ackLatency?.inMilliseconds ?? ''},$unsent,${recoveryMs ?? ''}',
    );
    if (ack.ok) _flushAttempt = 0;

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
