import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Satu hasil pembacaan detak jantung beserta waktunya.
/// [id] berisi rowid dari SQLite (null sebelum disimpan).
class HeartRateReading {
  const HeartRateReading({
    this.id,
    required this.bpm,
    required this.accuracy,
    required this.time,
  });

  final int? id;
  final double bpm;
  final int accuracy;
  final DateTime time;

  /// Ubah ke map untuk disimpan ke tabel SQLite.
  Map<String, Object?> toMap() {
    return {
      'bpm': bpm,
      'accuracy': accuracy,
      // Disimpan sebagai epoch milliseconds agar mudah diurutkan.
      'time': time.millisecondsSinceEpoch,
    };
  }

  /// Buat objek dari satu baris hasil query SQLite.
  factory HeartRateReading.fromMap(Map<String, Object?> map) {
    return HeartRateReading(
      id: map['id'] as int?,
      bpm: (map['bpm'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toInt(),
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
    );
  }
}

/// Helper akses database SQLite untuk menyimpan riwayat detak jantung.
///
/// Memakai satu instance (singleton) agar koneksi database dipakai ulang
/// sepanjang umur aplikasi.
class HeartRateDatabase {
  HeartRateDatabase._();

  static final HeartRateDatabase instance = HeartRateDatabase._();

  static const _dbName = 'heart_rate.db';
  static const _table = 'readings';

  Database? _db;

  /// Buka (atau buat) database. Dipanggil otomatis oleh operasi lain.
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bpm REAL NOT NULL,
            accuracy INTEGER NOT NULL,
            time INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// Simpan satu pembacaan dan kembalikan objek dengan [id] terisi.
  Future<HeartRateReading> insertReading(HeartRateReading reading) async {
    final db = await database;
    final id = await db.insert(_table, reading.toMap());
    return HeartRateReading(
      id: id,
      bpm: reading.bpm,
      accuracy: reading.accuracy,
      time: reading.time,
    );
  }

  /// Simpan banyak pembacaan sekaligus (satu batch dari watch) dalam satu
  /// transaksi agar cepat. Mengembalikan jumlah baris yang tersimpan.
  Future<int> insertReadings(List<HeartRateReading> readings) async {
    if (readings.isEmpty) return 0;
    final db = await database;
    final batch = db.batch();
    for (final r in readings) {
      batch.insert(_table, r.toMap());
    }
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  /// Ambil seluruh riwayat, terbaru lebih dulu.
  Future<List<HeartRateReading>> getReadings() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'time DESC');
    return rows.map(HeartRateReading.fromMap).toList();
  }

  /// Hapus seluruh riwayat.
  Future<void> clearReadings() async {
    final db = await database;
    await db.delete(_table);
  }
}
