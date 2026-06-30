import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shadowtempmail/main.dart';

void main() {
  testWidgets('ShadowTempMail app renders dashboard',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ShadowTempMailApp());
    await tester.pumpAndSettle();

    expect(find.text('ShadowTempMail'), findsOneWidget);
  });
}
