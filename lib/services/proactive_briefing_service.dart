import 'package:shared_preferences/shared_preferences.dart';

import 'challenge_service.dart';
import 'gamification_service.dart';
import 'location_service.dart';
import 'news_service.dart';
import 'notes_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'todo_service.dart';
import 'weather_service.dart';

/// Builds and (re-)schedules the proactive morning-briefing / evening-
/// summary notifications. These fire as genuine OS-level daily alarms via
/// NotificationService (the same mechanism already used for timers), so
/// they arrive even with the app fully closed — but since there is no
/// background data fetch at the moment they actually fire, their content
/// reflects whatever was available the last time they were (re-)scheduled
/// (app start, or toggling the setting) rather than the exact fire moment.
class ProactiveBriefingService {
  static const morningNotificationId = 9001;
  static const eveningNotificationId = 9002;
  static const journalNotificationId = 9003;
  static const morningHour = 7;
  static const eveningHour = 21;
  static const journalHour = 21;
  static const journalMinute = 30;

  final NotificationService notifications;
  final WeatherService weather;
  final NewsService news;
  final NotesService notes;
  final LocationService location;
  final GamificationService gamification;
  final SettingsService settings;
  final ChallengeService challenges;
  final TodoService todos;

  ProactiveBriefingService({
    required this.notifications,
    required this.weather,
    required this.news,
    required this.notes,
    required this.location,
    required this.gamification,
    required this.settings,
    required this.challenges,
    required this.todos,
  });

  Future<String> _weatherLine() async {
    final key = await settings.getWeatherApiKey();
    if (key == null || key.isEmpty) return '';
    try {
      final loc = await location.current();
      final result = await weather.byCoordinates(key, loc.latitude, loc.longitude);
      return ' Wetter in ${result.city}: ${result.description}, ${result.tempCelsius.round()}°C.';
    } catch (_) {
      return '';
    }
  }

  Future<String> _newsLine() async {
    final key = await settings.getNewsApiKey();
    if (key == null || key.isEmpty) return '';
    try {
      final headlines = await news.topHeadlines(key);
      if (headlines.isEmpty) return '';
      return ' Top-Meldung: ${headlines.first}.';
    } catch (_) {
      return '';
    }
  }

  Future<String> _remindersLine() async {
    final reminders = await notifications.pendingReminderBodies();
    if (reminders.isEmpty) return '';
    return ' Anstehende Termine: ${reminders.join(', ')}.';
  }

  Future<String> buildMorningBriefing() async {
    final buffer = StringBuffer('Guten Morgen!');
    buffer.write(await _weatherLine());
    final openNotes = await notes.list();
    if (openNotes.isNotEmpty) {
      buffer.write(' Du hast ${openNotes.length} offene Notiz${openNotes.length == 1 ? '' : 'en'}.');
    }
    final openTodos = await todos.openItems();
    if (openTodos.isNotEmpty) {
      buffer.write(' Du hast ${openTodos.length} offene Aufgabe${openTodos.length == 1 ? '' : 'n'}.');
    }
    buffer.write(await _remindersLine());
    buffer.write(await _newsLine());
    final challenge = await challenges.current();
    buffer.write('\n\nHeutige Challenge: ${challenge.text}');
    return buffer.toString();
  }

  Future<String> buildEveningSummary() async {
    final status = await gamification.statusText();
    return 'Guten Abend! $status';
  }

  /// Static invitation text (no AI call at scheduling time) — the user
  /// replies via chat, which is where the actual reflection happens (see
  /// CommandRouter's journal handling).
  String buildJournalPrompt() => 'Wie war dein Tag? Erzähl mir kurz davon, wenn du magst.';

  static const _lastAudioBriefingKey = 'proactive_briefing_last_audio_delivered';

  /// Returns today's morning briefing text — with a sound intro spoken
  /// aloud by the caller — exactly once per day, the first time the app is
  /// opened at/after [morningHour], if the morning-briefing setting is
  /// enabled. Returns null otherwise (not due yet, already delivered today,
  /// or disabled).
  ///
  /// Honest limitation: this can only actually "auto-play" the moment the
  /// app is next opened, not while the phone is locked/the app is fully
  /// closed — there's no background audio playback here, same boundary as
  /// every other proactive-notification feature in this app.
  Future<String?> claimMorningAudioBriefingIfDue({DateTime? now}) async {
    if (!await settings.getMorningBriefingEnabled()) return null;
    final effectiveNow = now ?? DateTime.now();
    if (effectiveNow.hour < morningHour) return null;

    final prefs = await SharedPreferences.getInstance();
    final today = effectiveNow.toIso8601String().substring(0, 10);
    if (prefs.getString(_lastAudioBriefingKey) == today) return null;
    await prefs.setString(_lastAudioBriefingKey, today);

    return buildMorningBriefing();
  }

  /// Re-schedules both notifications based on the current Einstellungen
  /// (enabled/disabled) and freshest available data — call on app start and
  /// whenever the user changes the toggles.
  Future<void> rescheduleAll() async {
    if (await settings.getMorningBriefingEnabled()) {
      await notifications.scheduleDailyNotification(
        id: morningNotificationId,
        title: 'J.A.R.V.I.S. Morgen-Briefing',
        body: await buildMorningBriefing(),
        hour: morningHour,
        minute: 0,
      );
    } else {
      await notifications.cancelDailyNotification(morningNotificationId);
    }

    if (await settings.getEveningSummaryEnabled()) {
      await notifications.scheduleDailyNotification(
        id: eveningNotificationId,
        title: 'J.A.R.V.I.S. Abend-Zusammenfassung',
        body: await buildEveningSummary(),
        hour: eveningHour,
        minute: 0,
      );
    } else {
      await notifications.cancelDailyNotification(eveningNotificationId);
    }

    if (await settings.getEveningJournalEnabled()) {
      await notifications.scheduleDailyNotification(
        id: journalNotificationId,
        title: 'J.A.R.V.I.S. Tagebuch',
        body: buildJournalPrompt(),
        hour: journalHour,
        minute: journalMinute,
      );
    } else {
      await notifications.cancelDailyNotification(journalNotificationId);
    }
  }
}
