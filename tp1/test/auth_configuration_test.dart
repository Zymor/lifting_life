import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tp1/core/auth/auth_diagnostics.dart';
import 'package:tp1/core/auth/email_otp_auth_service.dart';
import 'package:tp1/core/configuration/supabase_config.dart';

void main() {
  const url = 'https://project.supabase.co';
  String jwt(String role) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';

  test('missing configuration cannot enable real authentication', () {
    expect(SupabaseConfig.configurationIssue('', ''), 'missing_configuration');
  });
  test('accepts publishable and legacy anon key shapes', () {
    expect(
      SupabaseConfig.configurationIssue(url, 'sb_publishable_test'),
      isNull,
    );
    expect(SupabaseConfig.configurationIssue(url, jwt('anon')), isNull);
  });
  test('rejects private keys including encoded service role', () {
    for (final key in [
      'sb_secret_test',
      jwt('service_role'),
      jwt('authenticated'),
      'malformed',
    ]) {
      expect(SupabaseConfig.configurationIssue(url, key), isNotNull);
    }
  });
  test('rejects malformed URLs and embedded credentials', () {
    for (final badUrl in [
      'https:',
      'http://project.supabase.co',
      'https://user:password@project.supabase.co',
      '$url/auth/v1',
      '$url?key=secret',
    ]) {
      expect(
        SupabaseConfig.configurationIssue(badUrl, 'sb_publishable_test'),
        isNotNull,
      );
    }
  });
  test('SMTP recipient restrictions are not invalid email syntax', () {
    expect(
      SupabaseEmailOtpBackend.mapAuthException(
        const AuthException(
          'Restricted recipient',
          code: 'email_address_not_authorized',
          statusCode: '400',
        ),
      ),
      EmailAuthStatus.deliveryFailed,
    );
  });
  test('database server failure is not misreported as SMTP failure', () {
    expect(
      SupabaseEmailOtpBackend.mapAuthException(
        const AuthException(
          'Database error saving new user',
          code: 'unexpected_failure',
          statusCode: '500',
        ),
      ),
      EmailAuthStatus.unknown,
    );
  });
  test('diagnostics omit unexpected code/status payloads', () {
    final line = AuthDiagnostics.format(
      operation: 'sign_up',
      category: 'unknown',
      code: 'private-token-example',
      httpStatus: 'password=private',
    );
    expect(line, contains('code=unclassified http_status=none'));
    expect(line, isNot(contains('private')));
  });
  test('diagnostics retain known backend code and HTTP status', () {
    expect(
      AuthDiagnostics.format(
        operation: 'sign_up',
        category: 'unknown',
        code: 'unexpected_failure',
        httpStatus: '500',
      ),
      contains('code=unexpected_failure http_status=500'),
    );
  });
}
