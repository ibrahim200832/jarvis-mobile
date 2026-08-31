import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:installed_apps/app_info.dart';
import 'package:jarvis_mobile/core/command_router.dart';
import 'package:jarvis_mobile/services/ai_chat_service.dart';
import 'package:jarvis_mobile/services/ambient_sound_service.dart';
import 'package:jarvis_mobile/services/anime_service.dart';
import 'package:jarvis_mobile/services/app_launcher_service.dart';
import 'package:jarvis_mobile/services/app_lock_service.dart';
import 'package:jarvis_mobile/services/backup_export_service.dart';
import 'package:jarvis_mobile/services/call_service.dart';
import 'package:jarvis_mobile/services/challenge_service.dart';
import 'package:jarvis_mobile/services/code_snippet_service.dart';
import 'package:jarvis_mobile/services/contacts_service.dart';
import 'package:jarvis_mobile/services/device_info_service.dart';
import 'package:jarvis_mobile/services/email_service.dart';
import 'package:jarvis_mobile/services/gamification_service.dart';
import 'package:jarvis_mobile/services/home_assistant_service.dart';
import 'package:jarvis_mobile/services/ip_service.dart';
import 'package:jarvis_mobile/services/joke_service.dart';
import 'package:jarvis_mobile/services/journal_service.dart';
import 'package:jarvis_mobile/services/late_night_tease_service.dart';
import 'package:jarvis_mobile/services/location_service.dart';
import 'package:jarvis_mobile/services/mood_capture_service.dart';
import 'package:jarvis_mobile/services/music_dj_service.dart';
import 'package:jarvis_mobile/services/news_service.dart';
import 'package:jarvis_mobile/services/notes_service.dart';
import 'package:jarvis_mobile/services/notification_hub_service.dart';
import 'package:jarvis_mobile/services/proactive_briefing_service.dart';
import 'package:jarvis_mobile/services/notification_service.dart';
import 'package:jarvis_mobile/services/qr_service.dart';
import 'package:jarvis_mobile/services/random_fun_service.dart';
import 'package:jarvis_mobile/services/rpg_service.dart';
import 'package:jarvis_mobile/services/rss_feed_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/security_breach_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/services/soundboard_service.dart';
import 'package:jarvis_mobile/services/spotify_service.dart';
import 'package:jarvis_mobile/services/timer_service.dart';
import 'package:jarvis_mobile/services/todo_service.dart';
import 'package:jarvis_mobile/services/weather_service.dart';
import 'package:jarvis_mobile/services/web_search_service.dart';
import 'package:jarvis_mobile/services/offline_llm_service.dart';
import 'package:jarvis_mobile/services/webdav_sync_service.dart';
import 'package:jarvis_mobile/services/whatsapp_service.dart';
import 'package:jarvis_mobile/services/wikipedia_service.dart';
import 'package:jarvis_mobile/services/youtube_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Fakes: real network/platform calls are never touched by these tests. ---

/// A loud, high-pitched, fast-alternating synthetic sample — deterministically
/// classifies as VoiceMood.stressed (see mood_classifier_test.dart for the
/// isolated classification logic; this is just a fixed fixture for
/// CommandRouter-level wiring tests).
Int16List _loudSquareWaveSample({int length = 4000}) =>
    Int16List.fromList(List.generate(length, (i) => i.isEven ? 30000 : -30000));

class FakeWikipediaService extends WikipediaService {
  String? lastQuery;

  @override
  Future<String> summary(String query, {String lang = 'de'}) async {
    lastQuery = query;
    return 'WIKI:$query';
  }
}

class FakeJokeService extends JokeService {
  @override
  String randomJoke() => 'Ein Testwitz.';
}

class FakeNewsService extends NewsService {
  List<String> headlines = ['Erste Meldung', 'Zweite Meldung'];

  @override
  Future<List<String>> topHeadlines(String apiKey, {String country = 'de'}) async => headlines;
}

class FakeWeatherService extends WeatherService {
  @override
  Future<WeatherResult> byCity(String apiKey, String city) async =>
      WeatherResult(description: 'sonnig', tempCelsius: 21.5, city: city);

  @override
  Future<WeatherResult> byCoordinates(String apiKey, double lat, double lon) async =>
      WeatherResult(description: 'bewölkt', tempCelsius: 10.0, city: 'Irgendwo');
}

class FakeAnimeService extends AnimeService {
  AnimeResult? nextResult = AnimeResult(
    title: 'Hyouka',
    description: 'Ein Mitglied des Klassik-Klubs löst kleine Alltagsrätsel.',
    episodesOrChapters: 22,
    status: 'FINISHED',
    averageScore: 82,
    genres: ['Mystery', 'Slice of Life'],
    year: 2012,
  );

  @override
  Future<AnimeResult?> searchAnime(String title) async => nextResult;

  @override
  Future<AnimeResult?> searchManga(String title) async => nextResult;
}

/// In-memory stand-in for RssFeedService — real network calls are never
/// touched by these tests. checkForNewItems() returns whatever the test
/// pre-seeds via [nextNewItems] instead of actually fetching feeds.
class FakeRssFeedService extends RssFeedService {
  final _feeds = <RssFeedSource>[];
  List<RssItem> nextNewItems = [];
  String? lastAddedUrl;
  bool throwOnAdd = false;

  @override
  Future<List<RssFeedSource>> listFeeds() async => List.unmodifiable(_feeds);

  @override
  Future<RssFeedSource> addFeed(String url) async {
    lastAddedUrl = url;
    if (throwOnAdd) throw StateError('Kein RSS/Atom-Feed unter dieser Adresse gefunden.');
    final source = RssFeedSource(url: url, title: 'Test-Feed');
    _feeds.add(source);
    return source;
  }

  @override
  Future<void> removeFeed(String url) async {
    _feeds.removeWhere((f) => f.url == url);
  }

  @override
  Future<List<RssItem>> checkForNewItems() async => nextNewItems;
}

/// In-memory-ish stand-in for BackupExportService. exportNow() still writes
/// a small real temp file (so `File.length()` in CommandRouter works
/// without throwing) but skips the real archive/encrypt logic — that gets
/// its own dedicated backup_export_service_test.dart instead.
class FakeBackupExportService extends BackupExportService {
  int exportCount = 0;
  bool restoreResult = true;
  DateTime? fakeLastExport;

  @override
  Future<File> exportNow() async {
    exportCount++;
    fakeLastExport = DateTime.now();
    final file = File('${Directory.systemTemp.path}/fake_jarvis_backup_test.bin');
    await file.writeAsBytes(List.filled(2048, 0));
    return file;
  }

  @override
  Future<bool> restoreFromDisk() async => restoreResult;

  @override
  Future<DateTime?> lastExportTime() async => fakeLastExport;
}

/// In-memory stand-in for WebDavSyncService — real network calls are never
/// touched by these tests.
class FakeWebDavSyncService extends WebDavSyncService {
  int uploadCount = 0;
  int downloadCount = 0;
  bool throwOnUpload = false;
  bool throwOnDownload = false;

  @override
  Future<void> upload({required String baseUrl, required String username, required String password}) async {
    if (throwOnUpload) throw StateError('WebDAV-Upload fehlgeschlagen (Code 500).');
    uploadCount++;
  }

  @override
  Future<void> download({required String baseUrl, required String username, required String password}) async {
    if (throwOnDownload) throw StateError('Auf dem WebDAV-Server liegt noch kein Backup.');
    downloadCount++;
  }
}

/// In-memory stand-in for OfflineLlmService — the real one talks to the
/// flutter_gemma plugin, which has no platform-channel/FFI implementation
/// available under `flutter test`.
class FakeOfflineLlmService extends OfflineLlmService {
  bool installed = false;
  String nextReply = 'Offline-Testantwort.';

  @override
  Future<bool> isModelInstalled() async => installed;

  @override
  Future<String> ask(String prompt, {String systemInstruction = ''}) async => nextReply;
}

class FakeWebSearchService extends WebSearchService {
  String? lastBackendUrl;
  String? lastQuery;
  List<WebSearchResult> results = [WebSearchResult('Titel', 'Web-Ergebnis-Text')];

  @override
  Future<List<WebSearchResult>> search(String backendUrl, String query) async {
    lastBackendUrl = backendUrl;
    lastQuery = query;
    return results;
  }
}

class FakeWhatsappService extends WhatsappService {
  String? lastPhone;
  String? lastMessage;

  @override
  Future<bool> sendMessage({required String phone, required String message}) async {
    lastPhone = phone;
    lastMessage = message;
    return true;
  }
}

class FakeEmailService extends EmailService {
  String? lastTo;

  @override
  Future<bool> compose({required String to, required String subject, required String body}) async {
    lastTo = to;
    return true;
  }
}

class FakeCallService extends CallService {
  String? lastPhone;

  @override
  Future<bool> call(String phone) async {
    lastPhone = phone;
    return true;
  }
}

