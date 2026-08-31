import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/api_health_service.dart';
import 'package:jarvis_mobile/services/notification_hub_service.dart';
import 'package:jarvis_mobile/services/offline_llm_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/services/system_diagnostic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorageService extends SecureStorageService {
  final values = <String, String>{};
  bool throwOnWrite = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (throwOnWrite) throw Exception('secure storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeApiHealthService extends ApiHealthService {
  ApiHealthResult? nextResult;

  @override
  Future<ApiHealthResult> check(String backendUrl, {List<String> certPins = const [], Duration timeout = const Duration(seconds: 10)}) async {
    return nextResult ?? ApiHealthResult(reachable: false, checkedAt: DateTime.now(), error: 'no result configured');
  }
}

class _FakeOfflineLlmService extends OfflineLlmService {
  bool installed = false;

  @override
  Future<bool> isModelInstalled() async => installed;
}

class _FakeNotificationHubService extends NotificationHubService {
  bool enabled = false;

  @override
  Future<bool> isListenerEnabled() async => enabled;
}

void main() {
  late _FakeSecureStorageService secureStorage;
  late _FakeApiHealthService apiHealth;
  late SettingsService settings;
  late _FakeOfflineLlmService offlineLlm;
  late _FakeNotificationHubService notificationHub;
  late SystemDiagnosticService diagnostic;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage = _FakeSecureStorageService();
    apiHealth = _FakeApiHealthService();
    settings = SettingsService(secureStorage: secureStorage);
    offlineLlm = _FakeOfflineLlmService();
    notificationHub = _FakeNotificationHubService();
    diagnostic = SystemDiagnosticService(
      secureStorage: secureStorage,
      apiHealth: apiHealth,
      settings: settings,
      offlineLlm: offlineLlm,
      notificationHub: notificationHub,
    );
  });

  test('runSelfCheck returns one result per check', () async {
    final results = await diagnostic.runSelfCheck();
    expect(results.length, 6);
  });

  test('secure storage check passes on a successful round-trip', () async {
    final results = await diagnostic.runSelfCheck();
    final result = results.firstWhere((r) => r.label.contains('Sicherer Speicher'));
    expect(result.ok, isTrue);
  });

  test('secure storage check fails when writing throws', () async {
    secureStorage.throwOnWrite = true;
    final results = await diagnostic.runSelfCheck();
    final result = results.firstWhere((r) => r.label.contains('Sicherer Speicher'));
    expect(result.ok, isFalse);
  });

  test('API health check reflects reachability', () async {
    apiHealth.nextResult = ApiHealthResult(
      reachable: true,
      checkedAt: DateTime.now(),
      statusCode: 200,
      latency: const Duration(milliseconds: 88),
    );
    final results = await diagnostic.runSelfCheck();
    final result = results.firstWhere((r) => r.label.contains('KI-Server erreichbar'));
    expect(result.ok, isTrue);
    expect(result.detail, contains('88'));
  });

  test('offline model check reflects installed state', () async {
    offlineLlm.installed = true;
    final results = await diagnostic.runSelfCheck();
    final result = results.firstWhere((r) => r.label.contains('Offline-KI-Modell'));
    expect(result.ok, isTrue);
  });

  test('notification listener check reflects enabled state', () async {
    notificationHub.enabled = true;
    final results = await diagnostic.runSelfCheck();
    final result = results.firstWhere((r) => r.label.contains('Benachrichtigungszugriff'));
    expect(result.ok, isTrue);
  });

  test('a failing check does not prevent the others from running', () async {
    secureStorage.throwOnWrite = true;
    offlineLlm.installed = true;
    final results = await diagnostic.runSelfCheck();
    expect(results.length, 6);
    expect(results.firstWhere((r) => r.label.contains('Sicherer Speicher')).ok, isFalse);
    expect(results.firstWhere((r) => r.label.contains('Offline-KI-Modell')).ok, isTrue);
  });
}
