import 'dart:convert';

import 'package:http/http.dart' as http;

/// Triggers a real outbound phone call to the user via the Worker's Twilio
/// integration (see worker/ai-proxy.js `/call`), instead of just opening the
/// dialer like [CallService] does. Used for "ruf mich an, wenn..." and for
/// the calendar reminder call flow. Requires TWILIO_* secrets on the Worker
/// and a matching Anruf-Geheimnis in Einstellungen — see README.
class PhoneCallService {
  /// Returns null on success, or a human-readable error message.
  Future<String?> callMe({
    required String backendUrl,
    required String secret,
    required String phone,
    required String message,
  }) async {
    if (backendUrl.trim().isEmpty) return 'Anrufe benötigen eine KI-Server-Adresse in den Einstellungen.';
    if (secret.trim().isEmpty) return 'Kein Anruf-Geheimnis in den Einstellungen hinterlegt.';
    if (phone.trim().isEmpty) return 'Keine Telefonnummer für Anrufe in den Einstellungen hinterlegt.';

    try {
      final res = await http.post(
        Uri.parse(backendUrl.trim()).replace(path: '/call'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'to': phone.trim(), 'message': message, 'secret': secret.trim()}),
      );
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>?;
        return (body?['error'] as String?) ?? 'Anruf fehlgeschlagen (Code ${res.statusCode}).';
      }
      return null;
    } catch (e) {
      return 'Anruf fehlgeschlagen: $e';
    }
  }
}
