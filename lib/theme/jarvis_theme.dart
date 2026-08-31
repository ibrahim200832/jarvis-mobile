import 'package:flutter/material.dart';

/// Which color palette the app is currently rendering with — persisted via
/// SettingsService.getThemeVariant()/setThemeVariant() and switchable at
/// runtime from the Admin-Konsole's "Erscheinungsbild" section.
enum ThemeVariant { gold, cyan }

/// Color tokens mirrored from the companion "AETHER" web redesign (Lovable
/// project, `src/styles.css`) — "Iron-Man gold on obsidian". Kept as a single
/// source of truth so widgets don't hardcode ad-hoc colors. This is the
/// default (Gold) palette; see [JarvisCyanColors] for the alternate one.
/// Widgets should read colors via `Theme.of(context)
/// .extension<JarvisPaletteExtension>()!` rather than this class directly,
/// so they follow the active variant — this class (and [JarvisCyanColors])
/// only exists to hand [buildJarvisTheme] its literal values.
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

/// "Dark Cyan" alternate palette (Admin-Konsole "Erscheinungsbild" →
/// "Dark Cyan") — same dark-obsidian structure as [JarvisColors], but with a
/// cyan accent instead of gold. Error stays the same red in both variants:
/// that's a semantic warning color, not a decorative one.
class JarvisCyanColors {
  static const background = Color(0xFF0A1414);
  static const surface = Color(0xFF162626);
  static const accent = Color(0xFF32D6E0);
  static const onAccent = Color(0xFF042022);
  static const accentGlow = Color(0xFF7EEFF5);
  static const secondary = Color(0xFF1C2E2E);
  static const foreground = Color(0xFFE9F5F5);
  static const mutedForeground = Color(0xFF93ADAD);
  static const error = JarvisColors.error;
  static final border = Colors.white.withValues(alpha: 0.08);
  static final glassFill = surface.withValues(alpha: 0.62);
  static final glassFillStrong = surface.withValues(alpha: 0.85);
}

/// Makes the active palette (Gold or Cyan) available anywhere below the
/// MaterialApp via `Theme.of(context).extension<JarvisPaletteExtension>()`,
/// so widgets follow a runtime theme switch instead of a fixed [JarvisColors]
/// import.
@immutable
class JarvisPaletteExtension extends ThemeExtension<JarvisPaletteExtension> {
  const JarvisPaletteExtension({
    required this.background,
    required this.surface,
    required this.accent,
    required this.onAccent,
    required this.accentGlow,
    required this.secondary,
    required this.foreground,
    required this.mutedForeground,
    required this.error,
    required this.border,
    required this.glassFill,
    required this.glassFillStrong,
  });

  final Color background;
  final Color surface;
  final Color accent;
  final Color onAccent;
  final Color accentGlow;
  final Color secondary;
  final Color foreground;
  final Color mutedForeground;
  final Color error;
  final Color border;
  final Color glassFill;
  final Color glassFillStrong;

  @override
  JarvisPaletteExtension copyWith({
    Color? background,
    Color? surface,
    Color? accent,
    Color? onAccent,
    Color? accentGlow,
    Color? secondary,
    Color? foreground,
    Color? mutedForeground,
    Color? error,
    Color? border,
    Color? glassFill,
    Color? glassFillStrong,
  }) {
    return JarvisPaletteExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentGlow: accentGlow ?? this.accentGlow,
      secondary: secondary ?? this.secondary,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      error: error ?? this.error,
      border: border ?? this.border,
      glassFill: glassFill ?? this.glassFill,
      glassFillStrong: glassFillStrong ?? this.glassFillStrong,
    );
  }

  @override
  JarvisPaletteExtension lerp(ThemeExtension<JarvisPaletteExtension>? other, double t) {
    if (other is! JarvisPaletteExtension) return this;
    return JarvisPaletteExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      error: Color.lerp(error, other.error, t)!,
      border: Color.lerp(border, other.border, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassFillStrong: Color.lerp(glassFillStrong, other.glassFillStrong, t)!,
    );
  }

  // border/glassFill/glassFillStrong are `static final` on JarvisColors/
  // JarvisCyanColors (computed via .withValues), not compile-time
  // constants, so these can't be `const` — built once and reused instead.
  static final gold = JarvisPaletteExtension(
    background: JarvisColors.background,
    surface: JarvisColors.surface,
    accent: JarvisColors.accent,
    onAccent: JarvisColors.onAccent,
    accentGlow: JarvisColors.accentGlow,
    secondary: JarvisColors.secondary,
    foreground: JarvisColors.foreground,
    mutedForeground: JarvisColors.mutedForeground,
    error: JarvisColors.error,
    border: JarvisColors.border,
    glassFill: JarvisColors.glassFill,
    glassFillStrong: JarvisColors.glassFillStrong,
  );

  static final cyan = JarvisPaletteExtension(
    background: JarvisCyanColors.background,
    surface: JarvisCyanColors.surface,
    accent: JarvisCyanColors.accent,
    onAccent: JarvisCyanColors.onAccent,
    accentGlow: JarvisCyanColors.accentGlow,
    secondary: JarvisCyanColors.secondary,
    foreground: JarvisCyanColors.foreground,
    mutedForeground: JarvisCyanColors.mutedForeground,
    error: JarvisCyanColors.error,
    border: JarvisCyanColors.border,
    glassFill: JarvisCyanColors.glassFill,
    glassFillStrong: JarvisCyanColors.glassFillStrong,
  );
}

/// App-wide notifier so a theme change made deep in the navigation stack
/// (Admin-Konsole's "Erscheinungsbild" section) can update the running
/// MaterialApp without a full app restart — JarvisApp (main.dart) listens to
/// this and rebuilds with buildJarvisTheme(variant: ...).
final themeVariantNotifier = ValueNotifier<ThemeVariant>(ThemeVariant.gold);

ThemeData buildJarvisTheme({ThemeVariant variant = ThemeVariant.gold}) {
  final palette = variant == ThemeVariant.cyan ? JarvisPaletteExtension.cyan : JarvisPaletteExtension.gold;
  final colorScheme = ColorScheme.dark(
    primary: palette.accent,
    onPrimary: palette.onAccent,
    secondary: palette.secondary,
    onSecondary: palette.foreground,
    surface: palette.surface,
    onSurface: palette.foreground,
    surfaceContainerHighest: palette.secondary,
    onSurfaceVariant: palette.mutedForeground,
    outline: palette.border,
    error: palette.error,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.background,
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: palette.foreground,
          displayColor: palette.foreground,
        ),
    extensions: [palette],
  );
}
