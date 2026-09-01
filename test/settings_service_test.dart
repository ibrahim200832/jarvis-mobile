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

    test('app lock credentials are independent of the admin credentials', () async {
      await settings.setAdminCredentials('ibrahim', 'admin-secret');
      await settings.setAppLockCredentials('ibrahim', 'applock-secret');
      expect(await settings.verifyAdminCredentials('ibrahim', 'applock-secret'), isFalse);
      expect(await settings.verifyAppLockCredentials('ibrahim', 'admin-secret'), isFalse);
      expect(await settings.verifyAdminCredentials('ibrahim', 'admin-secret'), isTrue);
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

  group('admin PIN', () {
    test('hasAdminPin is false until a PIN is set', () async {
      expect(await settings.hasAdminPin(), isFalse);
      await settings.setAdminPin('1234');
      expect(await settings.hasAdminPin(), isTrue);
    });

    test('verifyAdminPin returns true for the correct PIN', () async {
      await settings.setAdminPin('1234');
      expect(await settings.verifyAdminPin('1234'), isTrue);
    });

    test('verifyAdminPin returns false for a wrong PIN', () async {
      await settings.setAdminPin('1234');
      expect(await settings.verifyAdminPin('0000'), isFalse);
    });

    test('verifyAdminPin returns false when no PIN has ever been set', () async {
      expect(await settings.verifyAdminPin('1234'), isFalse);
    });

    test('the PIN itself is never stored in plaintext, only a salted hash', () async {
      await settings.setAdminPin('1234');
      expect(secure.values.values, isNot(contains('1234')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().map((k) => prefs.get(k)), isNot(contains('1234')));
    });

    test('setAdminPin overwrites a previous PIN', () async {
      await settings.setAdminPin('1234');
      await settings.setAdminPin('5678');
      expect(await settings.verifyAdminPin('1234'), isFalse);
      expect(await settings.verifyAdminPin('5678'), isTrue);
    });

    test('clearAdminPin removes the PIN entirely', () async {
      await settings.setAdminPin('1234');
      await settings.clearAdminPin();
      expect(await settings.hasAdminPin(), isFalse);
      expect(await settings.verifyAdminPin('1234'), isFalse);
    });

    test('the admin PIN is independent of the emergency-lock PIN', () async {
      await settings.setAppLockPin('1111');
      await settings.setAdminPin('2222');
      expect(await settings.verifyAppLockPin('2222'), isFalse);
      expect(await settings.verifyAdminPin('1111'), isFalse);
      expect(await settings.verifyAppLockPin('1111'), isTrue);
      expect(await settings.verifyAdminPin('2222'), isTrue);
    });

    test('admin biometric toggle defaults to false and round-trips', () async {
      expect(await settings.getAdminBiometricEnabled(), isFalse);
      await settings.setAdminBiometricEnabled(true);
      expect(await settings.getAdminBiometricEnabled(), isTrue);
    });
  });

  group('admin credentials (username/password)', () {
    test('hasAdminCredentials is false until credentials are set', () async {
      expect(await settings.hasAdminCredentials(), isFalse);
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(await settings.hasAdminCredentials(), isTrue);
    });

    test('verifyAdminCredentials returns true for the correct username and password', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAdminCredentials('ibrahim', 'hunter2'), isTrue);
    });

    test('verifyAdminCredentials returns false for a wrong password', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAdminCredentials('ibrahim', 'wrong'), isFalse);
    });

    test('verifyAdminCredentials returns false for a wrong username, even with the right password', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAdminCredentials('someone-else', 'hunter2'), isFalse);
    });

    test('verifyAdminCredentials returns false when no credentials have ever been set', () async {
      expect(await settings.verifyAdminCredentials('ibrahim', 'hunter2'), isFalse);
    });

    test('the password itself is never stored in plaintext, only a salted hash', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(secure.values.values, isNot(contains('hunter2')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().map((k) => prefs.get(k)), isNot(contains('hunter2')));
    });

    test('the username is stored so it can be shown/prefilled', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(await settings.getAdminUsername(), 'ibrahim');
    });

    test('setAdminCredentials overwrites previous credentials', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      await settings.setAdminCredentials('ibrahim', 'newpassword');
      expect(await settings.verifyAdminCredentials('ibrahim', 'hunter2'), isFalse);
      expect(await settings.verifyAdminCredentials('ibrahim', 'newpassword'), isTrue);
    });

    test('clearAdminCredentials removes the credentials entirely', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      await settings.clearAdminCredentials();
      expect(await settings.hasAdminCredentials(), isFalse);
      expect(await settings.getAdminUsername(), isNull);
      expect(await settings.verifyAdminCredentials('ibrahim', 'hunter2'), isFalse);
    });

    test('admin credentials are independent of the admin PIN', () async {
      await settings.setAdminPin('1234');
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(await settings.verifyAdminPin('hunter2'), isFalse);
      expect(await settings.verifyAdminCredentials('ibrahim', '1234'), isFalse);
      expect(await settings.verifyAdminPin('1234'), isTrue);
      expect(await settings.verifyAdminCredentials('ibrahim', 'hunter2'), isTrue);
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
}
