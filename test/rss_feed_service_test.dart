import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_mobile/services/rss_feed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rssSample = '''
<?xml version="1.0"?>
<rss version="2.0">
  <channel>
    <title>Test News</title>
    <item>
      <title>Erste Schlagzeile</title>
      <link>https://example.com/1</link>
      <guid>guid-1</guid>
      <pubDate>Wed, 02 Oct 2024 15:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Zweite Schlagzeile</title>
      <link>https://example.com/2</link>
      <guid>guid-2</guid>
      <pubDate>Wed, 02 Oct 2024 16:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';

const _rssSampleWithThirdItem = '''
<?xml version="1.0"?>
<rss version="2.0">
  <channel>
    <title>Test News</title>
    <item>
      <title>Erste Schlagzeile</title>
      <link>https://example.com/1</link>
      <guid>guid-1</guid>
      <pubDate>Wed, 02 Oct 2024 15:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Zweite Schlagzeile</title>
      <link>https://example.com/2</link>
      <guid>guid-2</guid>
      <pubDate>Wed, 02 Oct 2024 16:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Dritte, brandneue Schlagzeile</title>
      <link>https://example.com/3</link>
      <guid>guid-3</guid>
      <pubDate>Wed, 02 Oct 2024 17:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';

const _atomSample = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Blog</title>
  <entry>
    <title>Atom-Eintrag</title>
    <link href="https://example.com/atom-1" />
    <id>urn:atom:1</id>
    <updated>2024-10-02T15:00:00Z</updated>
  </entry>
</feed>
''';

const _htmlWithFeedLink = '''
<!DOCTYPE html>
<html>
<head>
  <title>Example Site</title>
  <link rel="stylesheet" href="/style.css">
  <link rel="alternate" type="application/rss+xml" title="Feed" href="/feed.xml">
