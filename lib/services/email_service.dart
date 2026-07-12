import 'package:url_launcher/url_launcher.dart';

/// Opens the mail app with a pre-filled message, replacing the `smtplib`
/// based gmail sending from the desktop app.
class EmailService {
  Future<bool> compose({required String to, required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    return launchUrl(uri);
  }
}
