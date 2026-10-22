import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/core/auth/email_otp_auth_service.dart';
import 'package:tp1/screens/auth_onboarding_screen.dart';
import 'package:tp1/services/data_service.dart';

/// Test double for Supabase Auth. Lives only in the test suite — production
/// code always uses [SupabaseEmailOtpBackend] or reports "not configured".
class _FakeEmailBackend implements EmailOtpAuthBackend {
  EmailAuthStatus signUpStatus = EmailAuthStatus.success;
  EmailAuthStatus verifyStatus = EmailAuthStatus.success;
  EmailAuthStatus resendStatus = EmailAuthStatus.success;

  int signUpCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  int signInCalls = 0;
  String? lastEmail;
  String? lastUsername;
  String? lastPassword;
  String? lastToken;
  String? validEmail;
  String? validPassword;

  @override
  bool get isConfigured => true;

  @override
  Future<EmailAuthOutcome> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    signUpCalls++;
    lastEmail = email;
    lastPassword = password;
    lastUsername = username;
    return EmailAuthOutcome(signUpStatus);
  }

  @override
  Future<EmailAuthOutcome> verifySignupCode({
    required String email,
    required String token,
  }) async {
    verifyCalls++;
    lastToken = token;
    if (verifyStatus != EmailAuthStatus.success) {
      return EmailAuthOutcome(verifyStatus);
    }
    return EmailAuthOutcome(
      EmailAuthStatus.success,
      identity: VerifiedIdentity(
        userId: 'u-${email.hashCode}',
        email: email,
        emailConfirmed: true,
        username: lastUsername ?? 'athlete',
      ),
    );
  }

  @override
  Future<EmailAuthOutcome> resendSignupCode({required String email}) async {
    resendCalls++;
    lastEmail = email;
    return EmailAuthOutcome(resendStatus);
  }

  @override
  Future<EmailAuthOutcome> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    if (email == validEmail && password == validPassword) {
      return EmailAuthOutcome(
        EmailAuthStatus.success,
        identity: VerifiedIdentity(
          userId: 'u-login',
          email: email,
          emailConfirmed: true,
          username: lastUsername ?? 'athlete',
        ),
      );
    }
    return const EmailAuthOutcome(EmailAuthStatus.invalidCredentials);
  }

  @override
  Future<EmailAuthOutcome> sendPasswordResetCode({required String email}) async =>
      const EmailAuthOutcome(EmailAuthStatus.success);

  @override
  Future<EmailAuthOutcome> verifyRecoveryCodeAndUpdatePassword({
    required String email,
    required String token,
    required String newPassword,
  }) async =>
      const EmailAuthOutcome(EmailAuthStatus.success);

  @override
  Future<VerifiedIdentity?> restoreVerifiedSession() async => null;

  @override
  Future<void> updateUserMetadata(Map<String, dynamic> data) async {}

  @override
  Future<void> signOut() async {}
}

