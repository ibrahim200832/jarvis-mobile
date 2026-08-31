import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/log_service.dart';
import 'theme/jarvis_theme.dart';

/// Crash-Reporting & Logging: catches Flutter framework errors, uncaught
/// async errors, and (via LogService.error() calls elsewhere, e.g.
/// AiChatService's network failures) explicit API timeouts — all written
/// to a local log file reviewable via Einstellungen → Log-Viewer, so a
/// real-device issue can be diagnosed without a connected debugger.
void main() {
  final log = LogService();
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('de_DE');

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        originalOnError?.call(details);
        unawaited(log.error('FlutterError', details.exceptionAsString()));
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(log.error('PlatformDispatcher', error.toString()));
        return true;
      };

      runApp(const JarvisApp());
    },
    (error, stack) {
      unawaited(log.error('UncaughtZoneError', error.toString()));
    },
  );
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = buildJarvisTheme();
    return MaterialApp(
      title: 'J.A.R.V.I.S.',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
