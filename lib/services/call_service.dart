import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer, replacing PC-only telephony helpers from the
/// desktop app (a real PC has no phone radio, a mobile does).
class CallService {
  Future<bool> call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    return launchUrl(uri);
  }
}
