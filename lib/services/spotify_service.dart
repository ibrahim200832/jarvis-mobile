import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The custom URL scheme Spotify redirects back into the app with after
/// login on mobile/desktop — must exactly match a Redirect URI configured in
/// the user's own Spotify Developer Dashboard app, and the <activity>
/// registered for it in AndroidManifest.xml (see flutter_web_auth_2's setup).
const spotifyRedirectScheme = 'jarvismobile';
const spotifyRedirectUri = '$spotifyRedirectScheme://spotify-callback';

/// On the web build, custom URL schemes don't work — instead the redirect
/// must land back on an https:// page served by the app itself
/// (`web/spotify-callback.html`), which must *also* be registered as a
/// Redirect URI in the Spotify Developer Dashboard alongside the mobile one.
/// Resolved relative to the page's own base href so it works unchanged
/// whether the app is served from GitHub Pages, a custom domain, etc.
String _webRedirectUri() => Uri.base.resolve('spotify-callback.html').toString();

/// Scopes requested at login: playback state/control plus read access to the
/// user's playlists (own + collaborative), so JARVIS can play a specific
/// song or a whole playlist by name.
const _spotifyScopes =
    'user-read-playback-state user-modify-playback-state playlist-read-private playlist-read-collaborative';

/// A minimal view of a Spotify playlist, enough to find one by name and
/// start playing it.
class SpotifyPlaylist {
  SpotifyPlaylist(this.id, this.name, this.uri);

  final String id;
  final String name;
  final String uri;
}

/// Controls Spotify playback via the Web API, authenticated with the user's
/// own Spotify account through OAuth Authorization Code + PKCE (no client
/// secret needed on-device — safe for a public/mobile app, same reasoning as
/// the existing YouTube login via google_sign_in). Works on both mobile and
/// web/PC: the user just logs in with their normal Spotify account on
/// Spotify's own page — this app never sees their password. Requires the
/// user to create their own free Spotify Developer app and paste its Client
/// ID into Einstellungen, exactly like the YouTube Client ID setup (see
/// README).
///
/// Note: actually starting playback via the Web API requires a Spotify
/// Premium account and an already-open Spotify app on some device — a
/// Spotify platform limitation, not something this app can work around.
class SpotifyService {
  static const _keyAccessToken = 'spotify_access_token';
  static const _keyRefreshToken = 'spotify_refresh_token';
  static const _keyExpiresAt = 'spotify_expires_at';

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

  /// Runs the login flow (opens Spotify's consent page, captures the
  /// redirect, exchanges the code for tokens). Returns true on success.
  Future<bool> connect(String clientId) async {
    if (clientId.trim().isEmpty) return false;
    try {
      final redirectUri = kIsWeb ? _webRedirectUri() : spotifyRedirectUri;
      final verifier = _randomVerifier();
      final challenge = base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');

      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': clientId.trim(),
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'scope': _spotifyScopes,
      });

