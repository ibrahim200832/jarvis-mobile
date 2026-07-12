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

/// Sends free-form questions to a small backend (see worker/ai-proxy.js)
/// that holds the real AI API key server-side, so it never ships inside
/// the app itself. The backend may also return a phone action (see AiAction)
/// that the AI decided to trigger based on the conversation.
class AiChatService {
  Future<AiChatResult> ask(String backendUrl, String message) async {
    if (backendUrl.trim().isEmpty) {
      return AiChatResult(
        reply: 'Für freie Gespräche ist noch keine KI-Server-Adresse in den Einstellungen hinterlegt.',
      );
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
}
