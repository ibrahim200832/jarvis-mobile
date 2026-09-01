import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Gate screen shown before entering the Admin-Konsole (see
/// admin_console_screen.dart / AdminAuthService) — modeled on
/// EmergencyLockScreen, but unlike it this is NOT a hard lockout: it only
/// guards one screen, so a normal AppBar back button lets the user cancel
/// out to the regular settings screen instead of being forced to enter a
/// PIN.
///
/// Offers up to two independent, equally valid ways in — the Admin-PIN and
/// a username+password login — each shown only if actually configured (see
/// [hasPinConfigured]/[hasPasswordConfigured]), plus an optional biometric
/// button. Both share one failed-attempt lockout (see [checkLockout]),
/// re-checked after every failed attempt so a just-crossed threshold shows
/// up immediately.
class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({
    super.key,
    required this.hasPinConfigured,
    required this.hasPasswordConfigured,
    required this.checkLockout,
    required this.onUnlock,
    required this.onLogin,
    this.onBiometricUnlock,
  });

  final bool hasPinConfigured;
  final bool hasPasswordConfigured;

  /// How much longer the shared lockout has to run, or null if not
  /// currently locked out — called once on entry and again after every
  /// failed PIN/login attempt.
  final Future<Duration?> Function() checkLockout;

  /// Verifies the entered PIN and, on success, unlocks the admin console
  /// for the rest of this app session. Returns whether it was correct.
  final Future<bool> Function(String pin) onUnlock;

  /// Verifies the entered username+password. Returns whether they were
  /// correct.
  final Future<bool> Function(String username, String password) onLogin;

  /// Null when biometric unlock isn't enabled/available — in that case no
  /// biometric button is shown at all.
  final Future<bool> Function()? onBiometricUnlock;

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
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

  Future<void> _submitPin() async {
    final pin = _pinController.text;
    if (pin.isEmpty) return;
    setState(() {
      _checking = true;
      _wrongPin = false;
    });
    final correct = await widget.onUnlock(pin);
    if (!mounted) return;
    if (correct) {
      Navigator.of(context).pop(true);
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
      Navigator.of(context).pop(true);
    } else {
      await _refreshLockout();
      if (!mounted) return;
      setState(() {
        _wrongCredentials = true;
        _checking = false;
      });
    }
  }

  Future<void> _submitBiometrics() async {
    final onBiometricUnlock = widget.onBiometricUnlock;
    if (onBiometricUnlock == null) return;
    setState(() => _checking = true);
    final success = await onBiometricUnlock();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBiometrics = widget.onBiometricUnlock != null;
    final palette = Theme.of(context).extension<JarvisPaletteExtension>()!;
    final lockoutRemaining = _lockoutRemaining;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin-Zugang')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 64,
                  color: palette.accent,
                ),
                const SizedBox(height: 24),
                Text(
                  'Admin-Konsole gesperrt',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (lockoutRemaining != null)
                  Text(
                    'Zu viele Fehlversuche. Bitte in ${lockoutRemaining.inMinutes + 1} Minuten erneut versuchen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.error),
                  )
                else ...[
                  if (widget.hasPinConfigured) ...[
                    Text(
                      'Gib deine Admin-PIN ein, um fortzufahren.',
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
                        onSubmitted: (_) => _submitPin(),
                        decoration: InputDecoration(
                          labelText: 'Admin-PIN',
                          errorText: _wrongPin ? 'Falsche PIN' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _checking ? null : _submitPin,
                      child: const Text('Entsperren'),
                    ),
                  ],
                  if (widget.hasPinConfigured &&
                      widget.hasPasswordConfigured) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: palette.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'oder',
                            style: TextStyle(color: palette.mutedForeground),
                          ),
                        ),
                        Expanded(child: Divider(color: palette.border)),
                      ],
                    ),
                  ],
                  if (widget.hasPasswordConfigured) ...[
                    if (!widget.hasPinConfigured)
                      Text(
                        'Melde dich mit deinem Admin-Nutzernamen und -Passwort an.',
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
                        decoration: const InputDecoration(
                          labelText: 'Benutzername',
                        ),
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
                          errorText: _wrongCredentials
                              ? 'Falscher Benutzername oder falsches Passwort'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _checking ? null : _submitLogin,
                      child: const Text('Anmelden'),
                    ),
                  ],
                  if (showBiometrics) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _checking ? null : _submitBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Mit Biometrie entsperren'),
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
