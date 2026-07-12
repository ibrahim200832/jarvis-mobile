import 'dart:convert';
import 'package:http/http.dart' as http;

/// Looks up the device's public IP address, replacing the `requests.get`
/// call against an IP-lookup API in the original JARVIS.
class IpService {
  Future<String> publicIp() async {
    final res = await http.get(Uri.https('api.ipify.org', '/', {'format': 'json'}));
    if (res.statusCode != 200) {
      throw Exception('IP-Adresse konnte nicht ermittelt werden (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['ip'] as String;
  }
}
