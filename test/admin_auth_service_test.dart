import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/admin_auth_service.dart';
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
  late SettingsService settings;
  late AdminAuthService adminAuth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(secureStorage: _FakeSecureStorageService());
    adminAuth = AdminAuthService(settings: settings);
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

  test('unlockViaBiometrics() sets isUnlockedThisSession without a PIN check', () {
    adminAuth.unlockViaBiometrics();
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

    final freshInstance = AdminAuthService(settings: settings);

    expect(freshInstance.isUnlockedThisSession, isFalse);
  });
}
