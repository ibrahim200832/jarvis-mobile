import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_mobile/screens/api_health_screen.dart';
import 'package:jarvis_mobile/services/api_health_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for flutter_secure_storage (no platform channel
/// available in `flutter test`), same pattern as
/// command_router_test.dart's FakeSecureStorageService.
class _FakeSecureStorageService extends SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows reachable status after a successful check', (tester) async {
    final client = MockClient((request) async => http.Response('', 200));
    final apiHealth = ApiHealthService(unpinnedClientFactory: () => client);
    final settings = SettingsService(secureStorage: _FakeSecureStorageService());
    await settings.setAiBackendUrl('https://example.workers.dev');

    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: ApiHealthScreen(apiHealth: apiHealth, settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('Erreichbar'), findsOneWidget);
    expect(find.textContaining('example.workers.dev'), findsOneWidget);
  });

  testWidgets('shows unreachable status with error detail on failure', (tester) async {
    final client = MockClient((request) async => throw Exception('boom'));
    final apiHealth = ApiHealthService(unpinnedClientFactory: () => client);
    final settings = SettingsService(secureStorage: _FakeSecureStorageService());
    await settings.setAiBackendUrl('https://example.workers.dev');

    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: ApiHealthScreen(apiHealth: apiHealth, settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('Nicht erreichbar'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('manual refresh re-runs the check', (tester) async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response('', 200);
    });
    final apiHealth = ApiHealthService(unpinnedClientFactory: () => client);
    final settings = SettingsService(secureStorage: _FakeSecureStorageService());
    await settings.setAiBackendUrl('https://example.workers.dev');

    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: ApiHealthScreen(apiHealth: apiHealth, settings: settings)));
    await tester.pumpAndSettle();
    expect(callCount, 1);

    await tester.tap(find.byTooltip('Jetzt prüfen'));
    await tester.pumpAndSettle();
    expect(callCount, 2);
  });

  testWidgets('empty backend URL shows the "not configured" state', (tester) async {
    final client = MockClient((request) async => http.Response('', 200));
    final apiHealth = ApiHealthService(unpinnedClientFactory: () => client);
    final settings = SettingsService(secureStorage: _FakeSecureStorageService());
    await settings.setAiBackendUrl('');

    await tester.pumpWidget(MaterialApp(theme: buildJarvisTheme(), home: ApiHealthScreen(apiHealth: apiHealth, settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('Kein eigener Server konfiguriert'), findsOneWidget);
  });
}
