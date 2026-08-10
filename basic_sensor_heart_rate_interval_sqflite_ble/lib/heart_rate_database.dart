import 'dart:io';
import 'dart:math';
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
  static const _metaTable = 'meta';

  Database? _db;
  String? _deviceId;

  /// Buka (atau buat) database. Dipanggil otomatis oleh operasi lain.
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    _db = await openDatabase(
      path,
      version: 3,
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
        await db.execute(
          'CREATE TABLE $_metaTable (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: tambahkan kolom synced untuk store-and-forward.
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
          );
        }
        // v2 -> v3: tabel meta untuk menyimpan identitas perangkat.
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $_metaTable '
            '(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        }
      },
    );
    return _db!;
  }

  /// Identitas watch, dibuat sekali lalu disimpan permanen.
  ///
  /// Dikirim bersama tiap batch sehingga ponsel bisa memakai pasangan
  /// `(device_id, record_id)` sebagai identitas record — lebih kokoh daripada
  /// timestamp yang bisa bertabrakan atau berubah saat jam sistem disetel.
  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final db = await database;
    final rows = await db.query(
      _metaTable,
      where: 'key = ?',
      whereArgs: ['device_id'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _deviceId = rows.first['value'] as String;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await db.insert(_metaTable, {'key': 'device_id', 'value': id});
    return _deviceId = id;
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
  ///
  /// Kolom `device_id` + `id` adalah identitas yang dipakai ponsel sebagai
  /// `record_id`, sehingga kedua ekspor bisa dicocokkan tanpa mengandalkan
  /// timestamp.
  Future<String> toCsv() async {
    final db = await database;
    final device = await deviceId();
    final rows = await db.query(_table, orderBy: 'time ASC');
    final buffer = StringBuffer(
      'id,device_id,bpm,accuracy,time_ms,time_iso,synced\n',
    );
    for (final r in rows) {
      final reading = HeartRateReading.fromMap(r);
      buffer.writeln(
        '${reading.id},$device,${reading.bpm},${reading.accuracy},'
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
