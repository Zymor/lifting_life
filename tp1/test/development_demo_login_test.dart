import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/main_layout.dart';
import 'package:tp1/models/user_profile.dart';
import 'package:tp1/screens/dashboard_screen.dart';
import 'package:tp1/services/data_service.dart';

void main() {
  final data = DataService.instance;
  const realEmail = 'athlete@liftinglife.app';
  const realPassword = 'RealStrongPassword123!';
  const unseededDemoEmail = 'demo.lifter.4821@example.com';

  setUp(() {
    data.useEmailAuthBackendForTesting(null);
    data.initializeProductionState();
  });

  test('unregistered demo accounts are categorically rejected with no bypasses', () {
    final result = data.signIn(email: unseededDemoEmail, password: 'AnyPassword123!');
    expect(result.isSuccess, isFalse);
    expect(data.isAuthenticated, isFalse);
  });

  testWidgets('login screen does not display any demo boxes or fill shortcuts', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MainLayout()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 300));

    // Confirm that demo banners and shortcuts have been purged
    expect(find.text('Local development demo available'), findsNothing);
    expect(find.text('Fill Dev Account'), findsNothing);
    expect(find.text('Fill Lifter Account'), findsNothing);
  });

  testWidgets('registered legitimate user logs in securely and reaches dashboard', (tester) async {
    data.registerTestAthleteAccount(
      email: realEmail,
      password: realPassword,
      username: 'real_athlete',
    );

    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MainLayout()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 300));

    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);

    await tester.enterText(fields.at(0), realEmail);
    await tester.enterText(fields.at(1), realPassword);
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(data.isAuthenticated, isTrue);
    expect(data.currentUser?.role, UserRole.user);
    expect(data.currentUser?.email, realEmail);
    expect(find.byType(DashboardScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    data.signOut();
    await tester.pump();
  });

  test('incorrect password for legitimate account is rejected', () {
    data.registerTestAthleteAccount(
      email: realEmail,
      password: realPassword,
      username: 'real_athlete',
    );
    expect(data.signIn(email: realEmail, password: 'WrongPassword!').isSuccess, isFalse);
    expect(data.isAuthenticated, isFalse);
  });

  test('legitimate user session restores and handles clean logout', () async {
    data.registerTestAthleteAccount(
      email: realEmail,
      password: realPassword,
      username: 'real_athlete',
    );

    expect(data.signIn(email: realEmail, password: realPassword).isSuccess, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(await data.tryRestorePersistedSession(), isTrue);

    data.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(data.isAuthenticated, isFalse);
    expect(data.currentUser, isNull);
  });
}
