import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/admin_auth_service.dart';
import 'package:jarvis_mobile/services/log_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for flutter_secure_storage, same fake as
/// app_lock_service_test.dart/settings_service_test.dart.
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
  late Directory tempDir;
  late SettingsService settings;
  late LogService log;
  late AdminAuthService adminAuth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('jarvis_admin_auth_test_');
    settings = SettingsService(secureStorage: _FakeSecureStorageService());
    log = LogService(directoryOverride: tempDir);
    adminAuth = AdminAuthService(settings: settings, log: log);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('isUnlockedThisSession is false by default', () {
    expect(adminAuth.isUnlockedThisSession, isFalse);
  });

  test('unlock() with the correct PIN sets isUnlockedThisSession and returns true', () async {
    await settings.setAdminPin('1234');

    final result = await adminAuth.unlock('1234');

    expect(result, isTrue);
    expect(adminAuth.isUnlockedThisSession, isTrue);
  });

  test('unlock() with a wrong PIN leaves isUnlockedThisSession false and returns false', () async {
    await settings.setAdminPin('1234');

    final result = await adminAuth.unlock('0000');

    expect(result, isFalse);
    expect(adminAuth.isUnlockedThisSession, isFalse);
  });

  test('unlock() with no PIN configured always returns false', () async {
    final result = await adminAuth.unlock('anything');
    expect(result, isFalse);
    expect(adminAuth.isUnlockedThisSession, isFalse);
  });

  test('hasPinConfigured reflects SettingsService.hasAdminPin', () async {
    expect(await adminAuth.hasPinConfigured(), isFalse);
    await settings.setAdminPin('1234');
    expect(await adminAuth.hasPinConfigured(), isTrue);
  });

  test('unlockViaBiometrics() sets isUnlockedThisSession without a PIN check', () async {
    await adminAuth.unlockViaBiometrics();
    expect(adminAuth.isUnlockedThisSession, isTrue);
  });

  test('lockSession() clears an unlocked session', () async {
    await settings.setAdminPin('1234');
    await adminAuth.unlock('1234');
    expect(adminAuth.isUnlockedThisSession, isTrue);

    adminAuth.lockSession();

    expect(adminAuth.isUnlockedThisSession, isFalse);
  });

  test('a separate AdminAuthService instance does not inherit an unlocked session', () async {
    await settings.setAdminPin('1234');
    await adminAuth.unlock('1234');

    final freshInstance = AdminAuthService(settings: settings, log: log);

    expect(freshInstance.isUnlockedThisSession, isFalse);
  });

  group('login() (username/password)', () {
    test('with correct credentials sets isUnlockedThisSession and returns true', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');

      final result = await adminAuth.login('ibrahim', 'hunter2');

      expect(result, isTrue);
      expect(adminAuth.isUnlockedThisSession, isTrue);
    });

    test('with a wrong password leaves isUnlockedThisSession false and returns false', () async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');

      final result = await adminAuth.login('ibrahim', 'wrong');

      expect(result, isFalse);
      expect(adminAuth.isUnlockedThisSession, isFalse);
    });

    test('with no credentials configured always returns false', () async {
      final result = await adminAuth.login('ibrahim', 'anything');
      expect(result, isFalse);
    });

    test('hasPasswordConfigured reflects SettingsService.hasAdminCredentials', () async {
      expect(await adminAuth.hasPasswordConfigured(), isFalse);
      await settings.setAdminCredentials('ibrahim', 'hunter2');
      expect(await adminAuth.hasPasswordConfigured(), isTrue);
    });
  });

  group('shared failed-attempt lockout', () {
    final now = DateTime(2026, 1, 1, 12, 0);

    test('remainingLockout is null with no failed attempts', () async {
      expect(await adminAuth.remainingLockout(now: now), isNull);
    });

    test('locks out after maxFailedAttempts wrong PIN attempts', () async {
      await settings.setAdminPin('1234');
      for (var i = 0; i < AdminAuthService.maxFailedAttempts; i++) {
        await adminAuth.unlock('wrong', now: now);
      }

      expect(await adminAuth.remainingLockout(now: now), isNotNull);
      // Even the correct PIN is rejected without even being checked while locked out.
      expect(await adminAuth.unlock('1234', now: now), isFalse);
    });

    test('mixing PIN and password wrong attempts shares the same counter', () async {
      await settings.setAdminPin('1234');
      await settings.setAdminCredentials('ibrahim', 'hunter2');

      await adminAuth.unlock('wrong', now: now);
      await adminAuth.login('ibrahim', 'wrong', now: now);
      await adminAuth.unlock('wrong', now: now);
      await adminAuth.login('ibrahim', 'wrong', now: now);
      await adminAuth.unlock('wrong', now: now);

      expect(await adminAuth.remainingLockout(now: now), isNotNull);
      // Switching credential type doesn't bypass the lockout either.
      expect(await adminAuth.login('ibrahim', 'hunter2', now: now), isFalse);
    });

    test('lockout expires after lockoutDuration', () async {
      await settings.setAdminPin('1234');
      for (var i = 0; i < AdminAuthService.maxFailedAttempts; i++) {
        await adminAuth.unlock('wrong', now: now);
      }
      expect(await adminAuth.remainingLockout(now: now), isNotNull);

      final afterLockout = now.add(AdminAuthService.lockoutDuration).add(const Duration(seconds: 1));

      expect(await adminAuth.remainingLockout(now: afterLockout), isNull);
      expect(await adminAuth.unlock('1234', now: afterLockout), isTrue);
    });

    test('a successful login resets the failed-attempt counter', () async {
      await settings.setAdminPin('1234');
      await adminAuth.unlock('wrong', now: now);
      await adminAuth.unlock('wrong', now: now);
      await adminAuth.unlock('1234', now: now);

      // Two more wrong attempts after the reset shouldn't be enough to lock out.
      await adminAuth.unlock('wrong', now: now);
      await adminAuth.unlock('wrong', now: now);
      expect(await adminAuth.remainingLockout(now: now), isNull);
    });

    test('biometric unlock bypasses the lockout entirely', () async {
      await settings.setAdminPin('1234');
      for (var i = 0; i < AdminAuthService.maxFailedAttempts; i++) {
        await adminAuth.unlock('wrong', now: now);
      }
      expect(await adminAuth.remainingLockout(now: now), isNotNull);

      await adminAuth.unlockViaBiometrics();

      expect(adminAuth.isUnlockedThisSession, isTrue);
    });
  });

  group('recentSuccessfulLogins', () {
    test('is empty with no logins yet', () async {
      expect(await adminAuth.recentSuccessfulLogins(), isEmpty);
    });

    test('includes successful PIN/password/biometric logins, newest first, but not failures', () async {
      await settings.setAdminPin('1234');
      await settings.setAdminCredentials('ibrahim', 'hunter2');

      await adminAuth.unlock('wrong'); // failure, must not appear
      await adminAuth.unlock('1234');
      await adminAuth.login('ibrahim', 'hunter2');
      await adminAuth.unlockViaBiometrics();

      final logins = await adminAuth.recentSuccessfulLogins();

      expect(logins.length, 3);
      expect(logins[0].message, contains('Biometrie'));
      expect(logins[1].message, contains('Passwort'));
      expect(logins[2].message, contains('PIN'));
    });

    test('respects the limit parameter', () async {
      await settings.setAdminPin('1234');
      for (var i = 0; i < 5; i++) {
        await adminAuth.unlock('1234');
      }

      expect(await adminAuth.recentSuccessfulLogins(limit: 2), hasLength(2));
    });
  });

  group('idle timeout / auto-logout', () {
    test('recordActivity() starts a timer that locks the session and fires onIdleTimeout', () async {
      final shortTimeoutAuth = AdminAuthService(
        settings: settings,
        log: log,
        idleTimeout: const Duration(milliseconds: 20),
      );
      var fired = false;
      shortTimeoutAuth.onIdleTimeout = () => fired = true;
      await settings.setAdminPin('1234');
      await shortTimeoutAuth.unlock('1234');
      shortTimeoutAuth.recordActivity();

      await Future.delayed(const Duration(milliseconds: 60));

      expect(fired, isTrue);
      expect(shortTimeoutAuth.isUnlockedThisSession, isFalse);
    });

    test('recordActivity() called again resets the countdown', () async {
      final shortTimeoutAuth = AdminAuthService(
        settings: settings,
        log: log,
        idleTimeout: const Duration(milliseconds: 40),
      );
      var fired = false;
      shortTimeoutAuth.onIdleTimeout = () => fired = true;
      await settings.setAdminPin('1234');
      await shortTimeoutAuth.unlock('1234');
      shortTimeoutAuth.recordActivity();

      await Future.delayed(const Duration(milliseconds: 20));
      shortTimeoutAuth.recordActivity(); // resets before the first 40ms window elapses
      await Future.delayed(const Duration(milliseconds: 20));

      expect(fired, isFalse);
      expect(shortTimeoutAuth.isUnlockedThisSession, isTrue);

      shortTimeoutAuth.stopIdleTimeout();
    });

    test('stopIdleTimeout() prevents the callback from firing', () async {
      final shortTimeoutAuth = AdminAuthService(
        settings: settings,
        log: log,
        idleTimeout: const Duration(milliseconds: 20),
      );
      var fired = false;
      shortTimeoutAuth.onIdleTimeout = () => fired = true;
      shortTimeoutAuth.recordActivity();

      shortTimeoutAuth.stopIdleTimeout();
      await Future.delayed(const Duration(milliseconds: 60));

      expect(fired, isFalse);
    });
  });
}
