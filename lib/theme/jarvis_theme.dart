import 'package:flutter/material.dart';

/// Color tokens mirrored from the companion "AETHER" web redesign (Lovable
/// project, `src/styles.css`) — "Iron-Man gold on obsidian". Kept as a single
/// source of truth so widgets don't hardcode ad-hoc colors.
class JarvisColors {
  static const background = Color(0xFF120F0C);
  static const surface = Color(0xFF211C17);
  static const accent = Color(0xFFE3A552);
  static const onAccent = Color(0xFF241A0E);
  static const accentGlow = Color(0xFFF0C674);
  static const secondary = Color(0xFF2E2822);
  static const foreground = Color(0xFFF6F2EC);
  static const mutedForeground = Color(0xFFAFA79B);
  static const error = Color(0xFFD6533A);
  static final border = Colors.white.withValues(alpha: 0.08);
  static final glassFill = surface.withValues(alpha: 0.62);
  static final glassFillStrong = surface.withValues(alpha: 0.85);
}

ThemeData buildJarvisTheme() {
  final colorScheme = ColorScheme.dark(
    primary: JarvisColors.accent,
    onPrimary: JarvisColors.onAccent,
    secondary: JarvisColors.secondary,
    onSecondary: JarvisColors.foreground,
    surface: JarvisColors.surface,
    onSurface: JarvisColors.foreground,
    surfaceContainerHighest: JarvisColors.secondary,
    onSurfaceVariant: JarvisColors.mutedForeground,
    outline: JarvisColors.border,
    error: JarvisColors.error,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: JarvisColors.background,
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: JarvisColors.foreground,
          displayColor: JarvisColors.foreground,
        ),
  );
}
