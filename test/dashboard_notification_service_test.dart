import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/api_health_service.dart';
import 'package:jarvis_mobile/services/dashboard_notification_service.dart';
import 'package:jarvis_mobile/services/notification_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/services/todo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  int showCount = 0;
  int cancelCount = 0;
  String? lastBody;

  @override
  Future<void> showOngoingNotification({required int id, required String title, required String body}) async {
    showCount++;
    lastBody = body;
  }

  @override
  Future<void> cancelOngoingNotification(int id) async {
    cancelCount++;
  }
}

class _FakeApiHealthService extends ApiHealthService {
  ApiHealthResult? nextResult;

  @override
  Future<ApiHealthResult> check(String backendUrl, {List<String> certPins = const [], Duration timeout = const Duration(seconds: 10)}) async {
    return nextResult ?? ApiHealthResult(reachable: false, checkedAt: DateTime.now(), error: 'no result configured');
  }
}

class _FakeSettingsService extends SettingsService {
  bool dashboardEnabled = true;
  String? backendUrl;

  @override
  Future<bool> getDashboardNotificationEnabled() async => dashboardEnabled;

  @override
  Future<String?> getAiBackendUrl() async => backendUrl;

  @override
  Future<List<String>> getCertPins() async => [];
}

void main() {
  late _FakeNotificationService notifications;
  late _FakeApiHealthService apiHealth;
  late _FakeSettingsService settings;
  late TodoService todos;
  late DashboardNotificationService dashboard;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifications = _FakeNotificationService();
    apiHealth = _FakeApiHealthService();
    settings = _FakeSettingsService();
    todos = TodoService();
    dashboard = DashboardNotificationService(
      notifications: notifications,
      todos: todos,
      apiHealth: apiHealth,
      settings: settings,
    );
  });

  test('cancels the notification and skips the check when disabled', () async {
    settings.dashboardEnabled = false;
    await dashboard.refresh();

    expect(notifications.cancelCount, 1);
    expect(notifications.showCount, 0);
  });

  test('reports no configured server when the backend URL is empty', () async {
    settings.backendUrl = '';
    await dashboard.refresh();

    expect(notifications.showCount, 1);
    expect(notifications.lastBody, contains('Kein eigener Server konfiguriert'));
  });

  test('reports latency when the backend is reachable', () async {
    settings.backendUrl = 'https://example.com';
    apiHealth.nextResult = ApiHealthResult(
      reachable: true,
      checkedAt: DateTime.now(),
      statusCode: 200,
      latency: const Duration(milliseconds: 142),
    );
    await dashboard.refresh();

    expect(notifications.lastBody, contains('Online, 142ms'));
  });

  test('currentStatusLine() exposes the same text used in the notification body', () async {
    settings.backendUrl = 'https://example.com';
    apiHealth.nextResult = ApiHealthResult(
      reachable: true,
      checkedAt: DateTime.now(),
      statusCode: 200,
      latency: const Duration(milliseconds: 99),
    );
    expect(await dashboard.currentStatusLine(), 'Online, 99ms');
  });

  test('reports unreachable when the backend check fails', () async {
    settings.backendUrl = 'https://example.com';
    apiHealth.nextResult = ApiHealthResult(reachable: false, checkedAt: DateTime.now(), error: 'timeout');
    await dashboard.refresh();

    expect(notifications.lastBody, contains('Nicht erreichbar'));
  });

  test('includes the open to-do count', () async {
    await todos.add('müll rausbringen');
    await todos.add('einkaufen');
    await dashboard.refresh();

    expect(notifications.lastBody, contains('2 offene Aufgaben'));
  });

  test('uses singular wording for exactly one open to-do', () async {
    await todos.add('müll rausbringen');
    await dashboard.refresh();

    expect(notifications.lastBody, contains('1 offene Aufgabe'));
    expect(notifications.lastBody, isNot(contains('1 offene Aufgaben')));
  });
}