class FakeAppLauncherService extends AppLauncherService {
  @override
  Future<AppInfo?> findByName(String name) async => null;

  @override
  Future<bool> open(String packageName) async => true;
}

class FakeYoutubeService extends YoutubeService {
  String? lastQuery;

  @override
  Future<bool> search(String query) async {
    lastQuery = query;
    return true;
  }
}

class FakeLocationService extends LocationService {
  @override
  Future<LocationResult> current() async =>
      LocationResult(latitude: 52.5, longitude: 13.4, city: 'Berlin', country: 'Deutschland');
}

class FakeContactsService extends ContactsService {
  Contact? contactToReturn;

  @override
  Future<Contact?> find(String name) async => contactToReturn;
}

/// In-memory stand-in for flutter_secure_storage, which has no platform
/// channel available in `flutter test` — used wherever a *Service reads
/// through SecureStorageService, so real plugin code is never touched.
class FakeSecureStorageService extends SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService() : super(secureStorage: FakeSecureStorageService());

  String? weatherApiKey = 'test-key';
  String? newsApiKey = 'test-key';
  String? aiBackendUrl = '';
  String aiModel = 'openai';
  String persona = 'standard';

  @override
  Future<String?> getWeatherApiKey() async => weatherApiKey;

  @override
  Future<String?> getNewsApiKey() async => newsApiKey;

  @override
  Future<String?> getAiBackendUrl() async => aiBackendUrl;

  @override
  Future<String> getAiModel() async => aiModel;

  @override
  Future<String> getPersona() async => persona;

  @override
  Future<void> setPersona(String value) async {
    persona = value;
  }
}

class FakeIpService extends IpService {
  @override
  Future<String> publicIp() async => '1.2.3.4';
}

class FakeAiChatService extends AiChatService {
  String? lastMessage;
  List<AiTurn>? lastHistory;
  AiAction? nextAction;
  String? lastStoryMessage;
  List<AiTurn>? lastStoryHistory;
  String? lastStoryGenre;
  String? lastPersona;
  double? lastSarcasm;
  String? lastRpgMessage;
  List<AiTurn>? lastRpgHistory;
  String? lastRpgStatsSummary;
  int askRpgCallCount = 0;
  String? lastJournalDayText;
  int askJournalCallCount = 0;
  String? lastHmacSecret;
  List<String>? lastCertPins;
  int askNotificationDigestCallCount = 0;
  String? lastNotificationDigestSummary;

  @override
  Future<AiChatResult> ask(
    String backendUrl,
    String message, {
    String model = 'openai',
    List<AiTurn> history = const [],
    double sarcasm = 0.3,
    String persona = 'standard',
    String? hmacSecret,
    List<String> certPins = const [],
  }) async {
    lastMessage = message;
    lastHistory = history;
    lastPersona = persona;
    lastSarcasm = sarcasm;
    lastHmacSecret = hmacSecret;
    lastCertPins = certPins;
    return AiChatResult(reply: 'FAKE_AI:$message', action: nextAction);
  }

  @override
  Future<AiChatResult> askStory(
    String backendUrl,
    String message, {
    required String genre,
    List<AiTurn> history = const [],
    String? hmacSecret,
    List<String> certPins = const [],
  }) async {
    lastStoryMessage = message;
    lastStoryHistory = history;
    lastStoryGenre = genre;
    lastHmacSecret = hmacSecret;
    lastCertPins = certPins;
    return AiChatResult(reply: 'FAKE_STORY[$genre]:$message');
  }

  @override
  Future<AiChatResult> askRpg(
    String backendUrl,
    String message, {
    required String statsSummary,
    List<AiTurn> history = const [],
    String? hmacSecret,
    List<String> certPins = const [],
  }) async {
    askRpgCallCount++;
    lastRpgMessage = message;
    lastRpgHistory = history;
    lastRpgStatsSummary = statsSummary;
    lastHmacSecret = hmacSecret;
    lastCertPins = certPins;
    return AiChatResult(reply: 'FAKE_RPG:$message');
  }

  @override
  Future<AiChatResult> askJournal(
    String backendUrl,
    String dayText, {
    String? hmacSecret,
    List<String> certPins = const [],
  }) async {
    askJournalCallCount++;
    lastJournalDayText = dayText;
    lastHmacSecret = hmacSecret;
    lastCertPins = certPins;
    return AiChatResult(reply: 'FAKE_JOURNAL:$dayText');
  }

  @override
  Future<AiChatResult> askNotificationDigest(
    String backendUrl,
    String itemsSummary, {
    String? hmacSecret,
    List<String> certPins = const [],
  }) async {
    askNotificationDigestCallCount++;
    lastNotificationDigestSummary = itemsSummary;
    lastHmacSecret = hmacSecret;
    lastCertPins = certPins;
    return AiChatResult(reply: 'FAKE_DIGEST:$itemsSummary');
  }
}

class FakeDeviceInfoService extends DeviceInfoService {
  @override
  Future<int?> batteryLevel() async => 77;
}

class FakeSpotifyService extends SpotifyService {
  bool connected = false;

  @override
  Future<bool> isConnected() async => connected;
}

class FakeNotificationService extends NotificationService {
  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> scheduleTimerNotification({required int id, required String body, required Duration delay}) async {
    scheduleCalls++;
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
  }

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

  List<String> reminderBodies = [];

  @override
  Future<List<String>> pendingReminderBodies() async => reminderBodies;

  int immediateNotificationCalls = 0;
  String? lastImmediateNotificationBody;

  @override
  Future<void> showImmediateNotification({required int id, required String title, required String body}) async {
    immediateNotificationCalls++;
    lastImmediateNotificationBody = body;
  }
}

class FakeCodeSnippetService extends CodeSnippetService {
  int copyCalls = 0;
  String? lastCopied;

  @override
  Future<void> copyToClipboard(String code) async {
    copyCalls++;
    lastCopied = code;
  }
}

class FakeLateNightTeaseService extends LateNightTeaseService {
  String? nextTease;
  int callCount = 0;
  String? lastPersona;
  String? lastLowerText;

  @override
  Future<String?> maybeTease(String persona, String lowerText, {DateTime? now}) async {
    callCount++;
    lastPersona = persona;
    lastLowerText = lowerText;
    return nextTease;
  }
}

class FakeSoundboardService extends SoundboardService {
  int playCalls = 0;
  String? lastPlayed;

  @override
  Future<void> play(String name) async {
    playCalls++;
    lastPlayed = name;
  }
}

class FakeMoodCaptureService extends MoodCaptureService {
  Int16List? nextSample;
  int captureCalls = 0;

  @override
  Future<Int16List?> captureSample() async {
    captureCalls++;
    return nextSample;
  }
}

class FakeAmbientSoundService extends AmbientSoundService {
  int playCalls = 0;
  int stopCalls = 0;
  String? lastPlayed;

