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
}