</head>
<body>Hello</body>
</html>
''';

const _htmlWithoutFeedLink = '''
<!DOCTYPE html>
<html><head><title>No feed here</title></head><body>Hello</body></html>
''';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('looksLikeFeedXml', () {
    test('true for RSS root', () => expect(looksLikeFeedXml(_rssSample), isTrue));
    test('true for Atom root', () => expect(looksLikeFeedXml(_atomSample), isTrue));
    test('false for a plain HTML page', () => expect(looksLikeFeedXml(_htmlWithFeedLink), isFalse));
  });

  group('discoverFeedUrl', () {
    test('finds and resolves a relative alternate feed link', () {
      final result = discoverFeedUrl(_htmlWithFeedLink, Uri.parse('https://example.com/blog/'));
      expect(result, 'https://example.com/feed.xml');
    });

    test('returns null when no feed link is advertised', () {
      expect(discoverFeedUrl(_htmlWithoutFeedLink, Uri.parse('https://example.com/')), isNull);
    });
  });

  group('parseFeedXml', () {
    test('parses RSS 2.0 items with title, link, guid and pubDate', () {
      final parsed = parseFeedXml(_rssSample);
      expect(parsed.title, 'Test News');
      expect(parsed.items, hasLength(2));
      final first = parsed.items.first;
      expect(first.title, 'Erste Schlagzeile');
      expect(first.link, 'https://example.com/1');
      expect(first.id, 'guid-1');
      expect(first.publishedAt, DateTime.utc(2024, 10, 2, 15, 0, 0));
    });

    test('parses Atom entries with href-attribute link and ISO8601 updated', () {
      final parsed = parseFeedXml(_atomSample);
      expect(parsed.title, 'Atom Blog');
      expect(parsed.items, hasLength(1));
      final entry = parsed.items.first;
      expect(entry.title, 'Atom-Eintrag');
      expect(entry.link, 'https://example.com/atom-1');
      expect(entry.id, 'urn:atom:1');
      expect(entry.publishedAt, DateTime.utc(2024, 10, 2, 15, 0, 0));
    });
  });

  group('buildRssNotification', () {
    test('returns null for an empty list', () {
      expect(buildRssNotification([]), isNull);
    });

    test('a single item gets a headline-specific title', () {
      final parsed = parseFeedXml(_rssSample);
      final notification = buildRssNotification([parsed.items.first]);
      expect(notification!.title, 'Neue Schlagzeile: Test News');
      expect(notification.body, 'Erste Schlagzeile');
    });

    test('more than the preview count adds a "und N weitere" suffix', () {
      final parsed = parseFeedXml(_rssSampleWithThirdItem);
      final fourItems = [...parsed.items, parsed.items.first];
      final notification = buildRssNotification(fourItems);
      expect(notification!.title, '4 neue Schlagzeilen');
      expect(notification.body, contains('und 1 weitere'));
    });
  });

  group('RssFeedService', () {
    test('addFeed on a direct feed URL stores it and seeds the seen set so a repeat check finds nothing new', () async {
      final client = MockClient((request) async => http.Response(_rssSample, 200));
      final service = RssFeedService(client: client);

      final source = await service.addFeed('https://example.com/rss.xml');
      expect(source.title, 'Test News');
      expect((await service.listFeeds()).single.url, 'https://example.com/rss.xml');

      final newItems = await service.checkForNewItems();
      expect(newItems, isEmpty);
    });

    test('addFeed discovers the feed URL from a plain website page', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/feed.xml') return http.Response(_rssSample, 200);
        return http.Response(_htmlWithFeedLink, 200);
      });
      final service = RssFeedService(client: client);

      final source = await service.addFeed('https://example.com/blog/');
      expect(source.url, 'https://example.com/feed.xml');
    });

    test('addFeed throws when no feed can be found or discovered', () async {
      final client = MockClient((request) async => http.Response(_htmlWithoutFeedLink, 200));
      final service = RssFeedService(client: client);

      expect(() => service.addFeed('https://example.com/'), throwsA(isA<StateError>()));
    });

    test('addFeed rejects a feed that is already subscribed', () async {
      final client = MockClient((request) async => http.Response(_rssSample, 200));
      final service = RssFeedService(client: client);

      await service.addFeed('https://example.com/rss.xml');
      expect(() => service.addFeed('https://example.com/rss.xml'), throwsA(isA<StateError>()));
    });

    test('checkForNewItems reports only items published after the feed was added', () async {
      var body = _rssSample;
      final client = MockClient((request) async => http.Response(body, 200));
      final service = RssFeedService(client: client);

      await service.addFeed('https://example.com/rss.xml');
      body = _rssSampleWithThirdItem;

      final newItems = await service.checkForNewItems();
      expect(newItems, hasLength(1));
      expect(newItems.single.title, 'Dritte, brandneue Schlagzeile');
    });

    test('removeFeed drops the subscription', () async {
      final client = MockClient((request) async => http.Response(_rssSample, 200));
      final service = RssFeedService(client: client);

      await service.addFeed('https://example.com/rss.xml');
      await service.removeFeed('https://example.com/rss.xml');

      expect(await service.listFeeds(), isEmpty);
    });

    test('a feed that fails to fetch is skipped without blocking other feeds', () async {
      // Both feeds fetch successfully while being added (so both end up
      // subscribed with a seeded baseline); only afterwards does the "bad"
      // one start failing and the "good" one gain a new item, to isolate
      // checkForNewItems' per-feed error handling from addFeed's own fetch.
      var goodBody = _rssSample;
      var failBad = false;
      final client = MockClient((request) async {
        final isBad = request.url.toString().contains('bad');
        if (isBad) {
          if (failBad) throw Exception('unreachable');
          return http.Response(_rssSample, 200);
        }
        return http.Response(goodBody, 200);
      });
      final service = RssFeedService(client: client);
      await service.addFeed('https://good.example.com/rss.xml');
      await service.addFeed('https://bad.example.com/rss.xml');

      goodBody = _rssSampleWithThirdItem;
      failBad = true;

      // The "good" feed still reports its new item even though "bad" throws.
      final newItems = await service.checkForNewItems();
      expect(newItems, hasLength(1));
      expect(newItems.single.title, 'Dritte, brandneue Schlagzeile');
    });
  });
}
