import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

/// One subscribed RSS/Atom feed.
class RssFeedSource {
  RssFeedSource({required this.url, required this.title});

  final String url;
  final String title;

  Map<String, dynamic> toJson() => {'url': url, 'title': title};

  factory RssFeedSource.fromJson(Map<String, dynamic> json) =>
      RssFeedSource(url: json['url'] as String, title: json['title'] as String);
}

/// One headline from a feed. [id] is the feed's own guid/id when present,
/// falling back to the link — used to detect which items are genuinely new
/// since the last check.
class RssItem {
  RssItem({required this.id, required this.title, required this.link, required this.feedTitle, this.publishedAt});

  final String id;
  final String title;
  final String link;
  final String feedTitle;
  final DateTime? publishedAt;
}

class ParsedFeed {
  ParsedFeed({required this.title, required this.items});

  final String title;
  final List<RssItem> items;
}

/// Named UTC offsets RFC 822 (RSS `pubDate`) allows in place of a numeric
/// zone, so date parsing doesn't just give up on the very common "GMT".
const _rfc822ZoneOffsets = {
  'UT': '+0000',
  'GMT': '+0000',
  'UTC': '+0000',
  'EST': '-0500',
  'EDT': '-0400',
  'CST': '-0600',
  'CDT': '-0500',
  'MST': '-0700',
  'MDT': '-0600',
  'PST': '-0800',
  'PDT': '-0700',
};

DateTime? _tryParseDate(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return iso;

  var normalized = trimmed;
  for (final entry in _rfc822ZoneOffsets.entries) {
    if (normalized.endsWith(entry.key)) {
      normalized = '${normalized.substring(0, normalized.length - entry.key.length).trimRight()} ${entry.value}';
      break;
    }
  }
  for (final pattern in ['EEE, dd MMM yyyy HH:mm:ss Z', 'dd MMM yyyy HH:mm:ss Z']) {
    try {
      return DateFormat(pattern, 'en_US').parseUtc(normalized);
    } catch (_) {
      // try the next pattern
    }
  }
  return null;
}

/// Whether [body] looks like it's already RSS or Atom XML (as opposed to an
/// HTML page whose feed link still needs discovering — see [discoverFeedUrl]).
bool looksLikeFeedXml(String body) {
  final head = body.trimLeft();
  return head.contains('<rss') || head.contains('<feed');
}

