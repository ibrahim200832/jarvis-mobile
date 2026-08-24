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
}
