import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

/// Task-name constants shared between registration calls and
/// [callbackDispatcher] below. Each future unit built on top of this
/// scaffold (RSS-Feed-Reader, verschlüsselter Backup-Export) gets one more
/// constant here and one more `case` in the dispatcher — this file stays
/// the reusable infrastructure, not a place for per-feature business logic.
class BackgroundTaskNames {
  static const rssFeedCheck = 'rssFeedCheck';
  static const weeklyBackupExport = 'weeklyBackupExport';
}

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
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    await Workmanager().initialize(callbackDispatcher);
    _initialized = true;
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
@visibleForTesting
Future<bool> dispatchBackgroundTask(String task, Map<String, dynamic>? inputData) async {
  switch (task) {
    case BackgroundTaskNames.rssFeedCheck:
      // Wired up in Runde 13, Einheit 4 (Web-Scraper & RSS-Feed-Reader).
      return true;
    case BackgroundTaskNames.weeklyBackupExport:
      // Wired up in Runde 13, Einheit 5 (verschlüsselter Backup-Export).
      return true;
    default:
      return true;
  }
}
