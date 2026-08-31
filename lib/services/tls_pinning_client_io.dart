import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'spki_pin.dart';

/// Real implementation, used on mobile/desktop (anywhere `dart:io` is
/// available) — see tls_pinning_service.dart for why this needs a
/// conditional import instead of living there directly.
http.Client pinnedClient(List<String> spkiPinsBase64) {
  // withTrustedRoots: false means the platform's normal CA trust check is
  // skipped entirely and every connection is decided by
  // badCertificateCallback below — the standard dart:io idiom for
  // certificate pinning (there is no API to inspect a *successfully*
  // trusted chain, only a failed one, so we make every connection "fail"
  // by default and then explicitly allow only pinned keys).
  final inner = HttpClient(context: SecurityContext(withTrustedRoots: false));
  inner.badCertificateCallback = (X509Certificate cert, String host, int port) {
    final pin = spkiSha256Base64FromDer(Uint8List.fromList(cert.der));
    return pin != null && spkiPinsBase64.contains(pin);
  };
  return IOClient(inner);
}

/// Opens a bare TLS handshake to [host]:[port] purely to inspect whatever
/// certificate is presented — accepts any certificate for this single probe
/// (onBadCertificate: (_) => true) since the goal here is reading the pin,
/// not validating trust. Used for trust-on-first-use: Einstellungen shows
/// the result so the user can copy it in to "lock in" their own worker's
/// current certificate. No HTTP request is sent over this connection.
Future<String?> currentPin(String host, {int port = 443}) async {
  SecureSocket? socket;
  try {
    socket = await SecureSocket.connect(host, port, onBadCertificate: (_) => true).timeout(const Duration(seconds: 10));
    final cert = socket.peerCertificate;
    if (cert == null) return null;
    return spkiSha256Base64FromDer(Uint8List.fromList(cert.der));
  } catch (_) {
    return null;
  } finally {
    socket?.destroy();
  }
}
