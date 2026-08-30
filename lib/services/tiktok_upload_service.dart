import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_storage_service.dart';

/// The custom URL scheme TikTok redirects back into the app with after login
/// on mobile/desktop — must exactly match a Redirect URI configured in the
/// user's own TikTok Developer app, and the <activity> registered for it in
/// AndroidManifest.xml (see flutter_web_auth_2's setup).
const tiktokRedirectScheme = 'jarvismobile';
const tiktokRedirectUri = '$tiktokRedirectScheme://tiktok-callback';

/// On the web build, custom URL schemes don't work — instead the redirect
/// must land back on an https:// page served by the app itself
/// (`web/tiktok-callback.html`), which must *also* be registered as a
/// Redirect URI in the TikTok Developer app alongside the mobile one.
String _webRedirectUri() => Uri.base.resolve('tiktok-callback.html').toString();

/// Scopes requested at login: basic profile info plus permission to publish
/// videos on the user's behalf.
const _tiktokScopes = 'user.info.basic,video.publish';

/// A view of the connected TikTok creator, used to build the privacy picker
/// from live data rather than hardcoded values (TikTok's own content-sharing
/// guidelines require this) and to show the max allowed video length.
class TikTokCreatorInfo {
  TikTokCreatorInfo(this.nickname, this.privacyLevelOptions, this.maxVideoPostDurationSec);

  final String nickname;
  final List<String> privacyLevelOptions;
  final int maxVideoPostDurationSec;
}

/// Uploads videos to the user's own TikTok account via the Content Posting
/// API, authenticated through OAuth Authorization Code + PKCE. Unlike
/// Spotify's PKCE-only flow, TikTok's token endpoint also requires a client
/// secret — a secret can never live inside the app, so the token
/// exchange/refresh is proxied through the user's own Cloudflare Worker
/// (`/tiktok/token`, `/tiktok/refresh`), which holds it server-side. The
/// actual upload only needs the resulting user access token, so it talks
/// directly to TikTok.
///
/// Note: until the user's TikTok Developer app passes TikTok's own audit,
/// every upload is forced to "SELF_ONLY" (private) visibility regardless of
/// what's selected here — a TikTok platform restriction, not something this
/// app can work around.
class TikTokUploadService {
  TikTokUploadService({SecureStorageService? secureStorage}) : _secure = secureStorage ?? SecureStorageService();

  final SecureStorageService _secure;

  static const _keyAccessToken = 'tiktok_access_token';
  static const _keyRefreshToken = 'tiktok_refresh_token';
  static const _keyExpiresAt = 'tiktok_expires_at';

