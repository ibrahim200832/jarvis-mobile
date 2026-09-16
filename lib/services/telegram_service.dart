import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sends the user free Telegram messages through the Worker's bot — a
/// zero-cost alternative/addition to the Twilio phone calls, ported from the
/// original desktop tool's `notify.py`/`telegram_bot.py`. The Worker holds
/// the bot token as a secret; this service only ever handles the (not
/// secret) chat id, which it discovers automatically via [link] instead of
/// making the user look it up by hand.
class TelegramService {
  static const _keyChatId = 'telegram_chat_id';

  Future<String?> getChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyChatId);
  }

  Future<void> setChatId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChatId, value);
  }

  Future<bool> isConnected() async => (await getChatId())?.isNotEmpty ?? false;

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyChatId);
  }

  /// Finds the chat id of whoever most recently messaged the bot (the user
  /// must have sent it at least one message first) and saves it. Returns
  /// null on success, or a human-readable error.
  Future<String?> link({required String backendUrl, required String secret}) async {
    if (backendUrl.trim().isEmpty) return 'Telegram benötigt eine KI-Server-Adresse in den Einstellungen.';
    if (secret.trim().isEmpty) return 'Kein Anruf-Geheimnis in den Einstellungen hinterlegt.';

    final uri = Uri.parse(backendUrl.trim()).replace(path: '/telegram/link', queryParameters: {'secret': secret.trim()});
    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 200) {
      return (body?['error'] as String?) ?? 'Verbindung fehlgeschlagen (Code ${res.statusCode}).';
    }
    final chatId = body?['chat_id'] as String?;
    if (chatId == null) return 'Telegram hat keine Chat-ID geliefert.';
    await setChatId(chatId);
    return null;
  }

  /// Returns null on success, or a human-readable error.
  Future<String?> sendMessage({required String backendUrl, required String secret, required String message}) async {
    if (backendUrl.trim().isEmpty) return 'Telegram benötigt eine KI-Server-Adresse in den Einstellungen.';
    if (secret.trim().isEmpty) return 'Kein Anruf-Geheimnis in den Einstellungen hinterlegt.';
    final chatId = await getChatId();
    if (chatId == null || chatId.isEmpty) return 'Telegram ist nicht verbunden. Bitte in den Einstellungen verbinden.';

    final res = await http.post(
      Uri.parse(backendUrl.trim()).replace(path: '/telegram/notify'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'chat_id': chatId, 'message': message, 'secret': secret.trim()}),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      return (body?['error'] as String?) ?? 'Telegram-Nachricht fehlgeschlagen (Code ${res.statusCode}).';
    }
    return null;
  }
}
