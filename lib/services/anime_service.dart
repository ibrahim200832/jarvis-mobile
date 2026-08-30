import 'dart:convert';

import 'package:http/http.dart' as http;

/// One anime/manga lookup result.
class AnimeResult {
  final String title;
  final String? description;
  final int? episodesOrChapters;
  final String? status;
  final int? averageScore;
  final List<String> genres;
  final int? year;

  AnimeResult({
    required this.title,
    this.description,
    this.episodesOrChapters,
    this.status,
    this.averageScore,
    this.genres = const [],
    this.year,
  });
}

/// Looks up anime/manga info via the public AniList GraphQL API — free, no
/// API key needed. Always searches with isAdult: false so JARVIS never
/// surfaces 18+ entries, regardless of the search term.
class AnimeService {
  static const _endpoint = 'https://graphql.anilist.co';

  static const _query = '''
    query (\$search: String, \$type: MediaType) {
      Media(search: \$search, type: \$type, isAdult: false) {
        title { romaji english }
        description(asHtml: false)
        episodes
        chapters
        status
        averageScore
        genres
        startDate { year }
      }
    }
  ''';

  Future<AnimeResult?> searchAnime(String title) => _search(title, 'ANIME');
  Future<AnimeResult?> searchManga(String title) => _search(title, 'MANGA');

  Future<AnimeResult?> _search(String title, String type) async {
    final res = await http
        .post(
          Uri.parse(_endpoint),
          headers: {'content-type': 'application/json', 'accept': 'application/json'},
          body: jsonEncode({
            'query': _query,
            'variables': {'search': title, 'type': type},
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final media = data['data']?['Media'] as Map<String, dynamic>?;
    if (media == null) return null;

    final titles = media['title'] as Map<String, dynamic>? ?? {};
    final name = (titles['english'] as String?) ?? (titles['romaji'] as String?) ?? title;
    final rawDescription = media['description'] as String?;
    final description = rawDescription?.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\n', ' ').trim();

    return AnimeResult(
      title: name,
      description: (description == null || description.isEmpty) ? null : description,
      episodesOrChapters: media['episodes'] as int? ?? media['chapters'] as int?,
      status: media['status'] as String?,
      averageScore: media['averageScore'] as int?,
      genres: (media['genres'] as List?)?.cast<String>() ?? const [],
      year: (media['startDate'] as Map<String, dynamic>?)?['year'] as int?,
    );
  }
}
