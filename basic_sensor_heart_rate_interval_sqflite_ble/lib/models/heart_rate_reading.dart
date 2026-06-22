/// Satu hasil pembacaan detak jantung beserta waktunya.
/// [id] berisi rowid dari SQLite (null sebelum disimpan).
/// [synced] menandai apakah record ini sudah dikirim ke smartphone lewat BLE.
class HeartRateReading {
  const HeartRateReading({
    this.id,
    required this.bpm,
    required this.accuracy,
    required this.time,
    this.synced = false,
  });

  final int? id;
  final double bpm;
  final int accuracy;
  final DateTime time;
  final bool synced;

  /// Ubah ke map untuk disimpan ke tabel SQLite.
  Map<String, Object?> toMap() {
    return {
      'bpm': bpm,
      'accuracy': accuracy,
      // Disimpan sebagai epoch milliseconds agar mudah diurutkan.
      'time': time.millisecondsSinceEpoch,
      'synced': synced ? 1 : 0,
    };
  }

  /// Buat objek dari satu baris hasil query SQLite.
  factory HeartRateReading.fromMap(Map<String, Object?> map) {
    return HeartRateReading(
      id: map['id'] as int?,
      bpm: (map['bpm'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toInt(),
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      synced: ((map['synced'] as int?) ?? 0) == 1,
    );
  }
}
