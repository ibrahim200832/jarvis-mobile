import 'package:intl/intl.dart';

import '../services/app_launcher_service.dart';
import '../services/call_service.dart';
import '../services/contacts_service.dart';
import '../services/email_service.dart';
import '../services/ip_service.dart';
import '../services/joke_service.dart';
import '../services/location_service.dart';
import '../services/news_service.dart';
import '../services/qr_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';
import '../services/whatsapp_service.dart';
import '../services/wikipedia_service.dart';
import '../services/youtube_service.dart';

/// Result of handling one command: text to show/speak, plus an optional
/// QR payload the UI should render, or a request to open the camera screen.
class CommandResult {
  final String reply;
  final String? qrData;
  final bool openCamera;

  CommandResult(this.reply, {this.qrData, this.openCamera = false});
}

/// Parses a single line of recognized speech or typed text and dispatches it
/// to the matching feature service. This is the mobile equivalent of the big
/// if/elif command ladder in the original JARVIS.py.
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

  static const helpText = '''
Das kann ich für dich tun:
• "wie spät ist es" / "welcher tag ist heute"
• "erzähl mir einen witz"
• "wikipedia <Thema>" oder "was ist <Thema>"
• "nachrichten" (NewsAPI-Schlüssel in Einstellungen nötig)
• "wetter" oder "wetter in <Stadt>" (OpenWeatherMap-Schlüssel nötig)
• "standort" / "wo bin ich"
• "öffne <App-Name>"
• "kamera"
• "rufe <Kontakt> an"
• "whatsapp an <Kontakt>: <Nachricht>"
• "email an <Adresse>: <Nachricht>"
• "youtube <Suchbegriff>"
• "qr code <Text>"
• "meine ip" / "ip adresse"
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

      final wikiQuery = _extractAfter(lower, text, ['wikipedia', 'was ist', 'wer ist']);
      if (wikiQuery != null) {
        final result = await wikipedia.summary(wikiQuery);
        return CommandResult(result);
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
        await youtube.search(youtubeQuery);
        return CommandResult('Suche "$youtubeQuery" auf YouTube.');
      }

      final qrText = _extractAfter(lower, text, ['qr code für', 'qr code', 'erstelle qr code für']);
      if (qrText != null) {
        final data = qr.normalize(qrText);
        return CommandResult('Hier ist dein QR-Code.', qrData: data);
      }

      if (_matchesAny(lower, ['meine ip', 'ip adresse', 'ip-adresse', 'my ip'])) {
        final address = await ip.publicIp();
        return CommandResult('Deine öffentliche IP-Adresse lautet $address.');
      }

      return CommandResult('Das habe ich nicht verstanden. Sag "Hilfe" für eine Liste der Befehle.');
    } catch (e) {
      return CommandResult('Fehler: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<WeatherResult> _weatherAtCurrentLocation(String key) async {
    final loc = await location.current();
    return weather.byCoordinates(key, loc.latitude, loc.longitude);
  }

  bool _matchesAny(String lower, List<String> keywords) {
    return keywords.any((k) => lower.contains(k));
  }

  /// Finds the first matching prefix keyword and returns the remaining text
  /// after it (trimmed), or null if none of the prefixes match.
  String? _extractAfter(String lower, String original, List<String> prefixes) {
    for (final prefix in prefixes) {
      final idx = lower.indexOf(prefix);
      if (idx == -1) continue;
      final start = idx + prefix.length;
      if (start > original.length) continue;
      final rest = original.substring(start).trim();
      if (rest.isEmpty) continue;
      return rest;
    }
    return null;
  }
}
