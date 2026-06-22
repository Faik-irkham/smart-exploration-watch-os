import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ble_receiver.dart';
import '../heart_rate_database.dart';
import '../models/heart_rate_reading.dart';
import 'receiver_state.dart';

/// Mengelola layar penerima: menjembatani [BleReceiver] (sumber data BLE) dan
/// [HeartRateDatabase] ke [ReceiverState] yang ditampilkan UI.
class ReceiverCubit extends Cubit<ReceiverState> {
  ReceiverCubit() : super(const ReceiverState.initial()) {
    _ble.status.addListener(_onStatus);
    _ble.message.addListener(_onStatus);
    _readingsSub = _ble.onReadings.listen(_onReadings);
    _loadHistory();
  }

  final _ble = BleReceiver.instance;
  final _db = HeartRateDatabase.instance;

  StreamSubscription<List<HeartRateReading>>? _readingsSub;

  void _onStatus() {
    emit(state.copyWith(status: _ble.status.value, message: _ble.message.value));
  }

  /// Satu batch baru dari watch (urut terlama→terbaru): taruh di paling atas
  /// daftar (terbaru lebih dulu) dalam satu kali update.
  void _onReadings(List<HeartRateReading> readings) {
    emit(state.copyWith(
      history: [...readings.reversed, ...state.history],
    ));
  }

  /// Muat record yang sudah pernah diterima & disimpan sebelumnya.
  Future<void> _loadHistory() async {
    final readings = await _db.getReadings();
    if (isClosed) return;
    emit(state.copyWith(history: readings));
  }

  /// Mulai mencari & menerima dari watch.
  Future<void> start() => _ble.start();

  /// Putuskan koneksi dan hentikan penerimaan.
  Future<void> stop() => _ble.stop();

  /// Hapus seluruh riwayat tersimpan.
  Future<void> clearHistory() async {
    await _db.clearReadings();
    if (isClosed) return;
    emit(state.copyWith(history: const []));
  }

  /// Ekspor seluruh riwayat sebagai CSV ke folder Downloads. Mengembalikan nama
  /// file bila sukses.
  Future<String?> exportCsv() async {
    final csv = await _db.toCsv();
    final name = 'phone_hr_${_timestamp()}.csv';
    return _ble.saveToDownloads(
      name,
      'text/csv',
      Uint8List.fromList(utf8.encode(csv)),
    );
  }

  /// Ekspor salinan file database (.db) ke folder Downloads.
  Future<String?> exportDb() async {
    final bytes = await _db.fileBytes();
    final name = 'phone_hr_${_timestamp()}.db';
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
    _ble.status.removeListener(_onStatus);
    _ble.message.removeListener(_onStatus);
    _readingsSub?.cancel();
    _ble.stop();
    return super.close();
  }
}