  @override
  Future<void> play(String name) async {
    playCalls++;
    lastPlayed = name;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWikipediaService wikipedia;
  late FakeContactsService contacts;
  late FakeCallService call;
  late FakeWhatsappService whatsapp;
  late FakeAiChatService aiChat;
  late TimerService timer;
  late NotesService notes;
  late FakeEmailService email;
  late FakeYoutubeService youtube;
  late FakeNotificationService notifications;
  late FakeSpotifyService spotify;
  late FakeWebSearchService webSearch;
  late FakeSettingsService settings;
  late FakeCodeSnippetService snippets;
  late FakeSoundboardService soundboard;
  late GamificationService gamification;
  late ProactiveBriefingService briefing;
  late FakeAnimeService anime;
  late LateNightTeaseService lateNightTease;
  late ChallengeService challenges;
  late RpgService rpg;
  late JournalService journal;
  late FakeAmbientSoundService ambient;
  late FakeMoodCaptureService moodCapture;
  late SecurityBreachService securityBreach;
  late FakeRssFeedService feeds;
  late FakeBackupExportService backup;
  late FakeWebDavSyncService webdav;
  late FakeOfflineLlmService offlineLlm;
  late TodoService todos;
  late AppLockService appLock;
  late NotificationHubService notificationHub;
  late CommandRouter router;

  // Builds a CommandRouter from the shared setUp() fakes, with optional
  // per-test overrides — added so each new feature's required constructor
  // param doesn't force every call site in this file to be edited (there
  // used to be two full duplicates: `router` here and `freshRouter` in the
  // daily-bonus test below).
  CommandRouter buildRouter({
    GamificationService? gamificationOverride,
    LateNightTeaseService? lateNightTeaseOverride,
  }) => CommandRouter(
    wikipedia: wikipedia,
    jokes: FakeJokeService(),
    news: FakeNewsService(),
    weather: FakeWeatherService(),
    whatsapp: whatsapp,
    email: email,
    call: call,
    appLauncher: FakeAppLauncherService(),
    youtube: youtube,
    qr: QrService(),
    location: FakeLocationService(),
    contacts: contacts,
    settings: settings,
    ip: FakeIpService(),
    aiChat: aiChat,
    deviceInfo: FakeDeviceInfoService(),
    timer: timer,
    notes: notes,
    fun: RandomFunService(),
    notifications: notifications,
    spotify: spotify,
    webSearch: webSearch,
    snippets: snippets,
    soundboard: soundboard,
    gamification: gamificationOverride ?? gamification,
    musicDj: MusicDjService(),
    briefing: briefing,
    homeAssistant: HomeAssistantService(),
    anime: anime,
    lateNightTease: lateNightTeaseOverride ?? lateNightTease,
    challenges: challenges,
    rpg: rpg,
    journal: journal,
    ambient: ambient,
    moodCapture: moodCapture,
    securityBreach: securityBreach,
    feeds: feeds,
    backup: backup,
    webdav: webdav,
    offlineLlm: offlineLlm,
    todos: todos,
    appLock: appLock,
    notificationHub: notificationHub,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wikipedia = FakeWikipediaService();
    contacts = FakeContactsService();
    call = FakeCallService();
    whatsapp = FakeWhatsappService();
    aiChat = FakeAiChatService();
    timer = TimerService();
    notes = NotesService();
    todos = TodoService();
    notificationHub = NotificationHubService();
    email = FakeEmailService();
    youtube = FakeYoutubeService();
    notifications = FakeNotificationService();
    spotify = FakeSpotifyService();
    webSearch = FakeWebSearchService();
    settings = FakeSettingsService();
    appLock = AppLockService(settings: settings);
    snippets = FakeCodeSnippetService();
    soundboard = FakeSoundboardService();
    gamification = GamificationService();
    challenges = ChallengeService();
    briefing = ProactiveBriefingService(
      notifications: notifications,
      weather: FakeWeatherService(),
      news: FakeNewsService(),
      notes: notes,
      location: FakeLocationService(),
      gamification: gamification,
      settings: settings,
      challenges: challenges,
      todos: todos,
      notificationHub: notificationHub,
      aiChat: aiChat,
    );
    anime = FakeAnimeService();
    lateNightTease = LateNightTeaseService();
    rpg = RpgService();
    journal = JournalService();
    ambient = FakeAmbientSoundService();
    moodCapture = FakeMoodCaptureService()..nextSample = _loudSquareWaveSample();
    securityBreach = SecurityBreachService();
    feeds = FakeRssFeedService();
    backup = FakeBackupExportService();
    webdav = FakeWebDavSyncService();
    offlineLlm = FakeOfflineLlmService();

    router = buildRouter();
    // Pre-claim today's gamification bonus so it doesn't prepend a "🎉
    // Tages-Bonus" line to the very first handle() call in each test —
    // that's covered by its own dedicated test below instead.
    await gamification.claimDailyBonusIfNeeded();
  });

  test('empty input is rejected without touching any service', () async {
    final result = await router.handle('   ');
    expect(result.reply, 'Ich habe dich nicht verstanden.');
  });

  test('hilfe returns the help text', () async {
    final result = await router.handle('hilfe');
    expect(result.reply, contains('Das kann ich für dich tun'));
  });

  test('witz returns the joke', () async {
    final result = await router.handle('erzähl mir einen witz');
    expect(result.reply, 'Ein Testwitz.');
  });

  group('Rechner vs. Wikipedia priority', () {
    test('"was ist <mathe>" goes to the calculator, not Wikipedia', () async {
      final result = await router.handle('was ist 5 plus 3');
      expect(result.reply, 'Das Ergebnis ist 8.');
      expect(wikipedia.lastQuery, isNull);
    });

    test('"was ist <thema>" still goes to Wikipedia', () async {
      final result = await router.handle('was ist Photosynthese');
      expect(wikipedia.lastQuery, 'Photosynthese');
      expect(result.reply, 'WIKI:Photosynthese');
    });

    test('invalid math falls back to "kann nicht berechnen"', () async {
      final result = await router.handle('rechne 10 durch 0');
      expect(result.reply, 'Das konnte ich nicht berechnen.');
    });
  });

  test('recherchiere <Thema> triggers WebSearchService and shows the result', () async {
    settings.aiBackendUrl = 'https://worker.example';
    final result = await router.handle('recherchiere den aktuellen preis von bitcoin');
    expect(webSearch.lastBackendUrl, 'https://worker.example');
    expect(webSearch.lastQuery, 'den aktuellen preis von bitcoin');
    expect(result.reply, contains('Web-Ergebnis-Text'));
  });

  test('suche im internet nach <Frage> without a configured AI backend reports that clearly', () async {
    settings.aiBackendUrl = '';
    final result = await router.handle('suche im internet nach dem wetter auf dem mars');
    expect(result.reply, contains('Websuche benötigt eine KI-Server-Adresse'));
    expect(webSearch.lastQuery, isNull);
  });

  test('nachrichten lists the fake headlines', () async {
    final result = await router.handle('nachrichten');
    expect(result.reply, contains('Erste Meldung'));
    expect(result.reply, contains('Zweite Meldung'));
  });

  test('wetter in <Stadt> uses byCity', () async {
    final result = await router.handle('wetter in Hamburg');
    expect(result.reply, contains('Hamburg'));
    expect(result.reply, contains('sonnig'));
  });

  test('wetter without a city falls back to the current location', () async {
    final result = await router.handle('wetter');
    expect(result.reply, contains('bewölkt'));
  });

  test('standort reports the fake city/country', () async {
    final result = await router.handle('wo bin ich');
    expect(result.reply, contains('Berlin'));
    expect(result.reply, contains('Deutschland'));
  });

  test('öffne <unbekannte App> reports it was not found', () async {
    final result = await router.handle('öffne NichtInstalliert');
    expect(result.reply, contains('nicht finden'));
  });

  test('kamera sets openCamera on the result', () async {
    final result = await router.handle('kamera');
    expect(result.openCamera, isTrue);
  });

  test('rufe <unbekannter Kontakt> reports it was not found', () async {
    final result = await router.handle('rufe Mama an');
    expect(result.reply, contains('keinen Kontakt'));
    expect(call.lastPhone, isNull);
  });

  test('rufe <bekannter Kontakt> triggers CallService', () async {
    contacts.contactToReturn = Contact(name: 'Mama', phone: '+491701234567');
    final result = await router.handle('rufe Mama an');
    expect(call.lastPhone, '+491701234567');
    expect(result.reply, contains('Mama'));
  });

  test('whatsapp an <Kontakt>: <Nachricht> triggers WhatsappService', () async {
    contacts.contactToReturn = Contact(name: 'Mama', phone: '+491701234567');
    final result = await router.handle('whatsapp an Mama: Bin gleich da');
    expect(whatsapp.lastPhone, '+491701234567');
    expect(whatsapp.lastMessage, 'Bin gleich da');
    expect(result.reply, contains('Mama'));
  });

  test('email an <Adresse>: <Nachricht> triggers EmailService', () async {
    final result = await router.handle('email an chef@firma.de: Bin im Homeoffice');
    expect(result.reply, contains('chef@firma.de'));
  });

  test('youtube <Suchbegriff> triggers YoutubeService', () async {
    final result = await router.handle('youtube lofi hip hop');
    expect(result.reply, contains('lofi hip hop'));
  });

  test('qr code <Text> returns qrData', () async {
    final result = await router.handle('qr code https://example.com');
    expect(result.qrData, 'https://example.com');
  });

  test('meine ip returns the fake public IP', () async {
    final result = await router.handle('meine ip');
    expect(result.reply, contains('1.2.3.4'));
  });

  test('akkustand returns the fake battery level', () async {
    final result = await router.handle('akkustand');
    expect(result.reply, contains('77 Prozent'));
  });

  group('Timer', () {
    test('timer für <Zeit> starts a timer and schedules a notification', () async {
      final result = await router.handle('timer für 5 minuten');
      expect(result.reply, contains('Timer'));
      expect(router.timer.list().length, 1);
      expect(notifications.scheduleCalls, 1);
    });

    test('erinnere mich in <Zeit> an <Sache> keeps the label', () async {
      final result = await router.handle('erinnere mich in 10 minuten an die wäsche');
      expect(result.reply, contains('wäsche'));
    });

    test('unparsable time span reports the error', () async {
      final result = await router.handle('timer für einen moment');
      expect(result.reply, contains('nicht verstanden'));
    });

    test('meine timer lists active timers', () async {
      await router.handle('timer für 5 minuten');
      final result = await router.handle('meine timer');
      expect(result.reply, contains('Laufende Timer'));
    });

    test('meine timer reports nothing running when there is none', () async {
      final result = await router.handle('meine timer');
      expect(result.reply, 'Es läuft gerade kein Timer.');
    });

    test('timer abbrechen cancels every running timer and its notification', () async {
      await router.handle('timer für 5 minuten');
      final result = await router.handle('timer abbrechen');
      expect(result.reply, '1 Timer abgebrochen.');
      expect(router.timer.list(), isEmpty);
      expect(notifications.cancelCalls, 1);
    });
  });

