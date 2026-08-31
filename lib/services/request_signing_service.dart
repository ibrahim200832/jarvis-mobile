import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The three headers a signed request carries, ready to merge into an HTTP
/// request's header map.
class SignedRequestHeaders {
  SignedRequestHeaders({required this.timestamp, required this.nonce, required this.signature});

  final String timestamp;
  final String nonce;
  final String signature;

  Map<String, String> toHeaders() => {
    'X-Jarvis-Timestamp': timestamp,
    'X-Jarvis-Nonce': nonce,
    'X-Jarvis-Signature': signature,
  };
}

/// Signs outgoing requests to the user's own AI backend Worker (see
/// worker/ai-proxy.js) with an HMAC-SHA256, so the Worker can reject
/// requests that weren't sent by an app holding the shared secret
/// (Einstellungen → "KI-Server-Schlüssel"), plus a timestamp + random nonce
/// so it can also reject replayed copies of an intercepted request.
///
/// Purely computational — no I/O, no platform channel — so it's fully
/// unit-testable without mocking anything.
class RequestSigningService {
  /// Canonical string that gets signed:
  /// `METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(body)-hex`.
  ///
  /// The body is hashed rather than included directly so the signed string
  /// stays a small, fixed shape regardless of request size, and so both
  /// sides only need to agree on the exact raw bytes sent — not on
  /// serializing JSON identically. [path] must match what the receiving
  /// server sees as `new URL(request.url).pathname` (which is `/` for a
  /// bare origin, never empty) — callers should normalize accordingly.
  SignedRequestHeaders sign({
    required String secret,
    required String method,
    required String path,
    required String body,
    DateTime? now,
    String? nonceOverride,
  }) {
    final timestamp = ((now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = nonceOverride ?? _randomNonce();
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    final canonical = '$method\n$path\n$timestamp\n$nonce\n$bodyHash';
    final signature = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(canonical)).toString();
    return SignedRequestHeaders(timestamp: timestamp, nonce: nonce, signature: signature);
  }

  static String _randomNonce() {
    final rand = Random.secure();
    return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  }
}

/// Builds the header map for a POST to the user's own backend Worker.
/// Without a [secret] the request goes out unsigned — the Worker itself
/// decides whether that's still accepted (see worker/ai-proxy.js: signing
/// is enforced only once the operator has configured HMAC_SECRET
/// server-side, so this stays backward compatible with a Worker deployed
/// before this feature existed). Shared by AiChatService and
/// AppIntegrityService so both talk to the same Worker consistently.
Map<String, String> buildSignedHeaders({required String backendUrl, required String body, String? secret}) {
  final headers = {'content-type': 'application/json'};
  if (secret == null || secret.isEmpty) return headers;
  final uri = Uri.parse(backendUrl.trim());
  // Matches how the Worker sees it: new URL(request.url).pathname is never
  // empty, it's "/" for a bare origin.
  final path = uri.path.isEmpty ? '/' : uri.path;
  final signed = RequestSigningService().sign(secret: secret, method: 'POST', path: path, body: body);
  return {...headers, ...signed.toHeaders()};
}
