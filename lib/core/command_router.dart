import 'package:intl/intl.dart';

import '../services/ai_chat_service.dart';
import '../services/app_launcher_service.dart';
import '../services/calculator_service.dart';
import '../services/call_service.dart';
import '../services/code_snippet_service.dart';
import '../services/contacts_service.dart';
import '../services/device_info_service.dart';
import '../services/email_service.dart';
import '../services/ip_service.dart';
import '../services/joke_service.dart';
import '../services/location_service.dart';
import '../services/news_service.dart';
import '../services/notes_service.dart';
import '../services/notification_service.dart';
import '../services/qr_service.dart';
import '../services/random_fun_service.dart';
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

  /// Rolling window of past AI exchanges (user+assistant pairs), so a
  /// follow-up like "und morgen?" is understood in context instead of
  /// answered in isolation. Only exchanges that actually went through the
  /// AI fallback are kept — keyword-matched commands (weather, notes, ...)
  /// aren't relevant conversational context for it.
  final _aiHistory = <AiTurn>[];
  static const _maxHistoryTurns = 8;

  static const helpText = '''
Das kann ich für dich tun:
• "wie spät ist es" / "welcher tag ist heute"
• "erzähl mir einen witz"
• "wikipedia <Thema>" oder "was ist <Thema>"
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
• alles andere: frag mich einfach frei, ich antworte mit echter KI und kann
  dabei auch direkt anrufen, WhatsApp schreiben oder Apps öffnen
''';

  Future<CommandResult> handle(String rawInput) async {
    final text = rawInput.trim();
    final lower = text.toLowerCase();
    if (text.isEmpty) {
      return CommandResult('Ich habe dich nicht verstanden.');
    }

    try {
      if (_matchesAny(lower, ['hilfe', 'was kannst du', 'help'])) {
        return CommandResult(helpText);
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
        return CommandResult('Timer "${active.label}" gestellt: ${TimerService.describe(parsed.duration)}.');
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
        return CommandResult('Notiz gespeichert: $noteText');
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
      final aiResult = await aiChat.ask(
        backendUrl ?? '',
        text,
        model: aiModel,
        history: List.unmodifiable(_aiHistory),
        sarcasm: sarcasm,
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
        return CommandResult('Timer "${active.label}" gestellt: ${TimerService.describe(active.duration)}.');

      case 'add_note':
        final noteText = (action.params['text'] as String?)?.trim() ?? '';
        if (noteText.isEmpty) return CommandResult('Was soll ich mir merken?');
        await notes.add(noteText);
        return CommandResult('Notiz gespeichert: $noteText');

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
}
