import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/heart_rate_reading.dart';

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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            record_id INTEGER,
            bpm REAL NOT NULL,
            accuracy INTEGER NOT NULL,
            time INTEGER NOT NULL
          )
        ''');
        // Identitas record dari watch mencegah duplikat saat batch dikirim
        // ulang (mis. ACK hilang). Dipakai sebagai ganti timestamp karena
        // timestamp bisa bertabrakan atau bergeser saat jam sistem disetel.
        await db.execute(
          'CREATE UNIQUE INDEX idx_${_table}_record '
          'ON $_table(device_id, record_id)',
        );
        await db.execute('CREATE INDEX idx_${_table}_time ON $_table(time)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: buang duplikat lama (sisakan id terkecil), lalu buat indeks
        // unik pada time.
        if (oldVersion < 2) {
          await db.execute(
            'DELETE FROM $_table WHERE id NOT IN '
            '(SELECT MIN(id) FROM $_table GROUP BY time)',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_${_table}_time '
            'ON $_table(time)',
          );
        }
        // v2 -> v3 tidak lagi menambah apa pun; kolom yang dulu dibuat di sana
        // sudah tidak dipakai dan dibiarkan pada pemasangan yang memilikinya.
        // v3 -> v4: anti-duplikat pindah dari timestamp ke identitas record.
        // Indeks time dibuat non-unik agar timestamp yang bertabrakan tidak
        // lagi membuang record yang sebenarnya berbeda. Baris lama ber-
        // device_id NULL tidak saling bentrok karena SQLite memperlakukan NULL
        // sebagai nilai yang berbeda-beda pada indeks unik.
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE $_table ADD COLUMN device_id TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN record_id INTEGER');
          await db.execute('DROP INDEX IF EXISTS idx_${_table}_time');
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_${_table}_record '
            'ON $_table(device_id, record_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_${_table}_time ON $_table(time)',
          );
        }
      },
    );
    return _db!;
  }

  /// Simpan satu pembacaan dan kembalikan objek dengan [id] terisi.
  Future<HeartRateReading> insertReading(HeartRateReading reading) async {
    final db = await database;
    final id = await db.insert(
      _table,
      reading.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return HeartRateReading(
      id: id,
      deviceId: reading.deviceId,
      recordId: reading.recordId,
      bpm: reading.bpm,
      accuracy: reading.accuracy,
      time: reading.time,
    );
  }

  /// Simpan banyak pembacaan sekaligus (satu batch dari watch) dalam satu
  /// transaksi agar cepat.
  ///
  /// Mengembalikan jumlah record yang **baru** tersimpan; record yang sudah ada
  /// tidak dihitung, sehingga selisihnya terhadap panjang [readings] adalah
  /// jumlah duplikat.
  Future<int> insertReadings(List<HeartRateReading> readings) async {
    if (readings.isEmpty) return 0;
    final db = await database;
    final batch = db.batch();
    for (final r in readings) {
      batch.insert(
        _table,
        r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    final results = await batch.commit(noResult: false);
    // Insert yang diabaikan karena duplikat mengembalikan rowid 0.
    return results.where((r) => (r as int? ?? 0) > 0).length;
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

  /// Seluruh isi tabel sebagai CSV (urut terlama→terbaru), siap diekspor.
  Future<String> toCsv() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'time ASC');
    final buffer = StringBuffer(
      'id,device_id,record_id,bpm,accuracy,time_ms,time_iso\n',
    );
    for (final r in rows) {
      final reading = HeartRateReading.fromMap(r);
      buffer.writeln(
        '${reading.id},${reading.deviceId ?? ''},${reading.recordId ?? ''},'
        '${reading.bpm},${reading.accuracy},'
        '${reading.time.millisecondsSinceEpoch},'
        '${reading.time.toIso8601String()}',
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
