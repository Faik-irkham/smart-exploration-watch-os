/// Satu hasil pembacaan detak jantung beserta waktunya.
/// [id] berisi rowid dari SQLite (null sebelum disimpan).
class HeartRateReading {
  const HeartRateReading({
    this.id,
    required this.bpm,
    required this.accuracy,
    required this.time,
    this.accelMagnitudeMean,
    this.accelMagnitudeStd,
    this.accelSampleCount = 0,
  });

  final int? id;
  final double bpm;
  final int accuracy;
  final DateTime time;
  final double? accelMagnitudeMean;
  final double? accelMagnitudeStd;
  final int accelSampleCount;

  /// Ubah ke map untuk disimpan ke tabel SQLite.
  Map<String, Object?> toMap() {
    return {
      'bpm': bpm,
      'accuracy': accuracy,
      // Disimpan sebagai epoch milliseconds agar mudah diurutkan.
      'time': time.millisecondsSinceEpoch,
      'accel_magnitude_mean': accelMagnitudeMean,
      'accel_magnitude_std': accelMagnitudeStd,
      'accel_sample_count': accelSampleCount,
    };
  }

  /// Buat objek dari satu baris hasil query SQLite.
  factory HeartRateReading.fromMap(Map<String, Object?> map) {
    return HeartRateReading(
      id: map['id'] as int?,
      bpm: (map['bpm'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toInt(),
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      accelMagnitudeMean: (map['accel_magnitude_mean'] as num?)?.toDouble(),
      accelMagnitudeStd: (map['accel_magnitude_std'] as num?)?.toDouble(),
      accelSampleCount: (map['accel_sample_count'] as num?)?.toInt() ?? 0,
    );
  }
}
