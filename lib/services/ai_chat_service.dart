import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sends free-form questions to a small backend (see worker/ai-proxy.js)
/// that holds the real AI API key server-side, so it never ships inside
/// the app itself.
class AiChatService {
  Future<String> ask(String backendUrl, String message) async {
    if (backendUrl.trim().isEmpty) {
      return 'Für freie Gespräche ist noch keine KI-Server-Adresse in den Einstellungen hinterlegt.';
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
        return 'Die KI-Anfrage ist fehlgeschlagen (Code ${res.statusCode}).';
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = data['reply'] as String?;
      return (reply == null || reply.isEmpty) ? 'Ich habe keine Antwort erhalten.' : reply;
    } catch (_) {
      return 'Ich konnte die KI gerade nicht erreichen. Prüf deine Internetverbindung und die Server-Adresse in den Einstellungen.';
    }
  }
}
