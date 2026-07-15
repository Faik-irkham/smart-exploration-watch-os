import 'package:flutter_test/flutter_test.dart';

import 'package:heart_rate_phone_receiver/models/heart_rate_reading.dart';

void main() {
  test('receiver mendukung record accelerometer dan record HR lama', () {
    final withAccelerometer = HeartRateReading.fromMap({
      'id': 1,
      'bpm': 82.0,
      'accuracy': 3,
      'time': 1783267631326,
      'accel_magnitude_mean': 9.91,
      'accel_magnitude_std': 0.38,
      'accel_sample_count': 25,
    });
    final legacy = HeartRateReading.fromMap({
      'id': 2,
      'bpm': 80.0,
      'accuracy': 3,
      'time': 1783267632326,
    });

    expect(withAccelerometer.accelMagnitudeStd, 0.38);
    expect(withAccelerometer.accelSampleCount, 25);
    expect(legacy.accelMagnitudeMean, isNull);
    expect(legacy.accelSampleCount, 0);
  });
}
