import 'package:flutter_test/flutter_test.dart';

import 'package:heart_rate_phone_receiver/models/heart_rate_reading.dart';

void main() {
  test('record membawa identitas asalnya dari watch', () {
    final r = HeartRateReading.fromMap({
      'id': 1,
      'device_id': '9f2c1ab7e04d5386c1b0f7a2d3e45569',
      'record_id': 1041,
      'bpm': 82.0,
      'accuracy': 3,
      'time': 1783267631326,
    });

    expect(r.deviceId, '9f2c1ab7e04d5386c1b0f7a2d3e45569');
    expect(r.recordId, 1041);
    expect(r.time.millisecondsSinceEpoch, 1783267631326);
  });

  test('record dari protokol lama tetap terbaca tanpa identitas', () {
    // Payload format lama tidak membawa device/rid; barisnya harus tetap
    // bisa dimuat, hanya tanpa identitas record.
    final legacy = HeartRateReading.fromMap({
      'id': 2,
      'bpm': 80.0,
      'accuracy': 3,
      'time': 1783267632326,
    });

    expect(legacy.deviceId, isNull);
    expect(legacy.recordId, isNull);
    expect(legacy.bpm, 80.0);
  });
}
