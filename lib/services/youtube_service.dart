import 'package:url_launcher/url_launcher.dart';

/// Opens YouTube search results, replacing `pywhatkit.playonyt` from the
/// desktop app.
class YoutubeService {
  Future<bool> search(String query) async {
    final uri = Uri.https('www.youtube.com', '/results', {'search_query': query});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
