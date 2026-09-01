import 'package:shared_preferences/shared_preferences.dart';

import 'settings_service.dart';

/// Tracks whether the app is currently locked behind the emergency PIN
/// and/or username+password login (see SettingsService's
/// setAppLockPin/setAppLockCredentials for the actual credential storage)
/// and lets it be locked/unlocked. The lock *state* itself is not a secret,
/// so it's a plain SharedPreferences bool — only the PIN/password hashes
/// need secure storage.
///
/// Two equally valid, independent ways in: the PIN (see [unlock]) and a
/// username+password login (see [login]) — a completely separate credential
/// pair from the Admin-Konsole's (see AdminAuthService), since the two
/// protect different things (the whole app vs. just one settings screen).
/// Both share one failed-attempt lockout (see [remainingLockout]) so
/// switching between the two doesn't dodge it — persisted (not just
/// in-memory), since a simple app restart shouldn't bypass a lockout either.
///
/// Deliberately narrower than AdminAuthService: no biometrics, no
/// idle-timeout/auto-logout, no access log — this is a permanent,
/// no-bypass whole-app gate with no screen lifecycle to hang a timer off
/// of, not a session-scoped console.
class AppLockService {
  // ignore: prefer_initializing_formals
  AppLockService({required SettingsService settings}) : _settings = settings;

  final SettingsService _settings;

  static const _keyLocked = 'app_locked_state';
  static const maxFailedAttempts = 5;
  static const lockoutDuration = Duration(minutes: 5);

  Future<bool> hasPinConfigured() => _settings.hasAppLockPin();
  Future<bool> hasPasswordConfigured() => _settings.hasAppLockCredentials();

  /// Whether at least one unlock method (PIN or username+password) is set
  /// up — used to guard both the voice-command and shake-gesture triggers
  /// from locking the app with no way back in.
  Future<bool> hasAnyLockMethodConfigured() async => (await hasPinConfigured()) || (await hasPasswordConfigured());

  Future<void> lock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocked, true);
  }

  /// How much longer the lockout has to run, or null if not currently
  /// locked out (including if a past lockout has already expired — in
  /// which case this does NOT clear the stored state itself; [unlock]/
  /// [login] do that on the next actual successful attempt).
  Future<Duration?> remainingLockout({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final lockoutUntil = await _settings.getAppLockLockoutUntil();
    if (lockoutUntil == null) return null;
    final remaining = lockoutUntil.difference(effectiveNow);
    return remaining.isNegative ? null : remaining;
  }

  /// Verifies [pin] against the stored hash and, if correct, clears the
  /// locked state. Returns false without even checking the PIN while
  /// locked out.
  Future<bool> unlock(String pin, {DateTime? now}) async {
    if (await remainingLockout(now: now) != null) return false;
    final correct = await _settings.verifyAppLockPin(pin);
    if (correct) {
      await _recordSuccess();
    } else {
      await _recordFailure(now: now);
    }
    return correct;
  }

  /// Verifies [username]/[password] against the stored credentials — same
  /// lockout behavior as [unlock].
  Future<bool> login(String username, String password, {DateTime? now}) async {
    if (await remainingLockout(now: now) != null) return false;
    final correct = await _settings.verifyAppLockCredentials(username, password);
    if (correct) {
      await _recordSuccess();
    } else {
      await _recordFailure(now: now);
    }
    return correct;
  }

  Future<void> _recordSuccess() async {
    await _settings.setAppLockFailedAttempts(0);
    await _settings.setAppLockLockoutUntil(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocked, false);
  }

  Future<void> _recordFailure({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final attempts = (await _settings.getAppLockFailedAttempts()) + 1;
    await _settings.setAppLockFailedAttempts(attempts);
    if (attempts >= maxFailedAttempts) {
      await _settings.setAppLockLockoutUntil(effectiveNow.add(lockoutDuration));
    }
  }

  Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocked) ?? false;
  }
}
