import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
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