      // callbackUrlScheme is only used on mobile/desktop to recognise the
      // custom-scheme redirect; on web the actual capture happens via
      // spotify-callback.html's postMessage, so it's ignored there but still
      // needs a syntactically valid value.
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: spotifyRedirectScheme,
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) return false;

      return await _exchangeCode(clientId.trim(), code, verifier, redirectUri);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _exchangeCode(String clientId, String code, String verifier, String redirectUri) async {
    final res = await http.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'code_verifier': verifier,
      },
    );
    if (res.statusCode != 200) return false;
    return _storeTokens(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<bool> _storeTokens(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, json['access_token'] as String);
    final refreshToken = json['refresh_token'] as String?;
    if (refreshToken != null) await prefs.setString(_keyRefreshToken, refreshToken);
    final expiresIn = json['expires_in'] as int? ?? 3600;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));
    await prefs.setInt(_keyExpiresAt, expiresAt.millisecondsSinceEpoch);
    return true;
  }

  /// Returns a valid access token, refreshing it first if it's expired.
  /// Requires the Spotify Client ID (needed again for the refresh request).
  Future<String?> _validAccessToken(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt(_keyExpiresAt);
    final accessToken = prefs.getString(_keyAccessToken);
    if (accessToken != null && expiresAt != null && DateTime.now().millisecondsSinceEpoch < expiresAt) {
      return accessToken;
    }

    final refreshToken = prefs.getString(_keyRefreshToken);
    if (refreshToken == null) return null;
    final res = await http.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken, 'client_id': clientId},
    );
    if (res.statusCode != 200) return null;
    final ok = await _storeTokens(jsonDecode(res.body) as Map<String, dynamic>);
    return ok ? prefs.getString(_keyAccessToken) : null;
  }

  /// Searches for [query] and starts playing it on the user's currently
  /// active Spotify device. Returns a human-readable result message.
  Future<String> play(String clientId, String query) async {
    final token = await _validAccessToken(clientId);
    if (token == null) return 'Spotify ist nicht verbunden. Bitte in den Einstellungen anmelden.';

    final searchRes = await http.get(
      Uri.https('api.spotify.com', '/v1/search', {'q': query, 'type': 'track', 'limit': '1'}),
      headers: {'authorization': 'Bearer $token'},
    );
    if (searchRes.statusCode != 200) return 'Spotify-Suche fehlgeschlagen.';
    final items = (jsonDecode(searchRes.body)['tracks']?['items'] as List?) ?? [];
    if (items.isEmpty) return 'Ich habe "$query" nicht auf Spotify gefunden.';
    final track = items.first as Map<String, dynamic>;
    final uri = track['uri'] as String;
    final trackName = track['name'] as String? ?? query;
    final artist = ((track['artists'] as List?)?.firstOrNull as Map<String, dynamic>?)?['name'] as String?;

    final playRes = await http.put(
      Uri.https('api.spotify.com', '/v1/me/player/play'),
      headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
      body: jsonEncode({
        'uris': [uri],
      }),
    );
    if (playRes.statusCode == 404) {
      return 'Öffne zuerst Spotify auf einem Gerät, dann kann ich "$trackName" abspielen.';
    }
    if (playRes.statusCode != 204 && playRes.statusCode != 200) {
      return 'Spotify-Wiedergabe fehlgeschlagen (Code ${playRes.statusCode}). Braucht ein Premium-Konto.';
    }
    return artist == null ? 'Spiele "$trackName" auf Spotify.' : 'Spiele "$trackName" von $artist auf Spotify.';
  }

  /// Fetches the user's own and followed/collaborative playlists.
  Future<List<SpotifyPlaylist>> getPlaylists(String clientId) async {
    final token = await _validAccessToken(clientId);
    if (token == null) return [];

    final res = await http.get(
      Uri.https('api.spotify.com', '/v1/me/playlists', {'limit': '50'}),
      headers: {'authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return [];
    final items = (jsonDecode(res.body)['items'] as List?) ?? [];
    return items.map((item) {
      final m = item as Map<String, dynamic>;
      return SpotifyPlaylist(m['id'] as String, m['name'] as String? ?? '', m['uri'] as String);
    }).toList();
  }

  /// Finds a playlist by (partial, case-insensitive) name and starts playing
  /// it on the user's currently active Spotify device.
  Future<String> playPlaylist(String clientId, String name) async {
    final token = await _validAccessToken(clientId);
    if (token == null) return 'Spotify ist nicht verbunden. Bitte in den Einstellungen anmelden.';

    final playlists = await getPlaylists(clientId);
    final needle = name.toLowerCase();
    final match = playlists.where((p) => p.name.toLowerCase().contains(needle)).firstOrNull;
    if (match == null) return 'Ich konnte keine Playlist namens "$name" auf deinem Spotify-Konto finden.';

    final playRes = await http.put(
      Uri.https('api.spotify.com', '/v1/me/player/play'),
      headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
      body: jsonEncode({'context_uri': match.uri}),
    );
    if (playRes.statusCode == 404) {
      return 'Öffne zuerst Spotify auf einem Gerät, dann kann ich "${match.name}" abspielen.';
    }
    if (playRes.statusCode != 204 && playRes.statusCode != 200) {
      return 'Spotify-Wiedergabe fehlgeschlagen (Code ${playRes.statusCode}). Braucht ein Premium-Konto.';
    }
    return 'Spiele die Playlist "${match.name}" auf Spotify.';
  }

  static String _randomVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(64, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
