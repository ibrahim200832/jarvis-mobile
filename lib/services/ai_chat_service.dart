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

/// JARVIS's personality, shared by both AI backends below so the character
/// stays consistent whichever one answers.
String jarvisSystemPrompt(double sarcasm) =>
    'Du bist JARVIS, das KI-System von Tony Stark aus den Iron-Man-Filmen, jetzt im Dienst des Nutzers. '
    '${_personalityClause(sarcasm)} Im Kern loyal und stets bemüht, dem Nutzer das Leben '
    'leichter zu machen. Du sprichst den Nutzer mit "Sir" oder "Master" an. Antworte kurz (meist 1-2 Sätze), natürlich und im '
    'Gesprächston, wie ein echtes Telefonat, nicht wie ein Roman oder eine Liste. '
    'Das bisherige Gespräch steht dir unten zur Verfügung — lies es aktiv und beziehe dich bei Nachfragen '
    'ausdrücklich darauf, statt die Nachricht isoliert zu behandeln. Wenn du eine Tatsache nicht sicher '
    'weißt, sag das ehrlich, statt sie zu erfinden.';

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
  }) async {
    if (backendUrl.trim().isEmpty) {
      return _askFreeFallback(message, model, history, sarcasm);
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

  Uri _freeFallbackUri(String message, String model, List<AiTurn> history, double sarcasm) {
    final transcript = history.map((t) => '${t.role == 'user' ? 'Master' : 'JARVIS'}: ${t.content}').join('\n');
    final prompt = '${jarvisSystemPrompt(sarcasm)}'
        '${transcript.isEmpty ? '' : '\n\nBisheriges Gespräch:\n$transcript'}'
        '\n\nMaster sagt: $message\n\nJARVIS antwortet:';
    return Uri(
      scheme: 'https',
      host: 'text.pollinations.ai',
      pathSegments: [prompt],
      queryParameters: {'model': model},
    );
  }

  /// Retries once on a transient failure (timeout, bad status, empty body)
  /// before giving up — pollinations.ai is a free, unauthenticated public
  /// endpoint with no uptime guarantee, so a single blip shouldn't surface
  /// as an outright failure to the user.
  Future<AiChatResult> _askFreeFallback(String message, String model, List<AiTurn> history, double sarcasm) async {
    final uri = _freeFallbackUri(message, model, history, sarcasm);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 25));
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          return AiChatResult(reply: res.body.trim());
        }
        if (attempt == 0) continue;
        return AiChatResult(
          reply: 'Ich hab gerade keine Antwort bekommen, Master (Code ${res.statusCode}). Versuch es gleich nochmal.',
        );
      } on TimeoutException {
        if (attempt == 0) continue;
        return AiChatResult(reply: 'Die Antwort hat zu lange gedauert, Master. Versuch es gleich nochmal.');
      } catch (_) {
        if (attempt == 0) continue;
        return AiChatResult(
          reply: 'Ich konnte die KI gerade nicht erreichen, Master. Prüf deine Internetverbindung.',
        );
      }
    }
    return AiChatResult(reply: 'Ich hab gerade keine Antwort bekommen, Master.');
  }
}
