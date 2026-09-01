import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/screens/admin_console_screen.dart';
import 'package:jarvis_mobile/services/admin_auth_service.dart';
import 'package:jarvis_mobile/services/log_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for flutter_secure_storage, same fake as
/// settings_service_test.dart/command_router_test.dart.
class _FakeSecureStorageService extends SecureStorageService {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// This screen keeps growing across Runde 15/16's units — a tall test
/// viewport keeps every field inflated (ListView children outside the
/// default 600px-tall test surface + cache extent aren't inflated into
/// the element tree at all, so `find` can't see them) without needing
/// per-field dragUntilVisible calls that would need updating each time a
/// new section is added above an existing one.
///
/// AdminConsoleScreen now loads AdminAuthService.recentSuccessfulLogins()
/// (real dart:io via LogService) in initState()/_load() — same "chained
/// real I/O under testWidgets()'s fake-async zone" issue documented in
/// log_viewer_screen_test.dart, so this settles with alternating real
/// delays + pumps instead of a single pumpAndSettle() alone.
Future<void> _pumpConsole(
  WidgetTester tester,
  SettingsService settings, {
  required AdminAuthService adminAuth,
  Future<void> Function()? onClearAiMemory,
}) async {
  tester.view.physicalSize = const Size(800, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildJarvisTheme(),
      home: AdminConsoleScreen(
        settings: settings,
        onClearAiMemory: onClearAiMemory ?? () async {},
        adminAuth: adminAuth,
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;
  late SettingsService settings;
  late LogService log;
  late AdminAuthService adminAuth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('jarvis_admin_console_test_');
    settings = SettingsService(secureStorage: _FakeSecureStorageService());
    log = LogService(directoryOverride: tempDir);
    adminAuth = AdminAuthService(settings: settings, log: log);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // themeVariantNotifier is a process-wide singleton (see main.dart's
  // JarvisApp) — reset it after every test so a theme-switch test doesn't
  // leak state into whichever test runs next in this file.
  tearDown(() => themeVariantNotifier.value = ThemeVariant.gold);

  testWidgets('loads previously saved values into the fields', (tester) async {
    await settings.setAiBackendUrl('https://example.com');
    await settings.setAiHmacSecret('top-secret');
    await settings.setCertPins(['pin-one', 'pin-two']);
    await settings.setAiModel('mistral');
    await settings.setSystemPromptOverride('Du bist ein Pirat.');

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('top-secret'), findsOneWidget);
    expect(find.text('pin-one\npin-two'), findsOneWidget);
    expect(find.text('Mistral'), findsOneWidget);
    expect(find.text('Du bist ein Pirat.'), findsOneWidget);
  });

  testWidgets('saving persists the entered values through SettingsService', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    await tester.enterText(find.widgetWithText(TextField, 'KI-Server-Adresse (für freie Gespräche)'), 'https://jarvis.example');
    await tester.enterText(
      find.widgetWithText(TextField, 'KI-Server-Schlüssel (Request-Signierung)'),
      'a-new-secret',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'TLS-Zertifikat-Pins (Certificate Pinning)'),
      'only-pin',
    );
    await tester.tap(find.byKey(const Key('save-server-section')));
    await tester.pumpAndSettle();

    expect(await settings.getAiBackendUrl(), 'https://jarvis.example');
    expect(await settings.getAiHmacSecret(), 'a-new-secret');
    expect(await settings.getCertPins(), ['only-pin']);
  });

  testWidgets('an empty HMAC secret clears any previously saved one', (tester) async {
    await settings.setAiHmacSecret('will-be-cleared');

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    await tester.enterText(find.widgetWithText(TextField, 'KI-Server-Schlüssel (Request-Signierung)'), '');
    await tester.tap(find.byKey(const Key('save-server-section')));
    await tester.pumpAndSettle();

    expect(await settings.getAiHmacSecret(), isNull);
  });

