import 'package:intl/intl.dart';

import '../services/ai_chat_service.dart';
import '../services/ambient_sound_service.dart';
import '../services/anime_service.dart';
import '../services/app_launcher_service.dart';
import '../services/calculator_service.dart';
import '../services/call_service.dart';
import '../services/challenge_service.dart';
import '../services/code_snippet_service.dart';
import '../services/contacts_service.dart';
import '../services/device_info_service.dart';
import '../services/email_service.dart';
import '../services/gamification_service.dart';
import '../services/home_assistant_service.dart';
import '../services/ip_service.dart';
import '../services/joke_service.dart';
import '../services/journal_service.dart';
import '../services/late_night_tease_service.dart';
import '../services/location_service.dart';
import '../services/music_dj_service.dart';
import '../services/news_service.dart';
import '../services/notes_service.dart';
import '../services/notification_service.dart';
import '../services/proactive_briefing_service.dart';
import '../services/qr_service.dart';
import '../services/random_fun_service.dart';
import '../services/rpg_service.dart';
import '../services/settings_service.dart';
import '../services/soundboard_service.dart';
import '../services/spotify_service.dart';
import '../services/timer_service.dart';
import '../services/weather_service.dart';
import '../services/web_search_service.dart';
import '../services/whatsapp_service.dart';
import '../services/wikipedia_service.dart';
import '../services/youtube_service.dart';

/// Result of handling one command: text to show/speak, plus an optional
/// QR payload the UI should render, or a request to open the camera screen.
class CommandResult {
  final String reply;
  final String? qrData;
  final bool openCamera;
  final bool openYoutubeUpload;
  final String? youtubePrivacy;
  final DateTime? youtubePublishAt;
  final bool openTiktokUpload;

  CommandResult(
    this.reply, {
    this.qrData,
    this.openCamera = false,
    this.openYoutubeUpload = false,
    this.youtubePrivacy,
    this.youtubePublishAt,
    this.openTiktokUpload = false,
  });
}

/// Parses a single line of recognized speech or typed text and dispatches it
/// to the matching feature service. This is the mobile equivalent of the big
/// if/elif command ladder in the original JARVIS.py. Anything that doesn't
/// match a known command falls through to a real AI (see AiChatService), which
/// can either reply in free text or trigger a phone action (call, WhatsApp,
/// open app) itself via tool use.
class CommandRouter {
  CommandRouter({
    required this.wikipedia,
    required this.jokes,
    required this.news,
    required this.weather,
    required this.whatsapp,
    required this.email,
    required this.call,
    required this.appLauncher,
    required this.youtube,
    required this.qr,
    required this.location,
    required this.contacts,
    required this.settings,
    required this.ip,
    required this.aiChat,
    required this.deviceInfo,
    required this.timer,
    required this.notes,
    required this.fun,
    required this.notifications,
    required this.spotify,
    required this.webSearch,
    required this.snippets,
    required this.soundboard,
    required this.gamification,
    required this.musicDj,
    required this.briefing,
    required this.homeAssistant,
    required this.anime,
    required this.lateNightTease,
    required this.challenges,
    required this.rpg,
    required this.journal,
    required this.ambient,
  });

  final WikipediaService wikipedia;
  final JokeService jokes;
  final NewsService news;
  final WeatherService weather;
  final WhatsappService whatsapp;
  final EmailService email;
  final CallService call;
  final AppLauncherService appLauncher;
  final YoutubeService youtube;
  final QrService qr;
  final LocationService location;
  final ContactsService contacts;
  final SettingsService settings;
  final IpService ip;
  final AiChatService aiChat;
  final DeviceInfoService deviceInfo;
  final TimerService timer;
  final NotesService notes;
  final RandomFunService fun;
  final NotificationService notifications;
  final SpotifyService spotify;
  final WebSearchService webSearch;
  final CodeSnippetService snippets;
  final SoundboardService soundboard;
  final GamificationService gamification;
  final MusicDjService musicDj;
  final ProactiveBriefingService briefing;
  final HomeAssistantService homeAssistant;
  final AnimeService anime;
  final LateNightTeaseService lateNightTease;
  final ChallengeService challenges;
  final RpgService rpg;
  final JournalService journal;
  final AmbientSoundService ambient;

  /// Rolling window of past AI exchanges (user+assistant pairs), so a
  /// follow-up like "und morgen?" is understood in context instead of
  /// answered in isolation. Only exchanges that actually went through the
  /// AI fallback are kept — keyword-matched commands (weather, notes, ...)
  /// aren't relevant conversational context for it.
  final _aiHistory = <AiTurn>[];
  static const _maxHistoryTurns = 8;

  /// Interaktives Storytelling: while active, every input (except the exit
  /// phrase) is treated as the player's story action instead of going
  /// through the normal command ladder below.
  bool _storyMode = false;
  String _storyGenre = 'scifi';
  final _storyHistory = <AiTurn>[];
  static const _maxStoryTurns = 12;
  static const _storyExitPhrases = [
    'beende das abenteuer',
    'abenteuer beenden',
    'verlasse das abenteuer',
    'story beenden',
    'textabenteuer beenden',
  ];

  /// Überlebens-RPG: a separate, persistent-state survival mode (distinct
  /// from the free-form story mode above) — while active, every input
  /// (except reset/exit) is treated as an RPG action or narration prompt.
  /// Mutually exclusive with _storyMode (checked first, see _handleRaw).
  bool _rpgMode = false;
  final _rpgHistory = <AiTurn>[];
  static const _maxRpgTurns = 12;
  static const _rpgStartPhrases = [
    'starte das überlebens-rpg',
    'starte die postapokalypse',
    'starte das endlos-rpg',
    'starte survival modus',
    'setze das überlebens-rpg fort',
  ];
  static const _rpgResetPhrases = [
    'neues überlebens-rpg starten',
    'überlebens-rpg neu starten',
    'rpg von vorne starten',
  ];
  static const _rpgExitPhrases = [
    'beende das überlebens-rpg',
    'pausiere das überlebens-rpg',
    'verlasse das überlebens-rpg',
  ];

