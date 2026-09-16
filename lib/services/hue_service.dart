import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'hue_http_client.dart';

/// One Philips Hue light, enough to find one by name and report its state.
class HueLight {
  HueLight(this.id, this.name, this.on, this.brightness);

  final String id;
  final String name;
  final bool on;
  final double? brightness;
}

/// Controls Philips Hue lights over the local network via the Hue Bridge's
/// CLIP v2 API — same approach as the original desktop tool's `hue.py`, port
/// to Dart. No cloud, no Philips account: the phone just needs to be on the
/// same WiFi as the bridge. Ported behavior:
///   1. Save the bridge's local IP (from the Hue app, or discovery.meethue.com).
///   2. Press the bridge's round link button, then pair within ~30 seconds
///      — that's how the bridge proves a human authorized this app.
class HueService {
  static const _keyBridgeIp = 'hue_bridge_ip';
  static const _keyAppKey = 'hue_app_key';

  final http.Client _client = createHueClient();

  Future<String?> getBridgeIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBridgeIp);
  }

  Future<void> setBridgeIp(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBridgeIp, value);
  }

  Future<bool> isPaired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAppKey) != null;
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAppKey);
  }

  /// Presses-the-button pairing handshake. Returns null on success (app key
  /// saved), or a human-readable error — most commonly "press the bridge's
  /// button first" if it's called without that.
  Future<String?> pair(String bridgeIp) async {
    final ip = bridgeIp.trim();
    if (ip.isEmpty) return 'Keine Hue-Bridge-IP eingetragen.';
    await setBridgeIp(ip);

    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('https://$ip/api'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'devicetype': 'jarvis_mobile#phone', 'generateclientkey': true}),
      );
    } catch (e) {
      return 'Bridge nicht erreichbar: $e';
    }
    final data = jsonDecode(res.body) as List;
    final first = data.isNotEmpty ? data.first as Map<String, dynamic> : <String, dynamic>{};
    final error = first['error'] as Map<String, dynamic>?;
    if (error != null) {
      return '${error['description']} (Link-Knopf auf der Bridge drücken, dann innerhalb von 30 Sekunden erneut versuchen).';
    }
    final key = (first['success'] as Map<String, dynamic>?)?['username'] as String?;
    if (key == null) return 'Unerwartete Antwort der Bridge.';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppKey, key);
    return null;
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyAppKey);
    if (key == null) throw Exception('Hue Bridge ist nicht gekoppelt.');
    return {'hue-application-key': key};
  }

  Future<List<HueLight>> listLights() async {
    final ip = await getBridgeIp();
    if (ip == null || ip.isEmpty) return [];
    final headers = await _authHeaders();

    final res = await _client.get(Uri.parse('https://$ip/clip/v2/resource/light'), headers: headers);
    if (res.statusCode != 200) return [];
    final items = (jsonDecode(res.body)['data'] as List?) ?? [];
    return items.map((raw) {
      final m = raw as Map<String, dynamic>;
      final dimming = m['dimming'] as Map<String, dynamic>?;
      return HueLight(
        m['id'] as String,
        (m['metadata'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        (m['on'] as Map<String, dynamic>?)?['on'] as bool? ?? false,
        (dimming?['brightness'] as num?)?.toDouble(),
      );
    }).toList();
  }

  Future<HueLight?> _find(String name) async {
    final lights = await listLights();
    final needle = name.toLowerCase();
    final exact = lights.where((l) => l.name.toLowerCase() == needle);
    if (exact.isNotEmpty) return exact.first;
    final partial = lights.where((l) => l.name.toLowerCase().contains(needle));
    return partial.isNotEmpty ? partial.first : null;
  }

  /// Turns a light on/off, or (with [brightness], 0-100) sets its dimming
  /// level and implicitly turns it on if brightness > 0. Returns a
  /// human-readable result message.
  Future<String> setLight(String name, {bool? on, double? brightness}) async {
    final ip = await getBridgeIp();
    if (ip == null || ip.isEmpty || !await isPaired()) {
      return 'Hue Bridge ist nicht eingerichtet. Bitte in den Einstellungen koppeln.';
    }
    final light = await _find(name);
    if (light == null) return 'Ich habe keine Hue-Lampe namens "$name" gefunden.';

    final body = <String, dynamic>{};
    if (brightness != null) {
      final level = brightness.clamp(0, 100);
      body['on'] = {'on': level > 0};
      body['dimming'] = {'brightness': level};
    } else if (on != null) {
      body['on'] = {'on': on};
    }

    final headers = await _authHeaders();
    headers['content-type'] = 'application/json';
    final res = await _client.put(
      Uri.parse('https://$ip/clip/v2/resource/light/${light.id}'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) return 'Hue-Befehl fehlgeschlagen (Code ${res.statusCode}).';

    if (brightness != null) return '${light.name} auf ${brightness.round()}% gestellt.';
    return '${light.name} ${on == true ? 'eingeschaltet' : 'ausgeschaltet'}.';
  }
}
