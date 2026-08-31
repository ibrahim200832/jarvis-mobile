import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/screens/log_viewer_screen.dart';
import 'package:jarvis_mobile/services/log_service.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';

void main() {
  late Directory tempDir;
  late LogService log;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jarvis_log_viewer_test_');
    log = LogService(directoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // LogService does real dart:io file I/O. Under testWidgets()'s default
  // fake-async test zone, real I/O completion is delivered via
  // scheduleMicrotask, which the fake-async zone intercepts into its own
  // queue instead of running immediately — so a single wait+pump only
  // advances one step of a chained await (e.g. readAll() does exists()
  // THEN readAsLines(), each its own real-I/O-then-fake-microtask hop).
  // Repeating short real-time waits + pump() several times lets each
  // hop resolve in turn until the widget's setState() rebuild lands.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
  }

  testWidgets('shows a placeholder when no log entries exist', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: LogViewerScreen(logService: log)));
    await settle(tester);

    expect(find.text('Keine Log-Einträge vorhanden.'), findsOneWidget);
  });

  testWidgets('shows logged entries with level and message', (tester) async {
    await tester.runAsync(() async {
      await log.error('TestSource', 'ein Testfehler');
      await log.info('TestSource', 'eine Info');
    });

    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: LogViewerScreen(logService: log)));
    await settle(tester);

    expect(find.text('ein Testfehler'), findsOneWidget);
    expect(find.text('eine Info'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);
    expect(find.text('INFO'), findsOneWidget);
  });

  testWidgets('clearing the log removes all entries from view', (tester) async {
    await tester.runAsync(() => log.error('TestSource', 'wird gleich gelöscht'));

    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: LogViewerScreen(logService: log)));
    await settle(tester);
    expect(find.text('wird gleich gelöscht'), findsOneWidget);

    await tester.tap(find.byTooltip('Leeren'));
    await settle(tester);

    expect(find.text('wird gleich gelöscht'), findsNothing);
    expect(find.text('Keine Log-Einträge vorhanden.'), findsOneWidget);
  });

  testWidgets('liveMode shows "(live)" in the title and cleans up its timer on dispose', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: LogViewerScreen(logService: log, liveMode: true)));
    await settle(tester);

    expect(find.text('Log-Viewer (live)'), findsOneWidget);

    // Unmount to trigger dispose() and cancel the periodic timer before the
    // test ends — otherwise Flutter's test framework reports "a Timer is
    // still pending".
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('non-live mode keeps the plain title', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: LogViewerScreen(logService: log)));
    await settle(tester);

    expect(find.text('Log-Viewer'), findsOneWidget);
    expect(find.text('Log-Viewer (live)'), findsNothing);
  });
}