  testWidgets('saving the system prompt override persists it', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    await tester.enterText(
      find.widgetWithText(TextField, 'System-Prompt (überschreibt JARVIS\' Standard-Persönlichkeit komplett)'),
      'Du bist ein Pirat.',
    );
    await tester.tap(find.byKey(const Key('save-behavior-section')));
    await tester.pumpAndSettle();

    expect(await settings.getSystemPromptOverride(), 'Du bist ein Pirat.');
  });

  testWidgets('an empty system prompt override clears a previously saved one', (tester) async {
    await settings.setSystemPromptOverride('will-be-cleared');

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    await tester.enterText(
      find.widgetWithText(TextField, 'System-Prompt (überschreibt JARVIS\' Standard-Persönlichkeit komplett)'),
      '',
    );
    await tester.tap(find.byKey(const Key('save-behavior-section')));
    await tester.pumpAndSettle();

    expect(await settings.getSystemPromptOverride(), isNull);
  });

  testWidgets('"Zurücksetzen" clears the system prompt field without saving', (tester) async {
    await settings.setSystemPromptOverride('still-saved');

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();

    expect(find.text('still-saved'), findsNothing);
    expect(await settings.getSystemPromptOverride(), 'still-saved');
  });

  testWidgets('saving the default temperature persists 0.3', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('Temperatur: 0.30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-behavior-section')));
    await tester.pumpAndSettle();

    expect(await settings.getAiTemperature(), closeTo(0.3, 0.001));
  });

  testWidgets('saving the default context length persists 8', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('Kontext-Länge: 8 Gesprächsrunden'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-behavior-section')));
    await tester.pumpAndSettle();

    expect(await settings.getMaxHistoryTurns(), 8);
  });

  testWidgets('loads a previously saved context length', (tester) async {
    await settings.setMaxHistoryTurns(3);

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('Kontext-Länge: 3 Gesprächsrunden'), findsOneWidget);
  });

  testWidgets('loads a previously saved model tier and lets it be changed', (tester) async {
    await settings.setAiModelTier('fast');

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('Schnell'), findsOneWidget);

    await tester.tap(find.text('Schnell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intelligent').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-server-section')));
    await tester.pumpAndSettle();

    expect(await settings.getAiModelTier(), 'smart');
  });

  testWidgets('shows today\'s locally-tracked request count', (tester) async {
    await settings.recordAiRequestToday();
    await settings.recordAiRequestToday();

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('Anfragen heute: 2'), findsOneWidget);
  });

  testWidgets('checking latency with an empty backend field reports it immediately, no network call', (tester) async {
    // getAiBackendUrl() defaults to this app's own default Worker URL, not
    // empty — clear the field explicitly so this exercises
    // ApiHealthService's synchronous "kein eigener Server konfiguriert"
    // path instead of attempting a real HTTP request (which the Flutter
    // test binding fakes as a 400 response, not a thrown exception).
    await _pumpConsole(tester, settings, adminAuth: adminAuth);
    await tester.enterText(find.widgetWithText(TextField, 'KI-Server-Adresse (für freie Gespräche)'), '');

    await tester.tap(find.text('Latenz jetzt prüfen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nicht erreichbar'), findsOneWidget);
    expect(find.textContaining('Kein eigener Server konfiguriert'), findsOneWidget);
  });

  testWidgets('running the self-check shows a result per check', (tester) async {
    // Unlike "Latenz jetzt prüfen" (which reads the live TextField),
    // _runDiagnostic() builds a fresh SystemDiagnosticService that reads
    // getAiBackendUrl() straight from SettingsService — which defaults to
    // this app's own default Worker URL, not empty. Clearing the TextField
    // alone wouldn't affect it, so persist the empty value directly to
    // avoid a real, sandbox-incompatible network request.
    await settings.setAiBackendUrl('');

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    await tester.tap(find.text('Selbsttest ausführen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sicherer Speicher'), findsOneWidget);
    expect(find.textContaining('KI-Server erreichbar'), findsOneWidget);
    expect(find.textContaining('Offline-KI-Modell'), findsOneWidget);
  });

  testWidgets('clearing AI memory asks for confirmation, then invokes the callback', (tester) async {
    var cleared = 0;
    await _pumpConsole(tester, settings, adminAuth: adminAuth, onClearAiMemory: () async => cleared++);

    await tester.tap(find.text('KI-Gedächtnis löschen'));
    await tester.pumpAndSettle();
    expect(find.text('KI-Gedächtnis löschen?'), findsOneWidget);
    expect(cleared, 0);

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(cleared, 1);
    expect(find.text('KI-Gedächtnis gelöscht.'), findsOneWidget);
  });

  testWidgets('cancelling the AI-memory confirmation does not invoke the callback', (tester) async {
    var cleared = 0;
    await _pumpConsole(tester, settings, adminAuth: adminAuth, onClearAiMemory: () async => cleared++);

    await tester.tap(find.text('KI-Gedächtnis löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(cleared, 0);
  });

  testWidgets('offers a button to run a backup now', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('Backup jetzt ausführen'), findsOneWidget);
  });

  testWidgets('offers a button to open the live log viewer', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(find.text('Live-Log-Viewer öffnen'), findsOneWidget);
  });

  testWidgets('force-local-AI toggle defaults to off and persists when switched on', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Lokale KI erzwingen')).value,
      isFalse,
    );

    await tester.tap(find.text('Lokale KI erzwingen'));
    await tester.pumpAndSettle();

    expect(await settings.getForceLocalAiEnabled(), isTrue);
  });

  testWidgets('Discord toggle defaults to off and persists when switched on', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    expect(
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Discord-Bot-Versand')).value,
      isFalse,
    );

    await tester.tap(find.text('Discord-Bot-Versand'));
    await tester.pumpAndSettle();

    expect(await settings.getDiscordWebhookEnabled(), isTrue);
  });

  testWidgets('defaults to the gold theme selected', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    final segmented = tester.widget<SegmentedButton<ThemeVariant>>(find.byType(SegmentedButton<ThemeVariant>));
    expect(segmented.selected, {ThemeVariant.gold});
  });

  testWidgets('picking Dark Cyan persists it and updates the live app theme', (tester) async {
    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    await tester.tap(find.text('Dark Cyan'));
    await tester.pumpAndSettle();

    expect(await settings.getThemeVariant(), ThemeVariant.cyan);
    expect(themeVariantNotifier.value, ThemeVariant.cyan);
  });

  testWidgets('loads a previously saved Dark Cyan choice', (tester) async {
    await settings.setThemeVariant(ThemeVariant.cyan);

    await _pumpConsole(tester, settings, adminAuth: adminAuth);

    final segmented = tester.widget<SegmentedButton<ThemeVariant>>(find.byType(SegmentedButton<ThemeVariant>));
    expect(segmented.selected, {ThemeVariant.cyan});
  });

  group('Zugang & Sicherheit', () {
    testWidgets('shows a hint instead of the password-change form when no credentials are set up', (
      tester,
    ) async {
      await _pumpConsole(tester, settings, adminAuth: adminAuth);

      expect(
        find.textContaining('Noch keine Zugangsdaten eingerichtet'),
        findsOneWidget,
      );
      expect(find.text('Passwort ändern'), findsNothing);
    });

    testWidgets('shows the Zugriffs-Log empty state when no logins have been recorded', (tester) async {
      await settings.setAdminCredentials('ibrahim', 'hunter2');

      await _pumpConsole(tester, settings, adminAuth: adminAuth);

      expect(find.text('Noch keine Anmeldung protokolliert.'), findsOneWidget);
    });

    testWidgets('shows recorded successful logins in the Zugriffs-Log', (tester) async {
      await settings.setAdminPin('1234');
      await tester.runAsync(() => adminAuth.unlock('1234'));

      await _pumpConsole(tester, settings, adminAuth: adminAuth);

      expect(find.textContaining('Angemeldet per PIN.'), findsOneWidget);
    });

    testWidgets('changing the password with the correct current password succeeds', (tester) async {
      await settings.setAdminCredentials('ibrahim', 'oldpass');

      await _pumpConsole(tester, settings, adminAuth: adminAuth);

      await tester.enterText(find.widgetWithText(TextField, 'Aktuelles Passwort'), 'oldpass');
      await tester.enterText(find.widgetWithText(TextField, 'Neues Passwort'), 'newpass');
      await tester.enterText(find.widgetWithText(TextField, 'Neues Passwort bestätigen'), 'newpass');
      await tester.tap(find.byKey(const Key('change-admin-password')));
      await tester.pumpAndSettle();

      expect(await settings.verifyAdminCredentials('ibrahim', 'oldpass'), isFalse);
      expect(await settings.verifyAdminCredentials('ibrahim', 'newpass'), isTrue);
      expect(find.text('Passwort geändert.'), findsOneWidget);
    });

    testWidgets('changing the password with the wrong current password fails, leaving it unchanged', (
      tester,
    ) async {
      await settings.setAdminCredentials('ibrahim', 'oldpass');

      await _pumpConsole(tester, settings, adminAuth: adminAuth);

      await tester.enterText(find.widgetWithText(TextField, 'Aktuelles Passwort'), 'wrong');
      await tester.enterText(find.widgetWithText(TextField, 'Neues Passwort'), 'newpass');
      await tester.enterText(find.widgetWithText(TextField, 'Neues Passwort bestätigen'), 'newpass');
      await tester.tap(find.byKey(const Key('change-admin-password')));
      await tester.pumpAndSettle();

      expect(find.text('Aktuelles Passwort ist falsch.'), findsOneWidget);
      expect(await settings.verifyAdminCredentials('ibrahim', 'oldpass'), isTrue);
    });

    testWidgets('firing onIdleTimeout pops the console back to the caller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminConsoleScreen(
                    settings: settings,
                    onClearAiMemory: () async {},
                    adminAuth: adminAuth,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminConsoleScreen), findsOneWidget);

      adminAuth.onIdleTimeout?.call();
      await tester.pumpAndSettle();

      expect(find.byType(AdminConsoleScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
