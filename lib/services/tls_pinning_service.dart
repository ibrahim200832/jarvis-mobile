import 'package:http/http.dart' as http;

import 'tls_pinning_client_stub.dart' if (dart.library.io) 'tls_pinning_client_io.dart' as platform;

export 'spki_pin.dart' show spkiSha256Base64FromDer;

/// Certificate pinning for connections to the user's own AI backend Worker.
///
/// Each user deploys their own Worker under their own hostname (there is no
/// single "the" server this app talks to), so there is no fixed pin this
/// open-source app could ship hardcoded — a pin only means something once
/// the user has configured their own Worker's current certificate in
/// Einstellungen. An empty pin list means pinning is inactive: plain,
/// normal TLS validation applies, same as before this feature existed.
///
/// Real enforcement only exists on mobile/desktop — see
/// tls_pinning_client_stub.dart for why the web build is necessarily a
/// no-op here (not a shortcut, a genuine browser platform limitation).
class TlsPinningService {
  /// An http.Client that only accepts a TLS connection whose leaf
  /// certificate's SPKI hash is in [spkiPinsBase64]. If the list is empty,
  /// returns a plain, unpinned client instead (pinning "off").
  http.Client pinnedClient(List<String> spkiPinsBase64) {
    if (spkiPinsBase64.isEmpty) return http.Client();
    return platform.pinnedClient(spkiPinsBase64);
  }

  /// Trust-on-first-use helper: connects to [host]:[port] and returns the
  /// SPKI pin of whatever certificate is currently presented, without
  /// validating it against anything — the caller (Einstellungen) shows this
  /// to the user so they can review and explicitly save it as their pin.
  Future<String?> currentPin(String host, {int port = 443}) => platform.currentPin(host, port: port);
}
