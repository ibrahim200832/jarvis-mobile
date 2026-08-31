import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';
import 'package:jarvis_mobile/widgets/access_denied_flash.dart';
import 'package:jarvis_mobile/widgets/blinking_dot.dart';
import 'package:jarvis_mobile/widgets/scanline_overlay.dart';

// ScanlineOverlay/AccessDeniedFlash read their colors from
// Theme.of(context).extension<JarvisPaletteExtension>() rather than a fixed
// JarvisColors import, so every MaterialApp here needs buildJarvisTheme() —
// the plain default MaterialApp theme carries no such extension and a null
// check on it would throw.
void main() {
  testWidgets('ScanlineOverlay paints without throwing and can be disposed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: const SizedBox(width: 300, height: 300, child: ScanlineOverlay()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ScanlineOverlay), findsOneWidget);

    // Disposal: swap it out for an empty widget and make sure nothing throws.
    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: const SizedBox()));
    await tester.pump();
  });

  testWidgets('AccessDeniedFlash shows its text when visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildJarvisTheme(), home: const AccessDeniedFlash(visible: true)),
    );
    await tester.pump();
    expect(find.text('ZUGRIFF VERWEIGERT'), findsOneWidget);
  });

  testWidgets('AccessDeniedFlash is present but invisible when not visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildJarvisTheme(), home: const AccessDeniedFlash(visible: false)),
    );
    await tester.pump();
    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0);
  });

  testWidgets('showAccessDeniedFlash inserts an overlay entry that removes itself', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAccessDeniedFlash(context),
            child: const Text('trigger'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ZUGRIFF VERWEIGERT'), findsOneWidget);

    // Let the auto-dismiss timers fire and clean up.
    await tester.pump(const Duration(milliseconds: 1300));
  });

  testWidgets('BlinkingDot renders and disposes cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BlinkingDot(color: Colors.green)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(BlinkingDot), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
  });
}
