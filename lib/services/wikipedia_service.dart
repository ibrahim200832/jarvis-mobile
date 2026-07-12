import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches short Wikipedia summaries, mirroring the `wikipedia.summary(query,
/// sentences=5)` call in the original JARVIS.
class WikipediaService {
  Future<String> summary(String query, {String lang = 'de'}) async {
    final searchUri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'format': 'json',
      'srlimit': '1',
    });
    final searchRes = await http.get(searchUri);
    if (searchRes.statusCode != 200) {
      throw Exception('Wikipedia-Suche fehlgeschlagen (${searchRes.statusCode})');
    }
    final searchJson = jsonDecode(searchRes.body) as Map<String, dynamic>;
    final results = (searchJson['query']?['search'] as List?) ?? [];
    if (results.isEmpty) {
      return 'Dazu konnte ich nichts auf Wikipedia finden.';
    }
    final title = results.first['title'] as String;

    final summaryUri = Uri.https(
      '$lang.wikipedia.org',
      '/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
    );
    final summaryRes = await http.get(summaryUri);
    if (summaryRes.statusCode != 200) {
      throw Exception('Wikipedia-Zusammenfassung fehlgeschlagen (${summaryRes.statusCode})');
    }
    final summaryJson = jsonDecode(utf8.decode(summaryRes.bodyBytes)) as Map<String, dynamic>;
    final extract = summaryJson['extract'] as String? ?? '';
    return extract.isEmpty ? 'Dazu konnte ich nichts auf Wikipedia finden.' : extract;
  }
}
