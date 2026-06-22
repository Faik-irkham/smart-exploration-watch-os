// Basic smoke test untuk aplikasi heart rate.

import 'package:flutter_test/flutter_test.dart';

import 'package:basic_sensor_heart_rate/main.dart';

void main() {
  testWidgets('Menampilkan placeholder BPM saat belum ada data',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HeartRateApp());
    await tester.pump();

    // Label BPM selalu tampil; angka placeholder "--" muncul sebelum
    // ada pembacaan sensor.
    expect(find.text('BPM'), findsOneWidget);
  });
}