/// Looks for `<link rel="alternate" type="application/rss+xml" href="...">`
/// (or atom+xml) in an HTML page's `<head>`, the standard way sites
/// advertise their feed — so "add website X" works for any normal site,
/// not just a direct feed URL. Deliberately regex-based rather than a full
/// HTML parser: this app has no HTML-parsing dependency, and this specific,
/// well-known tag shape doesn't need one. Returns the resolved absolute
/// feed URL, or null if the page doesn't advertise one.
String? discoverFeedUrl(String html, Uri base) {
  final linkTag = RegExp(
    r'<link\b[^>]*>',
    caseSensitive: false,
  );
  for (final match in linkTag.allMatches(html)) {
    final tag = match.group(0)!;
    final isAlternate = RegExp('rel=["\']alternate["\']', caseSensitive: false).hasMatch(tag);
    final isFeedType = RegExp(
      r'type=["\x27]application/(?:rss|atom)\+xml["\x27]',
      caseSensitive: false,
    ).hasMatch(tag);
    if (!isAlternate || !isFeedType) continue;
    final hrefMatch = RegExp('href=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(tag);
    if (hrefMatch == null) continue;
    try {
      return base.resolve(hrefMatch.group(1)!).toString();
    } catch (_) {
      return null;
    }
  }
  return null;
}

String _elementText(XmlElement parent, String name) => parent.findElements(name).firstOrNull?.innerText.trim() ?? '';

/// Parses RSS 2.0 (`<item>`) or Atom (`<entry>`) XML into a feed title plus
/// its items. Throws [XmlParserException] (from package:xml) on malformed
/// XML — callers decide how to surface that.
ParsedFeed parseFeedXml(String body, {String fallbackTitle = ''}) {
  final doc = XmlDocument.parse(body);
  final rssItems = doc.findAllElements('item');
  final isAtom = rssItems.isEmpty;
  final entries = isAtom ? doc.findAllElements('entry') : rssItems;

  final channelTitle = doc.findAllElements('title').firstOrNull?.innerText.trim();
  final title = (channelTitle == null || channelTitle.isEmpty) ? fallbackTitle : channelTitle;

  final items = <RssItem>[];
  for (final entry in entries) {
    final itemTitle = _elementText(entry, 'title');
    String link;
    String id;
    DateTime? publishedAt;
    if (isAtom) {
      final linkEl = entry.findElements('link').firstOrNull;
      link = linkEl?.getAttribute('href')?.trim() ?? linkEl?.innerText.trim() ?? '';
      id = _elementText(entry, 'id');
      publishedAt = _tryParseDate(_elementText(entry, 'updated')) ?? _tryParseDate(_elementText(entry, 'published'));
    } else {
      link = _elementText(entry, 'link');
      id = _elementText(entry, 'guid');
      publishedAt = _tryParseDate(_elementText(entry, 'pubDate'));
    }
    final resolvedId = id.isEmpty ? link : id;
    if (resolvedId.isEmpty && itemTitle.isEmpty) continue;
    items.add(RssItem(id: resolvedId, title: itemTitle, link: link, feedTitle: title, publishedAt: publishedAt));
  }
  return ParsedFeed(title: title, items: items);
}

/// Builds a short title/body for a proactive notification (or an on-demand
/// chat reply) summarizing newly-found items, or null if there's nothing to
/// report. Pulled out as a pure function so it's testable without touching
/// NotificationService, and shared between the background task dispatcher
/// and CommandRouter's on-demand "was gibt's neues in meinen feeds" command.
({String title, String body})? buildRssNotification(List<RssItem> items) {
  if (items.isEmpty) return null;
  if (items.length == 1) {
    final item = items.first;
    return (title: 'Neue Schlagzeile: ${item.feedTitle}', body: item.title);
  }
  const previewCount = 3;
  final preview = items.take(previewCount).map((i) => '• ${i.title}').join('\n');
  final remaining = items.length - previewCount;
  final body = remaining > 0 ? '$preview\n… und $remaining weitere' : preview;
  return (title: '${items.length} neue Schlagzeilen', body: body);
}

/// Monitors subscribed RSS/Atom feeds (or plain websites that advertise
/// one, see [discoverFeedUrl]) and reports which items are new since the
/// last check, so JARVIS can proactively notify about fresh headlines —
/// either via the periodic background task (see BackgroundTaskService,
/// BackgroundTaskNames.rssFeedCheck) or on demand from the chat.
class RssFeedService {
  RssFeedService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _feedsKey = 'rss_feeds';
  static const _maxSeenPerFeed = 300;

  String _seenKey(String url) => 'rss_seen_$url';

  Future<List<RssFeedSource>> listFeeds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_feedsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => RssFeedSource.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveFeeds(List<RssFeedSource> feeds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedsKey, jsonEncode(feeds.map((f) => f.toJson()).toList()));
  }

  /// Resolves [url] to an actual feed URL (itself, if it's already RSS/Atom
  /// XML, or a discovered feed link if it's a normal website), fetches it
  /// once to determine the feed's title and seed the "already seen" set
  /// with its current items (so subscribing to an active feed doesn't
  /// immediately flood a notification with every past headline), and adds
  /// it to the subscription list.
  Future<RssFeedSource> addFeed(String url) async {
    final trimmedUrl = url.trim();
    final uri = Uri.parse(trimmedUrl);
    final firstResponse = await _client.get(uri).timeout(const Duration(seconds: 10));
    final feedUrl = looksLikeFeedXml(firstResponse.body) ? trimmedUrl : discoverFeedUrl(firstResponse.body, uri);
    if (feedUrl == null) {
      throw StateError('Kein RSS/Atom-Feed unter dieser Adresse gefunden.');
    }
    final body = feedUrl == trimmedUrl ? firstResponse.body : (await _client.get(Uri.parse(feedUrl)).timeout(const Duration(seconds: 10))).body;
    final parsed = parseFeedXml(body, fallbackTitle: uri.host);

    final feeds = await listFeeds();
    if (feeds.any((f) => f.url == feedUrl)) {
      throw StateError('Diesen Feed hast du schon abonniert.');
    }
    final source = RssFeedSource(url: feedUrl, title: parsed.title);
    await _saveFeeds([...feeds, source]);
    await _rememberSeen(feedUrl, parsed.items.map((i) => i.id));
    return source;
  }

  Future<void> removeFeed(String url) async {
    final feeds = await listFeeds();
    await _saveFeeds(feeds.where((f) => f.url != url).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey(url));
  }

  Future<ParsedFeed> fetchFeed(String url) async {
    final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    return parseFeedXml(res.body, fallbackTitle: Uri.parse(url).host);
  }

  Future<void> _rememberSeen(String feedUrl, Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _seenKey(feedUrl);
    final existing = prefs.getStringList(key) ?? const [];
    final merged = {...existing, ...ids}.toList();
    final trimmed = merged.length > _maxSeenPerFeed ? merged.sublist(merged.length - _maxSeenPerFeed) : merged;
    await prefs.setStringList(key, trimmed);
  }

  /// Checks every subscribed feed for items not yet in its "seen" set,
  /// returns the new ones, and marks them seen so a repeated check (or the
  /// next periodic background run) doesn't report them again. A feed that
  /// fails to fetch/parse is skipped rather than aborting the whole check.
  Future<List<RssItem>> checkForNewItems() async {
    final feeds = await listFeeds();
    final prefs = await SharedPreferences.getInstance();
    final newItems = <RssItem>[];
    for (final feed in feeds) {
      try {
        final parsed = await fetchFeed(feed.url);
        final seen = (prefs.getStringList(_seenKey(feed.url)) ?? const []).toSet();
        newItems.addAll(parsed.items.where((item) => !seen.contains(item.id)));
        await _rememberSeen(feed.url, parsed.items.map((i) => i.id));
      } catch (_) {
        // One unreachable/malformed feed shouldn't block the others.
      }
    }
    return newItems;
  }
}
