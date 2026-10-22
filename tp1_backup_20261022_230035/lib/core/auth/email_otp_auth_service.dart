import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_diagnostics.dart';

/// Outcome categories for every email-auth operation. The UI maps these to
/// the exact user-facing copy defined in [EmailAuthMessages].
enum EmailAuthStatus {
  success,
  invalidCode,
  expiredCode,
  tooManyAttempts,
  deliveryFailed,
  networkError,
  rateLimited,
  invalidEmail,
  weakPassword,
  invalidCredentials,
  emailNotConfirmed,
  emailAlreadyRegistered,
  serverMisconfigured,
  notConfigured,
  unknown,
}

/// User-facing copy for the email verification system.
class EmailAuthMessages {
  EmailAuthMessages._();

  static const String invalidCode =
      'Invalid verification code. Please try again.';
  static const String expiredCode = 'Your code has expired. Request a new one.';
  static const String deliveryFailed =
      "We couldn't send your verification email. Please try again.";
  static const String networkError =
      'Connection error. Check your internet and try again.';
  static const String tooManyAttempts =
      'Too many incorrect attempts. Request a new code to continue.';
  static const String rateLimited =
      'Too many requests. Please wait a moment before trying again.';
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String weakPassword =
      'Password is too weak. Use at least 8 characters with uppercase, numbers, and symbols.';
  static const String invalidCredentials =
      'Invalid email or password. Please try again.';
  static const String emailNotConfirmed =
      'Your email address has not been verified yet. Enter the 6-digit code we sent you.';
  static const String emailAlreadyRegistered =
      'An account with this email address already exists. Please log in.';
  static const String serverMisconfigured =
      'Email confirmation is disabled on the server. Enable "Confirm email" in Supabase Auth settings.';
  static const String notConfigured =
      'Email verification service is not configured. Connect Supabase (SUPABASE_URL and SUPABASE_ANON_KEY) to create accounts.';
  static const String unknown = 'Something went wrong. Please try again.';
  static const String verified = 'Email Verified Successfully!';

  static String forStatus(EmailAuthStatus status) {
    switch (status) {
      case EmailAuthStatus.success:
        return verified;
      case EmailAuthStatus.invalidCode:
        return invalidCode;
      case EmailAuthStatus.expiredCode:
        return expiredCode;
      case EmailAuthStatus.tooManyAttempts:
        return tooManyAttempts;
      case EmailAuthStatus.deliveryFailed:
        return deliveryFailed;
      case EmailAuthStatus.networkError:
        return networkError;
      case EmailAuthStatus.rateLimited:
        return rateLimited;
      case EmailAuthStatus.invalidEmail:
        return invalidEmail;
      case EmailAuthStatus.weakPassword:
        return weakPassword;
      case EmailAuthStatus.invalidCredentials:
        return invalidCredentials;
      case EmailAuthStatus.emailNotConfirmed:
        return emailNotConfirmed;
      case EmailAuthStatus.emailAlreadyRegistered:
        return emailAlreadyRegistered;
      case EmailAuthStatus.serverMisconfigured:
        return serverMisconfigured;
      case EmailAuthStatus.notConfigured:
        return notConfigured;
      case EmailAuthStatus.unknown:
        return unknown;
    }
  }
}

/// Identity of a user whose email address has been confirmed by the backend.
class VerifiedIdentity {
  final String userId;
  final String email;
  final String? username;
  final bool emailConfirmed;
  final Map<String, dynamic> metadata;

  const VerifiedIdentity({
    required this.userId,
    required this.email,
    required this.emailConfirmed,
    this.username,
    this.metadata = const {},
  });

  bool get onboardingCompleted => metadata['onboarding_completed'] == true;
}

class EmailAuthOutcome {
  final EmailAuthStatus status;
  final VerifiedIdentity? identity;

  const EmailAuthOutcome(this.status, {this.identity});

