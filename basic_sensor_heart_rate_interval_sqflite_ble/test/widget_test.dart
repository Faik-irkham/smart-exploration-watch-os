import 'package:flutter_test/flutter_test.dart';

import 'package:basic_sensor_heart_rate_interval_sqflite_ble/ble_peripheral.dart';
import 'package:basic_sensor_heart_rate_interval_sqflite_ble/models/heart_rate_reading.dart';

void main() {
  test('record HR bolak-balik lewat map SQLite tanpa kehilangan nilai', () {
    final asli = HeartRateReading(
      bpm: 82.0,
      accuracy: 3,
      time: DateTime.fromMillisecondsSinceEpoch(1783267631326),
      synced: true,
    );

    final pulih = HeartRateReading.fromMap({'id': 7, ...asli.toMap()});

    expect(pulih.id, 7);
    expect(pulih.bpm, 82.0);
    expect(pulih.accuracy, 3);
    expect(pulih.time.millisecondsSinceEpoch, 1783267631326);
    expect(pulih.synced, isTrue);
  });

  group('BatchAckResult', () {
    test('selisih terkirim dan tersimpan dihitung sebagai duplikat', () {
      const ack = BatchAckResult(
        batchId: 42,
        expected: 228,
        ok: true,
        stored: 226,
        status: 'ok',
      );

      expect(ack.duplicates, 2);
    });

    test('batch yang gagal tidak melaporkan duplikat', () {
      // stored=0 pada batch gagal bukan berarti 228 record duplikat; tanpa
      // penjagaan ini metrik duplikat akan melonjak tiap kali ada timeout.
      const ack = BatchAckResult(
        batchId: 42,
        expected: 228,
        status: 'timeout',
      );

      expect(ack.ok, isFalse);
      expect(ack.duplicates, 0);
    });
  });
}
