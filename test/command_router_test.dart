import 'package:flutter_test/flutter_test.dart';
import 'package:installed_apps/app_info.dart';
import 'package:jarvis_mobile/core/command_router.dart';
import 'package:jarvis_mobile/services/ai_chat_service.dart';
import 'package:jarvis_mobile/services/app_launcher_service.dart';
import 'package:jarvis_mobile/services/call_service.dart';
import 'package:jarvis_mobile/services/code_snippet_service.dart';
import 'package:jarvis_mobile/services/contacts_service.dart';
import 'package:jarvis_mobile/services/device_info_service.dart';
import 'package:jarvis_mobile/services/email_service.dart';
import 'package:jarvis_mobile/services/gamification_service.dart';
import 'package:jarvis_mobile/services/ip_service.dart';
import 'package:jarvis_mobile/services/joke_service.dart';
import 'package:jarvis_mobile/services/location_service.dart';
import 'package:jarvis_mobile/services/music_dj_service.dart';
import 'package:jarvis_mobile/services/news_service.dart';
import 'package:jarvis_mobile/services/notes_service.dart';
import 'package:jarvis_mobile/services/notification_service.dart';
import 'package:jarvis_mobile/services/qr_service.dart';
import 'package:jarvis_mobile/services/random_fun_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/services/soundboard_service.dart';
import 'package:jarvis_mobile/services/spotify_service.dart';
import 'package:jarvis_mobile/services/timer_service.dart';
import 'package:jarvis_mobile/services/weather_service.dart';
import 'package:jarvis_mobile/services/web_search_service.dart';
import 'package:jarvis_mobile/services/whatsapp_service.dart';
import 'package:jarvis_mobile/services/wikipedia_service.dart';
import 'package:jarvis_mobile/services/youtube_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Fakes: real network/platform calls are never touched by these tests. ---

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

class FakeSettingsService extends SettingsService {
  String? weatherApiKey = 'test-key';
  String? newsApiKey = 'test-key';
  String? aiBackendUrl = '';
  String aiModel = 'openai';

  @override
  Future<String?> getWeatherApiKey() async => weatherApiKey;

  @override
  Future<String?> getNewsApiKey() async => newsApiKey;

  @override
  Future<String?> getAiBackendUrl() async => aiBackendUrl;

  @override
  Future<String> getAiModel() async => aiModel;
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

  @override
  Future<AiChatResult> ask(
    String backendUrl,
    String message, {
    String model = 'openai',
    List<AiTurn> history = const [],
    double sarcasm = 0.3,
  }) async {
    lastMessage = message;
    lastHistory = history;
    return AiChatResult(reply: 'FAKE_AI:$message', action: nextAction);
  }

  @override
  Future<AiChatResult> askStory(
    String backendUrl,
    String message, {
    required String genre,
    List<AiTurn> history = const [],
  }) async {
    lastStoryMessage = message;
    lastStoryHistory = history;
    lastStoryGenre = genre;
    return AiChatResult(reply: 'FAKE_STORY[$genre]:$message');
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

class FakeSoundboardService extends SoundboardService {
  int playCalls = 0;
  String? lastPlayed;

  @override
  Future<void> play(String name) async {
    playCalls++;
    lastPlayed = name;
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
  late CommandRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wikipedia = FakeWikipediaService();
    contacts = FakeContactsService();
    call = FakeCallService();
    whatsapp = FakeWhatsappService();
    aiChat = FakeAiChatService();
    timer = TimerService();
    notes = NotesService();
    email = FakeEmailService();
    youtube = FakeYoutubeService();
    notifications = FakeNotificationService();
    spotify = FakeSpotifyService();
    webSearch = FakeWebSearchService();
    settings = FakeSettingsService();
    snippets = FakeCodeSnippetService();
    soundboard = FakeSoundboardService();
    gamification = GamificationService();

    router = CommandRouter(
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
      gamification: gamification,
      musicDj: MusicDjService(),
    );
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

    test('daily bonus is claimed once and folded into the next reply', () async {
      // Uses its own fresh service/prefs (the shared `gamification` from
      // setUp already pre-claimed today's bonus so router tests above
      // aren't affected by it).
      SharedPreferences.setMockInitialValues({});
      final freshGamification = GamificationService();
      final freshRouter = CommandRouter(
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
        gamification: freshGamification,
        musicDj: MusicDjService(),
      );

      final first = await freshRouter.handle('hilfe');
      expect(first.reply, contains('Tages-Bonus'));
      expect(first.reply, contains('+10 XP'));

      final second = await freshRouter.handle('hilfe');
      expect(second.reply, isNot(contains('Tages-Bonus')));
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
}
