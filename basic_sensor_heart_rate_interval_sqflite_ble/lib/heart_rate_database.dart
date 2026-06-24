import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/heart_rate_reading.dart';

/// Helper akses database SQLite untuk menyimpan riwayat detak jantung.
///
/// Memakai satu instance (singleton) agar koneksi database dipakai ulang
/// sepanjang umur aplikasi. Mendukung pola *store-and-forward*: tiap record
/// ditandai [synced]=0 saat disimpan, lalu di-set 1 setelah berhasil dikirim
/// ke smartphone (sehingga data yang belum terkirim tidak hilang walau phone
/// sempat terputus).
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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bpm REAL NOT NULL,
            accuracy INTEGER NOT NULL,
            time INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: tambahkan kolom synced untuk store-and-forward.
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
    return _db!;
  }

  /// Simpan satu pembacaan (default belum terkirim) dan kembalikan objek dengan
  /// [id] terisi.
  Future<HeartRateReading> insertReading(HeartRateReading reading) async {
    final db = await database;
    final id = await db.insert(_table, reading.toMap());
    return HeartRateReading(
      id: id,
      bpm: reading.bpm,
      accuracy: reading.accuracy,
      time: reading.time,
      synced: reading.synced,
    );
  }

  /// Ambil seluruh riwayat, terbaru lebih dulu.
  Future<List<HeartRateReading>> getReadings() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'time DESC');
    return rows.map(HeartRateReading.fromMap).toList();
  }

  /// Ambil record yang belum terkirim ke smartphone, urut terlama dulu.
  Future<List<HeartRateReading>> getUnsynced() async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'synced = 0',
      orderBy: 'time ASC',
    );
    return rows.map(HeartRateReading.fromMap).toList();
  }

  /// Jumlah record yang belum terkirim (untuk indikator UI).
  Future<int> countUnsynced() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE synced = 0',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Tandai sekumpulan record sebagai sudah terkirim.
  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $_table SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  /// Hapus seluruh riwayat.
  Future<void> clearReadings() async {
    final db = await database;
    await db.delete(_table);
  }

  /// Seluruh isi tabel sebagai CSV (urut terlama→terbaru), siap diekspor.
  Future<String> toCsv() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'time ASC');
    final buffer = StringBuffer('id,bpm,accuracy,time_ms,time_iso,synced\n');
    for (final r in rows) {
      final reading = HeartRateReading.fromMap(r);
      buffer.writeln(
        '${reading.id},${reading.bpm},${reading.accuracy},'
        '${reading.time.millisecondsSinceEpoch},'
        '${reading.time.toIso8601String()},${reading.synced ? 1 : 0}',
      );
    }
    return buffer.toString();
  }

  /// Salinan byte file database (WAL di-checkpoint dulu agar konsisten).
  Future<Uint8List> fileBytes() async {
    final db = await database;
    // Checkpoint WAL agar file .db konsisten. Pakai rawQuery (PRAGMA ini
    // mengembalikan baris); dibungkus try-catch karena bersifat opsional.
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    final dir = await getDatabasesPath();
    return File(p.join(dir, _dbName)).readAsBytes();
  }
}
