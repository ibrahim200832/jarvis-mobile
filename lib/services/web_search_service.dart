import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchResult {
  final String title;
  final String description;
  WebSearchResult(this.title, this.description);
}

/// Fetches live web results via the JARVIS AI Worker's `/search` endpoint,
/// giving JARVIS access to current information beyond its frozen training
/// data. The Worker holds the actual Brave Search API key server-side (see
/// worker/ai-proxy.js) — no key is ever stored or shipped in the app.
class WebSearchService {
  Future<List<WebSearchResult>> search(String backendUrl, String query) async {
    final uri = Uri.parse(backendUrl.trim()).replace(path: '/search', queryParameters: {'q': query});
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Websuche fehlgeschlagen (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (json['results'] as List?) ?? [];
    return results.map((r) {
      final m = r as Map<String, dynamic>;
      return WebSearchResult(m['title'] as String? ?? '', m['description'] as String? ?? '');
    }).toList();
  }
}
