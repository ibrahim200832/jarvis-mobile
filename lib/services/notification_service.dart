import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules OS-level notifications for timers/reminders, so they still fire
/// even if the app is backgrounded or fully closed. TimerService's in-memory
/// dart:async.Timer (see timer_service.dart) only fires while the app
/// process is alive — this is a companion mechanism scheduled alongside it,
/// not a replacement, kept in its own service so TimerService itself stays
/// plugin-free and trivially unit-testable.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<void> scheduleTimerNotification({
    required int id,
    required String body,
    required Duration delay,
  }) async {
    await _ensureInitialized();
    final status = await Permission.notification.request();
    if (!status.isGranted) return;

    await _plugin.zonedSchedule(
      id: id,
      title: 'J.A.R.V.I.S.',
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'jarvis_timers',
          'Timer & Erinnerungen',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact scheduling avoids needing the separate, user-grantable
      // "exact alarm" permission Android 12+ requires for precise timing —
      // a few seconds/minutes of drift is fine for a casual reminder.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// Schedules a notification that repeats every day at [hour]:[minute] —
  /// a genuine OS-level daily alarm (fires even with the app fully closed,
  /// same mechanism as scheduleTimerNotification), used for the proactive
  /// morning-briefing/evening-summary feature. Content is fixed at
  /// scheduling time (see ProactiveBriefingService) since there's no
  /// background data fetch right before it fires.
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _ensureInitialized();
    final status = await Permission.notification.request();
    if (!status.isGranted) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'jarvis_briefing',
          'Tägliche Briefings',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyNotification(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }
}
