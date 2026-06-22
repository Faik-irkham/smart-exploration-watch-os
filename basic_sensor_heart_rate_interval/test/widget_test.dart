// Basic smoke test untuk aplikasi heart rate dengan interval.

import 'package:flutter_test/flutter_test.dart';

import 'package:basic_sensor_heart_rate_interval/main.dart';

void main() {
  testWidgets('Menampilkan pilihan interval dan tombol mulai',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HeartRateApp());
    await tester.pump();

    // Ketiga pilihan interval harus tersedia di layar awal.
    expect(find.text('1 menit'), findsOneWidget);
    expect(find.text('3 menit'), findsOneWidget);
    expect(find.text('5 menit'), findsOneWidget);

    // Tombol untuk meminta izin sekaligus memulai pembacaan.
    expect(find.text('Izinkan & Mulai'), findsOneWidget);
  });
}