  group('Notizen', () {
    test('notiz <Text> saves a note', () async {
      final result = await router.handle('notiz kaufe milch');
      expect(result.reply, contains('Notiz gespeichert: kaufe milch'));
    });

    test('meine notizen lists saved notes', () async {
      await router.handle('notiz kaufe milch');
      final result = await router.handle('meine notizen');
      expect(result.reply, contains('1. kaufe milch'));
    });

    test('bare "notizen" also lists notes (regression: not misread as add)', () async {
      await router.handle('notiz kaufe milch');
      final result = await router.handle('zeig mir meine notizen bitte');
      expect(result.reply, contains('kaufe milch'));
    });

    test('no notes yet reports that clearly', () async {
      final result = await router.handle('meine notizen');
      expect(result.reply, 'Du hast noch keine Notizen.');
    });

    test('lösche notiz <n> removes the note at that position', () async {
      await router.handle('notiz erste');
      await router.handle('notiz zweite');
      final result = await router.handle('lösche notiz 1');
      expect(result.reply, contains('erste'));

      final remaining = await router.handle('meine notizen');
      expect(remaining.reply, isNot(contains('erste')));
      expect(remaining.reply, contains('zweite'));
    });

    test('lösche alle notizen clears the list', () async {
      await router.handle('notiz erste');
      await router.handle('lösche alle notizen');
      final result = await router.handle('meine notizen');
      expect(result.reply, 'Du hast noch keine Notizen.');
    });
  });

  group('Aufgaben (To-Dos)', () {
    test('neue aufgabe: <Text> saves a to-do', () async {
      final result = await router.handle('neue aufgabe: müll rausbringen');
      expect(result.reply, contains('Aufgabe gespeichert: müll rausbringen'));
    });

    test('meine aufgaben lists open to-dos', () async {
      await router.handle('neue aufgabe: müll rausbringen');
      final result = await router.handle('meine aufgaben');
      expect(result.reply, contains('1. müll rausbringen'));
    });

    test('no to-dos yet reports that clearly', () async {
      final result = await router.handle('offene aufgaben');
      expect(result.reply, 'Du hast keine offenen Aufgaben.');
    });

    test('aufgabe <n> erledigt marks it done and removes it from the open list', () async {
      await router.handle('neue aufgabe: müll rausbringen');
      final result = await router.handle('aufgabe 1 erledigt');
      expect(result.reply, contains('Erledigt: müll rausbringen'));

      final remaining = await router.handle('meine aufgaben');
      expect(remaining.reply, 'Du hast keine offenen Aufgaben.');
    });

    test('open-task numbering matches the full-list position, not a re-numbered filtered index', () async {
      await router.handle('neue aufgabe: erste');
      await router.handle('neue aufgabe: zweite');
      await router.handle('aufgabe 1 erledigt');

      final result = await router.handle('meine aufgaben');
      // "erste" (index 1) is done and hidden; "zweite" keeps its real
      // full-list number (2), so a follow-up "aufgabe 2 erledigt" still
      // refers to the item the user just saw listed.
      expect(result.reply, contains('2. zweite'));
      expect(result.reply, isNot(contains('erste')));
    });

    test('lösche aufgabe <n> removes the to-do at that position', () async {
      await router.handle('neue aufgabe: erste');
      await router.handle('neue aufgabe: zweite');
      final result = await router.handle('lösche aufgabe 1');
      expect(result.reply, contains('erste'));

      final remaining = await router.handle('meine aufgaben');
      expect(remaining.reply, isNot(contains('erste')));
      expect(remaining.reply, contains('zweite'));
    });

    test('lösche alle aufgaben clears the list', () async {
      await router.handle('neue aufgabe: erste');
      await router.handle('lösche alle aufgaben');
      final result = await router.handle('offene aufgaben');
      expect(result.reply, 'Du hast keine offenen Aufgaben.');
    });
  });

  group('Münzwurf, Würfel, Zufallszahl', () {
    test('münze werfen returns Kopf or Zahl', () async {
      final result = await router.handle('wirf eine münze');
      expect(result.reply, anyOf('Kopf!', 'Zahl!'));
    });

    test('würfle returns a value between 1 and 6', () async {
      final result = await router.handle('würfle');
      final match = RegExp(r'(\d+) gewürfelt').firstMatch(result.reply);
      expect(match, isNotNull);
      final value = int.parse(match!.group(1)!);
      expect(value, inInclusiveRange(1, 6));
    });

    test('würfle mit 20 seiten returns a value between 1 and 20', () async {
      final result = await router.handle('würfle mit 20 seiten');
      expect(result.reply, contains('W20'));
      final match = RegExp(r'eine (\d+) gewürfelt').firstMatch(result.reply);
      final value = int.parse(match!.group(1)!);
      expect(value, inInclusiveRange(1, 20));
    });

    test('zufallszahl zwischen 5 und 10 stays within bounds', () async {
      final result = await router.handle('zufallszahl zwischen 5 und 10');
      final value = int.parse(result.reply.trim());
      expect(value, inInclusiveRange(5, 10));
    });
  });

  group('Code-Snippets', () {
    test('code snippet für git commit copies the snippet to the clipboard', () async {
      final result = await router.handle('code snippet für git commit');
      expect(snippets.copyCalls, 1);
      expect(snippets.lastCopied, contains('git commit'));
      expect(result.reply, contains('Git: Commit erstellen'));
      expect(result.reply, contains('Zwischenablage'));
    });

    test('unknown snippet name suggests available ones instead of copying', () async {
      final result = await router.handle('code snippet für sowasgibtsnicht');
      expect(snippets.copyCalls, 0);
      expect(result.reply, contains('Das kenne ich nicht'));
    });

    test('welche code snippets kennst du lists the available titles', () async {
      final result = await router.handle('welche code snippets kennst du');
      expect(result.reply, contains('StatefulWidget'));
      expect(result.reply, contains('Git: Commit erstellen'));
    });
  });

  group('Soundboard', () {
    test('spiel sound boot plays the matching effect', () async {
      final result = await router.handle('spiel sound boot');
      expect(soundboard.playCalls, 1);
      expect(soundboard.lastPlayed, 'boot');
      expect(result.reply, contains('boot'));
    });

    test('unknown sound name suggests available ones instead of playing', () async {
      final result = await router.handle('spiel sound dieswirdsnie');
      expect(soundboard.playCalls, 0);
      expect(result.reply, contains('kenne ich nicht'));
    });

    test('welche sounds hast du lists the available names', () async {
      final result = await router.handle('welche sounds hast du');
      expect(result.reply, contains('click'));
      expect(result.reply, contains('boot'));
    });
  });

  group('Interaktives Storytelling', () {
    test('starte ein sci-fi abenteuer opens the story with the scifi genre', () async {
      final result = await router.handle('starte ein sci-fi abenteuer');
      expect(aiChat.lastStoryGenre, 'scifi');
      expect(result.reply, contains('FAKE_STORY[scifi]'));
      expect(result.reply, contains('beende das Abenteuer'));
    });

    test('starte eine detektivgeschichte opens the story with the detective genre', () async {
      final result = await router.handle('starte eine detektivgeschichte');
      expect(aiChat.lastStoryGenre, 'detective');
      expect(result.reply, contains('FAKE_STORY[detective]'));
    });

    test('while in story mode, input that looks like another command is treated as a story action', () async {
      await router.handle('starte ein sci-fi abenteuer');
      final result = await router.handle('öffne die tür');
      expect(aiChat.lastStoryMessage, 'öffne die tür');
      expect(result.reply, contains('FAKE_STORY[scifi]:öffne die tür'));
    });

    test('beende das abenteuer exits story mode and normal commands work again', () async {
      await router.handle('starte ein sci-fi abenteuer');
      final exitResult = await router.handle('beende das abenteuer');
      expect(exitResult.reply, contains('Willkommen zurück'));

      final helpResult = await router.handle('hilfe');
      expect(helpResult.reply, contains('Das kann ich für dich tun'));
    });
  });