Future<void> _openRegisterForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: AuthOnboardingScreen()));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 300));

  await tester.tap(find.text('Continue with Email'));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fillForm(
  WidgetTester tester, {
  String username = 'strength_ana',
  String email = 'ana@example.com',
  String password = 'Str0ng!Pass9',
  String? confirm,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), username);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);
  await tester.enterText(fields.at(3), confirm ?? password);
  await tester.pump();
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('CREATE ACCOUNT'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openLoginForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: AuthOnboardingScreen()));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 300));

  await tester.tap(find.text('Log In'));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late _FakeEmailBackend backend;

  setUp(() {
    DataService.instance.initializeProductionState();
    backend = _FakeEmailBackend();
    DataService.instance.useEmailAuthBackendForTesting(backend);
  });

  tearDown(() {
    DataService.instance.useEmailAuthBackendForTesting(null);
  });

  testWidgets('CREATE ACCOUNT calls Supabase once and opens the OTP screen',
      (tester) async {
    await _openRegisterForm(tester);
    await _fillForm(tester);
    await _submit(tester);

    expect(backend.signUpCalls, 1);
    expect(backend.lastEmail, 'ana@example.com');
    expect(backend.lastUsername, 'strength_ana');
    expect(find.text('Verify Your Email'), findsOneWidget);
    expect(find.textContaining('ana@example.com'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('repeated taps do not create duplicate signups', (tester) async {
    await _openRegisterForm(tester);
    await _fillForm(tester);

    // Two taps before the first request can finish.
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(backend.signUpCalls, 1);
    expect(find.text('Verify Your Email'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('password mismatch is shown inline and blocks the request',
      (tester) async {
    await _openRegisterForm(tester);
    await _fillForm(tester, confirm: 'Different!Pass9');
    await _submit(tester);

    expect(backend.signUpCalls, 0);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('network failure shows a message and restores the button',
      (tester) async {
    backend.signUpStatus = EmailAuthStatus.networkError;
    await _openRegisterForm(tester);
    await _fillForm(tester);
    await _submit(tester);

    expect(find.text('Unable to connect. Please try again.'), findsOneWidget);
    expect(find.text('Verify Your Email'), findsNothing);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('CREATING ACCOUNT...'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unconfigured backend never fakes a successful signup',
      (tester) async {
    DataService.instance.useEmailAuthBackendForTesting(null);

    await _openRegisterForm(tester);
    await _fillForm(tester);
    await _submit(tester);

    expect(
      find.text('Registration is temporarily unavailable. Please try again later.'),
      findsOneWidget,
    );
    expect(find.text('Verify Your Email'), findsNothing);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('valid OTP verifies the account and opens onboarding',
      (tester) async {
    await _openRegisterForm(tester);
    await _fillForm(tester);
    await _submit(tester);

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('otp_box_$i')), '${i + 1}');
    }
    await tester.pump();

    await tester.tap(find.text('Verify Email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(backend.verifyCalls, 1);
    expect(backend.lastToken, '123456');
    expect(DataService.instance.isAuthenticated, isTrue);
    expect(DataService.instance.currentUser?.emailVerified, isTrue);
    expect(find.text('Personalize Lifting Life'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wrong OTP keeps the user on the verification screen',
      (tester) async {
    backend.verifyStatus = EmailAuthStatus.invalidCode;
    await _openRegisterForm(tester);
    await _fillForm(tester);
    await _submit(tester);

    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('otp_box_$i')), '0');
    }
    await tester.pump();

    await tester.tap(find.text('Verify Email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Invalid verification code. Please try again.'),
        findsOneWidget);
    expect(DataService.instance.isAuthenticated, isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wrong password shows an error and restores the login button',
      (tester) async {
    backend.validEmail = 'ana@example.com';
    backend.validPassword = 'Str0ng!Pass9';

    await _openLoginForm(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(backend.signInCalls, 1);
    expect(find.text('Invalid email or password. Please try again.'),
        findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
    expect(DataService.instance.isAuthenticated, isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('correct password signs in through the backend', (tester) async {
    backend.validEmail = 'ana@example.com';
    backend.validPassword = 'Str0ng!Pass9';

    await _openLoginForm(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'Str0ng!Pass9');
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(backend.signInCalls, 1);
    expect(DataService.instance.isAuthenticated, isTrue);
    expect(find.text('Personalize Lifting Life'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  test('legacy salted SHA-256 hashing no longer throws', () {
    final data = DataService.instance;
    final otp = data.startPendingEmailRegistration(
      username: 'legacy_user',
      email: 'legacy@example.com',
      password: 'Str0ng!Pass9',
      deterministicOtpForTesting: '482915',
    );
    expect(otp, '482915');

    expect(data.verifyEmailOtp(otp).isSuccess, isTrue);
    data.signOut();

    final signedIn = data.signIn(
      email: 'legacy@example.com',
      password: 'Str0ng!Pass9',
    );
    expect(signedIn.isSuccess, isTrue);
  });
}
