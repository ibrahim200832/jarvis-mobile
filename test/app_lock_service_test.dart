import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/app_lock_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for flutter_secure_storage, same fake as
/// settings_service_test.dart/command_router_test.dart — a real
/// SettingsService() would hit the actual (unmocked) platform channel here.
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
  late SettingsService settings;
  late AppLockService appLock;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(secureStorage: _FakeSecureStorageService());
    appLock = AppLockService(settings: settings);
  });

  test('isLocked is false by default', () async {
    expect(await appLock.isLocked(), isFalse);
  });

  test('lock() sets the locked state', () async {
    await appLock.lock();
    expect(await appLock.isLocked(), isTrue);
  });

  test('unlock() with the correct PIN clears the locked state and returns true', () async {
    await settings.setAppLockPin('1234');
    await appLock.lock();

    final result = await appLock.unlock('1234');

    expect(result, isTrue);
    expect(await appLock.isLocked(), isFalse);
  });

  test('unlock() with a wrong PIN leaves the locked state untouched and returns false', () async {
    await settings.setAppLockPin('1234');
    await appLock.lock();

    final result = await appLock.unlock('0000');

    expect(result, isFalse);
    expect(await appLock.isLocked(), isTrue);
  });

  test('unlock() with no PIN configured always returns false', () async {
    await appLock.lock();
    final result = await appLock.unlock('anything');
    expect(result, isFalse);
    expect(await appLock.isLocked(), isTrue);
  });

  test('hasPinConfigured reflects SettingsService.hasAppLockPin', () async {
    expect(await appLock.hasPinConfigured(), isFalse);
    await settings.setAppLockPin('1234');
    expect(await appLock.hasPinConfigured(), isTrue);
  });

  group('login() (username/password)', () {
    test('with correct credentials clears the locked state and returns true', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      await appLock.lock();

      final result = await appLock.login('ibrahim', 'hunter2');

      expect(result, isTrue);
      expect(await appLock.isLocked(), isFalse);
    });

    test('with a wrong password leaves the locked state untouched and returns false', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      await appLock.lock();

      final result = await appLock.login('ibrahim', 'wrong');

      expect(result, isFalse);
      expect(await appLock.isLocked(), isTrue);
    });

    test('with no credentials configured always returns false', () async {
      final result = await appLock.login('ibrahim', 'anything');
      expect(result, isFalse);
    });

    test('hasPasswordConfigured reflects SettingsService.hasAppLockCredentials', () async {
      expect(await appLock.hasPasswordConfigured(), isFalse);
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await appLock.hasPasswordConfigured(), isTrue);
    });
  });

  group('hasAnyLockMethodConfigured', () {
    test('is false when neither a PIN nor credentials are configured', () async {
      expect(await appLock.hasAnyLockMethodConfigured(), isFalse);
    });

    test('is true with only a PIN configured', () async {
      await settings.setAppLockPin('1234');
      expect(await appLock.hasAnyLockMethodConfigured(), isTrue);
    });

    test('is true with only credentials configured', () async {
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await appLock.hasAnyLockMethodConfigured(), isTrue);
    });

    test('is true with both configured', () async {
      await settings.setAppLockPin('1234');
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      expect(await appLock.hasAnyLockMethodConfigured(), isTrue);
    });
  });

  group('shared failed-attempt lockout', () {
    final now = DateTime(2026, 1, 1, 12, 0);

    test('remainingLockout is null with no failed attempts', () async {
      expect(await appLock.remainingLockout(now: now), isNull);
    });

    test('locks out after maxFailedAttempts wrong PIN attempts', () async {
      await settings.setAppLockPin('1234');
      for (var i = 0; i < AppLockService.maxFailedAttempts; i++) {
        await appLock.unlock('wrong', now: now);
      }

      expect(await appLock.remainingLockout(now: now), isNotNull);
      // Even the correct PIN is rejected without even being checked while locked out.
      expect(await appLock.unlock('1234', now: now), isFalse);
    });

    test('mixing PIN and password wrong attempts shares the same counter', () async {
      await settings.setAppLockPin('1234');
      await settings.setAppLockCredentials('ibrahim', 'hunter2');

      await appLock.unlock('wrong', now: now);
      await appLock.login('ibrahim', 'wrong', now: now);
      await appLock.unlock('wrong', now: now);
      await appLock.login('ibrahim', 'wrong', now: now);
      await appLock.unlock('wrong', now: now);

      expect(await appLock.remainingLockout(now: now), isNotNull);
      // Switching credential type doesn't bypass the lockout either.
      expect(await appLock.login('ibrahim', 'hunter2', now: now), isFalse);
    });

    test('lockout expires after lockoutDuration', () async {
      await settings.setAppLockPin('1234');
      for (var i = 0; i < AppLockService.maxFailedAttempts; i++) {
        await appLock.unlock('wrong', now: now);
      }
      expect(await appLock.remainingLockout(now: now), isNotNull);

      final afterLockout = now.add(AppLockService.lockoutDuration).add(const Duration(seconds: 1));

      expect(await appLock.remainingLockout(now: afterLockout), isNull);
      expect(await appLock.unlock('1234', now: afterLockout), isTrue);
    });

    test('a successful unlock resets the failed-attempt counter', () async {
      await settings.setAppLockPin('1234');
      await appLock.lock();
      await appLock.unlock('wrong', now: now);
      await appLock.unlock('wrong', now: now);
      await appLock.unlock('1234', now: now);

      // Two more wrong attempts after the reset shouldn't be enough to lock out.
      await appLock.unlock('wrong', now: now);
      await appLock.unlock('wrong', now: now);
      expect(await appLock.remainingLockout(now: now), isNull);
    });

    test('lockout is checked before verifying credentials, not just the PIN', () async {
      await settings.setAppLockPin('1234');
      await settings.setAppLockCredentials('ibrahim', 'hunter2');
      for (var i = 0; i < AppLockService.maxFailedAttempts; i++) {
        await appLock.unlock('wrong', now: now);
      }

      expect(await appLock.login('ibrahim', 'hunter2', now: now), isFalse);
    });
  });
}
