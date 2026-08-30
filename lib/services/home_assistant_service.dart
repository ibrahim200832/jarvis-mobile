import 'dart:convert';

import 'package:http/http.dart' as http;

/// One Home Assistant entity's current state, enough to find a device by
/// its friendly name and report/change what it's doing.
class HaEntity {
  final String entityId;
  final String friendlyName;
  final String state;

  HaEntity({required this.entityId, required this.friendlyName, required this.state});
}

/// Controls and queries a local Home Assistant instance via its REST API.
/// Requires the user's own Home Assistant base URL (e.g.
/// http://192.168.1.50:8123) and a Long-Lived Access Token, entered in
/// Einstellungen — see
/// https://www.home-assistant.io/docs/authentication/#your-account-profile.
/// Never bundled/shared: this app only talks to whatever instance the user
/// configures on their own device.
class HomeAssistantService {
  String _normalize(String baseUrl) => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  Map<String, String> _headers(String token) => {
    'authorization': 'Bearer $token',
    'content-type': 'application/json',
  };

  Future<List<HaEntity>> _states(String baseUrl, String token) async {
    final uri = Uri.parse('${_normalize(baseUrl)}/api/states');
    final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Home Assistant antwortete mit Code ${res.statusCode}.');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final attrs = (m['attributes'] as Map<String, dynamic>?) ?? {};
      final entityId = m['entity_id'] as String;
      return HaEntity(
        entityId: entityId,
        friendlyName: (attrs['friendly_name'] as String?) ?? entityId,
        state: (m['state'] as String?) ?? 'unknown',
      );
    }).toList();
  }

  /// Matches free-text [name] against entity friendly names (exact first,
  /// then loose substring in either direction), optionally restricted to
  /// one domain (e.g. "light").
  HaEntity? _findByName(List<HaEntity> entities, String name, {String? domain}) {
    final needle = name.toLowerCase().trim();
    final candidates = domain == null ? entities : entities.where((e) => e.entityId.startsWith('$domain.'));
    for (final e in candidates) {
      if (e.friendlyName.toLowerCase() == needle) return e;
    }
    for (final e in candidates) {
      if (e.friendlyName.toLowerCase().contains(needle) || needle.contains(e.friendlyName.toLowerCase())) return e;
    }
    return null;
  }

  /// Turns a light (or, failing that, a switch) matching [name] on/off.
  Future<String> setLight(String baseUrl, String token, String name, {required bool turnOn}) async {
    List<HaEntity> entities;
    try {
      entities = await _states(baseUrl, token);
    } catch (e) {
      return 'Home Assistant war nicht erreichbar: ${e.toString().replaceFirst('Exception: ', '')}';
    }
    final entity = _findByName(entities, name, domain: 'light') ?? _findByName(entities, name, domain: 'switch');
    if (entity == null) {
      return 'Ich konnte kein Licht/Gerät namens "$name" in Home Assistant finden.';
    }
    final domain = entity.entityId.split('.').first;
    final service = turnOn ? 'turn_on' : 'turn_off';
    final uri = Uri.parse('${_normalize(baseUrl)}/api/services/$domain/$service');
    final res = await http
        .post(uri, headers: _headers(token), body: jsonEncode({'entity_id': entity.entityId}))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      return 'Home Assistant konnte "${entity.friendlyName}" nicht schalten (Code ${res.statusCode}).';
    }
    return '${entity.friendlyName} ist jetzt ${turnOn ? "an" : "aus"}.';
  }

  /// Reports the current state of any entity matching [name].
  Future<String> status(String baseUrl, String token, String name) async {
    List<HaEntity> entities;
    try {
      entities = await _states(baseUrl, token);
    } catch (e) {
      return 'Home Assistant war nicht erreichbar: ${e.toString().replaceFirst('Exception: ', '')}';
    }
    final entity = _findByName(entities, name);
    if (entity == null) {
      return 'Ich konnte kein Gerät namens "$name" in Home Assistant finden.';
    }
    return '${entity.friendlyName}: ${entity.state}.';
  }

  /// A lightweight reachability check, used by the "Verbindung testen"
  /// button in Einstellungen.
  Future<bool> testConnection(String baseUrl, String token) async {
    try {
      final uri = Uri.parse('${_normalize(baseUrl)}/api/');
      final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
