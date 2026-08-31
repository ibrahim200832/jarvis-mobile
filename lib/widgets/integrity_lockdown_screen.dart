import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Shown instead of the normal app UI when a Play Integrity attestation
/// check comes back with an explicit negative verdict (see
/// AppIntegrityService/home_screen.dart) — deliberately has no way to
/// dismiss or bypass it, since "der App-Integritäts-Check sperrt die App
/// bei erkannten Sicherheitsrisiken" was the explicit ask. Only ever shown
/// when a *configured* backend actively said the check failed — an
/// unconfigured or unreachable check (the common case) never reaches this.
class IntegrityLockdownScreen extends StatelessWidget {
  const IntegrityLockdownScreen({super.key});

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
                Icon(Icons.gpp_bad_outlined, size: 64, color: palette.error),
                const SizedBox(height: 24),
                Text(
                  'Sicherheitsprüfung fehlgeschlagen',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: palette.error, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Die App-Integritätsprüfung meldet, dass dieses Gerät oder diese Installation nicht vertrauenswürdig '
                  'ist (z. B. ein gerootetes Gerät oder eine veränderte/nachgebaute APK). JARVIS startet aus '
                  'Sicherheitsgründen nicht weiter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.mutedForeground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
