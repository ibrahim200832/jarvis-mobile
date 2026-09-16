import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;

/// The Hue Bridge serves its local CLIP v2 API over HTTPS with a
/// self-signed certificate (same as the original Python tool, which calls
/// `urllib3.disable_warnings()`) — there's no CA to validate against on a
/// LAN-only device, so any cert from a host on the private network is
/// accepted. This never runs against the public internet.
http.Client createHueClient() {
  final httpClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) => _isPrivateNetworkHost(host);
  return io_client.IOClient(httpClient);
}

bool _isPrivateNetworkHost(String host) {
  final address = InternetAddress.tryParse(host);
  if (address == null) return false;
  if (address.isLoopback) return true;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4 && bytes.length == 4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }
  return false;
}