  static const helpText = '''
Das kann ich für dich tun:
• "wie spät ist es" / "welcher tag ist heute"
• "erzähl mir einen witz"
• "wikipedia <Thema>" oder "was ist <Thema>"
• "anime <Titel>" / "manga <Titel>" (Infos über AniList, garantiert ohne 18+-Inhalte)
• "suche im internet nach <Frage>" / "recherchiere <Thema>"
• "nachrichten" (NewsAPI-Schlüssel in Einstellungen nötig)
• "wetter" oder "wetter in <Stadt>" (OpenWeatherMap-Schlüssel nötig)
• "standort" / "wo bin ich"
• "öffne <App-Name>"
• "kamera"
• "rufe <Kontakt> an"
• "whatsapp an <Kontakt>: <Nachricht>"
• "email an <Adresse>: <Nachricht>"
• "youtube <Suchbegriff>"
• "video hochladen" / "video öffentlich hochladen" (auf dein YouTube-Konto, siehe README)
• "video auf tiktok hochladen" (TikTok-Verbindung nötig, siehe Einstellungen)
• "qr code <Text>"
• "meine ip" / "ip adresse"
• "akkustand" / "wie ist der akku"
• "rechne <Aufgabe>" oder "was ist 12 mal 7"
• "timer für <Zeit>" oder "erinnere mich in 10 minuten an <Sache>"
• "meine timer" / "timer abbrechen"
• "notiz <Text>" / "meine notizen" / "lösche notiz <Nummer>"
• "wirf eine münze" / "würfle" / "zufallszahl zwischen 1 und 100"
• "spiele <Song> auf spotify" / "spiele playlist <Name> auf spotify" (Spotify-Verbindung nötig, siehe Einstellungen)
• "code snippet für <Flutter-Widget oder Git-Befehl>" (kopiert in die Zwischenablage) / "welche code snippets kennst du"
• "spiel sound <Name>" (z.B. boot, scan, alarm) / "welche sounds hast du"
• "ambient regen" / "ambient café" / "ambient lofi" (Hintergrund-Geräuschkulisse, läuft in einer Schleife) / "stoppe die geräuschkulisse" / "welche geräuschkulissen"
• "starte ein sci-fi abenteuer" / "starte eine detektivgeschichte" (interaktives Textadventure, "beende das abenteuer" zum Verlassen)
• "starte das überlebens-rpg" (postapokalyptisches Survival-Rollenspiel mit echtem Spielstand: iss/trink/rasten/durchsuche/baue eine waffe/baue unterschlupf/status, "beende das überlebens-rpg" pausiert, "neues überlebens-rpg starten" setzt zurück)
• "aktiviere den drill-trainer" / "aktiviere den gaming-kumpel" / "aktiviere die butler-persona" / "aktiviere jarvis standard" (Persona wechseln) / "welche persona"
• "mein level" / "meine xp" / "meine erfolge" (Notizen, Timer und Commits geben XP) / "commit gemacht" (loggt einen Code-Commit)
• "tägliche challenge" (heutige Mini-Herausforderung, erscheint auch im Morgen-Briefing) / "challenge erledigt"
• "musik zum <Stimmung>" (z.B. fokus, entspannen, workout, party) / "passende musik" (nach Tageszeit) (Spotify-Verbindung nötig)
• "morgen-briefing" / "abend-zusammenfassung" (Vorschau jetzt; automatischer täglicher Versand als Benachrichtigung ist in Einstellungen aktivierbar)
• "licht <Name> an" / "licht <Name> aus" / "status von <Gerät>" (Home Assistant, URL+Token in Einstellungen nötig)
• "wie war mein tag" / "mein tag war ..." (Abend-Tagebuch mit einfühlsamer KI-Reflexion) / "meine tagebucheinträge" / "letzter tagebucheintrag"
• alles andere: frag mich einfach frei, ich antworte mit echter KI und kann
  dabei auch direkt anrufen, WhatsApp schreiben oder Apps öffnen
''';

  /// Public entry point: claims the once-per-day XP bonus (if not already
  /// claimed today) and prepends a short note about it, and appends a
  /// once-per-night humorous tease if the user is clearly still coding deep
  /// in the night — except while an interactive story or the Überlebens-RPG
  /// is running, where either would break the narration.
  Future<CommandResult> handle(String rawInput) async {
    final inNarrativeMode = _storyMode || _rpgMode;
    final dailyBonus = inNarrativeMode ? null : await gamification.claimDailyBonusIfNeeded();
    final persona = await settings.getPersona();
    final tease = inNarrativeMode ? null : await lateNightTease.maybeTease(persona, rawInput.trim().toLowerCase());
    final result = await _handleRaw(rawInput);
    var reply = result.reply;
    if (tease != null) reply = '$reply\n\n$tease';
    if (dailyBonus != null) reply = '🎉 Tages-Bonus${dailyBonus.toSuffix()}\n\n$reply';
    return CommandResult(
      reply,
      qrData: result.qrData,
      openCamera: result.openCamera,
      openYoutubeUpload: result.openYoutubeUpload,
      youtubePrivacy: result.youtubePrivacy,
      youtubePublishAt: result.youtubePublishAt,
      openTiktokUpload: result.openTiktokUpload,
    );
  }

