import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'request_signing_service.dart';
import 'tls_pinning_service.dart';

/// App-Integritäts-Check (Google Play Integrity API) — asks the OS/Play
/// Store to attest that this install is genuine (not a modified/repacked
/// APK) and the device isn't rooted, then has the app's own server (see
/// worker/ai-proxy.js's /integrity/verify) verify that attestation with
/// Google. Android-only: there is no Play Integrity equivalent for iOS/web,
/// so [requestIntegrityToken] simply returns null there instead of
/// erroring — callers treat that as "no attestation available", not a
/// failure.
///
/// Uses `package:flutter/foundation.dart`'s [defaultTargetPlatform] rather
/// than `dart:io`'s `Platform` specifically so this file stays importable
/// (and compiles) unconditionally from web-built code too, unlike
/// dart:io-based platform checks which would need the same conditional-
/// import treatment as tls_pinning_service.dart.
class AppIntegrityService {
  static const _channel = MethodChannel('com.jarvis.mobile.jarvis_mobile/integrity');
  final _tlsPinning = TlsPinningService();

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Requests a signed integrity token for [nonce] from the native Play
  /// Integrity SDK (see MainActivity.kt), scoped to the Google Cloud
  /// project [cloudProjectNumber] the user linked in Einstellungen. Returns
  /// null (never throws) if unsupported on this platform, not configured,
  /// or the request fails for any reason (no network, Play Services
  /// missing, no linked cloud project yet, ...) — the caller degrades
  /// gracefully rather than treating "no attestation" as fatal.
  Future<String?> requestIntegrityToken({required String nonce, required String cloudProjectNumber}) async {
    if (!isSupported || cloudProjectNumber.trim().isEmpty) return null;
    try {
      return await _channel.invokeMethod<String>('requestIntegrityToken', {
        'nonce': nonce,
        'cloudProjectNumber': cloudProjectNumber.trim(),
      });
    } catch (_) {
      return null;
    }
  }

  /// Sends a Play Integrity [token] (and the [nonce] it was requested with)
  /// to the user's own Worker for verification against Google (see
  /// worker/ai-proxy.js's /integrity/verify — needs GOOGLE_SERVICE_ACCOUNT_JSON
  /// configured there, see README). Returns null (not false) if the check
  /// couldn't be performed at all (no backend configured, network error,
  /// endpoint not set up yet) — callers should treat that as "unknown", not
  /// as a failed check, since a still-unconfigured Worker is expected for
  /// most installs of this feature.
  Future<bool?> verifyWithBackend({
    required String backendUrl,
    required String token,
    required String nonce,
    String? hmacSecret,
    List<String> certPins = const [],
  }) async {
    if (backendUrl.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(backendUrl.trim()).replace(path: '/integrity/verify');
      final bodyJson = jsonEncode({'token': token, 'nonce': nonce});
      final headers = buildSignedHeaders(backendUrl: uri.toString(), body: bodyJson, secret: hmacSecret);
      final client = certPins.isEmpty ? http.Client() : _tlsPinning.pinnedClient(certPins);
      http.Response res;
      try {
        res = await client.post(uri, headers: headers, body: bodyJson).timeout(const Duration(seconds: 15));
      } finally {
        client.close();
      }
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['ok'] == true;
    } catch (_) {
      return null;
    }
  }
}
