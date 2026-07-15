import 'package:flutter_test/flutter_test.dart';

import 'package:basic_sensor_heart_rate_fastflush_sqflite_ble/models/heart_rate_reading.dart';

void main() {
  test('record HR mempertahankan ringkasan accelerometer', () {
    final time = DateTime.fromMillisecondsSinceEpoch(1783267631326);
    final reading = HeartRateReading(
      id: 7,
      bpm: 82,
      accuracy: 3,
      time: time,
      accelMagnitudeMean: 9.91,
      accelMagnitudeStd: 0.38,
      accelSampleCount: 25,
    );

    final restored = HeartRateReading.fromMap({'id': 7, ...reading.toMap()});

    expect(restored.bpm, 82);
    expect(restored.accelMagnitudeMean, 9.91);
    expect(restored.accelMagnitudeStd, 0.38);
    expect(restored.accelSampleCount, 25);
    expect(restored.time, time);
  });
}