  /// Migrates a legacy plaintext SharedPreferences token (saved before AES-256
  /// secure storage was introduced) into secure storage on first read, same
  /// pattern as SettingsService._secureGet.
  Future<String?> _secureGet(String key) async {
    final secure = await _secure.read(key);
    if (secure != null) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy == null) return null;
    await _secure.write(key, legacy);
    await prefs.remove(key);
    return legacy;
  }

  Future<bool> isConnected() async => await _secureGet(_keyRefreshToken) != null;

  Future<void> disconnect() async {
    await _secure.delete(_keyAccessToken);
    await _secure.delete(_keyRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyExpiresAt);
  }

  /// Runs the login flow (opens TikTok's consent page, captures the
  /// redirect, exchanges the code for tokens via the Worker). Returns true
  /// on success.
  Future<bool> connect(String clientKey, String backendUrl) async {
    if (clientKey.trim().isEmpty || backendUrl.trim().isEmpty) return false;
    try {
      final redirectUri = kIsWeb ? _webRedirectUri() : tiktokRedirectUri;
      final verifier = _randomVerifier();
      // TikTok's PKCE challenge is hex-encoded SHA256, unlike Spotify's
      // base64url encoding — Digest.toString() already returns hex.
      final challenge = sha256.convert(utf8.encode(verifier)).toString();

      final authUrl = Uri.https('www.tiktok.com', '/v2/auth/authorize/', {
        'client_key': clientKey.trim(),
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'scope': _tiktokScopes,
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: tiktokRedirectScheme,
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) return false;

      final res = await http.post(
        Uri.parse(backendUrl.trim()).replace(path: '/tiktok/token'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'code': code, 'redirect_uri': redirectUri, 'code_verifier': verifier}),
      );
      if (res.statusCode != 200) return false;
      return await _storeTokens(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _storeTokens(Map<String, dynamic> json) async {
    await _secure.write(_keyAccessToken, json['access_token'] as String);
    final refreshToken = json['refresh_token'] as String?;
    if (refreshToken != null) await _secure.write(_keyRefreshToken, refreshToken);
    final expiresIn = json['expires_in'] as int? ?? 3600;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyExpiresAt, expiresAt.millisecondsSinceEpoch);
    return true;
  }

  /// Returns a valid access token, refreshing it first (via the Worker) if
  /// it's expired.
  Future<String?> _validAccessToken(String backendUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt(_keyExpiresAt);
    final accessToken = await _secureGet(_keyAccessToken);
    if (accessToken != null && expiresAt != null && DateTime.now().millisecondsSinceEpoch < expiresAt) {
      return accessToken;
    }

    final refreshToken = await _secureGet(_keyRefreshToken);
    if (refreshToken == null || backendUrl.trim().isEmpty) return null;
    final res = await http.post(
      Uri.parse(backendUrl.trim()).replace(path: '/tiktok/refresh'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (res.statusCode != 200) return null;
    final ok = await _storeTokens(jsonDecode(res.body) as Map<String, dynamic>);
    return ok ? _secure.read(_keyAccessToken) : null;
  }

  /// Fetches the connected creator's nickname, available privacy options and
  /// max video length. TikTok's guidelines require the privacy picker to be
  /// built from this response rather than hardcoded.
  Future<TikTokCreatorInfo?> getCreatorInfo(String backendUrl) async {
    final token = await _validAccessToken(backendUrl);
    if (token == null) return null;

    final res = await http.post(
      Uri.https('open.tiktokapis.com', '/v2/post/publish/creator_info/query/'),
      headers: {'authorization': 'Bearer $token', 'content-type': 'application/json; charset=UTF-8'},
    );
    if (res.statusCode != 200) return null;
    final data = (jsonDecode(res.body)['data'] as Map<String, dynamic>?) ?? {};
    return TikTokCreatorInfo(
      data['creator_nickname'] as String? ?? '',
      ((data['privacy_level_options'] as List?) ?? ['SELF_ONLY']).cast<String>(),
      data['max_video_post_duration_sec'] as int? ?? 60,
    );
  }

  /// Uploads [videoBytes] to TikTok in chunks (Direct Post) and polls the
  /// publish status until it completes, fails, or a timeout is reached.
  Future<String> uploadVideo(
    String backendUrl, {
    required Uint8List videoBytes,
    required String title,
    required String privacyLevel,
  }) async {
    final token = await _validAccessToken(backendUrl);
    if (token == null) return 'TikTok ist nicht verbunden. Bitte in den Einstellungen anmelden.';

    final videoSize = videoBytes.length;
    const chunkLimit = 10 * 1024 * 1024; // 10 MB, within TikTok's 5-64 MB chunk range
    final totalChunkCount = videoSize <= chunkLimit ? 1 : (videoSize / chunkLimit).floor();
    final chunkSize = videoSize <= chunkLimit ? videoSize : chunkLimit;

    final initRes = await http.post(
      Uri.https('open.tiktokapis.com', '/v2/post/publish/video/init/'),
      headers: {'authorization': 'Bearer $token', 'content-type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'post_info': {
          'title': title,
          'privacy_level': privacyLevel,
          // Sent defensively for API versions that require an explicit mode;
          // harmless if the deployed version ignores it.
          'post_mode': 'DIRECT_POST',
          'media_type': 'VIDEO',
        },
        'source_info': {
          'source': 'FILE_UPLOAD',
          'video_size': videoSize,
          'chunk_size': chunkSize,
          'total_chunk_count': totalChunkCount,
        },
      }),
    );
    if (initRes.statusCode != 200) {
      return 'TikTok-Upload konnte nicht gestartet werden (Code ${initRes.statusCode}).';
    }
    final initData = (jsonDecode(initRes.body)['data'] as Map<String, dynamic>?) ?? {};
    final uploadUrl = initData['upload_url'] as String?;
    final publishId = initData['publish_id'] as String?;
    if (uploadUrl == null || publishId == null) {
      return 'TikTok hat keine Upload-Adresse zurückgegeben.';
    }

    for (var i = 0; i < totalChunkCount; i++) {
      final start = i * chunkSize;
      final end = (i == totalChunkCount - 1) ? videoSize - 1 : start + chunkSize - 1;
      final chunkRes = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Range': 'bytes $start-$end/$videoSize', 'Content-Type': 'video/mp4'},
        body: videoBytes.sublist(start, end + 1),
      );
      if (chunkRes.statusCode != 201 && chunkRes.statusCode != 200) {
        return 'TikTok-Upload fehlgeschlagen (Teil ${i + 1}/$totalChunkCount, Code ${chunkRes.statusCode}).';
      }
    }

    // Wait up to ~30s for processing, then stop blocking — the user can
    // check TikTok directly if it takes longer.
    for (var attempt = 0; attempt < 15; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      final statusRes = await http.post(
        Uri.https('open.tiktokapis.com', '/v2/post/publish/status/fetch/'),
        headers: {'authorization': 'Bearer $token', 'content-type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'publish_id': publishId}),
      );
      if (statusRes.statusCode != 200) continue;
      final status = (jsonDecode(statusRes.body)['data']?['status'] as String?) ?? '';
      if (status == 'PUBLISH_COMPLETE') return 'Video auf TikTok hochgeladen.';
      if (status == 'FAILED') return 'TikTok-Verarbeitung ist fehlgeschlagen.';
    }
    return 'Video wird noch von TikTok verarbeitet — schau in ein paar Minuten in der TikTok-App nach.';
  }

  static String _randomVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(64, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
