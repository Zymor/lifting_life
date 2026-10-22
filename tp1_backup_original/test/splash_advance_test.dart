import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/screens/auth_onboarding_screen.dart';

void main() {
  testWidgets('splash advances to welcome', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthOnboardingScreen()),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));

    // ignore: avoid_print
    print('splash visible: ${find.text('Checking secure session...').evaluate().isNotEmpty}');
    // ignore: avoid_print
    print('welcome visible: ${find.text('Welcome to Lifting Life').evaluate().isNotEmpty}');

    expect(find.text('Checking secure session...'), findsNothing);
    expect(find.text('Welcome to Lifting Life'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