  bool get isSuccess => status == EmailAuthStatus.success;
  String get message => EmailAuthMessages.forStatus(status);
}

/// Backend contract for email registration + 6-digit OTP verification.
///
/// The production implementation is [SupabaseEmailOtpBackend]: Supabase Auth
/// generates, emails (via the configured SMTP provider), expires, rate-limits
/// and verifies the code. The app never generates or stores OTPs itself.
abstract class EmailOtpAuthBackend {
  bool get isConfigured;

  /// Creates the account and triggers Supabase to email the 6-digit code.
  Future<EmailAuthOutcome> signUp({
    required String email,
    required String password,
    required String username,
  });

  /// Verifies the 6-digit signup code. On success a session is created.
  Future<EmailAuthOutcome> verifySignupCode({
    required String email,
    required String token,
  });

  /// Asks Supabase to email a fresh signup code (server enforces limits).
  Future<EmailAuthOutcome> resendSignupCode({required String email});

  Future<EmailAuthOutcome> signInWithPassword({
    required String email,
    required String password,
  });

  /// Sends a 6-digit password recovery code using the Recovery template.
  Future<EmailAuthOutcome> sendPasswordResetCode({required String email});

  Future<EmailAuthOutcome> verifyRecoveryCodeAndUpdatePassword({
    required String email,
    required String token,
    required String newPassword,
  });

  /// Returns the identity for an existing, valid, email-confirmed session.
  Future<VerifiedIdentity?> restoreVerifiedSession();

  Future<void> updateUserMetadata(Map<String, dynamic> data);

  Future<void> signOut();
}

/// Used when Supabase credentials are missing. It never simulates success:
/// every action reports [EmailAuthStatus.notConfigured].
class UnconfiguredEmailOtpBackend implements EmailOtpAuthBackend {
  const UnconfiguredEmailOtpBackend();

  static const _outcome = EmailAuthOutcome(EmailAuthStatus.notConfigured);

  @override
  bool get isConfigured => false;

  @override
  Future<EmailAuthOutcome> signUp({
    required String email,
    required String password,
    required String username,
  }) async => _outcome;

  @override
  Future<EmailAuthOutcome> verifySignupCode({
    required String email,
    required String token,
  }) async => _outcome;

  @override
  Future<EmailAuthOutcome> resendSignupCode({required String email}) async =>
      _outcome;

  @override
  Future<EmailAuthOutcome> signInWithPassword({
    required String email,
    required String password,
  }) async => _outcome;

  @override
  Future<EmailAuthOutcome> sendPasswordResetCode({
    required String email,
  }) async => _outcome;

  @override
  Future<EmailAuthOutcome> verifyRecoveryCodeAndUpdatePassword({
    required String email,
    required String token,
    required String newPassword,
  }) async => _outcome;

  @override
  Future<VerifiedIdentity?> restoreVerifiedSession() async => null;

  @override
  Future<void> updateUserMetadata(Map<String, dynamic> data) async {}

  @override
  Future<void> signOut() async {}
}

/// Real Supabase Auth implementation.
///
/// Requires in the Supabase dashboard: "Confirm email" enabled, custom SMTP
/// (Resend / SendGrid / Amazon SES) and the Confirm-signup template containing
/// `{{ .Token }}`. See documentation/EMAIL_OTP_SMTP_SETUP.md.
class SupabaseEmailOtpBackend implements EmailOtpAuthBackend {
  SupabaseEmailOtpBackend(
    this._client, {
    this.requestTimeout = const Duration(seconds: 20),
  });

  final SupabaseClient _client;
  final Duration requestTimeout;

  GoTrueClient get _auth => _client.auth;

  @override
  bool get isConfigured => true;