  group('Gamification (XP & Level)', () {
    test('notiz gives XP, echoed in the reply', () async {
      final result = await router.handle('notiz Milch kaufen');
      expect(result.reply, contains('Notiz gespeichert: Milch kaufen'));
      expect(result.reply, contains('+5 XP'));
    });

    test('timer für gives XP, echoed in the reply', () async {
      final result = await router.handle('timer für 5 minuten');
      expect(result.reply, contains('Timer'));
      expect(result.reply, contains('+5 XP'));
    });

    test('commit gemacht logs a commit and gives XP', () async {
      final result = await router.handle('commit gemacht');
      expect(result.reply, contains('Commit geloggt'));
      expect(result.reply, contains('+15 XP'));
    });

    test('mein level reports status text', () async {
      await router.handle('notiz eins');
      final result = await router.handle('mein level');
      expect(result.reply, contains('Level'));
      expect(result.reply, contains('XP gesamt'));
    });

    test('erste notiz unlocks the "Erste Notiz" achievement', () async {
      final result = await router.handle('notiz eins');
      expect(result.reply, contains('Erfolg freigeschaltet: Erste Notiz'));
    });

    test('öffne mein dashboard sets the openDashboard flag', () async {
      final result = await router.handle('öffne mein dashboard');
      expect(result.openDashboard, isTrue);
    });

    test('other commands do not set the openDashboard flag', () async {
      final result = await router.handle('hilfe');
      expect(result.openDashboard, isFalse);
    });

    test('ich habe X stunden geschlafen sets energy and confirms it', () async {
      final result = await router.handle('ich habe 8 stunden geschlafen');
      expect(result.reply, contains('8.0 Stunden Schlaf'));
      expect(result.reply, contains('100%'));
    });

    test('sleep hours accepts a comma decimal', () async {
      final result = await router.handle('ich habe 4,5 stunden geschlafen');
      expect(result.reply, contains('4.5 Stunden Schlaf'));
    });

    test('daily bonus is claimed once and folded into the next reply', () async {
      // Uses its own fresh service/prefs (the shared `gamification` from
      // setUp already pre-claimed today's bonus so router tests above
      // aren't affected by it).
      SharedPreferences.setMockInitialValues({});
      final freshGamification = GamificationService();
      final freshRouter = buildRouter(gamificationOverride: freshGamification);

      final first = await freshRouter.handle('hilfe');
      expect(first.reply, contains('Tages-Bonus'));
      expect(first.reply, contains('+10 XP'));

      final second = await freshRouter.handle('hilfe');
      expect(second.reply, isNot(contains('Tages-Bonus')));
    });
  });

  group('Notfall-Sperre & Fokus-Modus', () {
    test('sperre die app without a configured PIN asks to set one first', () async {
      final result = await router.handle('sperre die app');
      expect(result.triggerAppLock, isFalse);
      expect(result.reply, contains('PIN'));
    });

    test('sperre die app with a configured PIN sets the triggerAppLock flag', () async {
      await settings.setAppLockPin('1234');
      final result = await router.handle('notfall-sperre');
      expect(result.triggerAppLock, isTrue);
    });

    test('aktiviere fokus-modus sets the triggerFocusModeOn flag', () async {
      final result = await router.handle('aktiviere fokus-modus');
      expect(result.triggerFocusModeOn, isTrue);
      expect(result.triggerFocusModeOff, isFalse);
    });

    test('deaktiviere fokus-modus sets the triggerFocusModeOff flag', () async {
      final result = await router.handle('deaktiviere fokus-modus');
      expect(result.triggerFocusModeOff, isTrue);
      expect(result.triggerFocusModeOn, isFalse);
    });

    test('other commands do not set any of the lock/focus-mode flags', () async {
      final result = await router.handle('hilfe');
      expect(result.triggerAppLock, isFalse);
      expect(result.triggerFocusModeOn, isFalse);
      expect(result.triggerFocusModeOff, isFalse);
    });
  });

  group('Benachrichtigungs-Zusammenfasser', () {
    test('reports the feature is off when the toggle is disabled', () async {
      final result = await router.handle('meine benachrichtigungen');
      expect(result.reply, contains('noch aus'));
    });

    test('reports nothing captured once enabled (no native listener under test)', () async {
      await settings.setNotificationHubEnabled(true);
      final result = await router.handle('ungelesene benachrichtigungen');
      expect(result.reply, 'Keine neuen Benachrichtigungen.');
    });
  });

  group('Musik-DJ', () {
    test('musik zum fokus reports Spotify not connected (not set up in test)', () async {
      final result = await router.handle('musik zum fokus');
      expect(result.reply, contains('Spotify'));
    });

    test('musik zum <unbekannte stimmung> suggests known moods', () async {
      final result = await router.handle('musik zum quantenphysik');
      expect(result.reply, contains('kenne ich nicht'));
    });

    test('passende musik picks a time-of-day mood and reports Spotify not connected', () async {
      final result = await router.handle('passende musik');
      expect(result.reply, contains('Spotify'));
    });
  });

  group('Proaktive Nachrichten', () {
    test('morgen-briefing includes weather and news from the fake services', () async {
      final result = await router.handle('morgen-briefing');
      expect(result.reply, contains('Guten Morgen'));
      expect(result.reply, contains('bewölkt'));
      expect(result.reply, contains('Erste Meldung'));
      expect(result.reply, contains('Heutige Challenge'));
    });

    test('abend-zusammenfassung includes the gamification status', () async {
      final result = await router.handle('abend-zusammenfassung');
      expect(result.reply, contains('Guten Abend'));
      expect(result.reply, contains('Level'));
    });

    test('morgen-briefing includes pending reminders as Termine', () async {
      notifications.reminderBodies = ['⏰ „Zahnarzt" ist abgelaufen!'];
      final result = await router.handle('morgen-briefing');
      expect(result.reply, contains('Anstehende Termine'));
      expect(result.reply, contains('Zahnarzt'));
    });
  });

  group('Smart-Home (Home Assistant)', () {
    test('licht wohnzimmer an reports not set up (no URL/token in test settings)', () async {
      final result = await router.handle('licht wohnzimmer an');
      expect(result.reply, contains('Home Assistant ist nicht eingerichtet'));
    });

    test('schalte das licht küche aus reports not set up', () async {
      final result = await router.handle('schalte das licht küche aus');
      expect(result.reply, contains('Home Assistant ist nicht eingerichtet'));
    });

    test('status von heizung reports not set up', () async {
      final result = await router.handle('status von heizung');
      expect(result.reply, contains('Home Assistant ist nicht eingerichtet'));
    });
  });

  group('Anime & Manga (AniList)', () {
    test('anime <Titel> reports the looked-up info', () async {
      final result = await router.handle('anime hyouka');
      expect(result.reply, contains('Hyouka'));
      expect(result.reply, contains('2012'));
      expect(result.reply, contains('Episoden: 22'));
    });

    test('manga <Titel> uses "Kapitel" instead of "Episoden"', () async {
      final result = await router.handle('manga hyouka');
      expect(result.reply, contains('Kapitel: 22'));
    });

    test('unknown title reports not found', () async {
      anime.nextResult = null;
      final result = await router.handle('anime dieswirdsnie existieren');
      expect(result.reply, contains('nicht finden'));
    });
  });

  group('RSS-Feeds', () {
    test('abonniere feed <URL> subscribes and confirms', () async {
      final result = await router.handle('abonniere feed https://example.com/rss.xml');
      expect(result.reply, contains('Feed abonniert'));
      expect(feeds.lastAddedUrl, 'https://example.com/rss.xml');
    });

    test('a trailing "hinzu" is stripped from the URL', () async {
      await router.handle('füge feed https://example.com/rss.xml hinzu');
      expect(feeds.lastAddedUrl, 'https://example.com/rss.xml');
    });

    test('a feed that cannot be added reports the failure', () async {
      feeds.throwOnAdd = true;
      final result = await router.handle('abonniere feed https://example.com/nope');
      expect(result.reply, contains('Konnte den Feed nicht hinzufügen'));
    });

    test('meine feeds lists subscribed feeds', () async {
      await router.handle('abonniere feed https://example.com/rss.xml');
      final result = await router.handle('meine feeds');
      expect(result.reply, contains('https://example.com/rss.xml'));
    });

    test('meine feeds reports emptiness when nothing is subscribed', () async {
      final result = await router.handle('meine feeds');
      expect(result.reply, contains('noch keine Feeds'));
    });

    test('entferne feed <URL> removes a subscription', () async {
      await router.handle('abonniere feed https://example.com/rss.xml');
      await router.handle('entferne feed https://example.com/rss.xml');
      final result = await router.handle('meine feeds');
      expect(result.reply, contains('noch keine Feeds'));
    });

    test('was gibt\'s neues in meinen feeds reports new headlines on demand', () async {
      feeds.nextNewItems = [RssItem(id: '1', title: 'Große Neuigkeit', link: 'https://example.com/1', feedTitle: 'Test-Feed')];
      final result = await router.handle("was gibt's neues in meinen feeds");
      expect(result.reply, contains('Große Neuigkeit'));
    });

    test('reports no new headlines when there are none', () async {
      final result = await router.handle('rss updates');
      expect(result.reply, contains('Keine neuen Schlagzeilen'));
    });
  });

