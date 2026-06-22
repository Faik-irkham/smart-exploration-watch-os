import '../ble_peripheral.dart';
import '../models/heart_rate_reading.dart';

/// State imutable untuk layar pemantauan detak jantung (watch).
///
/// Semua data yang dibutuhkan UI ada di sini, dihasilkan oleh [MonitoringCubit].
class MonitoringState {
  const MonitoringState({
    required this.running,
    required this.flushing,
    required this.intervalMinutes,
    required this.permanentlyDenied,
    required this.denied,
    required this.lastStatusName,
    required this.error,
    required this.untilSync,
    required this.latestBpm,
    required this.latestAccuracy,
    required this.unsentCount,
    required this.history,
    required this.bleStatus,
    required this.bleMessage,
  });

  /// State awal sebelum pemantauan dimulai (interval default 5 menit).
  const MonitoringState.initial()
      : running = false,
        flushing = false,
        intervalMinutes = 5,
        permanentlyDenied = false,
        denied = false,
        lastStatusName = null,
        error = null,
        untilSync = Duration.zero,
        latestBpm = 0,
        latestAccuracy = 0,
        unsentCount = 0,
        history = const [],
        bleStatus = BleStatus.idle,
        bleMessage = null;

  final bool running; // mode pemantauan aktif
  final bool flushing; // sedang mengirim batch ke phone
  final int intervalMinutes; // interval pengiriman batch (menit)
  final bool permanentlyDenied; // izin diblokir permanen
  final bool denied; // izin ditolak (belum permanen)
  final String? lastStatusName; // nama status izin terakhir (diagnostik)
  final String? error; // error sensor (bukan soal izin)
  final Duration untilSync; // sisa waktu ke pengiriman berikutnya
  final double latestBpm; // nilai sensor terbaru
  final int latestAccuracy;
  final int unsentCount; // jumlah record belum terkirim
  final List<HeartRateReading> history;
  final BleStatus bleStatus; // status koneksi BLE ke ponsel
  final String? bleMessage; // pesan tambahan BLE (alamat / error)

  bool get hasReading => latestBpm > 0;

  static const Object _keep = Object();

  MonitoringState copyWith({
    bool? running,
    bool? flushing,
    int? intervalMinutes,
    bool? permanentlyDenied,
    bool? denied,
    Object? lastStatusName = _keep,
    Object? error = _keep,
    Duration? untilSync,
    double? latestBpm,
    int? latestAccuracy,
    int? unsentCount,
    List<HeartRateReading>? history,
    BleStatus? bleStatus,
    Object? bleMessage = _keep,
  }) {
    return MonitoringState(
      running: running ?? this.running,
      flushing: flushing ?? this.flushing,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
      denied: denied ?? this.denied,
      lastStatusName:
          lastStatusName == _keep ? this.lastStatusName : lastStatusName as String?,
      error: error == _keep ? this.error : error as String?,
      untilSync: untilSync ?? this.untilSync,
      latestBpm: latestBpm ?? this.latestBpm,
      latestAccuracy: latestAccuracy ?? this.latestAccuracy,
      unsentCount: unsentCount ?? this.unsentCount,
      history: history ?? this.history,
      bleStatus: bleStatus ?? this.bleStatus,
      bleMessage: bleMessage == _keep ? this.bleMessage : bleMessage as String?,
    );
  }
}
