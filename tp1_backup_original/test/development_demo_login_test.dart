import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/main_layout.dart';
import 'package:tp1/models/user_profile.dart';
import 'package:tp1/screens/dashboard_screen.dart';
import 'package:tp1/services/data_service.dart';

void main() {
  final data = DataService.instance;
  const email = 'demo.lifter.4821@example.com';
  const password = 'V9!qR7#zL2@mK8';

  setUp(() {
    data.useEmailAuthBackendForTesting(null);
    data.initializeProductionState();
  });

  testWidgets('demo credentials use the login button and reach Home', (tester) async {
    if (!data.isDevelopmentDemoAvailable) {
      expect(data.signIn(email: email, password: password).isSuccess, isFalse);
      expect(data.isAuthenticated, isFalse);
      return;
    }
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MainLayout()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Local development demo available'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(data.isAuthenticated, isTrue);
    expect(data.currentUser?.role, UserRole.user);
    expect(find.byType(DashboardScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    data.signOut();
    await tester.pump();
  });

  test('incorrect demo password is rejected', () {
    expect(data.signIn(email: email, password: 'wrong').isSuccess, isFalse);
    expect(data.isAuthenticated, isFalse);
  });

  test('demo can log in again after session restoration and logout', () async {
    if (!data.isDevelopmentDemoAvailable) return;
    expect(data.signIn(email: email, password: password).isSuccess, isTrue);
    // Let the asynchronous local session write complete before restoring it.
    await Future<void>.delayed(Duration.zero);
    expect(await data.tryRestorePersistedSession(), isTrue);
    data.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(data.signIn(email: email, password: password).isSuccess, isTrue);
    data.signOut();
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets('quick fill dev account button populates credentials and logs in as admin', (tester) async {
    if (!data.isDevelopmentDemoAvailable) return;
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MainLayout()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fill Dev Account'), findsOneWidget);
    await tester.tap(find.text('Fill Dev Account'));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(0)).controller?.text, DataService.devDemoEmail);
    expect(tester.widget<TextField>(fields.at(1)).controller?.text, DataService.devDemoPassword);

    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(data.isAuthenticated, isTrue);
    expect(data.currentUser?.role, UserRole.admin);
    expect(data.currentUser?.email, DataService.devDemoEmail);
    expect(find.byType(DashboardScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    data.signOut();
    await tester.pump();
  });
}
