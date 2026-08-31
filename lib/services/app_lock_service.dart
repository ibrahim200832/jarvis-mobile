import 'package:shared_preferences/shared_preferences.dart';

import 'settings_service.dart';

/// Tracks whether the app is currently locked behind the emergency PIN
/// (see SettingsService's setAppLockPin/verifyAppLockPin for the actual PIN
/// storage) and lets it be locked/unlocked. The lock *state* itself is not
/// a secret, so it's a plain SharedPreferences bool — only the PIN hash
/// needs secure storage.
class AppLockService {
  // ignore: prefer_initializing_formals
  AppLockService({required SettingsService settings}) : _settings = settings;

  final SettingsService _settings;

  static const _keyLocked = 'app_locked_state';

  Future<bool> hasPinConfigured() => _settings.hasAppLockPin();

  Future<void> lock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocked, true);
  }

  /// Verifies [pin] against the stored hash and, if correct, clears the
  /// locked state. Returns whether the PIN was correct.
  Future<bool> unlock(String pin) async {
    final correct = await _settings.verifyAppLockPin(pin);
    if (!correct) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocked, false);
    return true;
  }

  Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocked) ?? false;
  }
}
