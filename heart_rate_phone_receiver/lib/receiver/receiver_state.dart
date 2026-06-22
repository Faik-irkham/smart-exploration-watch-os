import '../ble_receiver.dart';
import '../models/heart_rate_reading.dart';

/// State imutable untuk layar penerima (phone), dihasilkan oleh [ReceiverCubit].
class ReceiverState {
  const ReceiverState({
    required this.status,
    required this.message,
    required this.history,
  });

  const ReceiverState.initial()
      : status = ReceiverStatus.idle,
        message = null,
        history = const [];

  final ReceiverStatus status;
  final String? message;
  final List<HeartRateReading> history;

  /// Apakah sedang aktif (scan/connect/terhubung) sehingga tombol jadi "Putuskan".
  bool get isActive =>
      status == ReceiverStatus.scanning ||
      status == ReceiverStatus.connecting ||
      status == ReceiverStatus.connected;

  /// Pembacaan terbaru (paling atas), null bila riwayat kosong.
  HeartRateReading? get latest => history.isNotEmpty ? history.first : null;

  static const Object _keep = Object();

  ReceiverState copyWith({
    ReceiverStatus? status,
    Object? message = _keep,
    List<HeartRateReading>? history,
  }) {
    return ReceiverState(
      status: status ?? this.status,
      message: message == _keep ? this.message : message as String?,
      history: history ?? this.history,
    );
  }
}