  @override
  Future<EmailAuthOutcome> signUp({
    required String email,
    required String password,
    required String username,
  }) {
    return _guard('sign_up', () async {
      final res = await _auth
          .signUp(
            email: email,
            password: password,
            data: {'username': username, 'display_name': username},
          )
          .timeout(requestTimeout);
      if (res.session != null) {
        // A session on signUp means "Confirm email" is OFF on the server,
        // which would let unverified addresses in. Refuse and sign out.
        await _auth.signOut();
        return const EmailAuthOutcome(EmailAuthStatus.serverMisconfigured);
      }
      // For anti-enumeration Supabase returns an obfuscated user when the
      // address already exists, so the response is always "code sent".
      return const EmailAuthOutcome(EmailAuthStatus.success);
    }, treatExistingAccountAsSent: true);
  }

  @override
  Future<EmailAuthOutcome> verifySignupCode({
    required String email,
    required String token,
  }) {
    return _guard('verify_signup', () async {
      final res = await _auth
          .verifyOTP(type: OtpType.signup, email: email, token: token)
          .timeout(requestTimeout);
      final user = res.user ?? res.session?.user;
      if (res.session == null || user == null) {
        return const EmailAuthOutcome(EmailAuthStatus.invalidCode);
      }
      return EmailAuthOutcome(
        EmailAuthStatus.success,
        identity: _identityFrom(user),
      );
    });
  }

  @override
  Future<EmailAuthOutcome> resendSignupCode({required String email}) {
    return _guard('resend_signup', () async {
      await _auth
          .resend(type: OtpType.signup, email: email)
          .timeout(requestTimeout);
      return const EmailAuthOutcome(EmailAuthStatus.success);
    }, treatExistingAccountAsSent: true);
  }

