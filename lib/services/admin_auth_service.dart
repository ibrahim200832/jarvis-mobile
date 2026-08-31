import 'settings_service.dart';

/// Gates access to the Admin-Konsole (see admin_console_screen.dart) behind
/// its own PIN — a separate credential from the emergency-lock PIN (see
/// AppLockService/SettingsService.setAppLockPin), since the two protect
/// different things: the emergency lock locks the whole app down, this only
/// guards one screen's worth of advanced/sensitive settings.
///
/// Unlike AppLockService, the unlocked state is deliberately an in-memory
/// field, never persisted — "unlocked for this session" per the feature
/// request means it resets on every app restart, requiring the PIN (or
/// biometrics, see BiometricAuthService) again each time the app is
/// relaunched.
class AdminAuthService {
  // ignore: prefer_initializing_formals
  AdminAuthService({required SettingsService settings}) : _settings = settings;

  final SettingsService _settings;

  bool _unlockedThisSession = false;

  bool get isUnlockedThisSession => _unlockedThisSession;

  Future<bool> hasPinConfigured() => _settings.hasAdminPin();

  /// Verifies [pin] against the stored hash and, if correct, unlocks the
  /// console for the rest of this app session. Returns whether the PIN was
  /// correct.
  Future<bool> unlock(String pin) async {
    final correct = await _settings.verifyAdminPin(pin);
    if (correct) _unlockedThisSession = true;
    return correct;
  }

  /// Marks the session unlocked after a successful biometric check (see
  /// BiometricAuthService) — biometrics never replace the PIN, they're only
  /// an alternative way to prove the same "this session is authorized"
  /// claim once a PIN already exists.
  void unlockViaBiometrics() {
    _unlockedThisSession = true;
  }

  /// Not currently called automatically anywhere — exposed for completeness
  /// and testability (e.g. a future "Admin-Konsole jetzt sperren" action).
  void lockSession() {
    _unlockedThisSession = false;
  }
}