  group('Backup-Export', () {
    test('erstelle jetzt ein backup triggers an export and reports the size', () async {
      final result = await router.handle('erstelle jetzt ein backup');
      expect(backup.exportCount, 1);
      expect(result.reply, contains('Backup erstellt'));
      expect(result.reply, contains('KB'));
    });

    test('backup wiederherstellen reports success when a backup exists', () async {
      backup.restoreResult = true;
      final result = await router.handle('backup wiederherstellen');
      expect(result.reply, contains('wiederhergestellt'));
    });

    test('backup wiederherstellen reports when there is nothing to restore', () async {
      backup.restoreResult = false;
      final result = await router.handle('backup wiederherstellen');
      expect(result.reply, contains('noch kein gespeichertes Backup'));
    });

    test('backup status reports emptiness before any export', () async {
      final result = await router.handle('backup status');
      expect(result.reply, contains('noch kein gespeichertes Backup'));
    });

    test('backup status reports the last export time after one exists', () async {
      await router.handle('erstelle jetzt ein backup');
      final result = await router.handle('backup status');
      expect(result.reply, contains('Letztes Backup'));
    });
  });

  group('WebDAV-Cloud-Sync', () {
    test('cloud-backup hochladen reports missing setup when WebDAV is not configured', () async {
      final result = await router.handle('cloud-backup hochladen');
      expect(result.reply, contains('nicht eingerichtet'));
      expect(webdav.uploadCount, 0);
    });

    test('cloud-backup hochladen uploads once WebDAV is configured', () async {
      await settings.setWebDavUrl('https://cloud.example.com/dav/');
      await settings.setWebDavUsername('nutzer');
      await settings.setWebDavPassword('geheim');

      final result = await router.handle('cloud-backup hochladen');

      expect(webdav.uploadCount, 1);
      expect(result.reply, contains('hochgeladen'));
    });

    test('cloud-backup hochladen reports a failure from the server', () async {
      await settings.setWebDavUrl('https://cloud.example.com/dav/');
      await settings.setWebDavUsername('nutzer');
      await settings.setWebDavPassword('geheim');
      webdav.throwOnUpload = true;

      final result = await router.handle('cloud-backup hochladen');

      expect(result.reply, contains('fehlgeschlagen'));
    });

    test('cloud-backup herunterladen restores once WebDAV is configured', () async {
      await settings.setWebDavUrl('https://cloud.example.com/dav/');
      await settings.setWebDavUsername('nutzer');
      await settings.setWebDavPassword('geheim');

      final result = await router.handle('cloud-backup herunterladen');

      expect(webdav.downloadCount, 1);
      expect(result.reply, contains('heruntergeladen'));
    });

    test('cloud-backup herunterladen reports missing setup when WebDAV is not configured', () async {
      final result = await router.handle('cloud-backup herunterladen');
      expect(result.reply, contains('nicht eingerichtet'));
      expect(webdav.downloadCount, 0);
    });
  });

  group('Offline-KI', () {
    test('offline-ki status reports not-ready when no model is installed', () async {
      final result = await router.handle('offline-ki status');
      expect(result.reply, contains('kein Offline-Modell installiert'));
    });

    test('offline-ki status reports ready once a model is installed', () async {
      offlineLlm.installed = true;
      final result = await router.handle('ist die offline-ki bereit');
      expect(result.reply, contains('einsatzbereit'));
    });
  });

  group('Persona-Wechsel', () {
    test('default persona is standard', () async {
      expect(await settings.getPersona(), 'standard');
    });

    test('aktiviere den drill-trainer switches persona and confirms', () async {
      final result = await router.handle('aktiviere den drill-trainer');
      expect(result.reply, contains('DRILL-TRAINER'));
      expect(await settings.getPersona(), 'drill_sergeant');
    });

    test('sei mein gaming-kumpel switches persona', () async {
      await router.handle('sei mein gaming-kumpel');
      expect(await settings.getPersona(), 'gaming_buddy');
    });

    test('butler-modus switches persona', () async {
      await router.handle('butler-modus');
      expect(await settings.getPersona(), 'butler');
    });

    test('active persona is echoed to the next ask() call', () async {
      await router.handle('aktiviere die butler-persona');
      await router.handle('freie frage an die ki');
      expect(aiChat.lastPersona, 'butler');
    });

    test('welche persona reports the current persona', () async {
      await router.handle('aktiviere den gaming-kumpel');
      final result = await router.handle('welche persona');
      expect(result.reply, contains('Gaming-Kumpel'));
    });

    test('aktiviere jarvis standard resets to standard', () async {
      await router.handle('aktiviere den drill-trainer');
      await router.handle('aktiviere jarvis standard');
      expect(await settings.getPersona(), 'standard');
    });
  });

  group('Tägliche Challenges', () {
    test('tägliche challenge reports today\'s challenge', () async {
      final result = await router.handle('tägliche challenge');
      expect(result.reply, contains('Heutige Challenge'));
    });

    test('challenge erledigt awards XP and marks it done', () async {
      final result = await router.handle('challenge erledigt');
      expect(result.reply, contains('Challenge erledigt'));
      expect(result.reply, contains('+20 XP'));
    });

    test('challenge erledigt twice the same day is idempotent', () async {
      await router.handle('challenge erledigt');
      final second = await router.handle('challenge erledigt');
      expect(second.reply, contains('schon erledigt'));
      expect(second.reply, isNot(contains('+20 XP')));
    });

    test('heutige challenge shows completed status after marking done', () async {
      await router.handle('challenge erledigt');
      final result = await router.handle('heutige challenge');
      expect(result.reply, contains('schon erledigt'));
    });
  });

  group('Überlebens-RPG', () {
    test('starte das überlebens-rpg creates a fresh run and calls the AI once', () async {
      final result = await router.handle('starte das überlebens-rpg');
      expect(aiChat.askRpgCallCount, 1);
      final stats = await rpg.loadStats();
      expect(stats, isNotNull);
      expect(stats!.day, 1);
      expect(stats.alive, isTrue);
      expect(result.reply, contains('FAKE_RPG'));
    });

    test('status query returns stats without calling the AI', () async {
      await router.handle('starte das überlebens-rpg');
      final before = aiChat.askRpgCallCount;
      final result = await router.handle('status');
      expect(result.reply, contains('Tag'));
      expect(aiChat.askRpgCallCount, before);
    });

    test('iss consumes one food unit', () async {
      await router.handle('starte das überlebens-rpg');
      final before = await rpg.loadStats();
      await router.handle('iss');
      final after = await rpg.loadStats();
      expect(after!.food, before!.food - 1);
    });

    test('trink consumes one water unit', () async {
      await router.handle('starte das überlebens-rpg');
      final before = await rpg.loadStats();
      await router.handle('trink');
      final after = await rpg.loadStats();
      expect(after!.water, before!.water - 1);
    });

    test('free-form text containing "wissen" does not accidentally trigger eating', () async {
      await router.handle('starte das überlebens-rpg');
      final before = await rpg.loadStats();
      await router.handle('ich möchte mehr darüber wissen');
      final after = await rpg.loadStats();
      expect(after!.food, before!.food);
    });

    test('death is reported and locks the mode from further AI calls', () async {
      await router.handle('starte das überlebens-rpg');
      await rpg.saveStats(
        const RpgStats(
          day: 5,
          health: 1,
          hunger: 0,
          thirst: 0,
          energy: 50,
          food: 0,
          water: 0,
          scrap: 0,
          hasWeapon: false,
          hasShelter: false,
          alive: true,
        ),
      );
      final deathResult = await router.handle('ich schaue mich um');
      expect(deathResult.reply, contains('☠️'));
      final stats = await rpg.loadStats();
      expect(stats!.alive, isFalse);

      final callsAfterDeath = aiChat.askRpgCallCount;
      final lockedResult = await router.handle('ich schaue mich um');
      expect(lockedResult.reply, contains('gestorben'));
      expect(aiChat.askRpgCallCount, callsAfterDeath);
    });

    test('neues überlebens-rpg starten resets after death', () async {
      await router.handle('starte das überlebens-rpg');
      await rpg.saveStats(
        const RpgStats(
          day: 5,
          health: 0,
          hunger: 0,
          thirst: 0,
          energy: 0,
          food: 0,
          water: 0,
          scrap: 0,
          hasWeapon: false,
          hasShelter: false,
          alive: false,
        ),
      );
      await router.handle('ich schaue mich um');
      await router.handle('neues überlebens-rpg starten');
      final stats = await rpg.loadStats();
      expect(stats!.alive, isTrue);
      expect(stats.day, 1);
    });

    test('pausing then resuming preserves stats instead of resetting', () async {
      await router.handle('starte das überlebens-rpg');
      await router.handle('iss');
      final statsAfterPause0 = await rpg.loadStats();
      await router.handle('beende das überlebens-rpg');
      final resumeResult = await router.handle('starte das überlebens-rpg');
      expect(resumeResult.reply, contains('fortgesetzt'));
      final statsAfterResume = await rpg.loadStats();
      expect(statsAfterResume!.food, statsAfterPause0!.food);
    });

    test('RPG trigger is swallowed as a story action while story mode is active', () async {
      await router.handle('starte ein sci-fi abenteuer');
      await router.handle('starte das überlebens-rpg');
      expect(aiChat.lastStoryMessage, 'starte das überlebens-rpg');
      expect(aiChat.askRpgCallCount, 0);
    });
  });

