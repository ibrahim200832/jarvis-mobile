import 'dart:async';

import 'log_service.dart';
import 'settings_service.dart';

/// Gates access to the Admin-Konsole (see admin_console_screen.dart) behind
/// its own credentials — separate from the emergency-lock PIN (see
/// AppLockService/SettingsService.setAppLockPin), since the two protect
/// different things: the emergency lock locks the whole app down, this only
/// guards one screen's worth of advanced/sensitive settings.
///
/// Two equally valid, independent ways in: the Admin-PIN (see [unlock]) and
/// a username+password login (see [login]) — neither replaces the other,
/// both just prove the same "this session is authorized" claim. Both share
/// one failed-attempt lockout (see [remainingLockout]) so switching between
/// the two doesn't let someone dodge it. Biometrics (see
/// [unlockViaBiometrics]/BiometricAuthService) deliberately bypass the
/// lockout entirely — a fingerprint isn't a guessable secret.
///
/// Unlike AppLockService, the unlocked state is deliberately an in-memory
/// field, never persisted — "unlocked for this session" per the feature
/// request means it resets on every app restart, requiring a fresh PIN/
/// login/biometric check again each time the app is relaunched. The
/// failed-attempt counter and lockout timestamp, by contrast, ARE
/// persisted (see SettingsService) — an in-memory-only lockout would be
/// trivially defeated by just restarting the app.
class AdminAuthService {
  AdminAuthService({
    required SettingsService settings,
    LogService? log,
    this.idleTimeout = const Duration(minutes: 5),
  })  : _settings = settings, // ignore: prefer_initializing_formals
        _log = log ?? LogService();

  final SettingsService _settings;
  final LogService _log;

  /// How long the console may sit idle (no recorded interaction, see
  /// [recordActivity]) before it auto-locks — an instance field rather than
  /// a constant so tests can shrink it instead of waiting real minutes.
  final Duration idleTimeout;

  static const _logSource = 'AdminAuth';
  static const maxFailedAttempts = 5;
  static const lockoutDuration = Duration(minutes: 5);

  bool _unlockedThisSession = false;
  Timer? _idleTimer;

  /// Called by AdminConsoleScreen when [idleTimeout] elapses with no
  /// activity — set to something that navigates back out of the console,
  /// since the session is no longer unlocked at that point.
  void Function()? onIdleTimeout;

  bool get isUnlockedThisSession => _unlockedThisSession;

  Future<bool> hasPinConfigured() => _settings.hasAdminPin();
  Future<bool> hasPasswordConfigured() => _settings.hasAdminCredentials();

  /// How much longer the lockout has to run, or null if not currently
  /// locked out (including if a past lockout has already expired — in
  /// which case this does NOT clear the stored state itself; [unlock]/
  /// [login] do that on the next actual attempt).
  Future<Duration?> remainingLockout({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final lockoutUntil = await _settings.getAdminLockoutUntil();
    if (lockoutUntil == null) return null;
    final remaining = lockoutUntil.difference(effectiveNow);
    return remaining.isNegative ? null : remaining;
  }

  /// Verifies [pin] against the stored hash and, if correct, unlocks the
  /// console for the rest of this app session. Returns false without even
  /// checking the PIN while locked out.
  Future<bool> unlock(String pin, {DateTime? now}) async {
    if (await remainingLockout(now: now) != null) return false;
    final correct = await _settings.verifyAdminPin(pin);
    if (correct) {
      await _recordSuccess('Angemeldet per PIN.');
    } else {
      await _recordFailure(now: now, message: 'Fehlgeschlagener PIN-Versuch.');
    }
    return correct;
  }

  /// Verifies [username]/[password] against the stored credentials — same
  /// lockout behavior as [unlock].
  Future<bool> login(String username, String password, {DateTime? now}) async {
    if (await remainingLockout(now: now) != null) return false;
    final correct = await _settings.verifyAdminCredentials(username, password);
    if (correct) {
      await _recordSuccess('Angemeldet als "$username" (Passwort).');
    } else {
      await _recordFailure(now: now, message: 'Fehlgeschlagener Passwort-Versuch für "$username".');
    }
    return correct;
  }

  /// Marks the session unlocked after a successful biometric check (see
  /// BiometricAuthService) — biometrics never replace the PIN/password,
  /// they're only an alternative way to prove the same claim once at least
  /// one of them already exists. Async now: also resets any prior failed
  /// attempts and logs the success, same as [unlock]/[login].
  Future<void> unlockViaBiometrics() => _recordSuccess('Angemeldet per Biometrie.');

  Future<void> _recordSuccess(String logMessage) async {
    await _settings.setAdminFailedAttempts(0);
    await _settings.setAdminLockoutUntil(null);
    _unlockedThisSession = true;
    await _log.info(_logSource, logMessage);
  }

  Future<void> _recordFailure({DateTime? now, required String message}) async {
    final effectiveNow = now ?? DateTime.now();
    final attempts = (await _settings.getAdminFailedAttempts()) + 1;
    await _settings.setAdminFailedAttempts(attempts);
    if (attempts >= maxFailedAttempts) {
      await _settings.setAdminLockoutUntil(effectiveNow.add(lockoutDuration));
    }
    await _log.warning(_logSource, message);
  }

  void lockSession() {
    _unlockedThisSession = false;
  }

  /// (Re)starts the idle countdown — call once after a successful unlock
  /// and again on every user interaction while the console is open (see
  /// AdminConsoleScreen). Firing calls [lockSession] and [onIdleTimeout].
  void recordActivity() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _fireIdleTimeout);
  }

  /// Cancels the idle countdown and unregisters the callback — call from
  /// AdminConsoleScreen.dispose() so a stray Timer never fires after the
  /// screen is gone (both a real-world correctness issue and, in
  /// flutter_test, a "Timer is still pending" test failure if skipped).
  void stopIdleTimeout() {
    _idleTimer?.cancel();
    _idleTimer = null;
    onIdleTimeout = null;
  }

  void _fireIdleTimeout() {
    _idleTimer = null;
    lockSession();
    onIdleTimeout?.call();
  }

  /// Newest-first successful logins (PIN/Passwort/Biometrie) for the
  /// Admin-Konsole's "Zugriffs-Log" section. Failed attempts are logged
  /// too (see [_recordFailure]) but at warning level, so they show up in
  /// the general Live-Log-Viewer without cluttering this success-only list.
  Future<List<LogEntry>> recentSuccessfulLogins({int limit = 10}) async {
    final entries = await _log.readAll();
    return entries.where((e) => e.source == _logSource && e.level == LogLevel.info).take(limit).toList();
  }
}
