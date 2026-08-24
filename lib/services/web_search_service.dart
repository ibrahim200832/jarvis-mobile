import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchResult {
  final String title;
  final String description;
  WebSearchResult(this.title, this.description);
}

/// Fetches live web results via the Brave Search API, giving JARVIS access to
/// current information beyond its frozen training data. Requires a free API
/// key from https://brave.com/search/api/ configured in Settings.
class WebSearchService {
  Future<List<WebSearchResult>> search(String apiKey, String query, {int count = 3}) async {
    if (apiKey.isEmpty) {
      throw Exception('Kein Websuche-Schlüssel hinterlegt. Bitte in den Einstellungen eintragen.');
    }
    final uri = Uri.https('api.search.brave.com', '/res/v1/web/search', {
      'q': query,
      'count': '$count',
    });
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
      'X-Subscription-Token': apiKey,
    });
    if (res.statusCode != 200) {
      throw Exception('Websuche fehlgeschlagen (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (json['web']?['results'] as List?) ?? [];
    return results.take(count).map((r) {
      final m = r as Map<String, dynamic>;
      final rawDescription = m['description'] as String? ?? '';
      return WebSearchResult(
        m['title'] as String? ?? '',
        rawDescription.replaceAll(RegExp(r'<[^>]*>'), ''), // Brave highlights matches with <strong> tags
      );
    }).toList();
  }
}
