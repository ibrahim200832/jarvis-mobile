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

    await tester.pumpWidget(MaterialApp(home: AdminConsoleScreen(settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('top-secret'), findsOneWidget);
    expect(find.text('pin-one\npin-two'), findsOneWidget);
    expect(find.text('Mistral'), findsOneWidget);
  });

  testWidgets('saving persists the entered values through SettingsService', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AdminConsoleScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'KI-Server-Adresse (für freie Gespräche)'), 'https://jarvis.example');
    await tester.enterText(
      find.widgetWithText(TextField, 'KI-Server-Schlüssel (Request-Signierung)'),
      'a-new-secret',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'TLS-Zertifikat-Pins (Certificate Pinning)'),
      'only-pin',
    );
    await tester.dragUntilVisible(
      find.text('Speichern'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(await settings.getAiBackendUrl(), 'https://jarvis.example');
    expect(await settings.getAiHmacSecret(), 'a-new-secret');
    expect(await settings.getCertPins(), ['only-pin']);
  });

  testWidgets('an empty HMAC secret clears any previously saved one', (tester) async {
    await settings.setAiHmacSecret('will-be-cleared');

    await tester.pumpWidget(MaterialApp(home: AdminConsoleScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'KI-Server-Schlüssel (Request-Signierung)'), '');
    await tester.dragUntilVisible(
      find.text('Speichern'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(await settings.getAiHmacSecret(), isNull);
  });
}