  @override
  Future<EmailAuthOutcome> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _guard('sign_in', () async {
      final res = await _auth
          .signInWithPassword(email: email, password: password)
          .timeout(requestTimeout);
      final user = res.user;
      if (res.session == null || user == null) {
        return const EmailAuthOutcome(EmailAuthStatus.invalidCredentials);
      }
      if (user.emailConfirmedAt == null) {
        await _auth.signOut();
        return const EmailAuthOutcome(EmailAuthStatus.emailNotConfirmed);
      }
      return EmailAuthOutcome(
        EmailAuthStatus.success,
        identity: _identityFrom(user),
      );
    });
  }

  @override
  Future<EmailAuthOutcome> sendPasswordResetCode({required String email}) {
    return _guard('send_recovery', () async {
      await _auth.resetPasswordForEmail(email).timeout(requestTimeout);
      return const EmailAuthOutcome(EmailAuthStatus.success);
    }, treatExistingAccountAsSent: true);
  }

  @override
  Future<EmailAuthOutcome> verifyRecoveryCodeAndUpdatePassword({
    required String email,
    required String token,
    required String newPassword,
  }) {
    return _guard('verify_recovery_and_update_password', () async {
      final res = await _auth
          .verifyOTP(type: OtpType.recovery, email: email, token: token)
          .timeout(requestTimeout);
      if (res.session == null) {
        return const EmailAuthOutcome(EmailAuthStatus.invalidCode);
      }
      await _auth
          .updateUser(UserAttributes(password: newPassword))
          .timeout(requestTimeout);
      // Force a fresh sign-in with the new password.
      await _auth.signOut();
      return const EmailAuthOutcome(EmailAuthStatus.success);
    });
  }

  @override
  Future<VerifiedIdentity?> restoreVerifiedSession() async {
    try {
      var session = _auth.currentSession;
      if (session == null) return null;
      if (session.isExpired) {
        final refreshed = await _auth.refreshSession().timeout(requestTimeout);
        session = refreshed.session;
      }
      final user = session?.user;
      if (session == null || user == null || user.emailConfirmedAt == null) {
        return null;
      }
      return _identityFrom(user);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateUserMetadata(Map<String, dynamic> data) async {
    try {
      if (_auth.currentSession == null) return;
      await _auth
          .updateUser(UserAttributes(data: data))
          .timeout(requestTimeout);
    } catch (_) {
      // Non-critical: local state is already saved; retried on next change.
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Local session is cleared by the SDK even if the network call fails.
    }
  }

  VerifiedIdentity _identityFrom(User user) {
    final meta = Map<String, dynamic>.from(user.userMetadata ?? const {});
    return VerifiedIdentity(
      userId: user.id,
      email: (user.email ?? '').toLowerCase(),
      username: meta['username']?.toString(),
      emailConfirmed: user.emailConfirmedAt != null,
      metadata: meta,
    );
  }

  Future<EmailAuthOutcome> _guard(
    String operation,
    Future<EmailAuthOutcome> Function() action, {
    bool treatExistingAccountAsSent = false,
  }) async {
    try {
      return await action();
    } on AuthException catch (e) {
      final status = mapAuthException(e);
      AuthDiagnostics.record(
        operation: operation,
        category: status.name,
        code: e.code,
        httpStatus: e.statusCode,
      );
      if (treatExistingAccountAsSent && isExistingAccountError(e)) {
        // Never reveal whether an address already has an account.
        return const EmailAuthOutcome(EmailAuthStatus.success);
      }
      return EmailAuthOutcome(status);
    } on TimeoutException {
      AuthDiagnostics.record(operation: operation, category: 'network_error');
      return const EmailAuthOutcome(EmailAuthStatus.networkError);
    } on SocketException {
      AuthDiagnostics.record(operation: operation, category: 'network_error');
      return const EmailAuthOutcome(EmailAuthStatus.networkError);
    } on HandshakeException {
      AuthDiagnostics.record(operation: operation, category: 'network_error');
      return const EmailAuthOutcome(EmailAuthStatus.networkError);
    } on HttpException {
      AuthDiagnostics.record(operation: operation, category: 'network_error');
      return const EmailAuthOutcome(EmailAuthStatus.networkError);
    } catch (_) {
      AuthDiagnostics.record(
        operation: operation,
        category: 'unexpected_failure',
      );
      return const EmailAuthOutcome(EmailAuthStatus.unknown);
    }
  }

  static bool isExistingAccountError(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    return code == 'user_already_exists' || code == 'email_exists';
  }

  /// Maps Supabase Auth error codes to [EmailAuthStatus]. Note that Supabase
  /// returns `otp_expired` for both wrong and expired codes; the caller uses
  /// the time the code was sent to tell the two apart.
  static EmailAuthStatus mapAuthException(AuthException e) {
    if (e is AuthRetryableFetchException) return EmailAuthStatus.networkError;
    final code = (e.code ?? '').toLowerCase();
    final msg = e.message.toLowerCase();
    final status = e.statusCode ?? '';

    switch (code) {
      case 'otp_expired':
        return EmailAuthStatus.invalidCode;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return EmailAuthStatus.rateLimited;
      case 'email_address_invalid':
      case 'validation_failed':
        return EmailAuthStatus.invalidEmail;
      case 'email_address_not_authorized':
        return EmailAuthStatus.deliveryFailed;
      case 'weak_password':
        return EmailAuthStatus.weakPassword;
      case 'invalid_credentials':
        return EmailAuthStatus.invalidCredentials;
      case 'email_not_confirmed':
        return EmailAuthStatus.emailNotConfirmed;
      case 'email_provider_disabled':
      case 'signup_disabled':
        return EmailAuthStatus.serverMisconfigured;
    }
    if (status == '429') return EmailAuthStatus.rateLimited;
    if (msg.contains('sending') && msg.contains('email')) {
      return EmailAuthStatus.deliveryFailed;
    }
    if (msg.contains('expired') ||
        msg.contains('invalid') && msg.contains('token')) {
      return EmailAuthStatus.invalidCode;
    }
    // A 5xx can be a database trigger failure; do not mislabel it as SMTP.
    if (status.startsWith('5')) return EmailAuthStatus.unknown;
    return EmailAuthStatus.unknown;
  }
}
