// Smoke test untuk aplikasi penerima (phone).

import 'package:flutter_test/flutter_test.dart';

import 'package:heart_rate_phone_receiver/main.dart';

void main() {
  testWidgets('Menampilkan tombol hubungkan watch', (tester) async {
    await tester.pumpWidget(const ReceiverApp());

    expect(find.text('Hubungkan watch'), findsOneWidget);
    expect(find.text('Penerima Detak Jantung'), findsOneWidget);
  });
}
