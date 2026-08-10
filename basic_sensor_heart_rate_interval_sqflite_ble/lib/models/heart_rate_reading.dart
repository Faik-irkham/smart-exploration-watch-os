/// Satu hasil pembacaan detak jantung beserta waktunya.
/// [id] berisi rowid dari SQLite (null sebelum disimpan).
/// [synced] menandai apakah record ini sudah dikirim ke smartphone lewat BLE.
///
/// [fresh] menandai apakah nilainya berasal dari pembacaan sensor **baru**
/// sejak record sebelumnya ditulis. Perekaman berjalan satu baris per detik
/// terlepas dari laju sensor, jadi saat jam dilepas nilai terakhir akan terus
/// ditulis ulang dan terlihat seperti data sah. Penanda ini membuat baris
/// semacam itu bisa dikenali secara pasti, bukan ditebak belakangan lewat
/// heuristik. Bernilai null untuk record dari versi sebelum penanda ini ada.
class HeartRateReading {
  const HeartRateReading({
    this.id,
    required this.bpm,
    required this.accuracy,
    required this.time,
    this.synced = false,
    this.fresh,
  });

  final int? id;
  final double bpm;
  final int accuracy;
  final DateTime time;
  final bool synced;
  final bool? fresh;

  /// Ubah ke map untuk disimpan ke tabel SQLite.
  Map<String, Object?> toMap() {
    return {
      'bpm': bpm,
      'accuracy': accuracy,
      // Disimpan sebagai epoch milliseconds agar mudah diurutkan.
      'time': time.millisecondsSinceEpoch,
      'synced': synced ? 1 : 0,
      'fresh': fresh == null ? null : (fresh! ? 1 : 0),
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
      fresh: map['fresh'] == null ? null : (map['fresh'] as int) == 1,
    );
  }
}
