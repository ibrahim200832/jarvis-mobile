import 'package:permission_handler/permission_handler.dart';

import 'api_health_service.dart';
import 'notification_hub_service.dart';
import 'offline_llm_service.dart';
import 'secure_storage_service.dart';
import 'settings_service.dart';

/// Outcome of a single check within [SystemDiagnosticService.runSelfCheck].
class DiagnosticResult {
  DiagnosticResult({required this.label, required this.ok, this.detail});

  final String label;
  final bool ok;
  final String? detail;
}

/// Admin-Konsole "Selbsttest": aggregates the health of several existing,
/// independent services into one status overview. Each check is isolated
/// in its own try/catch — one failing check must never prevent the others
/// from running or crash the screen calling this.
class SystemDiagnosticService {
  SystemDiagnosticService({
    SecureStorageService? secureStorage,
    ApiHealthService? apiHealth,
    SettingsService? settings,
    OfflineLlmService? offlineLlm,
    NotificationHubService? notificationHub,
  }) : _secureStorage = secureStorage ?? SecureStorageService(),
       _apiHealth = apiHealth ?? ApiHealthService(),
       _settings = settings ?? SettingsService(),
       _offlineLlm = offlineLlm ?? OfflineLlmService(),
       _notificationHub = notificationHub ?? NotificationHubService();

  final SecureStorageService _secureStorage;
  final ApiHealthService _apiHealth;
  final SettingsService _settings;
  final OfflineLlmService _offlineLlm;
  final NotificationHubService _notificationHub;

  static const _testKey = 'system_diagnostic_test_key';
  static const _testValue = 'ok';

  /// A single check that hangs (e.g. an unresponsive native offline-model
  /// runtime) must not freeze the whole self-test — this bounds every check
  /// the same way the individual try/catch blocks already bound exceptions.
  static const _checkTimeout = Duration(seconds: 5);

  Future<List<DiagnosticResult>> runSelfCheck() async {
    return [
      await _withTimeout('Sicherer Speicher (AES-256)', _checkSecureStorage()),
      await _withTimeout('KI-Server erreichbar', _checkApiHealth()),
      await _withTimeout('Offline-KI-Modell installiert', _checkOfflineModel()),
      await _withTimeout('Benachrichtigungszugriff (Android)', _checkNotificationListener()),
      await _withTimeout('Mikrofon-Berechtigung', _checkPermission('Mikrofon-Berechtigung', Permission.microphone)),
      await _withTimeout('Kamera-Berechtigung', _checkPermission('Kamera-Berechtigung', Permission.camera)),
    ];
  }

  Future<DiagnosticResult> _withTimeout(String label, Future<DiagnosticResult> check) {
    return check.timeout(_checkTimeout, onTimeout: () => DiagnosticResult(label: label, ok: false, detail: 'Zeitüberschreitung'));
  }

  Future<DiagnosticResult> _checkSecureStorage() async {
    try {
      await _secureStorage.write(_testKey, _testValue);
      final readBack = await _secureStorage.read(_testKey);
      await _secureStorage.delete(_testKey);
      return DiagnosticResult(
        label: 'Sicherer Speicher (AES-256)',
        ok: readBack == _testValue,
        detail: readBack == _testValue ? 'Schreib-/Lese-Test erfolgreich' : 'Rundtrip-Test fehlgeschlagen',
      );
    } catch (e) {
      return DiagnosticResult(label: 'Sicherer Speicher (AES-256)', ok: false, detail: e.toString());
    }
  }

  Future<DiagnosticResult> _checkApiHealth() async {
    try {
      final backendUrl = await _settings.getAiBackendUrl();
      final certPins = await _settings.getCertPins();
      final result = await _apiHealth.check(backendUrl ?? '', certPins: certPins);
      return DiagnosticResult(
        label: 'KI-Server erreichbar',
        ok: result.reachable,
        detail: result.reachable ? '${result.latency?.inMilliseconds}ms' : result.error,
      );
    } catch (e) {
      return DiagnosticResult(label: 'KI-Server erreichbar', ok: false, detail: e.toString());
    }
  }

  Future<DiagnosticResult> _checkOfflineModel() async {
    try {
      final installed = await _offlineLlm.isModelInstalled();
      return DiagnosticResult(
        label: 'Offline-KI-Modell installiert',
        ok: installed,
        detail: installed ? null : 'Kein lokales Modell installiert',
      );
    } catch (e) {
      return DiagnosticResult(label: 'Offline-KI-Modell installiert', ok: false, detail: e.toString());
    }
  }

  Future<DiagnosticResult> _checkNotificationListener() async {
    try {
      final enabled = await _notificationHub.isListenerEnabled();
      return DiagnosticResult(
        label: 'Benachrichtigungszugriff (Android)',
        ok: enabled,
        detail: enabled ? null : 'Nicht erteilt oder nicht unterstützt',
      );
    } catch (e) {
      return DiagnosticResult(label: 'Benachrichtigungszugriff (Android)', ok: false, detail: e.toString());
    }
  }

  Future<DiagnosticResult> _checkPermission(String label, Permission permission) async {
    try {
      final status = await permission.status;
      return DiagnosticResult(label: label, ok: status.isGranted, detail: status.toString());
    } catch (e) {
      return DiagnosticResult(label: label, ok: false, detail: e.toString());
    }
  }
}
