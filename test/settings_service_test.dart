import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for flutter_secure_storage — same fake as
/// command_router_test.dart, duplicated here since this file exercises
/// SettingsService in isolation.
class _FakeSecureStorageService extends SecureStorageService {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late _FakeSecureStorageService secure;
  late SettingsService settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secure = _FakeSecureStorageService();
    settings = SettingsService(secureStorage: secure);
  });

  group('secure (AES-256) storage', () {
    test('a saved weather API key round-trips through secure storage', () async {
      await settings.setWeatherApiKey('super-secret-weather-key');
      expect(await settings.getWeatherApiKey(), 'super-secret-weather-key');
      expect(secure.values['weather_api_key'], 'super-secret-weather-key');
    });

    test('a saved news API key round-trips through secure storage', () async {
      await settings.setNewsApiKey('super-secret-news-key');
      expect(await settings.getNewsApiKey(), 'super-secret-news-key');
    });

    test('a saved Home Assistant token round-trips through secure storage', () async {
      await settings.setHomeAssistantToken('ha-token-xyz');
      expect(await settings.getHomeAssistantToken(), 'ha-token-xyz');
    });

    test('a saved AI HMAC secret round-trips through secure storage', () async {
      await settings.setAiHmacSecret('hmac-secret-123');
      expect(await settings.getAiHmacSecret(), 'hmac-secret-123');
    });

    test('AI HMAC secret defaults to null when never set', () async {
      expect(await settings.getAiHmacSecret(), isNull);
    });

    test('clearAiHmacSecret removes the stored value', () async {
      await settings.setAiHmacSecret('hmac-secret-123');
      await settings.clearAiHmacSecret();
      expect(await settings.getAiHmacSecret(), isNull);
    });
  });

  group('certificate pins', () {
    test('defaults to an empty list when never set', () async {
      expect(await settings.getCertPins(), isEmpty);
    });

    test('a saved pin list round-trips', () async {
      await settings.setCertPins(['pin-a', 'pin-b']);
      expect(await settings.getCertPins(), ['pin-a', 'pin-b']);
    });

    test('saving an empty list clears any previously saved pins', () async {
      await settings.setCertPins(['pin-a']);
      await settings.setCertPins([]);
      expect(await settings.getCertPins(), isEmpty);
    });
  });

  group('app lock PIN', () {
    test('hasAppLockPin is false until a PIN is set', () async {
      expect(await settings.hasAppLockPin(), isFalse);
      await settings.setAppLockPin('1234');
      expect(await settings.hasAppLockPin(), isTrue);
    });

    test('verifyAppLockPin returns true for the correct PIN', () async {
      await settings.setAppLockPin('1234');
      expect(await settings.verifyAppLockPin('1234'), isTrue);
    });

    test('verifyAppLockPin returns false for a wrong PIN', () async {
      await settings.setAppLockPin('1234');
      expect(await settings.verifyAppLockPin('0000'), isFalse);
    });

    test('verifyAppLockPin returns false when no PIN has ever been set', () async {
      expect(await settings.verifyAppLockPin('1234'), isFalse);
    });

    test('the PIN itself is never stored in plaintext, only a salted hash', () async {
      await settings.setAppLockPin('1234');
      // Neither the raw secure-storage backing map nor the plaintext
      // SharedPreferences prefs should contain the PIN string anywhere.
      expect(secure.values.values, isNot(contains('1234')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().map((k) => prefs.get(k)), isNot(contains('1234')));
    });

    test('setAppLockPin overwrites a previous PIN', () async {
      await settings.setAppLockPin('1234');
      await settings.setAppLockPin('5678');
      expect(await settings.verifyAppLockPin('1234'), isFalse);
      expect(await settings.verifyAppLockPin('5678'), isTrue);
    });

    test('clearAppLockPin removes the PIN entirely', () async {
      await settings.setAppLockPin('1234');
      await settings.clearAppLockPin();
      expect(await settings.hasAppLockPin(), isFalse);
      expect(await settings.verifyAppLockPin('1234'), isFalse);
    });
  });

  group('app lock credentials (username/password)', () {
    test('hasAppLockCredentials is false until credentials are set', () async {
      expect(await settings.hasAppLockCredentials(), isFalse);
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await settings.hasAppLockCredentials(), isTrue);
    });

    test('verifyAppLockCredentials returns true for the correct username and password', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAppLockCredentials('ibrahim', 'hunter2'), isTrue);
    });

    test('verifyAppLockCredentials returns false for a wrong password', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAppLockCredentials('ibrahim', 'wrong'), isFalse);
    });

    test('verifyAppLockCredentials returns false for a wrong username, even with the right password', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAppLockCredentials('someone-else', 'hunter2'), isFalse);
    });

    test('verifyAppLockCredentials returns false when no credentials have ever been set', () async {
      expect(await settings.verifyAppLockCredentials('ibrahim', 'hunter2'), isFalse);
    });

    test('the password itself is never stored in plaintext, only a salted hash', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(secure.values.values, isNot(contains('hunter2')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().map((k) => prefs.get(k)), isNot(contains('hunter2')));
    });

    test('the username is stored so it can be shown/prefilled', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await settings.getAppLockUsername(), 'ibrahim');
    });

    test('setAppLockCredentials overwrites previous credentials', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      await settings.setAppLockCredentials('ibrahim', 'newpassword');
      expect(await settings.verifyAppLockCredentials('ibrahim', 'hunter2'), isFalse);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'newpassword'), isTrue);
    });

    test('clearAppLockCredentials removes the credentials entirely', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      await settings.clearAppLockCredentials();
      expect(await settings.hasAppLockCredentials(), isFalse);
      expect(await settings.getAppLockUsername(), isNull);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'hunter2'), isFalse);
    });

    test('app lock credentials are independent of the app lock PIN', () async {
      await settings.setAppLockPin('1234');
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAppLockPin('hunter2'), isFalse);
      expect(await settings.verifyAppLockCredentials('ibrahim', '1234'), isFalse);
      expect(await settings.verifyAppLockPin('1234'), isTrue);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'hunter2'), isTrue);
    });

    test('app lock credentials are independent of the admin accounts', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'admin-secret', isOwner: true);
      await settings.setAppLockCredentials('ibrahim', 'applock-secret');
      expect(await settings.findMatchingAdminAccount('ibrahim', 'applock-secret'), isNull);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'admin-secret'), isFalse);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'admin-secret'), isNotNull);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'applock-secret'), isTrue);
    });
  });

  group('app lock lockout', () {
    test('failed attempts default to 0 and round-trip', () async {
      expect(await settings.getAppLockFailedAttempts(), 0);
      await settings.setAppLockFailedAttempts(3);
      expect(await settings.getAppLockFailedAttempts(), 3);
    });

    test('lockout-until defaults to null and round-trips', () async {
      expect(await settings.getAppLockLockoutUntil(), isNull);
      final until = DateTime(2026, 1, 1, 12, 30);
      await settings.setAppLockLockoutUntil(until);
      expect(await settings.getAppLockLockoutUntil(), until);
    });

    test('setting lockout-until to null clears it', () async {
      await settings.setAppLockLockoutUntil(DateTime(2026, 1, 1));
      await settings.setAppLockLockoutUntil(null);
      expect(await settings.getAppLockLockoutUntil(), isNull);
    });

    test('app lock lockout is independent of the admin lockout', () async {
      await settings.setAppLockFailedAttempts(5);
      expect(await settings.getAdminFailedAttempts(), 0);
    });
  });

  group('admin accounts', () {
    test('getAdminAccounts is empty until an account is added', () async {
      expect(await settings.getAdminAccounts(), isEmpty);
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      expect((await settings.getAdminAccounts()).map((a) => a.username), ['ibrahim']);
    });

    test('addAdminAccount rejects a case-insensitive duplicate username', () async {
      await settings.addAdminAccount(username: 'Ibrahim', password: 'hunter2', isOwner: true);
      final added = await settings.addAdminAccount(username: 'ibrahim', password: 'other', isOwner: false);
      expect(added, isFalse);
      expect((await settings.getAdminAccounts()).length, 1);
    });

    test('findMatchingAdminAccount is case-sensitive on username, returns the account on a match', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      final match = await settings.findMatchingAdminAccount('ibrahim', 'hunter2');
      expect(match?.username, 'ibrahim');
      expect(match?.isOwner, isTrue);
      expect(await settings.findMatchingAdminAccount('Ibrahim', 'hunter2'), isNull);
    });

    test('findMatchingAdminAccount returns null for a wrong password', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'wrong'), isNull);
    });

    test('findMatchingAdminAccount returns null for an unknown username', () async {
      expect(await settings.findMatchingAdminAccount('ibrahim', 'hunter2'), isNull);
    });

    test('passwords are never stored in plaintext, only a salted hash', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      expect(secure.values.values, isNot(contains('hunter2')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().map((k) => prefs.get(k)), isNot(contains('hunter2')));
    });

    test('multiple accounts (owner + helpers) coexist independently', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'owner-pw'), isNotNull);
      expect(await settings.findMatchingAdminAccount('helper1', 'helper-pw'), isNotNull);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'helper-pw'), isNull);
      final accounts = await settings.getAdminAccounts();
      expect(accounts.where((a) => a.isOwner).single.username, 'ibrahim');
      expect(accounts.where((a) => !a.isOwner).single.username, 'helper1');
    });

    test('removeAdminAccount removes only the targeted account, returns false if not found', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);
      expect(await settings.removeAdminAccount('helper1'), isTrue);
      expect((await settings.getAdminAccounts()).map((a) => a.username), ['ibrahim']);
      expect(await settings.removeAdminAccount('nobody'), isFalse);
    });

    test('updateAdminAccountPassword changes only that account, keeping its role', () async {
      await settings.addAdminAccount(username: 'helper1', password: 'old-pw', isOwner: false);
      final updated = await settings.updateAdminAccountPassword('helper1', 'new-pw');
      expect(updated, isTrue);
      expect(await settings.findMatchingAdminAccount('helper1', 'old-pw'), isNull);
      final account = await settings.findMatchingAdminAccount('helper1', 'new-pw');
      expect(account, isNotNull);
      expect(account!.isOwner, isFalse);
    });

    test('updateAdminAccountPassword returns false for an unknown username', () async {
      expect(await settings.updateAdminAccountPassword('nobody', 'new-pw'), isFalse);
    });

    // The pre-Runde-18 single-shared-account setters (setAdminCredentials/
    // setAdminPin/setAdminBiometricEnabled) no longer exist — these tests
    // simulate data that a real device could still have on disk from
    // before this migration existed by writing the legacy keys directly,
    // exactly as those old setters used to.
    Future<void> seedLegacyCredentials(String username, String password) async {
      final salt = base64Url.encode(List<int>.filled(16, 7));
      final hash = sha256.convert(utf8.encode('$salt:$password')).toString();
      secure.values['admin_password_salt'] = salt;
      secure.values['admin_password_hash'] = hash;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_username', username);
    }

    Future<void> seedLegacyPin(String pin) async {
      final salt = base64Url.encode(List<int>.filled(16, 3));
      final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
      secure.values['admin_pin_salt'] = salt;
      secure.values['admin_pin_hash'] = hash;
    }

    test('a legacy single shared admin account is migrated into a new owner account', () async {
      await seedLegacyCredentials('legacy-user', 'legacy-pw');
      final accounts = await settings.getAdminAccounts();
      expect(accounts.length, 1);
      expect(accounts.single.username, 'legacy-user');
      expect(accounts.single.isOwner, isTrue);
      expect(await settings.findMatchingAdminAccount('legacy-user', 'legacy-pw'), isNotNull);
    });

    test('migration clears the legacy PIN/credentials/biometric keys afterwards', () async {
      await seedLegacyPin('1234');
      await seedLegacyCredentials('legacy-user', 'legacy-pw');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('admin_biometric_enabled', true);

      await settings.getAdminAccounts(); // triggers the one-time migration

      expect(secure.values.containsKey('admin_pin_salt'), isFalse);
      expect(secure.values.containsKey('admin_pin_hash'), isFalse);
      expect(secure.values.containsKey('admin_password_salt'), isFalse);
      expect(secure.values.containsKey('admin_password_hash'), isFalse);
      expect(prefs.containsKey('admin_username'), isFalse);
      expect(prefs.containsKey('admin_biometric_enabled'), isFalse);
    });

    test('a PIN-only legacy setup (no username/password) has no migration path and starts empty', () async {
      await seedLegacyPin('1234');
      expect(await settings.getAdminAccounts(), isEmpty);
    });

    test('admin accounts are independent of the emergency-lock accounts', () async {
      await settings.setAppLockCredentials('ibrahim', 'app-lock-pw');
      await settings.addAdminAccount(username: 'ibrahim', password: 'admin-pw', isOwner: true);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'admin-pw'), isFalse);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'app-lock-pw'), isNull);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'app-lock-pw'), isTrue);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'admin-pw'), isNotNull);
    });
  });

  group('admin lockout', () {
    test('failed attempts default to 0 and round-trip', () async {
      expect(await settings.getAdminFailedAttempts(), 0);
      await settings.setAdminFailedAttempts(3);
      expect(await settings.getAdminFailedAttempts(), 3);
    });

    test('lockout-until defaults to null and round-trips', () async {
      expect(await settings.getAdminLockoutUntil(), isNull);
      final until = DateTime(2026, 1, 1, 12, 30);
      await settings.setAdminLockoutUntil(until);
      expect(await settings.getAdminLockoutUntil(), until);
    });

    test('setting lockout-until to null clears it', () async {
      await settings.setAdminLockoutUntil(DateTime(2026, 1, 1));
      await settings.setAdminLockoutUntil(null);
      expect(await settings.getAdminLockoutUntil(), isNull);
    });
  });

  group('system prompt override & temperature', () {
    test('system prompt override defaults to null and round-trips', () async {
      expect(await settings.getSystemPromptOverride(), isNull);
      await settings.setSystemPromptOverride('Du bist ein Pirat.');
      expect(await settings.getSystemPromptOverride(), 'Du bist ein Pirat.');
    });

    test('clearSystemPromptOverride removes a saved override', () async {
      await settings.setSystemPromptOverride('Du bist ein Pirat.');
      await settings.clearSystemPromptOverride();
      expect(await settings.getSystemPromptOverride(), isNull);
    });

    test('AI temperature defaults to 0.3 and round-trips', () async {
      expect(await settings.getAiTemperature(), 0.3);
      await settings.setAiTemperature(0.9);
      expect(await settings.getAiTemperature(), 0.9);
    });

    test('max history turns defaults to 8 and round-trips', () async {
      expect(await settings.getMaxHistoryTurns(), 8);
      await settings.setMaxHistoryTurns(4);
      expect(await settings.getMaxHistoryTurns(), 4);
    });

    test('AI model tier defaults to smart and round-trips', () async {
      expect(await settings.getAiModelTier(), 'smart');
      await settings.setAiModelTier('fast');
      expect(await settings.getAiModelTier(), 'fast');
    });

    test('theme variant defaults to gold and round-trips', () async {
      expect(await settings.getThemeVariant(), ThemeVariant.gold);
      await settings.setThemeVariant(ThemeVariant.cyan);
      expect(await settings.getThemeVariant(), ThemeVariant.cyan);
      await settings.setThemeVariant(ThemeVariant.gold);
      expect(await settings.getThemeVariant(), ThemeVariant.gold);
    });

    test('force-local-AI toggle defaults to false and round-trips', () async {
      expect(await settings.getForceLocalAiEnabled(), isFalse);
      await settings.setForceLocalAiEnabled(true);
      expect(await settings.getForceLocalAiEnabled(), isTrue);
    });

    test('Discord-webhook placeholder toggle defaults to false and round-trips', () async {
      expect(await settings.getDiscordWebhookEnabled(), isFalse);
      await settings.setDiscordWebhookEnabled(true);
      expect(await settings.getDiscordWebhookEnabled(), isTrue);
    });

    test('AI request count starts at 0 and increments on each record', () async {
      final today = DateTime(2026, 8, 31);
      expect(await settings.getAiRequestCountToday(now: today), 0);
      await settings.recordAiRequestToday(now: today);
      await settings.recordAiRequestToday(now: today);
      expect(await settings.getAiRequestCountToday(now: today), 2);
    });

    test('the request count resets on a new day', () async {
      final day1 = DateTime(2026, 8, 31);
      final day2 = DateTime(2026, 9, 1);
      await settings.recordAiRequestToday(now: day1);
      await settings.recordAiRequestToday(now: day1);
      expect(await settings.getAiRequestCountToday(now: day2), 0);
      await settings.recordAiRequestToday(now: day2);
      expect(await settings.getAiRequestCountToday(now: day2), 1);
    });
  });

  group('legacy plaintext migration', () {
    test('an existing plaintext weather key is migrated into secure storage on first read', () async {
      SharedPreferences.setMockInitialValues({'weather_api_key': 'legacy-plaintext-key'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('weather_api_key'), 'legacy-plaintext-key');

      final migrated = await settings.getWeatherApiKey();
      expect(migrated, 'legacy-plaintext-key');
      // Now living in secure storage...
      expect(secure.values['weather_api_key'], 'legacy-plaintext-key');
      // ...and removed from the plaintext file.
      expect(prefs.getString('weather_api_key'), isNull);
    });

    test('overwriting a value removes any lingering legacy plaintext copy', () async {
      SharedPreferences.setMockInitialValues({'home_assistant_token': 'old-plaintext-token'});
      await settings.setHomeAssistantToken('new-secure-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('home_assistant_token'), isNull);
      expect(await settings.getHomeAssistantToken(), 'new-secure-token');
    });
  });

  group('installId', () {
    test('generates a value and returns the same one on every later call', () async {
      final first = await settings.getInstallId();
      expect(first, isNotEmpty);
      expect(await settings.getInstallId(), first);
    });

    test('two different SettingsService instances over the same storage agree once generated', () async {
      final id = await settings.getInstallId();
      final other = SettingsService(secureStorage: secure);
      expect(await other.getInstallId(), id);
    });
  });

  group('crash reporting toggle', () {
    test('defaults to enabled', () async {
      expect(await settings.getCrashReportingEnabled(), isTrue);
    });

    test('can be disabled and re-enabled', () async {
      await settings.setCrashReportingEnabled(false);
      expect(await settings.getCrashReportingEnabled(), isFalse);
      await settings.setCrashReportingEnabled(true);
      expect(await settings.getCrashReportingEnabled(), isTrue);
    });
  });

  group('telemetry backend URL', () {
    test('defaults to the same Worker URL as getAiBackendUrl', () async {
      expect(await settings.getTelemetryBackendUrl(), await settings.getAiBackendUrl());
    });

    test('can be overridden independently of the AI backend URL', () async {
      await settings.setTelemetryBackendUrl('https://my-own-telemetry.example');
      expect(await settings.getTelemetryBackendUrl(), 'https://my-own-telemetry.example');
      expect(await settings.getAiBackendUrl(), isNot('https://my-own-telemetry.example'));
    });
  });

  group('admin API key (secure storage)', () {
    test('round-trips through secure storage', () async {
      await settings.setAdminApiKey('top-secret-admin-key');
      expect(await settings.getAdminApiKey(), 'top-secret-admin-key');
      expect(secure.values['admin_api_key'], 'top-secret-admin-key');
    });

    test('is null before ever being set', () async {
      expect(await settings.getAdminApiKey(), isNull);
    });

    test('clearAdminApiKey removes it', () async {
      await settings.setAdminApiKey('will-be-cleared');
      await settings.clearAdminApiKey();
      expect(await settings.getAdminApiKey(), isNull);
    });
  });
}
