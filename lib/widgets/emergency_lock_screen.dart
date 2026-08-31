import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Shown instead of the normal app UI while the emergency PIN lock is
/// active (triggered by "sperre die app" or a shake gesture, see
/// AppLockService/CommandRouter) — deliberately has no dismiss/back button,
/// same "no bypass" convention as IntegrityLockdownScreen. The only way out
/// is entering the correct PIN.
class EmergencyLockScreen extends StatefulWidget {
  const EmergencyLockScreen({super.key, required this.onUnlock});

  /// Verifies the entered PIN and clears the locked state on success.
  /// Returns whether it was correct.
  final Future<bool> Function(String pin) onUnlock;

  @override
  State<EmergencyLockScreen> createState() => _EmergencyLockScreenState();
}

class _EmergencyLockScreenState extends State<EmergencyLockScreen> {
  final _pinController = TextEditingController();
  bool _wrongPin = false;
  bool _checking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
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
      setState(() {
        _wrongPin = true;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<JarvisPaletteExtension>()!;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
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
            ),
          ),
        ),
      ),
    );
  }
}
