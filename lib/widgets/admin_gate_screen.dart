import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Gate screen shown before entering the Admin-Konsole (see
/// admin_console_screen.dart / AdminAuthService) — modeled on
/// EmergencyLockScreen, but unlike it this is NOT a hard lockout: it only
/// guards one screen, so a normal AppBar back button lets the user cancel
/// out to the regular settings screen instead of being forced to log in.
///
/// Every account (owner or helper) logs in the same way — with their own
/// username+password, so the Zugriffs-Log can show who actually did what.
/// Shares one failed-attempt lockout (see [checkLockout]), re-checked after
/// every failed attempt so a just-crossed threshold shows up immediately.
class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({super.key, required this.checkLockout, required this.onLogin});

  /// How much longer the shared lockout has to run, or null if not
  /// currently locked out — called once on entry and again after every
  /// failed login attempt.
  final Future<Duration?> Function() checkLockout;

  /// Verifies the entered username+password. Returns whether they were
  /// correct.
  final Future<bool> Function(String username, String password) onLogin;

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refreshLockout() async {
    final remaining = await widget.checkLockout();
    if (!mounted) return;
    setState(() => _lockoutRemaining = remaining);
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

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    'Melde dich mit deinem Nutzernamen und Passwort an.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.mutedForeground),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _usernameController,
                      textAlign: TextAlign.center,
                      autofocus: true,
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
            ),
          ),
        ),
      ),
    );
  }
}
