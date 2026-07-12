import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp with a pre-filled message, replacing `pywhatkit.sendwhatmsg`
/// from the desktop app. `phone` must be in international format, e.g.
/// "+491701234567".
class WhatsappService {
  Future<bool> sendMessage({required String phone, required String message}) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/${digits.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
