import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Gate screen shown before entering the Admin-Konsole (see
/// admin_console_screen.dart / AdminAuthService) — modeled on
/// EmergencyLockScreen, but unlike it this is NOT a hard lockout: it only
/// guards one screen, so a normal AppBar back button lets the user cancel
/// out to the regular settings screen instead of being forced to enter a
/// PIN.
class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({super.key, required this.onUnlock, this.onBiometricUnlock});

  /// Verifies the entered PIN and, on success, unlocks the admin console
  /// for the rest of this app session. Returns whether it was correct.
  final Future<bool> Function(String pin) onUnlock;

  /// Null when biometric unlock isn't enabled/available — in that case no
  /// biometric button is shown at all, PIN entry is the only path.
  final Future<bool> Function()? onBiometricUnlock;

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
  final _pinController = TextEditingController();
  bool _wrongPin = false;
  bool _checking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
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
      setState(() {
        _wrongPin = true;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Admin-Zugang')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 64, color: palette.accent),
                const SizedBox(height: 24),
                Text(
                  'Admin-Konsole gesperrt',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: palette.accent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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
                if (showBiometrics) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _submitBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Mit Biometrie entsperren'),
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
