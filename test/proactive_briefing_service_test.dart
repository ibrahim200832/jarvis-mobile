import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/ai_chat_service.dart';
import 'package:jarvis_mobile/services/challenge_service.dart';
import 'package:jarvis_mobile/services/gamification_service.dart';
import 'package:jarvis_mobile/services/location_service.dart';
import 'package:jarvis_mobile/services/news_service.dart';
import 'package:jarvis_mobile/services/notes_service.dart';
import 'package:jarvis_mobile/services/notification_hub_service.dart';
import 'package:jarvis_mobile/services/notification_service.dart';
import 'package:jarvis_mobile/services/proactive_briefing_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/services/todo_service.dart';
import 'package:jarvis_mobile/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNewsService extends NewsService {
  @override
  Future<List<String>> topHeadlines(String apiKey, {String country = 'de'}) async => ['Erste Meldung'];
}

class _FakeWeatherService extends WeatherService {
  @override
  Future<WeatherResult> byCoordinates(String apiKey, double lat, double lon) async =>
      WeatherResult(description: 'bewölkt', tempCelsius: 10.0, city: 'Irgendwo');
}

class _FakeLocationService extends LocationService {
  @override
  Future<LocationResult> current() async =>
      LocationResult(latitude: 52.5, longitude: 13.4, city: 'Berlin', country: 'Deutschland');
}

class _FakeSettingsService extends SettingsService {
  String? weatherApiKey = 'test-key';
  String? newsApiKey = 'test-key';
  bool morningEnabled = true;
  bool notificationHubEnabled = false;
  bool notificationDigestAiEnabled = false;
  String? aiBackendUrl;

  @override
  Future<String?> getWeatherApiKey() async => weatherApiKey;

  @override
  Future<String?> getNewsApiKey() async => newsApiKey;

  @override
  Future<bool> getMorningBriefingEnabled() async => morningEnabled;

  @override
  Future<bool> getNotificationHubEnabled() async => notificationHubEnabled;

  @override
  Future<bool> getNotificationDigestAiEnabled() async => notificationDigestAiEnabled;

  @override
  Future<String?> getAiBackendUrl() async => aiBackendUrl;

  // Avoids touching the real (unmocked) flutter_secure_storage platform
  // channel that the base class's getAiHmacSecret()/getCertPins() would
  // otherwise hit under `flutter test` — this fake has no injected secure
  // storage, unlike command_router_test.dart's FakeSettingsService.
  @override
  Future<String?> getAiHmacSecret() async => null;

  @override
  Future<List<String>> getCertPins() async => [];
}

class _FakeNotificationHubService extends NotificationHubService {
  List<CapturedNotification> itemsToReturn = [];

  @override
  Future<List<CapturedNotification>> getCaptured() async => itemsToReturn;
}

class _FakeAiChatService extends AiChatService {
  int askNotificationDigestCallCount = 0;
  String? lastItemsSummary;

  @override
  Future<AiChatResult> askNotificationDigest(
    String backendUrl,
    String itemsSummary, {
    String? hmacSecret,
    List<String> certPins = const [],
  }) async {
    askNotificationDigestCallCount++;
    lastItemsSummary = itemsSummary;
    return AiChatResult(reply: 'FAKE_AI_DIGEST');
  }
}

class _FakeNotificationService extends NotificationService {
  List<String> reminderBodies = [];

  @override
  Future<List<String>> pendingReminderBodies() async => reminderBodies;

  @override
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> cancelDailyNotification(int id) async {}
}

