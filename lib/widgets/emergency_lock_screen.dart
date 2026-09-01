import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Shown instead of the normal app UI while the emergency lock is active
/// (triggered by "sperre die app" or a shake gesture, see
/// AppLockService/CommandRouter) — deliberately has no dismiss/back button,
/// same "no bypass" convention as IntegrityLockdownScreen. The only way out
/// is entering a correct PIN or username+password.
///
/// Offers up to two independent, equally valid ways in — the emergency PIN
/// and a username+password login — each shown only if actually configured
/// (see [hasPinConfigured]/[hasPasswordConfigured]). Both share one
/// failed-attempt lockout (see [checkLockout]), re-checked once on entry
/// (so a cold start during an already-active, persisted lockout shows the
/// real reason instead of a misleading "falsche PIN") and again after every
/// failed attempt.
class EmergencyLockScreen extends StatefulWidget {
  const EmergencyLockScreen({
    super.key,
    required this.hasPinConfigured,
    required this.hasPasswordConfigured,
    required this.checkLockout,
    required this.onUnlock,
    required this.onLogin,
  });

  final bool hasPinConfigured;
  final bool hasPasswordConfigured;

  /// How much longer the shared lockout has to run, or null if not
  /// currently locked out — called once on entry and again after every
  /// failed PIN/login attempt.
  final Future<Duration?> Function() checkLockout;

  /// Verifies the entered PIN and clears the locked state on success.
  /// Returns whether it was correct.
  final Future<bool> Function(String pin) onUnlock;

  /// Verifies the entered username+password and clears the locked state on
  /// success. Returns whether they were correct.
  final Future<bool> Function(String username, String password) onLogin;

  @override
  State<EmergencyLockScreen> createState() => _EmergencyLockScreenState();
}

class _EmergencyLockScreenState extends State<EmergencyLockScreen> {
  final _pinController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _wrongPin = false;
  bool _wrongCredentials = false;
  bool _checking = false;
  Duration? _lockoutRemaining;

  @override
  void initState() {
    super.initState();
    _refreshLockout();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refreshLockout() async {
    final remaining = await widget.checkLockout();
    if (!mounted) return;
    setState(() => _lockoutRemaining = remaining);
  }

  Future<void> _submit() async {
    final pin = _pinController.text;
    if (pin.isEmpty) return;
    setState(() {
      _checking = true;
      _wrongPin = false;
    });
    final correct = await widget.onUnlock(pin);
    if (!mounted) return;
    if (correct) {
      _pinController.clear();
    } else {
      await _refreshLockout();
      if (!mounted) return;
      setState(() {
        _wrongPin = true;
        _checking = false;
      });
    }
  }

  Future<void> _submitLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    setState(() {
      _checking = true;
      _wrongCredentials = false;
    });
    final correct = await widget.onLogin(username, password);
    if (!mounted) return;
    if (correct) {
      _usernameController.clear();
      _passwordController.clear();
    } else {
      await _refreshLockout();
      if (!mounted) return;
      setState(() {
        _wrongCredentials = true;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<JarvisPaletteExtension>()!;
    final lockoutRemaining = _lockoutRemaining;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64, color: palette.accent),
                const SizedBox(height: 24),
                Text(
                  'Notfall-Sperre aktiv',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: palette.accent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (lockoutRemaining != null)
                  Text(
                    'Zu viele Fehlversuche. Bitte in ${lockoutRemaining.inMinutes + 1} Minuten erneut '
                    'versuchen. JARVIS bleibt bis dahin vollständig gesperrt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.error),
                  )
                else ...[
                  if (widget.hasPinConfigured) ...[
                    Text(
                      'Gib deine PIN ein, um JARVIS wieder zu entsperren.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.mutedForeground),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          errorText: _wrongPin ? 'Falsche PIN' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _checking ? null : _submit,
                      child: const Text('Entsperren'),
                    ),
                  ],
                  if (widget.hasPinConfigured && widget.hasPasswordConfigured) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: palette.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('oder', style: TextStyle(color: palette.mutedForeground)),
                        ),
                        Expanded(child: Divider(color: palette.border)),
                      ],
                    ),
                  ],
                  if (widget.hasPasswordConfigured) ...[
                    if (!widget.hasPinConfigured)
                      Text(
                        'Melde dich mit deinem Nutzernamen und Passwort an, um JARVIS wieder zu entsperren.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.mutedForeground),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _usernameController,
                        textAlign: TextAlign.center,
                        autofocus: !widget.hasPinConfigured,
                        decoration: const InputDecoration(labelText: 'Benutzername'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        onSubmitted: (_) => _submitLogin(),
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          errorText: _wrongCredentials ? 'Falscher Benutzername oder falsches Passwort' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _checking ? null : _submitLogin,
                      child: const Text('Anmelden'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
