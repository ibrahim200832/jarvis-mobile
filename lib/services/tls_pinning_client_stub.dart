import 'package:http/http.dart' as http;

/// No-op fallback used wherever `dart:io` isn't available (the web build —
/// see the conditional import in tls_pinning_service.dart). Browsers manage
/// TLS entirely themselves; there is no web API for a page to inspect or
/// reject the server's certificate, so certificate pinning simply isn't
/// something a web page can do. Returns a perfectly normal client — the
/// browser's own TLS validation still applies as always, this only means
/// the *extra* pinning layer is unavailable on this platform.
http.Client pinnedClient(List<String> spkiPinsBase64) => http.Client();

Future<String?> currentPin(String host, {int port = 443}) async => null;