  Future<CommandResult> _handleRaw(String rawInput) async {
    final text = rawInput.trim();
    final lower = text.toLowerCase();
    if (text.isEmpty) {
      return CommandResult('Ich habe dich nicht verstanden.');
    }

    if (_storyMode) {
      return _handleStoryTurn(text, lower);
    }
    if (_rpgMode) {
      return _handleRpgTurn(text, lower);
    }

    try {
      if (_matchesAny(lower, ['hilfe', 'was kannst du', 'help'])) {
        return CommandResult(helpText);
      }

      if (_matchesAny(lower, _rpgResetPhrases)) {
        return await _startRpg(reset: true);
      }
      if (_matchesAny(lower, _rpgStartPhrases)) {
        return await _startRpg(reset: false);
      }

      const personaTriggers = {
        'drill_sergeant': ['aktiviere den drill-trainer', 'drill-trainer modus', 'sei mein drill-trainer'],
        'gaming_buddy': ['aktiviere den gaming-kumpel', 'gaming-kumpel modus', 'sei mein gaming-kumpel'],
        'butler': ['aktiviere die butler-persona', 'butler-modus', 'sei mein butler'],
        'standard': ['aktiviere jarvis standard', 'standard-persona', 'normale persönlichkeit'],
      };
      for (final entry in personaTriggers.entries) {
        if (_matchesAny(lower, entry.value)) {
          await settings.setPersona(entry.key);
          return CommandResult(_personaConfirmation(entry.key));
        }
      }
      if (_matchesAny(lower, ['welche persona', 'aktuelle persona'])) {
        final current = await settings.getPersona();
        return CommandResult('Aktuelle Persona: ${_personaLabel(current)}.');
      }

      final detectiveStart = _matchesAny(lower, [
        'starte eine detektivgeschichte',
        'starte ein detektiv-abenteuer',
        'starte einen krimi',
      ]);
      final scifiStart = _matchesAny(lower, [
        'starte ein sci-fi abenteuer',
        'starte ein science-fiction abenteuer',
        'starte ein textabenteuer',
        'starte ein text-abenteuer',
        'starte ein rollenspiel',
        'starte ein interaktives abenteuer',
      ]);
      if (detectiveStart || scifiStart) {
        return await _startStory(detectiveStart ? 'detective' : 'scifi');
      }

      if (_matchesAny(lower, ['wie spät', 'uhrzeit', 'what time'])) {
        final now = DateFormat.Hm('de_DE').format(DateTime.now());
        return CommandResult('Es ist $now Uhr.');
      }

      if (_matchesAny(lower, ['welcher tag', 'heutiges datum', 'datum', 'what day'])) {
        final now = DateFormat('EEEE, d. MMMM y', 'de_DE').format(DateTime.now());
        return CommandResult('Heute ist $now.');
      }

      if (_matchesAny(lower, ['witz', 'joke'])) {
        return CommandResult(jokes.randomJoke());
      }

      final mathQuery = _extractAfter(lower, text, ['rechne', 'berechne', 'wie viel ist', 'wieviel ist', 'was ist']);
      if (mathQuery != null && CalculatorService.looksLikeExpression(mathQuery)) {
        final result = CalculatorService.evaluate(mathQuery);
        if (result == null) return CommandResult('Das konnte ich nicht berechnen.');
        return CommandResult('Das Ergebnis ist ${CalculatorService.format(result)}.');
      }

      final wikiQuery = _extractAfter(lower, text, ['wikipedia', 'was ist', 'wer ist']);
      if (wikiQuery != null) {
        final result = await wikipedia.summary(wikiQuery);
        return CommandResult(result);
      }

      final animeQuery = _extractAfter(lower, text, ['anime info zu', 'suche anime nach', 'anime ']);
      if (animeQuery != null) {
        return CommandResult(await _lookupAnime(animeQuery, isManga: false));
      }

      final mangaQuery = _extractAfter(lower, text, ['manga info zu', 'suche manga nach', 'manga ']);
      if (mangaQuery != null) {
        return CommandResult(await _lookupAnime(mangaQuery, isManga: true));
      }

      if (_matchesAny(lower, ['meine tagebucheinträge', 'letzter tagebucheintrag'])) {
        return CommandResult(await _journalListing(latestOnly: lower.contains('letzter')));
      }

      final journalEntryText = _extractAfter(lower, text, ['mein tag war', 'heute war', 'tagebuch:', 'tagebucheintrag:']);
      if (journalEntryText != null) {
        return CommandResult(await _submitJournalEntry(journalEntryText));
      }

      if (_matchesAny(lower, ['wie war mein tag', 'tagebucheintrag', 'abend-check-in', 'lass uns über meinen tag reden'])) {
        return CommandResult(
          'Wie war dein Tag, Master? Erzähl mir kurz davon, z. B. "mein tag war ..." oder "heute war ...".',
        );
      }

      final webSearchQuery = _extractAfter(lower, text, ['suche im internet nach', 'suche online nach', 'recherchiere']);
      if (webSearchQuery != null) {
        final backendUrl = await settings.getAiBackendUrl();
        if (backendUrl == null || backendUrl.isEmpty) {
          return CommandResult('Websuche benötigt eine KI-Server-Adresse in den Einstellungen.');
        }
        final results = await webSearch.search(backendUrl, webSearchQuery);
        if (results.isEmpty) return CommandResult('Ich konnte dazu nichts im Web finden.');
        return CommandResult(results.take(2).map((r) => r.description).join(' '));
      }

      if (_matchesAny(lower, ['nachrichten', 'news', 'schlagzeilen'])) {
        final key = await settings.getNewsApiKey();
        final headlines = await news.topHeadlines(key ?? '');
        if (headlines.isEmpty) return CommandResult('Ich habe keine Schlagzeilen gefunden.');
        return CommandResult('Aktuelle Schlagzeilen:\n${headlines.map((h) => '• $h').join('\n')}');
      }

      if (_matchesAny(lower, ['wetter', 'weather'])) {
        final key = await settings.getWeatherApiKey();
        if (key == null || key.isEmpty) {
          return CommandResult('Kein OpenWeatherMap-Schlüssel hinterlegt. Bitte in den Einstellungen eintragen.');
        }
        final city = _extractAfter(lower, text, ['wetter in', 'weather in']);
        final result = city != null
            ? await weather.byCity(key, city)
            : await _weatherAtCurrentLocation(key);
        return CommandResult(
          'Das Wetter in ${result.city}: ${result.description}, ${result.tempCelsius.toStringAsFixed(1)}°C.',
        );
      }

      if (_matchesAny(lower, ['standort', 'wo bin ich', 'where am i'])) {
        final loc = await location.current();
        final place = [loc.city, loc.country].where((s) => s != null && s.isNotEmpty).join(', ');
        return CommandResult(
          place.isEmpty
              ? 'Deine Koordinaten: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}'
              : 'Du befindest dich in $place (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}).',
        );
      }

      final appName = _extractAfter(lower, text, ['öffne', 'open']);
      if (appName != null && appName.trim().toLowerCase() != 'kamera' && appName.trim().toLowerCase() != 'camera') {
        final app = await appLauncher.findByName(appName);
        if (app == null) return CommandResult('Ich konnte die App "$appName" nicht finden.');
        await appLauncher.open(app.packageName);
        return CommandResult('Öffne ${app.name}.');
      }

      if (_matchesAny(lower, ['kamera', 'camera'])) {
        return CommandResult('Öffne die Kamera.', openCamera: true);
      }

      if (_matchesAny(lower, ['hochladen', 'upload']) && _matchesAny(lower, ['tiktok'])) {
        return CommandResult('Öffne den TikTok-Upload.', openTiktokUpload: true);
      }

      if (_matchesAny(lower, ['hochladen', 'upload']) && _matchesAny(lower, ['video', 'youtube'])) {
        final privacy = _matchesAny(lower, ['öffentlich', 'public'])
            ? 'public'
            : _matchesAny(lower, ['nicht gelistet', 'ungelistet', 'unlisted'])
            ? 'unlisted'
            : null;
        return CommandResult(
          privacy == null
              ? 'Öffne den YouTube-Upload.'
              : 'Öffne den YouTube-Upload (${privacy == 'public' ? 'öffentlich' : 'nicht gelistet'} vorausgewählt).',
          openYoutubeUpload: true,
          youtubePrivacy: privacy,
        );
      }

      final callTarget = _extractAfter(lower, text, ['rufe', 'ruf', 'call']);
      if (callTarget != null) {
        final cleaned = callTarget.replaceAll(RegExp(r'\s*an\s*$'), '').trim();
        final contact = await contacts.find(cleaned);
        if (contact == null) {
          return CommandResult('Ich habe keinen Kontakt namens "$cleaned" gefunden. Füge ihn in den Einstellungen hinzu.');
        }
        await call.call(contact.phone);
        return CommandResult('Rufe ${contact.name} an.');
      }

      final whatsappBody = _extractAfter(lower, text, ['whatsapp an', 'whatsapp']);
      if (whatsappBody != null && whatsappBody.contains(':')) {
        final parts = whatsappBody.split(':');
        final name = parts.first.trim();
        final message = parts.sublist(1).join(':').trim();
        final contact = await contacts.find(name);
        if (contact == null) {
          return CommandResult('Ich habe keinen Kontakt namens "$name" gefunden. Füge ihn in den Einstellungen hinzu.');
        }
        await whatsapp.sendMessage(phone: contact.phone, message: message);
        return CommandResult('Öffne WhatsApp für ${contact.name}.');
      }

      final emailBody = _extractAfter(lower, text, ['email an', 'email', 'e-mail an', 'e-mail']);
      if (emailBody != null && emailBody.contains(':')) {
        final parts = emailBody.split(':');
        final to = parts.first.trim();
        final message = parts.sublist(1).join(':').trim();
        await email.compose(to: to, subject: 'Nachricht von JARVIS', body: message);
        return CommandResult('Öffne E-Mail an $to.');
      }

      final moodText = _extractAfter(lower, text, ['musik zum', 'musik für', 'spiel musik zum', 'spiel musik für']);
      if (moodText != null) {
        final pick = musicDj.forMood(moodText);
        if (pick == null) {
          return CommandResult('Diese Stimmung kenne ich nicht. Versuch z.B.: ${musicDj.knownMoods.take(6).join(', ')}.');
        }
        return CommandResult(await _playMoodOnSpotify(pick));
      }

      if (_matchesAny(lower, ['passende musik', 'musik-dj', 'was passt musikalisch', 'musik für jetzt'])) {
        return CommandResult(await _playMoodOnSpotify(musicDj.forTimeOfDay()));
      }

      final youtubeQuery = _extractAfter(lower, text, ['youtube', 'spiele']);
      if (youtubeQuery != null) {
        if (youtubeQuery.contains('spotify')) {
          final withoutSpotify = youtubeQuery.replaceAll(RegExp(r'\s*(auf|bei|in)?\s*spotify\s*'), ' ').trim();
          if (withoutSpotify.contains('playlist')) {
            final playlistName = withoutSpotify.replaceAll(RegExp(r'^(meine\s+)?playlist\s*'), '').trim();
            return CommandResult(await _playPlaylistOnSpotify(playlistName));
          }
          return CommandResult(await _playOnSpotify(withoutSpotify));
        }
        await youtube.search(youtubeQuery);
        return CommandResult('Suche "$youtubeQuery" auf YouTube.');
      }

      final qrText = _extractAfter(lower, text, ['qr code für', 'qr code', 'erstelle qr code für']);
      if (qrText != null) {
        final data = qr.normalize(qrText);
        return CommandResult('Hier ist dein QR-Code.', qrData: data);
      }

      if (_matchesAny(lower, ['welche code snippets', 'verfügbare snippets', 'code snippets liste', 'code-snippets liste'])) {
        return CommandResult('Diese Code-Snippets kenne ich: ${snippets.availableTitles.join(', ')}.');
      }

      final snippetQuery = _extractAfter(lower, text, [
        'code snippet für',
        'code-snippet für',
        'code snippet',
        'code-snippet',
        'quick ref für',
        'quick reference für',
        'git befehl für',
        'zeig mir den code für',
      ]);
      if (snippetQuery != null) {
        final entry = snippets.find(snippetQuery);
        if (entry == null) {
          return CommandResult(
            'Das kenne ich nicht. Verfügbar sind z.B.: ${snippets.availableTitles.take(6).join(', ')}.',
          );
        }
        await snippets.copyToClipboard(entry.value.code);
        return CommandResult('${entry.value.title}: ${entry.value.explanation} Ich hab dir den Code in die Zwischenablage kopiert.');
      }

      if (_matchesAny(lower, ['welche sounds', 'verfügbare sounds', 'soundboard liste'])) {
        return CommandResult('Diese Sounds kenne ich: ${soundboard.availableNames.join(', ')}.');
      }

      // Note: deliberately no "spiele sound ..." phrasing here — "spiele" is
      // already claimed by the earlier YouTube-search trigger above and
      // would shadow this block before it's ever reached.
      final soundQuery = _extractAfter(lower, text, [
        'spiel sound',
        'soundboard',
        'sound abspielen',
        'spiel den sound',
      ]);
      if (soundQuery != null) {
        if (!soundboard.has(soundQuery)) {
          return CommandResult(
            'Den Sound kenne ich nicht. Verfügbar sind z.B.: ${soundboard.availableNames.take(6).join(', ')}.',
          );
        }
        await soundboard.play(soundQuery);
        return CommandResult('Sound „$soundQuery" wird abgespielt.');
      }

      if (_matchesAny(lower, ['welche geräuschkulissen', 'welche ambient sounds'])) {
        return CommandResult('Diese Soundscapes kenne ich: ${ambient.availableNames.join(', ')}.');
      }

      if (_matchesAny(lower, ['stoppe die geräuschkulisse', 'stoppe den hintergrundsound', 'beende die soundscape'])) {
        await ambient.stop();
        return CommandResult('Geräuschkulisse gestoppt.');
      }

      const ambientTriggers = {
        'regen': ['aktiviere regengeräusche', 'spiel regengeräusche', 'ambient regen'],
        'café': ['aktiviere café-geräusche', 'spiel café-geräusche', 'ambient café'],
        'lofi': ['aktiviere lofi hintergrundmusik', 'spiel lofi hintergrundmusik', 'ambient lofi'],
      };
      for (final entry in ambientTriggers.entries) {
        if (_matchesAny(lower, entry.value)) {
          await ambient.play(entry.key);
          return CommandResult('Geräuschkulisse „${entry.key}" läuft jetzt im Hintergrund.');
        }
      }

      if (_matchesAny(lower, ['meine ip', 'ip adresse', 'ip-adresse', 'my ip'])) {
        final address = await ip.publicIp();
        return CommandResult('Deine öffentliche IP-Adresse lautet $address.');
      }

      if (_matchesAny(lower, ['akkustand', 'akku', 'batterie', 'battery'])) {
        final level = await deviceInfo.batteryLevel();
        return CommandResult(
          level == null
              ? 'Ich konnte den Akkustand gerade nicht auslesen.'
              : 'Dein Akku ist bei $level Prozent.',
        );
      }

      if (_matchesAny(lower, ['timer abbrechen', 'alle timer stoppen', 'timer stoppen', 'timer löschen'])) {
        final count = timer.cancelAll();
        await notifications.cancelAll();
        return CommandResult(count == 0 ? 'Es läuft gerade kein Timer.' : '$count Timer abgebrochen.');
      }

      if (_matchesAny(lower, ['meine timer', 'laufende timer', 'timer status'])) {
        final active = timer.list();
        if (active.isEmpty) return CommandResult('Es läuft gerade kein Timer.');
        final lines = active.map((t) => '• ${t.label}: noch ${TimerService.describe(t.remaining)}');
        return CommandResult('Laufende Timer:\n${lines.join('\n')}');
      }

      final timerQuery = _extractAfter(
        lower,
        text,
        ['stelle einen timer für', 'starte einen timer für', 'timer für', 'wecker für', 'erinnere mich in'],
      );
      if (timerQuery != null) {
        final parsed = TimerService.parse(timerQuery);
        if (parsed == null) {
          return CommandResult('Ich habe die Zeitangabe nicht verstanden. Sag z. B. "timer für 5 minuten".');
        }
        final active = timer.start(parsed.duration, label: parsed.label);
        await notifications.scheduleTimerNotification(
          id: active.id.hashCode,
          body: '⏰ „${active.label}" ist abgelaufen!',
          delay: parsed.duration,
        );
        final xp = await gamification.awardForTimer();
        return CommandResult(
          'Timer "${active.label}" gestellt: ${TimerService.describe(parsed.duration)}.${xp.toSuffix()}',
        );
      }

      if (_matchesAny(lower, ['lösche alle notizen', 'alle notizen löschen', 'notizen löschen'])) {
        await notes.clear();
        return CommandResult('Alle Notizen gelöscht.');
      }

      final deleteNoteQuery = _extractAfter(lower, text, ['lösche notiz']);
      if (deleteNoteQuery != null) {
        final index = int.tryParse(deleteNoteQuery.trim());
        if (index == null) return CommandResult('Sag z. B. "lösche notiz 2".');
        final removed = await notes.deleteAt(index);
        return CommandResult(removed == null ? 'Notiz $index existiert nicht.' : 'Notiz gelöscht: $removed');
      }

      if (_matchesAny(lower, ['notizen'])) {
        final all = await notes.list();
        if (all.isEmpty) return CommandResult('Du hast noch keine Notizen.');
        final lines = List.generate(all.length, (i) => '${i + 1}. ${all[i]}');
        return CommandResult('Deine Notizen:\n${lines.join('\n')}');
      }

      // Trailing spaces/colon on these prefixes require a right-hand word
      // boundary too, so e.g. "notizen" (plural) isn't misread as the
      // "notiz " prefix with "en" left over as bogus note text.
      final noteText = _extractAfter(lower, text, ['notiere dir', 'merke dir', 'notiz:', 'notiere ', 'neue notiz ', 'notiz ']);
      if (noteText != null) {
        await notes.add(noteText);
        final xp = await gamification.awardForNote();
        return CommandResult('Notiz gespeichert: $noteText${xp.toSuffix()}');
      }

      if (_matchesAny(lower, ['mein level', 'meine xp', 'mein rang', 'meine erfolge', 'meine achievements'])) {
        return CommandResult(await gamification.statusText());
      }

      if (_matchesAny(lower, ['tägliche challenge', 'heutige challenge', 'meine challenge', 'challenge des tages'])) {
        final challenge = await challenges.current();
        final done = await challenges.isCompletedToday();
        return CommandResult(
          done
              ? 'Heutige Challenge (schon erledigt): ${challenge.text}'
              : 'Heutige Challenge: ${challenge.text}',
        );
      }

      if (_matchesAny(lower, ['challenge erledigt', 'challenge abgeschlossen', 'challenge geschafft'])) {
        if (await challenges.isCompletedToday()) {
          return CommandResult('Die heutige Challenge hast du schon erledigt gemeldet, Master.');
        }
        await challenges.markCompleted();
        final xp = await gamification.awardForChallenge();
        return CommandResult('Challenge erledigt!${xp.toSuffix()}');
      }

      if (_matchesAny(lower, ['morgen-briefing', 'morgenbriefing', 'gib mir das briefing'])) {
        return CommandResult(await briefing.buildMorningBriefing());
      }

      if (_matchesAny(lower, ['abend-zusammenfassung', 'tageszusammenfassung', 'abendzusammenfassung'])) {
        return CommandResult(await briefing.buildEveningSummary());
      }

      final lightOnMatch = RegExp(
        r'^(?:schalte |mach )?(?:das |die )?licht(?:er)?\s+(.+?)\s+an\b',
      ).firstMatch(lower);
      if (lightOnMatch != null) {
        return CommandResult(await _setHomeAssistantLight(lightOnMatch.group(1)!.trim(), turnOn: true));
      }

      final lightOffMatch = RegExp(
        r'^(?:schalte |mach )?(?:das |die )?licht(?:er)?\s+(.+?)\s+aus\b',
      ).firstMatch(lower);
      if (lightOffMatch != null) {
        return CommandResult(await _setHomeAssistantLight(lightOffMatch.group(1)!.trim(), turnOn: false));
      }

      final deviceStatusQuery = _extractAfter(lower, text, ['status von', 'wie ist der status von', 'gerätestatus von']);
      if (deviceStatusQuery != null) {
        return CommandResult(await _homeAssistantStatus(deviceStatusQuery));
      }

      if (_matchesAny(lower, ['commit gemacht', 'ich habe committet', 'logge einen commit', 'trage einen commit ein'])) {
        final xp = await gamification.logCommit();
        return CommandResult('Commit geloggt.${xp.toSuffix()}');
      }

      if (_matchesAny(lower, ['wirf eine münze', 'münze werfen', 'kopf oder zahl', 'münze'])) {
        return CommandResult('${fun.flipCoin()}!');
      }

      final diceSidesQuery = _extractAfter(lower, text, ['würfle mit', 'würfel mit']);
      if (diceSidesQuery != null) {
        final sides = int.tryParse(RegExp(r'\d+').stringMatch(diceSidesQuery) ?? '');
        if (sides == null || sides < 2) return CommandResult('Sag z. B. "würfle mit 20 seiten".');
        return CommandResult('Du hast eine ${fun.rollDice(sides: sides)} gewürfelt (W$sides).');
      }

      if (_matchesAny(lower, ['würfle', 'würfel'])) {
        return CommandResult('Du hast eine ${fun.rollDice()} gewürfelt.');
      }

      final rangeQuery = _extractAfter(lower, text, ['zufallszahl zwischen', 'zufallszahl von']);
      if (rangeQuery != null) {
        final numbers = RegExp(r'\d+').allMatches(rangeQuery).map((m) => int.parse(m.group(0)!)).toList();
        if (numbers.length < 2) return CommandResult('Sag z. B. "zufallszahl zwischen 1 und 100".');
        return CommandResult('${fun.randomInRange(numbers[0], numbers[1])}');
      }

      final backendUrl = await settings.getAiBackendUrl();
      final aiModel = await settings.getAiModel();
      final sarcasm = await settings.getSarcasmLevel();
      final persona = await settings.getPersona();
      final aiResult = await aiChat.ask(
        backendUrl ?? '',
        text,
        model: aiModel,
        history: List.unmodifiable(_aiHistory),
        sarcasm: sarcasm,
        persona: persona,
      );
      _aiHistory.add(AiTurn(role: 'user', content: text));
      _aiHistory.add(AiTurn(role: 'assistant', content: aiResult.reply));
      while (_aiHistory.length > _maxHistoryTurns * 2) {
        _aiHistory.removeAt(0);
      }
      return await _handleAiResult(aiResult);
    } catch (e) {
      return CommandResult('Fehler: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  static const _personaLabels = {
    'standard': 'JARVIS (Standard)',
    'drill_sergeant': 'Drill-Trainer',
    'gaming_buddy': 'Gaming-Kumpel',
    'butler': 'Butler',
  };

  String _personaLabel(String persona) => _personaLabels[persona] ?? _personaLabels['standard']!;

  String _personaConfirmation(String persona) {
    switch (persona) {
      case 'drill_sergeant':
        return 'DRILL-TRAINER AKTIVIERT! Auf geht\'s, keine Ausreden mehr!';
      case 'gaming_buddy':
        return 'Yo! Bin jetzt dein Gaming-Kumpel, lass uns zocken.';
      case 'butler':
        return 'Sehr wohl, gnädiger Herr. Die Butler-Persona ist ab sofort aktiv.';
      default:
        return 'Zurück zur Standard-Persona, Master.';
    }
  }

  Future<CommandResult> _startStory(String genre) async {
    try {
      _storyGenre = genre;
      _storyHistory.clear();
      final backendUrl = await settings.getAiBackendUrl();
      const kickoff = 'Starte die Geschichte mit einer packenden Eröffnungsszene.';
      final result = await aiChat.askStory(backendUrl ?? '', kickoff, genre: genre, history: const []);
      _storyHistory.add(AiTurn(role: 'user', content: kickoff));
      _storyHistory.add(AiTurn(role: 'assistant', content: result.reply));
      _storyMode = true;
      return CommandResult('${result.reply}\n\n(Sag jederzeit "beende das Abenteuer", um auszusteigen.)');
    } catch (e) {
      return CommandResult('Fehler: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<CommandResult> _handleStoryTurn(String text, String lower) async {
    if (_matchesAny(lower, _storyExitPhrases)) {
      _storyMode = false;
      _storyHistory.clear();
      return CommandResult('Das Abenteuer endet hier. Willkommen zurück, Master.');
    }
    try {
      final backendUrl = await settings.getAiBackendUrl();
      final result = await aiChat.askStory(
        backendUrl ?? '',
        text,
        genre: _storyGenre,
        history: List.unmodifiable(_storyHistory),
      );
      _storyHistory.add(AiTurn(role: 'user', content: text));
      _storyHistory.add(AiTurn(role: 'assistant', content: result.reply));
      while (_storyHistory.length > _maxStoryTurns * 2) {
        _storyHistory.removeAt(0);
      }
      return CommandResult(result.reply);
    } catch (e) {
      return CommandResult('Fehler: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<CommandResult> _handleAiResult(AiChatResult aiResult) async {
    final action = aiResult.action;
    if (action == null) {
      return CommandResult(aiResult.reply);
    }

    switch (action.type) {
      case 'call_contact':
        final name = (action.params['name'] as String?)?.trim() ?? '';
        final contact = await contacts.find(name);
        if (contact == null) {
          return CommandResult('Ich habe keinen Kontakt namens "$name" gefunden. Füge ihn in den Einstellungen hinzu.');
        }
        await call.call(contact.phone);
        return CommandResult('Rufe ${contact.name} an.');

      case 'send_whatsapp':
        final name = (action.params['name'] as String?)?.trim() ?? '';
        final message = (action.params['message'] as String?)?.trim() ?? '';
        final contact = await contacts.find(name);
        if (contact == null) {
          return CommandResult('Ich habe keinen Kontakt namens "$name" gefunden. Füge ihn in den Einstellungen hinzu.');
        }
        await whatsapp.sendMessage(phone: contact.phone, message: message);
        return CommandResult('Öffne WhatsApp für ${contact.name}.');

      case 'open_app':
        final appName = (action.params['app_name'] as String?)?.trim() ?? '';
        final app = await appLauncher.findByName(appName);
        if (app == null) return CommandResult('Ich konnte die App "$appName" nicht finden.');
        await appLauncher.open(app.packageName);
        return CommandResult('Öffne ${app.name}.');

      case 'set_timer':
        final minutesValue = action.params['minutes'];
        final minutes = minutesValue is num ? minutesValue.toInt() : int.tryParse('$minutesValue');
        if (minutes == null || minutes <= 0) {
          return CommandResult('Ich habe die Zeitangabe nicht verstanden. Sag z. B. "timer für 5 minuten".');
        }
        final label = (action.params['label'] as String?)?.trim();
        final active = timer.start(Duration(minutes: minutes), label: label);
        await notifications.scheduleTimerNotification(
          id: active.id.hashCode,
          body: '⏰ „${active.label}" ist abgelaufen!',
          delay: active.duration,
        );
        final timerXp = await gamification.awardForTimer();
        return CommandResult(
          'Timer "${active.label}" gestellt: ${TimerService.describe(active.duration)}.${timerXp.toSuffix()}',
        );

      case 'add_note':
        final noteText = (action.params['text'] as String?)?.trim() ?? '';
        if (noteText.isEmpty) return CommandResult('Was soll ich mir merken?');
        await notes.add(noteText);
        final noteXp = await gamification.awardForNote();
        return CommandResult('Notiz gespeichert: $noteText${noteXp.toSuffix()}');

      case 'get_weather':
        final key = await settings.getWeatherApiKey();
        if (key == null || key.isEmpty) {
          return CommandResult('Kein OpenWeatherMap-Schlüssel hinterlegt. Bitte in den Einstellungen eintragen.');
        }
        final city = (action.params['city'] as String?)?.trim();
        final weatherResult = (city == null || city.isEmpty) ? await _weatherAtCurrentLocation(key) : await weather.byCity(key, city);
        return CommandResult(
          'Das Wetter in ${weatherResult.city}: ${weatherResult.description}, ${weatherResult.tempCelsius.toStringAsFixed(1)}°C.',
        );

      case 'open_camera':
        return CommandResult('Öffne die Kamera.', openCamera: true);

      case 'search_wikipedia':
        final topic = (action.params['topic'] as String?)?.trim() ?? '';
        if (topic.isEmpty) return CommandResult('Wonach soll ich auf Wikipedia suchen?');
        return CommandResult(await wikipedia.summary(topic));

      case 'get_news':
        final newsKey = await settings.getNewsApiKey();
        final headlines = await news.topHeadlines(newsKey ?? '');
        if (headlines.isEmpty) return CommandResult('Ich habe keine Schlagzeilen gefunden.');
        return CommandResult('Aktuelle Schlagzeilen:\n${headlines.map((h) => '• $h').join('\n')}');

      case 'send_email':
        final to = (action.params['to'] as String?)?.trim() ?? '';
        if (to.isEmpty) return CommandResult('An welche E-Mail-Adresse soll ich schreiben?');
        final subject = (action.params['subject'] as String?)?.trim();
        final body = (action.params['body'] as String?)?.trim() ?? '';
        await email.compose(
          to: to,
          subject: (subject == null || subject.isEmpty) ? 'Nachricht von JARVIS' : subject,
          body: body,
        );
        return CommandResult('Öffne E-Mail an $to.');

      case 'search_youtube':
        final query = (action.params['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) return CommandResult('Wonach soll ich auf YouTube suchen?');
        await youtube.search(query);
        return CommandResult('Suche "$query" auf YouTube.');

      case 'search_web':
        final query = (action.params['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) return CommandResult('Wonach soll ich im Web suchen?');
        final backendUrl = await settings.getAiBackendUrl();
        if (backendUrl == null || backendUrl.isEmpty) {
          return CommandResult('Websuche benötigt eine KI-Server-Adresse in den Einstellungen.');
        }
        final results = await webSearch.search(backendUrl, query);
        if (results.isEmpty) return CommandResult('Ich konnte dazu nichts im Web finden.');
        return CommandResult(results.take(2).map((r) => r.description).join(' '));

      case 'play_music':
        final song = (action.params['query'] as String?)?.trim() ?? '';
        if (song.isEmpty) return CommandResult('Was soll ich auf Spotify abspielen?');
        return CommandResult(await _playOnSpotify(song));

      case 'play_playlist':
        final playlistName = (action.params['query'] as String?)?.trim() ?? '';
        if (playlistName.isEmpty) return CommandResult('Welche Playlist soll ich abspielen?');
        return CommandResult(await _playPlaylistOnSpotify(playlistName));

      case 'open_tiktok_upload':
        return CommandResult('Öffne den TikTok-Upload.', openTiktokUpload: true);

      case 'open_youtube_upload':
        final uploadPrivacy = _normalizeYoutubePrivacy(action.params['privacy_status'] as String?);
        final publishAt = _parseYoutubePublishAt(action.params['publish_at'] as String?);
        return CommandResult(
          'Öffne den YouTube-Upload.',
          openYoutubeUpload: true,
          youtubePrivacy: publishAt != null ? 'private' : uploadPrivacy,
          youtubePublishAt: publishAt,
        );

      default:
        return CommandResult(aiResult.reply);
    }
  }

  Future<WeatherResult> _weatherAtCurrentLocation(String key) async {
    final loc = await location.current();
    return weather.byCoordinates(key, loc.latitude, loc.longitude);
  }

  Future<(String, String)?> _homeAssistantCredentials() async {
    final url = await settings.getHomeAssistantUrl();
    final token = await settings.getHomeAssistantToken();
    if (url == null || url.isEmpty || token == null || token.isEmpty) return null;
    return (url, token);
  }

  Future<String> _setHomeAssistantLight(String name, {required bool turnOn}) async {
    final creds = await _homeAssistantCredentials();
    if (creds == null) {
      return 'Home Assistant ist nicht eingerichtet. Bitte URL und Token in den Einstellungen eintragen.';
    }
    return homeAssistant.setLight(creds.$1, creds.$2, name, turnOn: turnOn);
  }

  Future<String> _homeAssistantStatus(String name) async {
    final creds = await _homeAssistantCredentials();
    if (creds == null) {
      return 'Home Assistant ist nicht eingerichtet. Bitte URL und Token in den Einstellungen eintragen.';
    }
    return homeAssistant.status(creds.$1, creds.$2, name);
  }

  Future<String> _lookupAnime(String title, {required bool isManga}) async {
    final result = isManga ? await anime.searchManga(title) : await anime.searchAnime(title);
    if (result == null) return 'Ich konnte "$title" nicht finden.';

    final buffer = StringBuffer(result.title);
    if (result.year != null) buffer.write(' (${result.year})');
    buffer.write('.');
    if (result.genres.isNotEmpty) buffer.write(' Genres: ${result.genres.take(3).join(', ')}.');
    if (result.averageScore != null) buffer.write(' Bewertung: ${result.averageScore}/100.');
    final unit = isManga ? 'Kapitel' : 'Episoden';
    if (result.episodesOrChapters != null) buffer.write(' $unit: ${result.episodesOrChapters}.');
    if (result.description != null) {
      final desc = result.description!.length > 300 ? '${result.description!.substring(0, 300)}…' : result.description!;
      buffer.write(' $desc');
    }
    return buffer.toString().trim();
  }

  Future<String> _submitJournalEntry(String entryText) async {
    final backendUrl = await settings.getAiBackendUrl();
    final result = await aiChat.askJournal(backendUrl ?? '', entryText);
    await journal.add(entryText, result.reply);
    return result.reply;
  }

  Future<String> _journalListing({required bool latestOnly}) async {
    if (latestOnly) {
      final entry = await journal.latest();
      if (entry == null) return 'Du hast noch keine Tagebucheinträge.';
      return '${_formatJournalDate(entry.date)}: ${entry.text}\n\n${entry.reflection}';
    }
    final entries = await journal.list();
    if (entries.isEmpty) return 'Du hast noch keine Tagebucheinträge.';
    final recent = entries.length > 5 ? entries.sublist(entries.length - 5) : entries;
    return recent.map((e) => '${_formatJournalDate(e.date)}: ${e.text}').join('\n');
  }

  String _formatJournalDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Future<String> _playMoodOnSpotify(MoodPick pick) async {
    final clientId = await settings.getSpotifyClientId();
    if (clientId == null || clientId.isEmpty) {
      return 'Spotify ist nicht eingerichtet. Bitte Client-ID in den Einstellungen eintragen und verbinden.';
    }
    if (!await spotify.isConnected()) {
      return 'Spotify ist noch nicht verbunden. Bitte in den Einstellungen anmelden.';
    }
    return spotify.playMoodPlaylist(clientId, pick.query, pick.label);
  }

  Future<String> _playOnSpotify(String song) async {
    final clientId = await settings.getSpotifyClientId();
    if (clientId == null || clientId.isEmpty) {
      return 'Spotify ist nicht eingerichtet. Bitte Client-ID in den Einstellungen eintragen und verbinden.';
    }
    if (!await spotify.isConnected()) {
      return 'Spotify ist noch nicht verbunden. Bitte in den Einstellungen anmelden.';
    }
    return spotify.play(clientId, song);
  }

  Future<String> _playPlaylistOnSpotify(String name) async {
    final clientId = await settings.getSpotifyClientId();
    if (clientId == null || clientId.isEmpty) {
      return 'Spotify ist nicht eingerichtet. Bitte Client-ID in den Einstellungen eintragen und verbinden.';
    }
    if (!await spotify.isConnected()) {
      return 'Spotify ist noch nicht verbunden. Bitte in den Einstellungen anmelden.';
    }
    if (name.isEmpty) return 'Welche Playlist soll ich abspielen?';
    return spotify.playPlaylist(clientId, name);
  }

  String? _normalizeYoutubePrivacy(String? raw) {
    const allowed = {'private', 'unlisted', 'public'};
    final value = raw?.trim().toLowerCase();
    return allowed.contains(value) ? value : null;
  }

  DateTime? _parseYoutubePublishAt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim())?.toUtc();
    if (parsed == null || !parsed.isAfter(DateTime.now().toUtc())) return null;
    return parsed;
  }

  bool _matchesAny(String lower, List<String> keywords) {
    return keywords.any((k) => lower.contains(k));
  }

  static final _wordCharPattern = RegExp(r'[a-zA-ZäöüÄÖÜß0-9]');

  bool _isWordChar(String ch) => _wordCharPattern.hasMatch(ch);

  /// Like _matchesAny but requires the phrase not be glued to another
  /// letter/digit on either side — needed for short RPG action keywords
  /// (e.g. "iss") where a bare contains() would false-positive inside an
  /// unrelated word (e.g. "wissen").
  bool _matchesWholeWord(String lower, List<String> phrases) {
    for (final phrase in phrases) {
      var searchStart = 0;
      while (true) {
        final idx = lower.indexOf(phrase, searchStart);
        if (idx == -1) break;
        final leftOk = idx == 0 || !_isWordChar(lower[idx - 1]);
        final endIdx = idx + phrase.length;
        final rightOk = endIdx >= lower.length || !_isWordChar(lower[endIdx]);
        if (leftOk && rightOk) return true;
        searchStart = idx + 1;
      }
    }
    return false;
  }

  /// Finds the first *word-boundary* match of any prefix keyword and returns
  /// the remaining text after it (trimmed), or null if none match. Plain
  /// substring search would let e.g. "ruf" misfire inside "anrufen" and chop
  /// the target text at the wrong point, so a match only counts if it isn't
  /// glued to another letter/digit on its left side.
  String? _extractAfter(String lower, String original, List<String> prefixes) {
    for (final prefix in prefixes) {
      var searchStart = 0;
      while (true) {
        final idx = lower.indexOf(prefix, searchStart);
        if (idx == -1) break;
        final boundaryOk = idx == 0 || !_isWordChar(lower[idx - 1]);
        if (boundaryOk) {
          final start = idx + prefix.length;
          if (start <= original.length) {
            final rest = original.substring(start).trim();
            if (rest.isNotEmpty) return rest;
          }
        }
        searchStart = idx + 1;
      }
    }
    return null;
  }

  static const _rpgStatusPhrases = ['status', 'meine werte', 'wie geht es mir', 'rpg status'];
  static const _rpgEatPhrases = ['iss', 'esse', 'nahrung zu mir'];
  static const _rpgDrinkPhrases = ['trink', 'trinke'];
  static const _rpgRestPhrases = ['ruh dich aus', 'ruhe dich aus', 'rasten', 'schlafen'];
  static const _rpgScavengePhrases = ['durchsuche', 'plündere', 'suche nach beute'];
  static const _rpgCraftWeaponPhrases = ['baue eine waffe', 'crafte eine waffe', 'waffe bauen'];
  static const _rpgBuildShelterPhrases = ['baue unterschlupf', 'unterschlupf bauen', 'baue ein lager'];

  /// Starts a fresh run (if none exists yet, or [reset] is true) or resumes
  /// an existing alive one. A previously-dead save re-enters the locked
  /// "you died" state instead of silently starting over — the player must
  /// use a reset phrase explicitly to discard it.
  Future<CommandResult> _startRpg({required bool reset}) async {
    try {
      final existing = reset ? null : await rpg.loadStats();
      if (existing != null && existing.alive && !reset) {
        _rpgHistory
          ..clear()
          ..addAll(await rpg.loadHistory());
        _rpgMode = true;
        return CommandResult('Überlebens-RPG fortgesetzt.\n\n${existing.summary()}');
      }
      if (existing != null && !existing.alive && !reset) {
        _rpgMode = true;
        return CommandResult(_rpgDeathMessage(existing));
      }

      final stats = await rpg.startNewRun();
      _rpgHistory.clear();
      final backendUrl = await settings.getAiBackendUrl();
      const kickoff = 'Starte das Überlebens-RPG mit einer packenden Eröffnungsszene der Apokalypse.';
      final result = await aiChat.askRpg(backendUrl ?? '', kickoff, statsSummary: stats.summary(), history: const []);
      _rpgHistory.add(AiTurn(role: 'user', content: kickoff));
      _rpgHistory.add(AiTurn(role: 'assistant', content: result.reply));
      await rpg.saveHistory(_rpgHistory);
      _rpgMode = true;
      return CommandResult(
        '${result.reply}\n\n(Befehle: iss, trink, rasten, durchsuche, baue eine waffe, baue unterschlupf, status. '
        '"beende das überlebens-rpg" pausiert.)',
      );
    } catch (e) {
      return CommandResult('Fehler: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  String _rpgDeathMessage(RpgStats stats) =>
      'Du bist an Tag ${stats.day} gestorben. Sag "neues überlebens-rpg starten", um von vorne zu beginnen, '
      'oder "beende das überlebens-rpg", um auszusteigen.';

  Future<CommandResult> _handleRpgTurn(String text, String lower) async {
    if (_matchesAny(lower, _rpgExitPhrases)) {
      _rpgMode = false;
      return CommandResult('Das Überlebens-RPG pausiert. Dein Fortschritt bleibt gespeichert, Master.');
    }
    if (_matchesAny(lower, _rpgResetPhrases)) {
      return await _startRpg(reset: true);
    }

    try {
      var stats = await rpg.loadStats() ?? RpgStats.initial();

      if (!stats.alive) {
        return CommandResult(_rpgDeathMessage(stats));
      }

      if (_matchesWholeWord(lower, _rpgStatusPhrases)) {
        return CommandResult(stats.summary());
      }

      String? actionMessage;
      if (_matchesWholeWord(lower, _rpgEatPhrases)) {
        final r = RpgService.eat(stats);
        stats = r.stats;
        actionMessage = r.message;
      } else if (_matchesWholeWord(lower, _rpgDrinkPhrases)) {
        final r = RpgService.drink(stats);
        stats = r.stats;
        actionMessage = r.message;
      } else if (_matchesWholeWord(lower, _rpgRestPhrases)) {
        final r = RpgService.rest(stats);
        stats = r.stats;
        actionMessage = r.message;
      } else if (_matchesWholeWord(lower, _rpgScavengePhrases)) {
        final r = RpgService.scavenge(stats);
        stats = r.stats;
        actionMessage = r.message;
      } else if (_matchesWholeWord(lower, _rpgCraftWeaponPhrases)) {
        final r = RpgService.craftWeapon(stats);
        stats = r.stats;
        actionMessage = r.message;
      } else if (_matchesWholeWord(lower, _rpgBuildShelterPhrases)) {
        final r = RpgService.buildShelter(stats);
        stats = r.stats;
        actionMessage = r.message;
      }

      stats = RpgService.advanceDay(stats);
      await rpg.saveStats(stats);

      final backendUrl = await settings.getAiBackendUrl();
      final aiMessage = actionMessage == null ? text : '$text\n\n(Ergebnis: $actionMessage)';
      final result = await aiChat.askRpg(
        backendUrl ?? '',
        aiMessage,
        statsSummary: stats.summary(),
        history: List.unmodifiable(_rpgHistory),
      );
      _rpgHistory.add(AiTurn(role: 'user', content: text));
      _rpgHistory.add(AiTurn(role: 'assistant', content: result.reply));
      while (_rpgHistory.length > _maxRpgTurns * 2) {
        _rpgHistory.removeAt(0);
      }
      await rpg.saveHistory(_rpgHistory);

      if (!stats.alive) {
        return CommandResult('${result.reply}\n\n☠️ ${_rpgDeathMessage(stats)}');
      }
      return CommandResult(result.reply);
    } catch (e) {
      return CommandResult('Fehler: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }
}
