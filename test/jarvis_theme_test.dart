import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';

void main() {
  test('buildJarvisTheme defaults to the gold palette', () {
    final theme = buildJarvisTheme();
    final palette = theme.extension<JarvisPaletteExtension>();
    expect(palette, isNotNull);
    expect(palette!.accent, JarvisColors.accent);
  });

  test('buildJarvisTheme(variant: cyan) uses the cyan palette', () {
    final theme = buildJarvisTheme(variant: ThemeVariant.cyan);
    final palette = theme.extension<JarvisPaletteExtension>();
    expect(palette, isNotNull);
    expect(palette!.accent, JarvisCyanColors.accent);
  });

  test('gold and cyan palettes produce visibly different accent colors', () {
    final gold = buildJarvisTheme(variant: ThemeVariant.gold).extension<JarvisPaletteExtension>()!;
    final cyan = buildJarvisTheme(variant: ThemeVariant.cyan).extension<JarvisPaletteExtension>()!;
    expect(gold.accent, isNot(cyan.accent));
    expect(gold.background, isNot(cyan.background));
  });

  test('both variants keep the same semantic error color', () {
    final gold = buildJarvisTheme(variant: ThemeVariant.gold).extension<JarvisPaletteExtension>()!;
    final cyan = buildJarvisTheme(variant: ThemeVariant.cyan).extension<JarvisPaletteExtension>()!;
    expect(gold.error, cyan.error);
  });

  test('colorScheme.primary matches the active palette accent', () {
    final goldTheme = buildJarvisTheme();
    expect(goldTheme.colorScheme.primary, JarvisColors.accent);

    final cyanTheme = buildJarvisTheme(variant: ThemeVariant.cyan);
    expect(cyanTheme.colorScheme.primary, JarvisCyanColors.accent);
  });

  test('lerp between the two palettes stays within the same interpolation, not a fallback', () {
    final gold = JarvisPaletteExtension.gold;
    final cyan = JarvisPaletteExtension.cyan;
    final halfway = gold.lerp(cyan, 0.5);
    expect(halfway.accent, isNot(gold.accent));
    expect(halfway.accent, isNot(cyan.accent));
  });
}
