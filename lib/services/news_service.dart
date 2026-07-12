import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches top headlines from NewsAPI.org, mirroring the `requests.get`
/// call against newsapi.org in the original JARVIS. Requires a free API
/// key from https://newsapi.org configured in Settings.
class NewsService {
  Future<List<String>> topHeadlines(String apiKey, {String country = 'de'}) async {
    if (apiKey.isEmpty) {
      throw Exception('Kein NewsAPI-Schlüssel hinterlegt. Bitte in den Einstellungen eintragen.');
    }
    final uri = Uri.https('newsapi.org', '/v2/top-headlines', {
      'country': country,
      'apiKey': apiKey,
      'pageSize': '5',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('News konnten nicht geladen werden (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final articles = (json['articles'] as List?) ?? [];
    return articles.map((a) => (a as Map<String, dynamic>)['title'] as String).toList();
  }
}
