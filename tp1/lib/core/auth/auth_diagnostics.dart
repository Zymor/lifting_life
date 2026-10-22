import 'package:flutter/foundation.dart';

/// Never accepts exception messages, request bodies, identities or credentials.
class AuthDiagnostics {
  AuthDiagnostics._();

  static const _knownCodes = {
    'otp_expired',
    'over_email_send_rate_limit',
    'over_request_rate_limit',
    'email_address_invalid',
    'email_address_not_authorized',
    'validation_failed',
    'weak_password',
    'invalid_credentials',
    'email_not_confirmed',
    'email_provider_disabled',
    'signup_disabled',
    'user_already_exists',
    'email_exists',
    'unexpected_failure',
    'request_timeout',
  };

  static String format({
    required String operation,
    required String category,
    String? code,
    String? httpStatus,
  }) {
    final safeCode = _knownCodes.contains(code) ? code : 'unclassified';
    final safeStatus = RegExp(r'^[1-5][0-9]{2}$').hasMatch(httpStatus ?? '')
        ? httpStatus
        : 'none';
    // Operation/category are constant internal labels, never server messages.
    return 'auth operation=$operation category=$category '
        'code=$safeCode http_status=$safeStatus';
  }

  static void record({
    required String operation,
    required String category,
    String? code,
    String? httpStatus,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      format(
        operation: operation,
        category: category,
        code: code,
        httpStatus: httpStatus,
      ),
    );
  }
}
