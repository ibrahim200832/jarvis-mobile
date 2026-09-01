import 'dart:async';

import 'log_service.dart';
import 'settings_service.dart';

/// Gates access to the Admin-Konsole (see admin_console_screen.dart) behind
/// individual, named accounts — separate from the emergency-lock PIN/
/// credentials (see AppLockService/SettingsService.setAppLockPin), since
/// the two protect different things: the emergency lock locks the whole
/// app down, this only guards one screen's worth of advanced/sensitive
/// settings.
///
/// One owner account plus any number of helper accounts (see
/// SettingsService.getAdminAccounts) — everyone logs in with their own
/// username+password (see [login]), so the Zugriffs-Log shows who actually
/// did what. Only the owner may add/remove accounts (see [isOwner],
/// [addHelperAccount], [removeAccount]); any logged-in account may change
/// its own password (see [changeOwnPassword]). All login attempts share
/// one failed-attempt lockout (see [remainingLockout]), regardless of
/// which username was guessed.
///
/// The unlocked state is deliberately an in-memory field, never persisted —
/// "unlocked for this session" per the feature request means it resets on
/// every app restart, requiring a fresh login each time the app is
/// relaunched. The failed-attempt counter and lockout timestamp, by
/// contrast, ARE persisted (see SettingsService) — an in-memory-only
/// lockout would be trivially defeated by just restarting the app.
class AdminAuthService {
  AdminAuthService({
    required SettingsService settings,
    LogService? log,
    this.idleTimeout = const Duration(minutes: 5),
  })  : _settings = settings, // ignore: prefer_initializing_formals
        _log = log ?? LogService();

  final SettingsService _settings;
  final LogService _log;

  /// Exposes the injected LogService instance so AdminConsoleScreen can
  /// reuse it for Fehler-Historie/Verlauf/Export instead of constructing a
  /// second, independent instance pointed at the same file.
  LogService get log => _log;

  /// How long the console may sit idle (no recorded interaction, see
  /// [recordActivity]) before it auto-locks — an instance field rather than
  /// a constant so tests can shrink it instead of waiting real minutes.
  final Duration idleTimeout;

  static const _logSource = 'AdminAuth';
  static const maxFailedAttempts = 5;
  static const lockoutDuration = Duration(minutes: 5);

  /// The account this session is currently logged in as, or null if not
  /// logged in.
  AdminAccount? currentAccount;
  Timer? _idleTimer;

  /// Called by AdminConsoleScreen when [idleTimeout] elapses with no
  /// activity — set to something that navigates back out of the console,
  /// since the session is no longer unlocked at that point.
  void Function()? onIdleTimeout;

  bool get isUnlockedThisSession => currentAccount != null;
  bool get isOwner => currentAccount?.isOwner ?? false;

  /// Verifies [username]/[password] against the stored accounts. Returns
  /// false without even checking while locked out.
  Future<bool> login(String username, String password, {DateTime? now}) async {
    if (await remainingLockout(now: now) != null) return false;
    final account = await _settings.findMatchingAdminAccount(username, password);
    if (account != null) {
      currentAccount = account;
      await _recordSuccess('Angemeldet als "$username".');
      return true;
    }
    await _recordFailure(now: now, message: 'Fehlgeschlagener Login-Versuch für "$username".');
    return false;
  }

  /// How much longer the lockout has to run, or null if not currently
  /// locked out (including if a past lockout has already expired — in
  /// which case this does NOT clear the stored state itself; [login] does
  /// that on the next actual attempt).
  Future<Duration?> remainingLockout({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final lockoutUntil = await _settings.getAdminLockoutUntil();
    if (lockoutUntil == null) return null;
    final remaining = lockoutUntil.difference(effectiveNow);
    return remaining.isNegative ? null : remaining;
  }

  /// Adds a new helper account (never an owner — there's exactly one owner
  /// account for the app's lifetime). Returns false if the current session
  /// isn't an owner, or if the username is already taken.
  Future<bool> addHelperAccount(String username, String password) async {
    if (!isOwner) return false;
    return _settings.addAdminAccount(username: username, password: password, isOwner: false);
  }

  /// Removes an account by username. Returns false if the current session
  /// isn't an owner, if the target is the owner account itself (never
  /// removable this way), or if no such account exists.
  Future<bool> removeAccount(String username) async {
    if (!isOwner) return false;
    final accounts = await _settings.getAdminAccounts();
    final target = accounts.where((a) => a.username == username).firstOrNull;
    if (target == null || target.isOwner) return false;
    return _settings.removeAdminAccount(username);
  }

  /// Changes the currently logged-in account's own password. Returns false
  /// if nobody is logged in, or if [currentPassword] doesn't match.
  Future<bool> changeOwnPassword(String currentPassword, String newPassword) async {
    final account = currentAccount;
    if (account == null) return false;
    final verified = await _settings.findMatchingAdminAccount(account.username, currentPassword);
    if (verified == null) return false;
    final updated = await _settings.updateAdminAccountPassword(account.username, newPassword);
    if (updated) {
      currentAccount = await _settings.findMatchingAdminAccount(account.username, newPassword);
    }
    return updated;
  }

  Future<void> _recordSuccess(String logMessage) async {
    await _settings.setAdminFailedAttempts(0);
    await _settings.setAdminLockoutUntil(null);
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
    currentAccount = null;
  }

  /// (Re)starts the idle countdown — call once after a successful login
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

  /// Newest-first successful logins for the Admin-Konsole's "Zugriffs-Log"
  /// section. Failed attempts are logged too (see [_recordFailure]) but at
  /// warning level, so they show up in the general Live-Log-Viewer without
  /// cluttering this success-only list.
  Future<List<LogEntry>> recentSuccessfulLogins({int limit = 10}) async {
    final entries = await _log.readAll();
    return entries.where((e) => e.source == _logSource && e.level == LogLevel.info).take(limit).toList();
  }
}
