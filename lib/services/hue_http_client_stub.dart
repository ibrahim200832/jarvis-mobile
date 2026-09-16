import 'package:http/http.dart' as http;

/// Web fallback: browsers never allow overriding certificate validation, so
/// a Hue Bridge's self-signed cert simply fails there — expected, matching
/// the original desktop tool's "local network only" nature. A plain client
/// still lets [HueService] surface a clear connection error instead of a
/// missing-symbol crash.
http.Client createHueClient() => http.Client();
