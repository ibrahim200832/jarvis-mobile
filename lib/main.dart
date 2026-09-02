import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/crash_report_service.dart';
import 'services/log_service.dart';
import 'services/settings_service.dart';
import 'theme/jarvis_theme.dart';

/// Crash-Reporting & Logging: catches Flutter framework errors, uncaught
/// async errors, and (via LogService.error() calls elsewhere, e.g.
/// AiChatService's network failures) explicit API timeouts — all written
/// to a local log file reviewable via Einstellungen → Log-Viewer, so a
/// real-device issue can be diagnosed without a connected debugger. Runde 21
/// additionally forwards every error (never warning/info) to
/// CrashReportService via LogService.onError, so the developer sees it too
/// — see that class's doc for exactly what is/isn't sent.
void main() {
  final log = LogService();
  log.onError = (entry) => unawaited(CrashReportService(settings: SettingsService()).reportError(entry));
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('de_DE');

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        originalOnError?.call(details);
        unawaited(log.error('FlutterError', _describeError(details.exceptionAsString(), details.stack)));
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(log.error('PlatformDispatcher', _describeError(error.toString(), stack)));
        return true;
      };

      runApp(const JarvisApp());
    },
    (error, stack) {
      unawaited(log.error('UncaughtZoneError', _describeError(error.toString(), stack)));
    },
  );
}

/// LogService's on-disk format is one entry per line, so a raw multi-line
/// stack trace would corrupt it (see LogEntry.toLine/tryParse) — this flattens
/// newlines and caps the length before it ever reaches log.error(...).
String _describeError(String summary, StackTrace? stack) {
  if (stack == null) return summary;
  final flatStack = stack.toString().replaceAll('\n', ' ').trim();
  final truncated = flatStack.length > 500 ? '${flatStack.substring(0, 500)}…' : flatStack;
  return '$summary | Stack: $truncated';
}

/// Stateful (rather than the previous StatelessWidget) so a theme change
/// made deep in the navigation stack (Admin-Konsole "Erscheinungsbild") can
/// rebuild MaterialApp's theme immediately via themeVariantNotifier, without
/// requiring a full app restart.
class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});

  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  @override
  void initState() {
    super.initState();
    _loadStoredThemeVariant();
  }

  Future<void> _loadStoredThemeVariant() async {
    themeVariantNotifier.value = await SettingsService().getThemeVariant();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeVariant>(
      valueListenable: themeVariantNotifier,
      builder: (context, variant, _) {
        final theme = buildJarvisTheme(variant: variant);
        return MaterialApp(
          title: 'J.A.R.V.I.S.',
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          home: const HomeScreen(),
        );
      },
    );
  }
}
