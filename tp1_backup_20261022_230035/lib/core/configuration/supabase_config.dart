import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_diagnostics.dart';
import '../security/secure_session_storage.dart';

enum AppEnvironment {
  development('development'),
  staging('staging'),
  production('production');

  final String nameKey;
  const AppEnvironment(this.nameKey);

  static AppEnvironment fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }
}

/// Centralized Supabase & OAuth configuration owned by AI Agent 1.
/// Never stores or exposes service-role keys or SMTP/Resend secrets in the client.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static String get clientKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;

  /// Structural validation only; an actual Auth request must validate the key.
  /// JWT decoding here is NOT authentication or signature verification.
  static String? configurationIssue(String url, String key) {
    if (url.isEmpty || key.isEmpty) return 'missing_configuration';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'invalid_project_url';
    }
    if (key.startsWith('sb_secret_')) return 'private_key_rejected';
    if (key.startsWith('sb_publishable_') && key.length > 15) return null;
    try {
      final parts = key.split('.');
      if (parts.length != 3) return 'invalid_public_key';
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map || claims['role'] != 'anon') {
        return 'private_or_non_anon_key_rejected';
      }
      return null;
    } catch (_) {
      return 'invalid_public_key';
    }
  }

  static const String rawEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String oauthRedirectScheme = String.fromEnvironment(
    'OAUTH_REDIRECT_URI',
    defaultValue: 'io.liftinglife.app://login-callback',
  );

  static const String facebookAppId = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: '',
  );

  static const String appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: '',
  );

  static AppEnvironment get environment =>
      AppEnvironment.fromString(rawEnvironment);

  /// Returns true only when valid HTTPS Supabase URL and public anon key are provided.
  static bool get isConfigured {
    return configurationIssue(supabaseUrl, clientKey) == null;
  }

  static bool get isFacebookOAuthConfigured =>
      isConfigured && facebookAppId.trim().isNotEmpty;

  static bool get isAppleOAuthConfigured =>
      isConfigured && appleServiceId.trim().isNotEmpty;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initializes Supabase with Keychain/Keystore backed session storage when configured.
  static Future<void> initializeIfConfigured({
    LocalStorage? customAuthStorage,
  }) async {
    if (_initialized) return;
    final issue = configurationIssue(supabaseUrl, clientKey);
    if (issue != null) {
      AuthDiagnostics.record(operation: 'initialize', category: issue);
      return;
    }
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: clientKey,
      // Use our redacted diagnostics instead of SDK exception text logging.
      debug: false,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: customAuthStorage ?? SecureSessionStorage.instance,
        autoRefreshToken: true,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient? get clientOrNull =>
      _initialized ? Supabase.instance.client : null;

  /// Reports missing external credentials so the app never claims unconfigured OAuth/SMTP is active.
  static List<String> getMissingExternalConfigurations() {
    final missing = <String>[];
    if (!isConfigured) {
      missing.add(
        'SUPABASE_URL and SUPABASE_ANON_KEY (--dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon_key>)',
      );
    }
    if (facebookAppId.trim().isEmpty) {
      missing.add(
        'FACEBOOK_APP_ID & Facebook OAuth Client Secret in Supabase Dashboard -> Authentication -> Providers -> Facebook',
      );
    }
    if (appleServiceId.trim().isEmpty) {
      missing.add(
        'APPLE_SERVICE_ID, Apple Team ID, Key ID & .p8 Private Key in Supabase Dashboard -> Authentication -> Providers -> Apple',
      );
    }
    return missing;
  }
}