  group('Abend-Tagebuch', () {
    test('wie war mein tag shows a static invitation without calling the AI', () async {
      final result = await router.handle('wie war mein tag');
      expect(result.reply, contains('Wie war dein Tag'));
      expect(aiChat.askJournalCallCount, 0);
    });

    test('mein tag war ... submits an entry and returns the AI reflection', () async {
      final result = await router.handle('mein tag war ziemlich stressig, aber am Ende gut ausgegangen');
      expect(aiChat.askJournalCallCount, 1);
      expect(aiChat.lastJournalDayText, 'ziemlich stressig, aber am Ende gut ausgegangen');
      expect(result.reply, contains('FAKE_JOURNAL'));
    });

    test('submitted entries are persisted and listable', () async {
      await router.handle('mein tag war produktiv');
      final result = await router.handle('meine tagebucheinträge');
      expect(result.reply, contains('produktiv'));
    });

    test('letzter tagebucheintrag shows the most recent entry with its reflection', () async {
      await router.handle('mein tag war ruhig');
      final result = await router.handle('letzter tagebucheintrag');
      expect(result.reply, contains('ruhig'));
      expect(result.reply, contains('FAKE_JOURNAL'));
    });

    test('no entries yet reports that clearly', () async {
      final result = await router.handle('meine tagebucheinträge');
      expect(result.reply, contains('noch keine Tagebucheinträge'));
    });
  });

  group('Ambiente Soundscapes', () {
    test('ambient regen starts the rain soundscape', () async {
      final result = await router.handle('ambient regen');
      expect(ambient.playCalls, 1);
      expect(ambient.lastPlayed, 'regen');
      expect(result.reply, contains('regen'));
    });

    test('spiel café-geräusche starts the café soundscape', () async {
      await router.handle('spiel café-geräusche');
      expect(ambient.lastPlayed, 'café');
    });

    test('aktiviere lofi hintergrundmusik starts the lofi soundscape', () async {
      await router.handle('aktiviere lofi hintergrundmusik');
      expect(ambient.lastPlayed, 'lofi');
    });

    test('stoppe die geräuschkulisse stops playback', () async {
      await router.handle('ambient regen');
      final result = await router.handle('stoppe die geräuschkulisse');
      expect(ambient.stopCalls, 1);
      expect(result.reply, contains('gestoppt'));
    });

    test('welche geräuschkulissen lists available names', () async {
      final result = await router.handle('welche geräuschkulissen');
      expect(result.reply, contains('regen'));
      expect(result.reply, contains('lofi'));
    });
  });

  group('Echte Audio-Tonanalyse (Mood-Check)', () {
    test('stimmungscheck sets requestMoodCheck without capturing (two-phase split)', () async {
      final result = await router.handle('stimmungscheck');
      expect(result.requestMoodCheck, isTrue);
      expect(moodCapture.captureCalls, 0);
    });

    test('runMoodCheck() actually captures and returns a mood description', () async {
      final reply = await router.runMoodCheck();
      expect(moodCapture.captureCalls, 1);
      expect(reply, contains('gestresst'));
    });

    test('a null capture degrades gracefully', () async {
      moodCapture.nextSample = null;
      final reply = await router.runMoodCheck();
      expect(reply, contains('konnte deine Stimme'));
    });

    test('the sarcasm nudge is not applied to the ask() call during the mood check itself', () async {
      await router.runMoodCheck();
      expect(aiChat.lastSarcasm, isNull);
    });

    test('the sarcasm nudge shows up on the NEXT ask() call after a mood check', () async {
      await router.runMoodCheck();
      await router.handle('freie frage an die ki');
      // Default sarcasm is 0.3; a stressed reading nudges it down by 0.3.
      expect(aiChat.lastSarcasm, closeTo(0.0, 0.001));
    });

    test('disabling the auto-adjust toggle leaves sarcasm unaffected', () async {
      await settings.setMoodAutoAdjustEnabled(false);
      await router.runMoodCheck();
      await router.handle('freie frage an die ki');
      expect(aiChat.lastSarcasm, closeTo(0.3, 0.001));
    });
  });

  group('Kontextabhängige Spätnacht-Reaktion', () {
    test('tease is appended when the fake service returns one', () async {
      final fakeTease = FakeLateNightTeaseService()..nextTease = 'Geh schlafen!';
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      final result = await freshRouter.handle('erzähl mir einen witz');
      expect(result.reply, contains('Geh schlafen!'));
      expect(fakeTease.callCount, 1);
    });

    test('no tease line when the service returns null', () async {
      final fakeTease = FakeLateNightTeaseService();
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      final result = await freshRouter.handle('erzähl mir einen witz');
      expect(result.reply, isNot(contains('\n\nGeh schlafen')));
    });

    test('current persona is passed through to maybeTease', () async {
      final fakeTease = FakeLateNightTeaseService();
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      await freshRouter.handle('aktiviere den drill-trainer');
      await freshRouter.handle('hilfe');
      expect(fakeTease.lastPersona, 'drill_sergeant');
    });

    test('tease is skipped during interactive story mode', () async {
      final fakeTease = FakeLateNightTeaseService()..nextTease = 'Geh schlafen!';
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      await freshRouter.handle('starte ein sci-fi abenteuer');
      final callsBefore = fakeTease.callCount;
      final result = await freshRouter.handle('ich öffne die Tür');
      expect(result.reply, isNot(contains('Geh schlafen!')));
      expect(fakeTease.callCount, callsBefore);
    });

    test('no push notification by default, even when a tease fires', () async {
      final fakeTease = FakeLateNightTeaseService()..nextTease = 'Geh schlafen!';
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      await freshRouter.handle('erzähl mir einen witz');
      expect(notifications.immediateNotificationCalls, 0);
    });

    test('push notification fires when night-alert setting is enabled', () async {
      await settings.setNightAlertEnabled(true);
      final fakeTease = FakeLateNightTeaseService()..nextTease = 'Geh schlafen!';
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      await freshRouter.handle('erzähl mir einen witz');
      expect(notifications.immediateNotificationCalls, 1);
      expect(notifications.lastImmediateNotificationBody, contains('Kaffeevorrat'));
    });

    test('no push notification when no tease fires, even if the setting is enabled', () async {
      await settings.setNightAlertEnabled(true);
      final fakeTease = FakeLateNightTeaseService();
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      await freshRouter.handle('erzähl mir einen witz');
      expect(notifications.immediateNotificationCalls, 0);
    });
  });

  group('Simulierte Sicherheitsbrüche', () {
    final ddosChallenge = SecurityBreachService.challenges.firstWhere((c) => c.id == 'ddos');

    test('on-demand trigger shows a challenge prompt', () async {
      final result = await router.handle('simuliere einen sicherheitsbruch');
      expect(result.reply, contains('SICHERHEITSBRUCH ERKANNT'));
    });

    test('correct answer awards XP and confirms the firewall was defended', () async {
      router.startBreachChallenge(ddosChallenge);
      final result = await router.handle('a');
      expect(result.reply, contains('Firewall erfolgreich verteidigt'));
      expect(result.reply, contains('+${GamificationService.breachXp} XP'));
    });

    test('incorrect answer gives a harmless failure message and no XP', () async {
      router.startBreachChallenge(ddosChallenge);
      final result = await router.handle('b');
      expect(result.reply, contains('Firewall kompromittiert'));
      expect(result.reply, isNot(contains('XP')));
    });

    test('a skip phrase exits without scoring right or wrong', () async {
      router.startBreachChallenge(ddosChallenge);
      final result = await router.handle('überspringen');
      expect(result.reply, contains('übersprungen'));
      expect(result.reply, isNot(contains('Firewall')));
    });

    test('breach mode is single-turn: normal commands work again right after', () async {
      router.startBreachChallenge(ddosChallenge);
      await router.handle('a');
      final result = await router.handle('hilfe');
      expect(result.reply, contains('Das kann ich für dich tun'));
    });

    test('breach mode suppresses the daily bonus and late-night tease while active', () async {
      final fakeTease = FakeLateNightTeaseService()..nextTease = 'Geh schlafen!';
      final freshRouter = buildRouter(lateNightTeaseOverride: fakeTease);
      freshRouter.startBreachChallenge(ddosChallenge);
      final result = await freshRouter.handle('a');
      expect(result.reply, isNot(contains('Geh schlafen!')));
      expect(fakeTease.callCount, 0);
    });
  });

  test('unmatched input falls through to the AI', () async {
    final result = await router.handle('wie geht es dir heute');
    expect(aiChat.lastMessage, 'wie geht es dir heute');
    expect(result.reply, 'FAKE_AI:wie geht es dir heute');
  });

