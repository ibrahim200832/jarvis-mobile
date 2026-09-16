import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// One Google Calendar event, enough to list/announce and to create new ones.
class CalendarEvent {
  CalendarEvent(this.id, this.title, this.start, {this.allDay = false});

  final String id;
  final String title;
  final DateTime start;
  final bool allDay;
}

/// Reads and creates events on the user's own Google Calendar, authenticated
/// via Google Sign-In (same client ID as the existing YouTube upload
/// feature — a Google Cloud OAuth client can hold multiple API scopes).
/// Requesting offline access additionally hands the app a one-time
/// `serverAuthCode`, which [connectReminders] forwards to the Worker so it
/// can place background reminder calls without the app open (see
/// worker/ai-proxy.js `/calendar/connect` and README, Abschnitt
/// "Anruf-Erinnerungen").
class CalendarService {
  static const _keyRemindersConnected = 'calendar_reminders_connected';

  /// [clientIdProvider] is read lazily (not at construction time), since the
  /// Google Client ID lives in async SharedPreferences-backed Einstellungen
  /// and this service is created once, up front, in home_screen.dart — same
  /// reasoning as YoutubeUploadService, just deferred one step further since
  /// this service is long-lived instead of created per upload flow.
  CalendarService({required Future<String?> Function() clientIdProvider}) : _clientIdProvider = clientIdProvider;

  final Future<String?> Function() _clientIdProvider;
  GoogleSignIn? _googleSignIn;

  Future<GoogleSignIn> _signInClient() async {
    if (_googleSignIn != null) return _googleSignIn!;
    final clientId = await _clientIdProvider();
    final client = GoogleSignIn(
      scopes: const ['https://www.googleapis.com/auth/calendar'],
      serverClientId: (clientId != null && clientId.isNotEmpty) ? clientId : null,
    );
    _googleSignIn = client;
    return client;
  }

  Future<GoogleSignInAccount?> get currentUser async => (await _signInClient()).currentUser;

  Future<GoogleSignInAccount?> signIn() async => (await _signInClient()).signIn();

  Future<void> signOut() async => (await _signInClient()).signOut();

  Future<String?> _accessToken() async {
    final googleSignIn = await _signInClient();
    var account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();
    account ??= await googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  /// Signs in fresh (so Google issues a `serverAuthCode`) and sends it to the
  /// Worker together with the phone number reminder calls should go to.
  /// Returns null on success, or a human-readable error.
  Future<String?> connectReminders({
    required String backendUrl,
    required String secret,
    required String phone,
  }) async {
    if (backendUrl.trim().isEmpty) return 'Kalender-Erinnerungen benötigen eine KI-Server-Adresse in den Einstellungen.';
    if (secret.trim().isEmpty) return 'Kein Anruf-Geheimnis in den Einstellungen hinterlegt.';
    if (phone.trim().isEmpty) return 'Keine Telefonnummer für Anrufe in den Einstellungen hinterlegt.';

    final googleSignIn = await _signInClient();
    await googleSignIn.signOut(); // force a fresh serverAuthCode
    final account = await googleSignIn.signIn();
    if (account == null) return 'Google-Anmeldung wurde abgebrochen.';
    final serverAuthCode = account.serverAuthCode;
    if (serverAuthCode == null) return 'Google hat keinen serverAuthCode geliefert.';

    final res = await http.post(
      Uri.parse(backendUrl.trim()).replace(path: '/calendar/connect'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'serverAuthCode': serverAuthCode, 'phone': phone.trim(), 'secret': secret.trim()}),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      return (body?['error'] as String?) ?? 'Verbindung fehlgeschlagen (Code ${res.statusCode}).';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemindersConnected, true);
    return null;
  }

  Future<bool> remindersConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRemindersConnected) ?? false;
  }

  Future<bool> disconnectReminders({required String backendUrl, required String secret}) async {
    if (backendUrl.trim().isEmpty || secret.trim().isEmpty) return false;
    final res = await http.post(
      Uri.parse(backendUrl.trim()).replace(path: '/calendar/disconnect'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'secret': secret.trim()}),
    );
    if (res.statusCode != 200) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemindersConnected, false);
    return true;
  }

  /// Lists events starting within [from]..[to] (both inclusive), soonest
  /// first.
  Future<List<CalendarEvent>> listEvents(DateTime from, DateTime to) async {
    final token = await _accessToken();
    if (token == null) return [];

    final uri = Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events', {
      'timeMin': from.toUtc().toIso8601String(),
      'timeMax': to.toUtc().toIso8601String(),
      'singleEvents': 'true',
      'orderBy': 'startTime',
    });
    final res = await http.get(uri, headers: {'authorization': 'Bearer $token'});
    if (res.statusCode != 200) return [];

    final items = (jsonDecode(res.body)['items'] as List?) ?? [];
    return items.map((raw) {
      final m = raw as Map<String, dynamic>;
      final start = m['start'] as Map<String, dynamic>? ?? {};
      final dateTime = start['dateTime'] as String?;
      final date = start['date'] as String?;
      return CalendarEvent(
        m['id'] as String? ?? '',
        m['summary'] as String? ?? 'Ohne Titel',
        DateTime.parse(dateTime ?? date ?? DateTime.now().toIso8601String()),
        allDay: dateTime == null,
      );
    }).toList();
  }

  /// Creates a new event and returns a human-readable confirmation, or an
  /// error message.
  Future<String> createEvent({required String title, required DateTime start, Duration duration = const Duration(hours: 1)}) async {
    final token = await _accessToken();
    if (token == null) return 'Google Kalender ist nicht verbunden. Bitte in den Einstellungen anmelden.';

    final res = await http.post(
      Uri.https('www.googleapis.com', '/calendar/v3/calendars/primary/events'),
      headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
      body: jsonEncode({
        'summary': title,
        'start': {'dateTime': start.toUtc().toIso8601String()},
        'end': {'dateTime': start.add(duration).toUtc().toIso8601String()},
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      return 'Termin konnte nicht angelegt werden (Code ${res.statusCode}).';
    }
    return 'Termin "$title" angelegt.';
  }
}