void main() {
  late ProactiveBriefingService briefing;
  late _FakeSettingsService settings;
  late _FakeNotificationService notifications;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = _FakeSettingsService();
    notifications = _FakeNotificationService();
    briefing = ProactiveBriefingService(
      notifications: notifications,
      weather: _FakeWeatherService(),
      news: _FakeNewsService(),
      notes: NotesService(),
      location: _FakeLocationService(),
      gamification: GamificationService(),
      settings: settings,
      challenges: ChallengeService(),
      todos: TodoService(),
      notificationHub: NotificationHubService(),
      aiChat: AiChatService(),
    );
  });

  group('buildMorningBriefing - Termine', () {
    test('includes pending reminders when present', () async {
      notifications.reminderBodies = ['⏰ „Zahnarzt" ist abgelaufen!'];
      final text = await briefing.buildMorningBriefing();
      expect(text, contains('Anstehende Termine'));
      expect(text, contains('Zahnarzt'));
    });

    test('omits the reminders line when none are pending', () async {
      notifications.reminderBodies = [];
      final text = await briefing.buildMorningBriefing();
      expect(text, isNot(contains('Anstehende Termine')));
    });
  });

  group('buildMorningBriefing - Aufgaben', () {
    test('includes an open-todo count when to-dos exist', () async {
      final todos = TodoService();
      await todos.add('müll rausbringen');
      briefing = ProactiveBriefingService(
        notifications: notifications,
        weather: _FakeWeatherService(),
        news: _FakeNewsService(),
        notes: NotesService(),
        location: _FakeLocationService(),
        gamification: GamificationService(),
        settings: settings,
        challenges: ChallengeService(),
        todos: todos,
        notificationHub: NotificationHubService(),
        aiChat: AiChatService(),
      );
      final text = await briefing.buildMorningBriefing();
      expect(text, contains('1 offene Aufgabe'));
    });

    test('omits the to-do line when none are open', () async {
      final text = await briefing.buildMorningBriefing();
      expect(text, isNot(contains('offene Aufgabe')));
    });
  });

  group('buildEveningSummary - Benachrichtigungs-Zusammenfasser', () {
    late _FakeNotificationHubService notificationHub;
    late _FakeAiChatService fakeAiChat;

    setUp(() {
      notificationHub = _FakeNotificationHubService();
      fakeAiChat = _FakeAiChatService();
      briefing = ProactiveBriefingService(
        notifications: notifications,
        weather: _FakeWeatherService(),
        news: _FakeNewsService(),
        notes: NotesService(),
        location: _FakeLocationService(),
        gamification: GamificationService(),
        settings: settings,
        challenges: ChallengeService(),
        todos: TodoService(),
        notificationHub: notificationHub,
        aiChat: fakeAiChat,
      );
    });

    test('omits the digest entirely when the feature is disabled', () async {
      settings.notificationHubEnabled = false;
      notificationHub.itemsToReturn = [
        CapturedNotification(packageName: 'com.whatsapp', title: 'x', text: 'y', postedAt: DateTime(2026, 1, 1)),
      ];
      final text = await briefing.buildEveningSummary();
      expect(text, isNot(contains('Benachrichtigungen:')));
      expect(fakeAiChat.askNotificationDigestCallCount, 0);
    });

    test('omits the digest when enabled but nothing was captured', () async {
      settings.notificationHubEnabled = true;
      notificationHub.itemsToReturn = [];
      final text = await briefing.buildEveningSummary();
      expect(text, isNot(contains('Benachrichtigungen:')));
    });

    test('uses the local rule-based digest when AI summarization is off', () async {
      settings.notificationHubEnabled = true;
      settings.notificationDigestAiEnabled = false;
      settings.aiBackendUrl = 'https://example.com';
      notificationHub.itemsToReturn = [
        CapturedNotification(packageName: 'com.whatsapp', title: 'x', text: 'hallo', postedAt: DateTime(2026, 1, 1)),
      ];
      final text = await briefing.buildEveningSummary();
      expect(text, contains('Benachrichtigungen:'));
      expect(text, contains('Whatsapp'));
      expect(fakeAiChat.askNotificationDigestCallCount, 0);
    });

    test('uses the local rule-based digest when AI is on but no custom backend is configured', () async {
      settings.notificationHubEnabled = true;
      settings.notificationDigestAiEnabled = true;
      settings.aiBackendUrl = null;
      notificationHub.itemsToReturn = [
        CapturedNotification(packageName: 'com.whatsapp', title: 'x', text: 'hallo', postedAt: DateTime(2026, 1, 1)),
      ];
      final text = await briefing.buildEveningSummary();
      expect(text, contains('Whatsapp'));
      expect(fakeAiChat.askNotificationDigestCallCount, 0);
    });

    test('calls the AI digest only when both AI summarization is on AND a custom backend is set', () async {
      settings.notificationHubEnabled = true;
      settings.notificationDigestAiEnabled = true;
      settings.aiBackendUrl = 'https://example.com';
      notificationHub.itemsToReturn = [
        CapturedNotification(packageName: 'com.whatsapp', title: 'x', text: 'hallo', postedAt: DateTime(2026, 1, 1)),
      ];
      final text = await briefing.buildEveningSummary();
      expect(fakeAiChat.askNotificationDigestCallCount, 1);
      expect(text, contains('FAKE_AI_DIGEST'));
    });
  });

  group('claimMorningAudioBriefingIfDue', () {
    test('returns null before the morning hour', () async {
      final result = await briefing.claimMorningAudioBriefingIfDue(now: DateTime(2026, 1, 1, 6, 59));
      expect(result, isNull);
    });

    test('returns the briefing text at/after the morning hour', () async {
      final result = await briefing.claimMorningAudioBriefingIfDue(now: DateTime(2026, 1, 1, 7, 0));
      expect(result, isNotNull);
      expect(result, contains('Guten Morgen'));
    });

    test('returns null when the morning briefing setting is disabled', () async {
      settings.morningEnabled = false;
      final result = await briefing.claimMorningAudioBriefingIfDue(now: DateTime(2026, 1, 1, 8, 0));
      expect(result, isNull);
    });

    test('only claims once per day', () async {
      final first = await briefing.claimMorningAudioBriefingIfDue(now: DateTime(2026, 1, 1, 8, 0));
      final second = await briefing.claimMorningAudioBriefingIfDue(now: DateTime(2026, 1, 1, 20, 0));
      expect(first, isNotNull);
      expect(second, isNull);
    });

    test('claims again on a new day', () async {
      final first = await briefing.claimMorningAudioBriefingIfDue(now: DateTime(2026, 1, 1, 8, 0));
      final second = await briefing.claimMorningAudioBriefingIfDue(now: DateTime(2026, 1, 2, 8, 0));
      expect(first, isNotNull);
      expect(second, isNotNull);
    });
  });
}
