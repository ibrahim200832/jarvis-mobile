import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_mobile/services/crash_report_service.dart';
import 'package:jarvis_mobile/services/log_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    PackageInfo.setMockInitialValues(
      appName: 'JARVIS',
      packageName: 'com.jarvismobile.app',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    settings = SettingsService(secureStorage: _FakeSecureStorageService());
    // The session cap is a static counter shared across every instance for
    // the lifetime of the test process — reset it so one test's sends don't
    // count against another's.
    CrashReportService.resetSessionCountForTest();
  });

  LogEntry entry({LogLevel level = LogLevel.error}) => LogEntry(
    timestamp: DateTime.utc(2026, 1, 1),
    level: level,
    source: 'TestSource',
    message: 'something broke',
  );

  group('reportError', () {
    test('does nothing when crash reporting is disabled', () async {
      await settings.setCrashReportingEnabled(false);
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service = CrashReportService(settings: settings, client: client);

      await service.reportError(entry());

      expect(called, isFalse);
    });

    test('does nothing when the telemetry backend URL is empty', () async {
      await settings.setTelemetryBackendUrl('');
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service = CrashReportService(settings: settings, client: client);

      await service.reportError(entry());

      expect(called, isFalse);
    });

    test('POSTs the report to /report-error with the expected body', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      });
      final service = CrashReportService(settings: settings, client: client);

      await service.reportError(entry());

      expect(captured, isNotNull);
      expect(captured!.url.toString(), 'https://telemetry.example/report-error');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['level'], 'error');
      expect(body['source'], 'TestSource');
      expect(body['message'], 'something broke');
      expect(body['appVersion'], '1.2.3+45');
      expect(body['installId'], await settings.getInstallId());
    });

    test('a network failure is swallowed, never thrown', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      final client = MockClient((request) async => throw Exception('offline'));
      final service = CrashReportService(settings: settings, client: client);

      await service.reportError(entry());
    });

    test('stops sending once the per-session cap is reached', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('{}', 200);
      });
      final service = CrashReportService(settings: settings, client: client);

      for (var i = 0; i < CrashReportService.maxReportsPerSession + 5; i++) {
        await service.reportError(entry());
      }

      expect(callCount, CrashReportService.maxReportsPerSession);
    });
  });

  group('applyRemoteOverridesIfAny', () {
    test('applies a non-null forceLocalAiEnabled override', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setForceLocalAiEnabled(false);
      final client = MockClient((request) async => http.Response('{"forceLocalAiEnabled":true}', 200));
      final service = CrashReportService(settings: settings, client: client);

      await service.applyRemoteOverridesIfAny();

      expect(await settings.getForceLocalAiEnabled(), isTrue);
    });

    test('a null override leaves the local setting untouched', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setForceLocalAiEnabled(true);
      final client = MockClient((request) async => http.Response('{"forceLocalAiEnabled":null}', 200));
      final service = CrashReportService(settings: settings, client: client);

      await service.applyRemoteOverridesIfAny();

      expect(await settings.getForceLocalAiEnabled(), isTrue);
    });

    test('a non-200 response is ignored', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      await settings.setForceLocalAiEnabled(true);
      final client = MockClient((request) async => http.Response('', 500));
      final service = CrashReportService(settings: settings, client: client);

      await service.applyRemoteOverridesIfAny();

      expect(await settings.getForceLocalAiEnabled(), isTrue);
    });

    test('a network failure is swallowed, never thrown', () async {
      await settings.setTelemetryBackendUrl('https://telemetry.example');
      final client = MockClient((request) async => throw Exception('offline'));
      final service = CrashReportService(settings: settings, client: client);

      await service.applyRemoteOverridesIfAny();
    });
  });
}
