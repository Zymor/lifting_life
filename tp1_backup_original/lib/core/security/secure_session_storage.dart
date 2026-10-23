import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform-backed Secure Session & Local Draft Persistence Service (AI Agent 1).
/// Uses Android Keystore / EncryptedSharedPreferences and iOS Keychain via FlutterSecureStorage.
/// Includes a safe in-memory fallback when running inside headless widget tests.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage._();
  static final SecureSessionStorage instance = SecureSessionStorage._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Fallback map used in headless flutter_test environments without native platform channels
  final Map<String, String> _memoryVault = <String, String>{};
  final Map<String, Future<void>> _pendingWrites = {};

  Future<void> _serialize(String key, Future<void> Function() operation) {
    final previous = _pendingWrites[key] ?? Future<void>.value();
    final next = previous.then((_) => operation());
    _pendingWrites[key] = next;
    return next.whenComplete(() {
      if (identical(_pendingWrites[key], next)) _pendingWrites.remove(key);
    });
  }

  static const String _kActiveSessionKey = 'll_secure_auth_session_v1';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final token = await getItem(key: supabasePersistSessionKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    return getItem(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await setItem(key: supabasePersistSessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await removeItem(key: supabasePersistSessionKey);
  }

  bool get _isFlutterTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  void clearMemoryVaultForTesting() {
    _memoryVault.clear();
  }

  Future<String?> getItem({required String key}) async {
    await _pendingWrites[key];
    if (_isFlutterTest) {
      return _memoryVault[key];
    }
    try {
      final val = await _secureStorage
          .read(key: key)
          .timeout(const Duration(seconds: 2));
      if (val != null) {
        _memoryVault[key] = val;
        return val;
      }
    } on MissingPluginException {
      // Headless unit/widget test environment
    } on PlatformException {
      // Fallback if Keystore/Keychain is locked during test
    } catch (_) {
      // Safe fallback
    }
    return _memoryVault[key];
  }

  Future<void> setItem({
    required String key,
    required String value,
  }) => _serialize(key, () => _writeItem(key: key, value: value));

  Future<void> _writeItem({required String key, required String value}) async {
    _memoryVault[key] = value;
    if (_isFlutterTest) {
      return;
    }
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(const Duration(seconds: 2));
    } on MissingPluginException {
      // Headless unit/widget test environment
    } on PlatformException {
      // Fallback
    } catch (_) {
      // Safe fallback
    }
  }

  Future<void> removeItem({required String key}) =>
      _serialize(key, () => _deleteItem(key: key));

  Future<void> _deleteItem({required String key}) async {
    _memoryVault.remove(key);
    if (_isFlutterTest) {
      return;
    }
    try {
      await _secureStorage
          .delete(key: key)
          .timeout(const Duration(seconds: 2));
    } on MissingPluginException {
      // Headless unit/widget test environment
    } on PlatformException {
      // Fallback
    } catch (_) {
      // Safe fallback
    }
  }

  /// Stores profile/onboarding session metadata. Never stores passwords, OTPs,
  /// or auth tokens (the Supabase SDK persists its own tokens via this class).
  Future<void> saveSessionSnapshot({
    required String userId,
    required String email,
    required DateTime expiresAt,
    required bool onboardingCompleted,
  }) async {
    final payload = jsonEncode({
      'userId': userId,
      'email': email,
      'expiresAt': expiresAt.toIso8601String(),
      'onboardingCompleted': onboardingCompleted,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await setItem(key: _kActiveSessionKey, value: payload);
  }

  /// Reads and validates the stored session snapshot. Returns null if missing or expired.
  Future<Map<String, dynamic>?> readValidSessionSnapshot() async {
    final raw = await getItem(key: _kActiveSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final expiresRaw = decoded['expiresAt'] as String?;
      if (expiresRaw == null) return null;
      final expiresAt = DateTime.tryParse(expiresRaw);
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        await removeItem(key: _kActiveSessionKey);
        return null;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Clears active session credentials on logout without erasing the user's cloud/saved workout history.
  Future<void> clearActiveSession() async {
    await removeItem(key: _kActiveSessionKey);
  }

  /// Saves user-scoped JSON data (e.g. workouts, active draft, PRs, profile) keyed by authenticated userId.
  Future<void> saveUserScopedJson({
    required String userId,
    required String collection,
    required Object jsonEncodable,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId is required for user-scoped persistence.');
    }
    final key = 'll_user_${userId.trim()}_$collection';
    await setItem(key: key, value: jsonEncode(jsonEncodable));
  }

  /// Reads user-scoped JSON data strictly isolated to the specified authenticated userId.
  Future<dynamic> readUserScopedJson({
    required String userId,
    required String collection,
  }) async {
    if (userId.trim().isEmpty) return null;
    final key = 'll_user_${userId.trim()}_$collection';
    final raw = await getItem(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Removes all user-scoped local caches when an account is permanently deleted.
  Future<void> purgeAllDataForDeletedUser(String userId) async {
    for (final col in const [
      'profile',
      'workouts',
      'active_draft',
      'templates',
      'prs',
      'favorites',
      'enrollments',
      'sync_queue',
    ]) {
      await removeItem(key: 'll_user_${userId.trim()}_$col');
    }
    await clearActiveSession();
  }
}