  test('AI fallback remembers prior turns as history for follow-up questions', () async {
    await router.handle('wer war albert einstein');
    expect(aiChat.lastHistory, isEmpty);

    await router.handle('und wann ist er gestorben');
    expect(aiChat.lastHistory!.length, 2);
    expect(aiChat.lastHistory![0].role, 'user');
    expect(aiChat.lastHistory![0].content, 'wer war albert einstein');
    expect(aiChat.lastHistory![1].role, 'assistant');
    expect(aiChat.lastHistory![1].content, 'FAKE_AI:wer war albert einstein');
  });

  test('AI set_timer action starts a real timer', () async {
    aiChat.nextAction = AiAction(type: 'set_timer', params: {'minutes': 5, 'label': 'Kaffee'});
    final result = await router.handle('kannst du mich in 5 minuten an den kaffee erinnern');
    expect(result.reply, contains('Kaffee'));
    expect(timer.list(), hasLength(1));
    expect(notifications.scheduleCalls, 1);
  });

  test('AI add_note action saves a note', () async {
    aiChat.nextAction = AiAction(type: 'add_note', params: {'text': 'Milch kaufen'});
    final result = await router.handle('merk dir bitte milch kaufen');
    expect(result.reply, contains('Milch kaufen'));
    expect(await notes.list(), contains('Milch kaufen'));
  });

  test('AI search_wikipedia action calls WikipediaService', () async {
    aiChat.nextAction = AiAction(type: 'search_wikipedia', params: {'topic': 'Albert Einstein'});
    final result = await router.handle('was weißt du über albert einstein');
    expect(wikipedia.lastQuery, 'Albert Einstein');
    expect(result.reply, 'WIKI:Albert Einstein');
  });

  test('AI get_news action lists the fake headlines', () async {
    aiChat.nextAction = AiAction(type: 'get_news', params: {});
    final result = await router.handle('was gibt es neues');
    expect(result.reply, contains('Erste Meldung'));
  });

  test('AI send_email action composes an email to the raw address', () async {
    aiChat.nextAction = AiAction(type: 'send_email', params: {'to': 'chef@firma.de', 'body': 'Bin im Homeoffice'});
    final result = await router.handle('schick eine email an chef@firma.de dass ich im homeoffice bin');
    expect(email.lastTo, 'chef@firma.de');
    expect(result.reply, contains('chef@firma.de'));
  });

  test('AI search_youtube action calls YoutubeService', () async {
    aiChat.nextAction = AiAction(type: 'search_youtube', params: {'query': 'lofi hip hop'});
    final result = await router.handle('kannst du bitte lofi hip hop für mich raussuchen');
    expect(youtube.lastQuery, 'lofi hip hop');
    expect(result.reply, contains('lofi hip hop'));
  });

  test('AI search_web action calls WebSearchService', () async {
    settings.aiBackendUrl = 'https://worker.example';
    aiChat.nextAction = AiAction(type: 'search_web', params: {'query': 'aktueller bitcoin preis'});
    final result = await router.handle('was kostet bitcoin gerade');
    expect(webSearch.lastQuery, 'aktueller bitcoin preis');
    expect(result.reply, contains('Web-Ergebnis-Text'));
  });

  test('spiele <song> auf spotify reports missing Spotify setup instead of going to YouTube', () async {
    final result = await router.handle('spiele bohemian rhapsody auf spotify');
    expect(result.reply, contains('Spotify ist nicht eingerichtet'));
    expect(youtube.lastQuery, isNull);
  });

  test('AI play_music action reports missing Spotify setup', () async {
    aiChat.nextAction = AiAction(type: 'play_music', params: {'query': 'bohemian rhapsody'});
    final result = await router.handle('kannst du bohemian rhapsody abspielen');
    expect(result.reply, contains('Spotify ist nicht eingerichtet'));
  });

  test('spiele playlist <name> auf spotify reports missing Spotify setup instead of going to YouTube', () async {
    final result = await router.handle('spiele playlist workout auf spotify');
    expect(result.reply, contains('Spotify ist nicht eingerichtet'));
    expect(youtube.lastQuery, isNull);
  });

  test('AI play_playlist action reports missing Spotify setup', () async {
    aiChat.nextAction = AiAction(type: 'play_playlist', params: {'query': 'workout'});
    final result = await router.handle('kannst du meine workout playlist abspielen');
    expect(result.reply, contains('Spotify ist nicht eingerichtet'));
  });

  test('video hochladen sets openYoutubeUpload with no forced privacy', () async {
    final result = await router.handle('video hochladen');
    expect(result.openYoutubeUpload, isTrue);
    expect(result.youtubePrivacy, isNull);
  });

  test('video öffentlich hochladen preselects public', () async {
    final result = await router.handle('video öffentlich hochladen');
    expect(result.openYoutubeUpload, isTrue);
    expect(result.youtubePrivacy, 'public');
  });

  test('video nicht gelistet hochladen preselects unlisted', () async {
    final result = await router.handle('video nicht gelistet hochladen');
    expect(result.youtubePrivacy, 'unlisted');
  });

  test('AI open_youtube_upload action passes through a valid privacy_status', () async {
    aiChat.nextAction = AiAction(type: 'open_youtube_upload', params: {'privacy_status': 'public'});
    final result = await router.handle('kannst du das öffentlich freigeben');
    expect(result.openYoutubeUpload, isTrue);
    expect(result.youtubePrivacy, 'public');
    expect(result.youtubePublishAt, isNull);
  });

  test('AI open_youtube_upload action forces private when publish_at is set', () async {
    final future = DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String();
    aiChat.nextAction = AiAction(
      type: 'open_youtube_upload',
      params: {'privacy_status': 'public', 'publish_at': future},
    );
    final result = await router.handle('plane das für morgen ein');
    expect(result.youtubePrivacy, 'private');
    expect(result.youtubePublishAt, isNotNull);
  });

  test('AI open_youtube_upload action ignores an invalid privacy_status and a past publish_at', () async {
    aiChat.nextAction = AiAction(
      type: 'open_youtube_upload',
      params: {'privacy_status': 'geheim', 'publish_at': '2000-01-01T00:00:00Z'},
    );
    final result = await router.handle('mach das bitte klar');
    expect(result.youtubePrivacy, isNull);
    expect(result.youtubePublishAt, isNull);
  });

  test('video auf tiktok hochladen sets openTiktokUpload', () async {
    final result = await router.handle('video auf tiktok hochladen');
    expect(result.openTiktokUpload, isTrue);
  });

  test('AI open_tiktok_upload action sets openTiktokUpload', () async {
    aiChat.nextAction = AiAction(type: 'open_tiktok_upload', params: {});
    final result = await router.handle('kannst du das auf tiktok posten');
    expect(result.openTiktokUpload, isTrue);
  });

  group('HMAC-Request-Signierung', () {
    test('a configured secret is passed through to ask()', () async {
      await settings.setAiHmacSecret('test-secret');
      await router.handle('wie geht es dir heute');
      expect(aiChat.lastHmacSecret, 'test-secret');
    });

    test('no configured secret passes null through to ask()', () async {
      await router.handle('wie geht es dir heute');
      expect(aiChat.lastHmacSecret, isNull);
    });

    test('a configured secret is passed through to askStory()', () async {
      await settings.setAiHmacSecret('test-secret');
      await router.handle('starte ein sci-fi abenteuer');
      expect(aiChat.lastHmacSecret, 'test-secret');
    });

    test('a configured secret is passed through to askRpg()', () async {
      await settings.setAiHmacSecret('test-secret');
      await router.handle('starte das überlebens-rpg');
      expect(aiChat.lastHmacSecret, 'test-secret');
    });

    test('a configured secret is passed through to askJournal()', () async {
      await settings.setAiHmacSecret('test-secret');
      await router.handle('mein tag war ziemlich gut');
      expect(aiChat.lastHmacSecret, 'test-secret');
    });
  });

  group('TLS-Zertifikat-Pinning', () {
    test('configured pins are passed through to ask()', () async {
      await settings.setCertPins(['pin-a', 'pin-b']);
      await router.handle('wie geht es dir heute');
      expect(aiChat.lastCertPins, ['pin-a', 'pin-b']);
    });

    test('no configured pins passes an empty list through to ask()', () async {
      await router.handle('wie geht es dir heute');
      expect(aiChat.lastCertPins, isEmpty);
    });

    test('configured pins are passed through to askStory()', () async {
      await settings.setCertPins(['pin-a']);
      await router.handle('starte ein sci-fi abenteuer');
      expect(aiChat.lastCertPins, ['pin-a']);
    });

    test('configured pins are passed through to askRpg()', () async {
      await settings.setCertPins(['pin-a']);
      await router.handle('starte das überlebens-rpg');
      expect(aiChat.lastCertPins, ['pin-a']);
    });

    test('configured pins are passed through to askJournal()', () async {
      await settings.setCertPins(['pin-a']);
      await router.handle('mein tag war ziemlich gut');
      expect(aiChat.lastCertPins, ['pin-a']);
    });
  });
}
