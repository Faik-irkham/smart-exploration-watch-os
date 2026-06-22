// Smoke test untuk aplikasi watch heart rate + BLE.

import 'package:flutter_test/flutter_test.dart';

import 'package:basic_sensor_heart_rate_interval_sqflite_ble/main.dart';

void main() {
  testWidgets('Layar awal menampilkan tombol mulai', (tester) async {
    await tester.pumpWidget(const HeartRateApp());

    // Layar setup menampilkan ajakan memilih interval dan tombol mulai.
    expect(find.text('Izinkan & Mulai'), findsOneWidget);
    expect(find.text('1 menit'), findsOneWidget);
  });
}
