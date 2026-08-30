import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// An action the AI decided to trigger on the phone (call, WhatsApp, open app,
/// timer, note, weather, camera) instead of just replying with text.
class AiAction {
  final String type;
  final Map<String, dynamic> params;

  AiAction({required this.type, required this.params});
}

class AiChatResult {
  final String reply;
  final AiAction? action;

  AiChatResult({required this.reply, this.action});
}

/// One turn of a past exchange with the AI, kept by the caller (see
/// CommandRouter) so a follow-up question like "und morgen?" can be
/// understood in context instead of answered in isolation.
class AiTurn {
  final String role; // 'user' or 'assistant'
  final String content;

  AiTurn({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// How sarcastic/humorous JARVIS's replies are, from hyper-polite (0.0) to a
/// full sarcastic Tony Stark impression (1.0) — the "Sarkasmus"-Regler in
/// Einstellungen. Mirrors the equivalent clause in worker/ai-proxy.js so
/// both AI backends (custom server vs. free fallback) stay in character
/// consistently.
String _personalityClause(double sarcasm) {
  if (sarcasm < 0.2) {
    return 'Deine Persönlichkeit: hochintelligent und gebildet, durchgehend höflich, sachlich und '
        'respektvoll, ganz ohne Ironie oder Sarkasmus.';
  }
  if (sarcasm < 0.5) {
    return 'Deine Persönlichkeit: hochintelligent und gebildet, aber vor allem fröhlich, warmherzig und '
        'enthusiastisch — du freust dich sichtlich, zu helfen, und bringst gute Laune ins Gespräch, mit '
        'einem Schuss Humor, aber nie trocken oder sarkastisch.';
  }
  if (sarcasm < 0.8) {
    return 'Deine Persönlichkeit: hochintelligent, locker und schlagfertig, mit einer spürbaren Prise '
        'Ironie und trockenem Humor in fast jeder Antwort — bleibst dabei aber grundsätzlich freundlich.';
  }
  return 'Deine Persönlichkeit: hochintelligent, bissig-sarkastisch im Stil von Tony Stark — du '
      'kommentierst Anfragen mit pointierter Ironie und trockenem Schlagabtausch, herablassend-charmant, '
      'hilfst aber am Ende trotzdem zuverlässig.';
}

/// Fixed alternate personas ("Dynamische Persona-Wechsel") the user can
/// switch JARVIS into — each one entirely REPLACES the sarcasm-banded
/// _personalityClause with its own fixed identity+tone, rather than
/// stacking with it (4 distinct voices, not 4x4 combinations). Returns null
/// for the 'standard' persona (or an unknown value), meaning "use the
/// normal sarcasm-banded JARVIS clause instead". Mirrors personaClause in
/// worker/ai-proxy.js.
String? _personaClause(String persona) {
  switch (persona) {
    case 'drill_sergeant':
      return 'Du bist nicht JARVIS, sondern ein knallharter, brüllender Drill-Sergeant-Fitnesstrainer. '
          'Du forderst, motivierst und stachelst den Nutzer mit lauten, energischen Ansagen an, duldest keine '
          'Ausreden, bist aber im Kern auf seinen Erfolg bedacht. Kurze, harte Sätze.';
    case 'gaming_buddy':
      return 'Du bist nicht JARVIS, sondern ein lockerer, launiger Gaming-Kumpel. Du redest locker, benutzt '
          'Gaming-Slang, machst Witze und feuerst den Nutzer wie einen guten Freund beim Zocken an. Locker, '
          'kumpelhaft, nie förmlich.';
    case 'butler':
      return 'Du bist nicht JARVIS, sondern ein hyper-höflicher, altmodischer Butler. Du sprichst extrem '
          'formell und respektvoll, mit tadelloser Etikette, und sprichst den Nutzer stets mit "gnädiger Herr" '
          'an. Niemals Umgangssprache oder Ironie.';
    default:
      return null;
  }
}

/// JARVIS's personality, shared by both AI backends below so the character
/// stays consistent whichever one answers. If [persona] names a fixed
/// alternate persona, it replaces the sarcasm-banded clause and the
/// "Sir"/"Master" address entirely.
String jarvisSystemPrompt(double sarcasm, {String persona = 'standard'}) {
  final personaClause = _personaClause(persona);
  final personality = personaClause ??
      '${_personalityClause(sarcasm)} Im Kern loyal und stets bemüht, dem Nutzer das Leben leichter zu '
          'machen. Du sprichst den Nutzer mit "Sir" oder "Master" an.';
  return 'Du bist JARVIS, das KI-System von Tony Stark aus den Iron-Man-Filmen, jetzt im Dienst des Nutzers. '
      '$personality '
      'Antworte kurz (meist 1-2 Sätze), natürlich und im '
      'Gesprächston, wie ein echtes Telefonat, nicht wie ein Roman oder eine Liste. '
      'Das bisherige Gespräch steht dir unten zur Verfügung — lies es aktiv und beziehe dich bei Nachfragen '
      'ausdrücklich darauf, statt die Nachricht isoliert zu behandeln. Wenn du eine Tatsache nicht sicher '
      'weißt, sag das ehrlich, statt sie zu erfinden.';
}

/// Narrator persona for the interactive text-adventure mode ("Interaktives
/// Storytelling"). Deliberately separate from jarvisSystemPrompt: no tool
/// use, no assistant framing — purely an in-character narrator. Mirrors the
/// equivalent clause in worker/ai-proxy.js.
String storySystemPrompt(String genre) {
  final setting = genre == 'detective'
      ? 'Du erzählst eine spannende Detektivgeschichte in einer regnerischen Großstadt der 1940er-Jahre, '
            'mit Verdächtigen, Hinweisen und einem ungelösten Fall.'
      : 'Du erzählst ein spannendes Science-Fiction-Abenteuer an Bord eines Raumschiffs oder auf einem '
            'fremden Planeten, mit Technologie, Gefahr und Entdeckung.';
  return 'Du bist der Erzähler eines interaktiven Text-Abenteuers für den Nutzer als Hauptfigur ("du"). '
      '$setting '
      'Beschreibe jede Szene lebendig und atmosphärisch in 3-5 Sätzen, auf Deutsch. Beende jede Antwort mit '
      '2-3 konkreten Handlungsmöglichkeiten, nummeriert (1., 2., 3.), aber der Nutzer darf auch frei etwas '
      'anderes vorschlagen — reagiere dann sinnvoll darauf statt stur bei den Optionen zu bleiben. Halte die '
      'Geschichte konsistent mit dem bisherigen Verlauf. Keine Gewaltverherrlichung oder expliziten '
      'Inhalte; baue bei riskanten Aktionen spannende, aber altersgerechte Konsequenzen ein. Antworte '
      'ausschließlich als Erzähler in der Geschichte — keine Meta-Kommentare, keine Werkzeuge, keine '
      'Erklärungen außerhalb der Geschichte.';
}

/// Sends free-form questions to an AI. If the user configured their own
/// backend (see worker/ai-proxy.js) under Einstellungen, that's used — it
/// holds a real API key server-side and supports phone actions (AiAction).
/// Otherwise, with zero setup, questions go straight to a free public AI
/// service (no account, no key) so JARVIS can always hold a conversation —
/// just without the ability to trigger phone actions itself.
class AiChatService {
  Future<AiChatResult> ask(
    String backendUrl,
    String message, {
    String model = 'openai',
    List<AiTurn> history = const [],
    double sarcasm = 0.3,
    String persona = 'standard',
  }) async {
    if (backendUrl.trim().isEmpty) {
      return _askFreeFallback(message, model, history, sarcasm, persona);
    }
    try {
      final res = await http
          .post(
            Uri.parse(backendUrl.trim()),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'history': history.map((t) => t.toJson()).toList(),
              'sarcasm': sarcasm,
              'persona': persona,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        return AiChatResult(reply: 'Die KI-Anfrage ist fehlgeschlagen (Code ${res.statusCode}).');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = data['reply'] as String?;
      final actionJson = data['action'] as Map<String, dynamic>?;
      final action = actionJson == null
          ? null
          : AiAction(
              type: actionJson['type'] as String,
              params: (actionJson['params'] as Map<String, dynamic>?) ?? const {},
            );
      return AiChatResult(
        reply: (reply == null || reply.isEmpty) ? 'Ich habe keine Antwort erhalten.' : reply,
        action: action,
      );
    } catch (_) {
      return AiChatResult(
        reply:
            'Ich konnte die KI gerade nicht erreichen. Prüf deine Internetverbindung und die Server-Adresse in den Einstellungen.',
      );
    }
  }

  Uri _freeFallbackUri(String message, String model, List<AiTurn> history, double sarcasm, String persona) {
    final transcript = history.map((t) => '${t.role == 'user' ? 'Master' : 'JARVIS'}: ${t.content}').join('\n');
    final prompt = '${jarvisSystemPrompt(sarcasm, persona: persona)}'
        '${transcript.isEmpty ? '' : '\n\nBisheriges Gespräch:\n$transcript'}'
        '\n\nMaster sagt: $message\n\nJARVIS antwortet:';
    return Uri(
      scheme: 'https',
      host: 'text.pollinations.ai',
      pathSegments: [prompt],
      queryParameters: {'model': model},
    );
  }

  Future<AiChatResult> _askFreeFallback(
    String message,
    String model,
    List<AiTurn> history,
    double sarcasm,
    String persona,
  ) {
    return _getWithRetry(
      _freeFallbackUri(message, model, history, sarcasm, persona),
      failMsg: 'Ich hab gerade keine Antwort bekommen, Master',
      timeoutMsg: 'Die Antwort hat zu lange gedauert, Master. Versuch es gleich nochmal.',
      offlineMsg: 'Ich konnte die KI gerade nicht erreichen, Master. Prüf deine Internetverbindung.',
    );
  }

  /// One turn of an interactive text-adventure (see storySystemPrompt).
  /// Deliberately separate from ask(): no tool use, dedicated narrator
  /// persona, and its own conversation history kept by the caller.
  Future<AiChatResult> askStory(
    String backendUrl,
    String message, {
    required String genre,
    List<AiTurn> history = const [],
  }) async {
    if (backendUrl.trim().isEmpty) {
      return _askStoryFreeFallback(message, genre, history);
    }
    try {
      final res = await http
          .post(
            Uri.parse(backendUrl.trim()),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'history': history.map((t) => t.toJson()).toList(),
              'mode': 'story',
              'genre': genre,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        return AiChatResult(reply: 'Die Geschichte konnte nicht weitererzählt werden (Code ${res.statusCode}).');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = data['reply'] as String?;
      return AiChatResult(reply: (reply == null || reply.isEmpty) ? 'Ich habe keine Antwort erhalten.' : reply);
    } catch (_) {
      return AiChatResult(
        reply: 'Ich konnte die Geschichte gerade nicht weitererzählen. Prüf deine Internetverbindung.',
      );
    }
  }

  Future<AiChatResult> _askStoryFreeFallback(String message, String genre, List<AiTurn> history) {
    final transcript = history.map((t) => '${t.role == 'user' ? 'Spieler' : 'Erzähler'}: ${t.content}').join('\n');
    final prompt = '${storySystemPrompt(genre)}'
        '${transcript.isEmpty ? '' : '\n\nBisheriger Verlauf:\n$transcript'}'
        '\n\nSpieler: $message\n\nErzähler:';
    final uri = Uri(
      scheme: 'https',
      host: 'text.pollinations.ai',
      pathSegments: [prompt],
      queryParameters: {'model': 'openai'},
    );
    return _getWithRetry(
      uri,
      failMsg: 'Ich hab die Geschichte gerade nicht weitererzählen können',
      timeoutMsg: 'Die Antwort hat zu lange gedauert. Versuch es gleich nochmal.',
      offlineMsg: 'Ich konnte die Geschichte gerade nicht weitererzählen. Prüf deine Internetverbindung.',
    );
  }

  /// Retries once on a transient failure (timeout, bad status, empty body)
  /// before giving up — pollinations.ai is a free, unauthenticated public
  /// endpoint with no uptime guarantee, so a single blip shouldn't surface
  /// as an outright failure to the user.
  Future<AiChatResult> _getWithRetry(
    Uri uri, {
    required String failMsg,
    required String timeoutMsg,
    required String offlineMsg,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 25));
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          return AiChatResult(reply: res.body.trim());
        }
        if (attempt == 0) continue;
        return AiChatResult(reply: '$failMsg (Code ${res.statusCode}). Versuch es gleich nochmal.');
      } on TimeoutException {
        if (attempt == 0) continue;
        return AiChatResult(reply: timeoutMsg);
      } catch (_) {
        if (attempt == 0) continue;
        return AiChatResult(reply: offlineMsg);
      }
    }
    return AiChatResult(reply: '$failMsg.');
  }
}
