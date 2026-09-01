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

  test('lockSession() clears an unlocked session', () async {
    await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
    await adminAuth.login('ibrahim', 'hunter2');
    expect(adminAuth.isUnlockedThisSession, isTrue);

    adminAuth.lockSession();

    expect(adminAuth.isUnlockedThisSession, isFalse);
  });

  test('a separate AdminAuthService instance does not inherit an unlocked session', () async {
    await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
    await adminAuth.login('ibrahim', 'hunter2');

    final freshInstance = AdminAuthService(settings: settings, log: log);

    expect(freshInstance.isUnlockedThisSession, isFalse);
  });

  group('login()', () {
    test('with correct credentials sets isUnlockedThisSession, currentAccount and returns true', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);

      final result = await adminAuth.login('ibrahim', 'hunter2');

      expect(result, isTrue);
      expect(adminAuth.isUnlockedThisSession, isTrue);
      expect(adminAuth.currentAccount?.username, 'ibrahim');
    });

    test('with a wrong password leaves isUnlockedThisSession false and returns false', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);

      final result = await adminAuth.login('ibrahim', 'wrong');

      expect(result, isFalse);
      expect(adminAuth.isUnlockedThisSession, isFalse);
    });

    test('with no accounts configured always returns false', () async {
      final result = await adminAuth.login('ibrahim', 'anything');
      expect(result, isFalse);
    });

    test('isOwner reflects the logged-in account\'s role', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);

      await adminAuth.login('helper1', 'helper-pw');
      expect(adminAuth.isOwner, isFalse);

      adminAuth.lockSession();
      await adminAuth.login('ibrahim', 'owner-pw');
      expect(adminAuth.isOwner, isTrue);
    });

    test('isOwner is false when nobody is logged in', () {
      expect(adminAuth.isOwner, isFalse);
    });
  });

  group('account management (owner-only)', () {
    test('addHelperAccount succeeds when the current session is the owner', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await adminAuth.login('ibrahim', 'owner-pw');

      final added = await adminAuth.addHelperAccount('helper1', 'helper-pw');

      expect(added, isTrue);
      final accounts = await settings.getAdminAccounts();
      expect(accounts.where((a) => a.username == 'helper1').single.isOwner, isFalse);
    });

    test('addHelperAccount fails when the current session is a helper', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);
      await adminAuth.login('helper1', 'helper-pw');

      final added = await adminAuth.addHelperAccount('helper2', 'pw');

      expect(added, isFalse);
      expect((await settings.getAdminAccounts()).any((a) => a.username == 'helper2'), isFalse);
    });

    test('addHelperAccount fails when nobody is logged in', () async {
      final added = await adminAuth.addHelperAccount('helper1', 'pw');
      expect(added, isFalse);
    });

    test('removeAccount succeeds for a helper when the current session is the owner', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);
      await adminAuth.login('ibrahim', 'owner-pw');

      final removed = await adminAuth.removeAccount('helper1');

      expect(removed, isTrue);
      expect((await settings.getAdminAccounts()).any((a) => a.username == 'helper1'), isFalse);
    });

    test('removeAccount fails when the current session is a helper', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);
      await adminAuth.login('helper1', 'helper-pw');

      final removed = await adminAuth.removeAccount('ibrahim');

      expect(removed, isFalse);
      expect((await settings.getAdminAccounts()).any((a) => a.username == 'ibrahim'), isTrue);
    });

    test('removeAccount refuses to remove the owner account, even when logged in as owner', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await adminAuth.login('ibrahim', 'owner-pw');

      final removed = await adminAuth.removeAccount('ibrahim');

      expect(removed, isFalse);
      expect((await settings.getAdminAccounts()).any((a) => a.username == 'ibrahim'), isTrue);
    });
  });

  group('changeOwnPassword', () {
    test('succeeds with the correct current password and updates currentAccount', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'old-pw', isOwner: true);
      await adminAuth.login('ibrahim', 'old-pw');

      final result = await adminAuth.changeOwnPassword('old-pw', 'new-pw');

      expect(result, isTrue);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'old-pw'), isNull);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'new-pw'), isNotNull);
      expect(adminAuth.currentAccount?.username, 'ibrahim');
    });

    test('fails with the wrong current password, leaving the password unchanged', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'old-pw', isOwner: true);
      await adminAuth.login('ibrahim', 'old-pw');

      final result = await adminAuth.changeOwnPassword('wrong', 'new-pw');

      expect(result, isFalse);
      expect(await settings.findMatchingAdminAccount('ibrahim', 'old-pw'), isNotNull);
    });

    test('fails when nobody is logged in', () async {
      final result = await adminAuth.changeOwnPassword('anything', 'new-pw');
      expect(result, isFalse);
    });

    test('a helper can change their own password too, not just the owner', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'owner-pw', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'old-pw', isOwner: false);
      await adminAuth.login('helper1', 'old-pw');

      final result = await adminAuth.changeOwnPassword('old-pw', 'new-pw');

      expect(result, isTrue);
      expect(await settings.findMatchingAdminAccount('helper1', 'new-pw'), isNotNull);
    });
  });

  group('shared failed-attempt lockout', () {
    final now = DateTime(2026, 1, 1, 12, 0);

    test('remainingLockout is null with no failed attempts', () async {
      expect(await adminAuth.remainingLockout(now: now), isNull);
    });

    test('locks out after maxFailedAttempts wrong login attempts', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      for (var i = 0; i < AdminAuthService.maxFailedAttempts; i++) {
        await adminAuth.login('ibrahim', 'wrong', now: now);
      }

      expect(await adminAuth.remainingLockout(now: now), isNotNull);
      // Even the correct password is rejected without even being checked while locked out.
      expect(await adminAuth.login('ibrahim', 'hunter2', now: now), isFalse);
    });

    test('wrong attempts across different usernames share the same counter', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);

      await adminAuth.login('ibrahim', 'wrong', now: now);
      await adminAuth.login('helper1', 'wrong', now: now);
      await adminAuth.login('ibrahim', 'wrong', now: now);
      await adminAuth.login('helper1', 'wrong', now: now);
      await adminAuth.login('ibrahim', 'wrong', now: now);

      expect(await adminAuth.remainingLockout(now: now), isNotNull);
      // Switching which username is being guessed doesn't bypass the lockout either.
      expect(await adminAuth.login('helper1', 'helper-pw', now: now), isFalse);
    });

    test('lockout expires after lockoutDuration', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      for (var i = 0; i < AdminAuthService.maxFailedAttempts; i++) {
        await adminAuth.login('ibrahim', 'wrong', now: now);
      }
      expect(await adminAuth.remainingLockout(now: now), isNotNull);

      final afterLockout = now.add(AdminAuthService.lockoutDuration).add(const Duration(seconds: 1));

      expect(await adminAuth.remainingLockout(now: afterLockout), isNull);
      expect(await adminAuth.login('ibrahim', 'hunter2', now: afterLockout), isTrue);
    });

    test('a successful login resets the failed-attempt counter', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      await adminAuth.login('ibrahim', 'wrong', now: now);
      await adminAuth.login('ibrahim', 'wrong', now: now);
      await adminAuth.login('ibrahim', 'hunter2', now: now);

      // Two more wrong attempts after the reset shouldn't be enough to lock out.
      await adminAuth.login('ibrahim', 'wrong', now: now);
      await adminAuth.login('ibrahim', 'wrong', now: now);
      expect(await adminAuth.remainingLockout(now: now), isNull);
    });
  });

  group('recentSuccessfulLogins', () {
    test('is empty with no logins yet', () async {
      expect(await adminAuth.recentSuccessfulLogins(), isEmpty);
    });

    test('includes successful logins with the real username, newest first, but not failures', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      await settings.addAdminAccount(username: 'helper1', password: 'helper-pw', isOwner: false);

      await adminAuth.login('ibrahim', 'wrong'); // failure, must not appear
      await adminAuth.login('ibrahim', 'hunter2');
      adminAuth.lockSession();
      await adminAuth.login('helper1', 'helper-pw');

      final logins = await adminAuth.recentSuccessfulLogins();

      expect(logins.length, 2);
      expect(logins[0].message, contains('helper1'));
      expect(logins[1].message, contains('ibrahim'));
    });

    test('respects the limit parameter', () async {
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      for (var i = 0; i < 5; i++) {
        adminAuth.lockSession();
        await adminAuth.login('ibrahim', 'hunter2');
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
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      await shortTimeoutAuth.login('ibrahim', 'hunter2');
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
      await settings.addAdminAccount(username: 'ibrahim', password: 'hunter2', isOwner: true);
      await shortTimeoutAuth.login('ibrahim', 'hunter2');
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
