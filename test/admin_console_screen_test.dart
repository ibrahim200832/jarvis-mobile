import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/screens/admin_console_screen.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
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

/// This screen keeps growing across Runde 15's units — a tall test
/// viewport keeps every field inflated (ListView children outside the
/// default 600px-tall test surface + cache extent aren't inflated into
/// the element tree at all, so `find` can't see them) without needing
/// per-field dragUntilVisible calls that would need updating each time a
/// new section is added above an existing one.
Future<void> _pumpConsole(WidgetTester tester, SettingsService settings) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: AdminConsoleScreen(settings: settings)));
  await tester.pumpAndSettle();
}

void main() {
  late SettingsService settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(secureStorage: _FakeSecureStorageService());
  });

  testWidgets('loads previously saved values into the fields', (tester) async {
    await settings.setAiBackendUrl('https://example.com');
    await settings.setAiHmacSecret('top-secret');
    await settings.setCertPins(['pin-one', 'pin-two']);
    await settings.setAiModel('mistral');
    await settings.setSystemPromptOverride('Du bist ein Pirat.');

    await _pumpConsole(tester, settings);

    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('top-secret'), findsOneWidget);
    expect(find.text('pin-one\npin-two'), findsOneWidget);
    expect(find.text('Mistral'), findsOneWidget);
    expect(find.text('Du bist ein Pirat.'), findsOneWidget);
  });

  testWidgets('saving persists the entered values through SettingsService', (tester) async {
    await _pumpConsole(tester, settings);

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

    await _pumpConsole(tester, settings);

    await tester.enterText(find.widgetWithText(TextField, 'KI-Server-Schlüssel (Request-Signierung)'), '');
    await tester.tap(find.byKey(const Key('save-server-section')));
    await tester.pumpAndSettle();

    expect(await settings.getAiHmacSecret(), isNull);
  });

  testWidgets('saving the system prompt override persists it', (tester) async {
    await _pumpConsole(tester, settings);

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

    await _pumpConsole(tester, settings);

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

    await _pumpConsole(tester, settings);

    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();

    expect(find.text('still-saved'), findsNothing);
    expect(await settings.getSystemPromptOverride(), 'still-saved');
  });

  testWidgets('saving the default temperature persists 0.3', (tester) async {
    await _pumpConsole(tester, settings);

    expect(find.text('Temperatur: 0.30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-behavior-section')));
    await tester.pumpAndSettle();

    expect(await settings.getAiTemperature(), closeTo(0.3, 0.001));
  });
}
