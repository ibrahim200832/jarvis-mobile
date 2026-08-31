import 'api_health_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'todo_service.dart';

/// Builds and (re-)shows the persistent "Lockscreen-Dashboard" status
/// notification (see NotificationService.showOngoingNotification) — the
/// closest real equivalent of a lock-screen widget, since Android has had
/// no actual lock-screen widgets since v5.
class DashboardNotificationService {
  DashboardNotificationService({
    required this.notifications,
    required this.todos,
    required this.apiHealth,
    required this.settings,
  });

  final NotificationService notifications;
  final TodoService todos;
  final ApiHealthService apiHealth;
  final SettingsService settings;

  static const notificationId = 9006;

  Future<void> refresh() async {
    if (!await settings.getDashboardNotificationEnabled()) {
      await notifications.cancelOngoingNotification(notificationId);
      return;
    }

    final openCount = (await todos.openItems()).length;
    final todoLine = '$openCount offene Aufgabe${openCount == 1 ? '' : 'n'}';

    await notifications.showOngoingNotification(
      id: notificationId,
      title: 'J.A.R.V.I.S.',
      body: '${await _statusLine()} · $todoLine',
    );
  }

  Future<String> _statusLine() async {
    final backendUrl = await settings.getAiBackendUrl();
    if (backendUrl == null || backendUrl.trim().isEmpty) return 'Kein eigener Server konfiguriert';

    final certPins = await settings.getCertPins();
    final result = await apiHealth.check(backendUrl, certPins: certPins);
    if (!result.reachable) return 'Nicht erreichbar';
    final latencyMs = result.latency?.inMilliseconds;
    return latencyMs == null ? 'Online' : 'Online, ${latencyMs}ms';
  }
}
