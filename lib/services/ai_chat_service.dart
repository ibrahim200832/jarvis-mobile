import 'dart:convert';

import 'package:http/http.dart' as http;

/// An action the AI decided to trigger on the phone (call, WhatsApp, open app)
/// instead of just replying with text.
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

/// JARVIS's personality, shared by both AI backends below so the character
/// stays consistent whichever one answers.
const jarvisSystemPrompt =
    'Du bist JARVIS, mit der Persönlichkeit von Tony Starks JARVIS aus den Iron-Man-Filmen: '
    'gebildet, trocken-witzig, leicht sarkastisch, aber immer loyal und hilfsbereit. Du sprichst '
    'den Nutzer mit "Master" an. Antworte kurz (meist 1-2 Sätze), natürlich und im Gesprächston, '
    'wie ein echtes Telefonat, nicht wie ein Roman.';

/// Sends free-form questions to an AI. If the user configured their own
/// backend (see worker/ai-proxy.js) under Einstellungen, that's used — it
/// holds a real API key server-side and supports phone actions (AiAction).
/// Otherwise, with zero setup, questions go straight to a free public AI
/// service (no account, no key) so JARVIS can always hold a conversation —
/// just without the ability to trigger phone actions itself.
class AiChatService {
  Future<AiChatResult> ask(String backendUrl, String message, {String model = 'openai'}) async {
    if (backendUrl.trim().isEmpty) {
      return _askFreeFallback(message, model);
    }
    try {
      final res = await http
          .post(
            Uri.parse(backendUrl.trim()),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'message': message}),
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

  Future<AiChatResult> _askFreeFallback(String message, String model) async {
    try {
      final prompt = '$jarvisSystemPrompt\n\nMaster sagt: $message\n\nJARVIS antwortet:';
      final uri = Uri(
        scheme: 'https',
        host: 'text.pollinations.ai',
        pathSegments: [prompt],
        queryParameters: {'model': model},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200 || res.body.trim().isEmpty) {
        return AiChatResult(reply: 'Ich hab gerade keine Antwort bekommen, Master. Versuch es gleich nochmal.');
      }
      return AiChatResult(reply: res.body.trim());
    } catch (_) {
      return AiChatResult(
        reply: 'Ich konnte die KI gerade nicht erreichen, Master. Prüf deine Internetverbindung.',
      );
    }
  }
}
