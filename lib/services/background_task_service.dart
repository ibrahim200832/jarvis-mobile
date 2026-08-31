import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'api_health_service.dart';
import 'backup_export_service.dart';
import 'dashboard_notification_service.dart';
import 'notification_service.dart';
import 'rss_feed_service.dart';
import 'settings_service.dart';
import 'todo_service.dart';

/// Task-name constants shared between registration calls and
/// [callbackDispatcher] below. Each future unit built on top of this
/// scaffold (RSS-Feed-Reader, verschlüsselter Backup-Export) gets one more
/// constant here and one more `case` in the dispatcher — this file stays
/// the reusable infrastructure, not a place for per-feature business logic.
class BackgroundTaskNames {
  static const rssFeedCheck = 'rssFeedCheck';
  static const weeklyBackupExport = 'weeklyBackupExport';
  static const dashboardRefresh = 'dashboardRefresh';
}

/// Notification id for proactive "new headlines" alerts fired from the
/// background RSS check — distinct from ProactiveBriefingService's
/// 9001-9003 and the late-night-tease emergency alert's 9004.
const rssHeadlinesNotificationId = 9005;

/// Thin wrapper around the `workmanager` plugin for genuine OS-scheduled
/// background execution that survives a fully closed app — unlike the
/// `flutter_local_notifications`-based proactive briefings in
/// `ProactiveBriefingService`, which only *display* pre-baked content at a
/// scheduled time, this actually runs Dart code in the background (fetch a
/// feed, write a backup file, ...).
///
/// Deliberately `kIsWeb`-gated: this app's web build has no service worker
/// set up for `workmanager`'s web backend (an experimental, PWA-only,
/// Chromium-only implementation with real limitations — see the
/// `workmanager` package docs), so every method below becomes a
/// predictable no-op on web instead of depending on a feature that isn't
/// wired up for this app's web target.
class BackgroundTaskService {
  BackgroundTaskService({SettingsService? settings}) : _settings = settings ?? SettingsService();

  final SettingsService _settings;
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    await Workmanager().initialize(callbackDispatcher);
    _initialized = true;
  }

  /// Registers or cancels the periodic RSS-feed-check task to match the
  /// current Einstellungen toggle (see SettingsService.getRssFeedCheckEnabled)
  /// — called on every app start (like ProactiveBriefingService.rescheduleAll)
  /// and right after the toggle is saved, so it takes effect immediately
  /// either way.
  Future<void> syncRssFeedTask() async {
    if (kIsWeb) return;
    if (await _settings.getRssFeedCheckEnabled()) {
      await registerPeriodic(
        BackgroundTaskNames.rssFeedCheck,
        BackgroundTaskNames.rssFeedCheck,
        frequency: const Duration(hours: 3),
      );
    } else {
      await cancelByUniqueName(BackgroundTaskNames.rssFeedCheck);
    }
  }

  /// Registers or cancels the weekly encrypted backup export task to match
  /// the current Einstellungen toggle (see
  /// SettingsService.getWeeklyBackupExportEnabled) — same on-every-app-start
  /// + on-toggle-save convention as [syncRssFeedTask].
  Future<void> syncBackupExportTask() async {
    if (kIsWeb) return;
    if (await _settings.getWeeklyBackupExportEnabled()) {
      await registerPeriodic(
        BackgroundTaskNames.weeklyBackupExport,
        BackgroundTaskNames.weeklyBackupExport,
        frequency: const Duration(days: 7),
      );
    } else {
      await cancelByUniqueName(BackgroundTaskNames.weeklyBackupExport);
    }
  }

  /// Registers or cancels the periodic dashboard-notification-refresh task
  /// to match the current Einstellungen toggle (see
  /// SettingsService.getDashboardNotificationEnabled) — same
  /// on-every-app-start + on-toggle-save convention as [syncRssFeedTask].
  /// 30 minutes is the real freshness mechanism here; the native widget's
  /// own updatePeriodMillis (Einheit 9) is just a fallback, since Android
  /// enforces a ~15-30 minute floor on periodic background work anyway.
  Future<void> syncDashboardTask() async {
    if (kIsWeb) return;
    if (await _settings.getDashboardNotificationEnabled()) {
      await registerPeriodic(
        BackgroundTaskNames.dashboardRefresh,
        BackgroundTaskNames.dashboardRefresh,
        frequency: const Duration(minutes: 30),
      );
    } else {
      await cancelByUniqueName(BackgroundTaskNames.dashboardRefresh);
    }
  }

  Future<void> registerPeriodic(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    Map<String, dynamic>? inputData,
  }) async {
    if (kIsWeb) return;
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      inputData: inputData,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> cancelByUniqueName(String uniqueName) async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await Workmanager().cancelAll();
  }
}

/// Runs in a separate, headless background isolate spawned by the OS — it
/// has no access to any state or service instances from the running app, so
/// each branch constructs whatever it needs from scratch. Must stay a
/// top-level function (not a method) for `workmanager` to find it via its
/// `@pragma('vm:entry-point')` marker.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask(dispatchBackgroundTask);
}

/// The actual per-task dispatch logic, pulled out of [callbackDispatcher] so
/// it's callable (and testable) without touching the real `Workmanager()`
/// plugin singleton, which has no platform-channel implementation available
/// under `flutter test`.
///
/// [rssFeedService]/[notificationService]/[backupExportService] are
/// test-only injection points (real instances are constructed when
/// omitted, exactly what [callbackDispatcher] does) — this headless
/// isolate has no DI container to pull real ones from anyway, and
/// `flutter test` has no platform-channel implementation for any of these
/// plugins, so a plain call with no overrides would throw under test.
@visibleForTesting
Future<bool> dispatchBackgroundTask(
  String task,
  Map<String, dynamic>? inputData, {
  RssFeedService? rssFeedService,
  NotificationService? notificationService,
  BackupExportService? backupExportService,
  DashboardNotificationService? dashboardNotificationService,
}) async {
  switch (task) {
    case BackgroundTaskNames.rssFeedCheck:
      final newItems = await (rssFeedService ?? RssFeedService()).checkForNewItems();
      final notification = buildRssNotification(newItems);
      if (notification != null) {
        await (notificationService ?? NotificationService()).showImmediateNotification(
          id: rssHeadlinesNotificationId,
          title: notification.title,
          body: notification.body,
        );
      }
      return true;
    case BackgroundTaskNames.weeklyBackupExport:
      await (backupExportService ?? BackupExportService()).exportNow();
      return true;
    case BackgroundTaskNames.dashboardRefresh:
      await (dashboardNotificationService ??
              DashboardNotificationService(
                notifications: NotificationService(),
                todos: TodoService(),
                apiHealth: ApiHealthService(),
                settings: SettingsService(),
              ))
          .refresh();
      return true;
    default:
      return true;
  }
}
