import 'challenge_service.dart';
import 'gamification_service.dart';
import 'location_service.dart';
import 'news_service.dart';
import 'notes_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';
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
  static const morningHour = 7;
  static const eveningHour = 21;

  final NotificationService notifications;
  final WeatherService weather;
  final NewsService news;
  final NotesService notes;
  final LocationService location;
  final GamificationService gamification;
  final SettingsService settings;
  final ChallengeService challenges;

  ProactiveBriefingService({
    required this.notifications,
    required this.weather,
    required this.news,
    required this.notes,
    required this.location,
    required this.gamification,
    required this.settings,
    required this.challenges,
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

  Future<String> buildMorningBriefing() async {
    final buffer = StringBuffer('Guten Morgen!');
    buffer.write(await _weatherLine());
    final openNotes = await notes.list();
    if (openNotes.isNotEmpty) {
      buffer.write(' Du hast ${openNotes.length} offene Notiz${openNotes.length == 1 ? '' : 'en'}.');
    }
    buffer.write(await _newsLine());
    final challenge = await challenges.current();
    buffer.write('\n\nHeutige Challenge: ${challenge.text}');
    return buffer.toString();
  }

  Future<String> buildEveningSummary() async {
    final status = await gamification.statusText();
    return 'Guten Abend! $status';
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
  }
}
