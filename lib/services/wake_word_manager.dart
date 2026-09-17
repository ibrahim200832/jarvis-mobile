import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'wake_word_task_handler.dart';

/// Starts/stops the always-on "Jarvis" wake-word listener as an Android
/// foreground service (persistent notification required by Android for
/// any service that keeps the microphone open in the background) — see
/// [WakeWordTaskHandler] for the actual detection logic.
class WakeWordManager {
  static bool _initialized = false;

  static void _ensureInit() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'jarvis_wake_word',
        channelName: 'JARVIS Weckwort',
        channelDescription: 'JARVIS hört im Hintergrund auf "Jarvis"',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  /// Returns null on success, or a human-readable error (e.g. missing
  /// permission) — permissions are requested first if not yet granted.
  static Future<String?> start() async {
    _ensureInit();

    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimizations();
    }

    try {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'JARVIS hört zu',
        notificationText: 'Sag "Jarvis", um mit mir zu sprechen.',
        callback: wakeWordTaskEntryPoint,
      );
      return null;
    } catch (e) {
      return 'Weckwort-Dienst konnte nicht gestartet werden: $e';
    }
  }

  static Future<void> stop() => FlutterForegroundTask.stopService();
}
