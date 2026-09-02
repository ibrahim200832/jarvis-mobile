import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/services/telemetry_admin_service.dart';
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

  group('listInstalls', () {
    test('returns an empty list when no admin key is configured', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{"installs":[]}', 200);
      });
      final service = TelemetryAdminService(settings: settings, client: client);

      expect(await service.listInstalls(), isEmpty);
      expect(called, isFalse);
    });

    test('sends the admin key header and parses the response', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setAdminApiKey('shh-secret');
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'installs': [
              {
                'installId': 'install-a',
                'firstSeen': 1000,
                'lastSeen': 2000,
                'appVersion': '1.0.0+1',
                'platform': 'android',
                'errorCount': 3,
                'forceLocalAiEnabled': true,
              },
            ],
          }),
          200,
        );
      });
      final service = TelemetryAdminService(settings: settings, client: client);

      final installs = await service.listInstalls();

      expect(captured!.headers['X-Jarvis-Admin-Key'], 'shh-secret');
      expect(captured!.url.toString(), 'https://telemetry.example/admin/installs');
      expect(installs, hasLength(1));
      expect(installs.single.installId, 'install-a');
      expect(installs.single.errorCount, 3);
      expect(installs.single.forceLocalAiEnabled, isTrue);
    });

    test('a non-200 response yields an empty list', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setAdminApiKey('shh-secret');
      final client = MockClient((request) async => http.Response('', 401));
      final service = TelemetryAdminService(settings: settings, client: client);

      expect(await service.listInstalls(), isEmpty);
    });

    test('a network failure is swallowed, returning an empty list', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setAdminApiKey('shh-secret');
      final client = MockClient((request) async => throw Exception('offline'));
      final service = TelemetryAdminService(settings: settings, client: client);

      expect(await service.listInstalls(), isEmpty);
    });
  });

  group('getInstallErrors', () {
    test('sends the admin key header, URL-encodes the install ID, and parses errors', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setAdminApiKey('shh-secret');
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'errors': [
              {'level': 'error', 'source': 'FlutterError', 'message': 'boom', 'createdAt': 5000},
            ],
          }),
          200,
        );
      });
      final service = TelemetryAdminService(settings: settings, client: client);

      final errors = await service.getInstallErrors('install a/b');

      expect(captured!.headers['X-Jarvis-Admin-Key'], 'shh-secret');
      expect(captured!.url.toString(), contains(Uri.encodeComponent('install a/b')));
      expect(errors, hasLength(1));
      expect(errors.single.message, 'boom');
    });
  });

  group('setRemoteOverride', () {
    test('POSTs the override and reports success', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setAdminApiKey('shh-secret');
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      });
      final service = TelemetryAdminService(settings: settings, client: client);

      final success = await service.setRemoteOverride('install-a', forceLocalAi: true);

      expect(success, isTrue);
      expect(captured!.url.toString(), 'https://telemetry.example/admin/installs/install-a/config');
      expect(jsonDecode(captured!.body), {'forceLocalAiEnabled': true});
    });

    test('a null override clears it and is sent as JSON null', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setAdminApiKey('shh-secret');
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      });
      final service = TelemetryAdminService(settings: settings, client: client);

      await service.setRemoteOverride('install-a', forceLocalAi: null);

      expect(jsonDecode(captured!.body), {'forceLocalAiEnabled': null});
    });

    test('returns false without an admin key configured', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service = TelemetryAdminService(settings: settings, client: client);

      expect(await service.setRemoteOverride('install-a', forceLocalAi: true), isFalse);
      expect(called, isFalse);
    });

    test('a non-200 response reports failure', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setAdminApiKey('shh-secret');
      final client = MockClient((request) async => http.Response('', 500));
      final service = TelemetryAdminService(settings: settings, client: client);

      expect(await service.setRemoteOverride('install-a', forceLocalAi: true), isFalse);
    });
  });
}
