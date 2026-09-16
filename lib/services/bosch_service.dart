import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// One Bosch/Siemens Home Connect appliance (washer, dryer, dishwasher, ...).
class BoschAppliance {
  BoschAppliance(this.haId, this.name, this.type, this.connected);

  final String haId;
  final String name;
  final String type;
  final bool connected;
}

/// Talks to Bosch/Siemens appliances (washer, dryer, dishwasher) via the
/// Home Connect cloud API, authenticated through OAuth2 **Device Flow** —
/// ported from the original desktop tool's `bosch.py`. Device Flow needs no
/// redirect URI and no client secret (unlike the app's other OAuth
/// integrations), so unlike Spotify/TikTok this runs entirely on-device: the
/// user visits a short URL on any device and enters a code, while the app
/// polls in the background until Bosch confirms it.
///
/// Requires the user's own (free) Home Connect Developer application,
/// registered with Authorization Flow "Device Flow" — see README.
class BoschService {
  static const _api = 'https://api.home-connect.com';
  static const _keyClientId = 'bosch_client_id';
  static const _keyAccessToken = 'bosch_access_token';
  static const _keyRefreshToken = 'bosch_refresh_token';
  static const _keyExpiresAt = 'bosch_expires_at';

  Future<String?> getClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyClientId);
  }

  Future<void> setClientId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClientId, value);
  }

  Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken) != null;
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyExpiresAt);
  }

  /// Starts the device-flow handshake: opens the verification page in the
  /// browser and polls until the user approves it there (or it times out).
  /// Returns null on success, or a human-readable error.
  Future<String?> connect(String clientId) async {
    if (clientId.trim().isEmpty) return 'Keine Home-Connect-Client-ID eingetragen.';

    final startRes = await http.post(
      Uri.parse('$_api/security/oauth/device_authorization'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: {'client_id': clientId.trim()},
    );
    if (startRes.statusCode != 200) {
      return 'Home-Connect-Anfrage fehlgeschlagen (Code ${startRes.statusCode}).';
    }
    final start = jsonDecode(startRes.body) as Map<String, dynamic>;
    final deviceCode = start['device_code'] as String?;
    final verificationUri = start['verification_uri_complete'] as String? ?? start['verification_uri'] as String?;
    final interval = (start['interval'] as num?)?.toInt() ?? 5;
    final expiresIn = (start['expires_in'] as num?)?.toInt() ?? 300;
    if (deviceCode == null || verificationUri == null) return 'Unerwartete Antwort von Home Connect.';

    await launchUrl(Uri.parse(verificationUri), mode: LaunchMode.externalApplication);

    final deadline = DateTime.now().add(Duration(seconds: expiresIn));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));
      final tokenRes = await http.post(
        Uri.parse('$_api/security/oauth/token'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': deviceCode,
          'client_id': clientId.trim(),
        },
      );
      if (tokenRes.statusCode == 200) {
        await setClientId(clientId.trim());
        await _storeTokens(jsonDecode(tokenRes.body) as Map<String, dynamic>);
        return null;
      }
      final error = (jsonDecode(tokenRes.body) as Map<String, dynamic>?)?['error'] as String?;
      if (error != 'authorization_pending') {
        return 'Home-Connect-Anmeldung fehlgeschlagen: ${error ?? tokenRes.statusCode}';
      }
    }
    return 'Zeit abgelaufen, bevor die Anmeldung bestätigt wurde. Bitte erneut versuchen.';
  }

  Future<void> _storeTokens(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, json['access_token'] as String);
    final refreshToken = json['refresh_token'] as String?;
    if (refreshToken != null) await prefs.setString(_keyRefreshToken, refreshToken);
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 86400;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));
    await prefs.setInt(_keyExpiresAt, expiresAt.millisecondsSinceEpoch);
  }

  Future<String?> _validAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt(_keyExpiresAt);
    final accessToken = prefs.getString(_keyAccessToken);
    if (accessToken != null && expiresAt != null && DateTime.now().millisecondsSinceEpoch < expiresAt) {
      return accessToken;
    }

    final refreshToken = prefs.getString(_keyRefreshToken);
    final clientId = prefs.getString(_keyClientId);
    if (refreshToken == null || clientId == null) return null;
    final res = await http.post(
      Uri.parse('$_api/security/oauth/token'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken, 'client_id': clientId},
    );
    if (res.statusCode != 200) return null;
    await _storeTokens(jsonDecode(res.body) as Map<String, dynamic>);
    return prefs.getString(_keyAccessToken);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _validAccessToken();
    if (token == null) throw Exception('Home Connect ist nicht verbunden.');
    return {'Authorization': 'Bearer $token', 'Accept': 'application/vnd.bsh.sdk.v1+json'};
  }

  Future<List<BoschAppliance>> listAppliances() async {
    if (!await isConnected()) return [];
    final res = await http.get(Uri.parse('$_api/api/homeappliances'), headers: await _headers());
    if (res.statusCode != 200) return [];
    final items = (jsonDecode(res.body)['data']?['homeappliances'] as List?) ?? [];
    return items.map((raw) {
      final m = raw as Map<String, dynamic>;
      return BoschAppliance(
        m['haId'] as String,
        m['name'] as String? ?? '',
        m['type'] as String? ?? '',
        m['connected'] as bool? ?? false,
      );
    }).toList();
  }

  static const _typeAliases = {
    'waschmaschine': 'Washer',
    'wäsche': 'Washer',
    'trockner': 'Dryer',
    'geschirrspüler': 'Dishwasher',
    'spülmaschine': 'Dishwasher',
    'backofen': 'Oven',
  };

  Future<BoschAppliance?> _find(String query) async {
    final appliances = await listAppliances();
    if (appliances.isEmpty) return null;
    final needle = query.toLowerCase().trim();
    final wantedType = _typeAliases[needle];
    if (wantedType != null) {
      final byType = appliances.where((a) => a.type == wantedType);
      if (byType.isNotEmpty) return byType.first;
    }
    final byName = appliances.where((a) => a.name.toLowerCase().contains(needle));
    return byName.isNotEmpty ? byName.first : null;
  }

  /// Reports whether [applianceQuery] (a type like "waschmaschine" or a
  /// device name) currently has an active program running, and how long is
  /// left, or that it isn't connected/found.
  Future<String> describeStatus(String applianceQuery) async {
    if (!await isConnected()) return 'Home Connect ist nicht verbunden. Bitte in den Einstellungen anmelden.';
    final appliance = await _find(applianceQuery);
    if (appliance == null) return 'Ich habe kein Gerät gefunden, das zu "$applianceQuery" passt.';
    if (!appliance.connected) return '${appliance.name} ist gerade offline.';

    final res = await http.get(
      Uri.parse('$_api/api/homeappliances/${appliance.haId}/programs/active'),
      headers: await _headers(),
    );
    if (res.statusCode == 404) return '${appliance.name} läuft gerade nicht (kein aktives Programm).';
    if (res.statusCode != 200) return 'Status von ${appliance.name} konnte nicht abgerufen werden.';

    final options = (jsonDecode(res.body)['data']?['options'] as List?) ?? [];
    num? remainingSeconds;
    for (final raw in options) {
      final option = raw as Map<String, dynamic>;
      if ((option['key'] as String? ?? '').endsWith('RemainingProgramTime')) {
        remainingSeconds = option['value'] as num?;
        break;
      }
    }
    if (remainingSeconds == null) return '${appliance.name} läuft gerade.';
    final minutes = (remainingSeconds / 60).round();
    return '${appliance.name} läuft noch, noch etwa $minutes Minuten.';
  }
}
