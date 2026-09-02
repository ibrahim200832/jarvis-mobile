import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/log_service.dart';

void main() {
  late Directory tempDir;
  late LogService log;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jarvis_log_test_');
    log = LogService(directoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('LogEntry', () {
    test('toLine/tryParse round-trips', () {
      final entry = LogEntry(
        timestamp: DateTime.utc(2026, 1, 1, 12, 30),
        level: LogLevel.error,
        source: 'AiChatService',
        message: 'Timeout nach 25s',
      );
      final parsed = LogEntry.tryParse(entry.toLine());
      expect(parsed, isNotNull);
      expect(parsed!.timestamp, entry.timestamp);
      expect(parsed.level, LogLevel.error);
      expect(parsed.source, 'AiChatService');
      expect(parsed.message, 'Timeout nach 25s');
    });

    test('a message containing a tab character still round-trips', () {
      final entry = LogEntry(timestamp: DateTime.utc(2026, 1, 1), level: LogLevel.info, source: 'X', message: 'a\tb');
      final parsed = LogEntry.tryParse(entry.toLine());
      expect(parsed!.message, 'a\tb');
    });

    test('tryParse returns null for a malformed line', () {
      expect(LogEntry.tryParse('not a valid line'), isNull);
      expect(LogEntry.tryParse(''), isNull);
    });
  });

  group('LogService', () {
    test('readAll is empty when nothing was ever logged', () async {
      expect(await log.readAll(), isEmpty);
    });

    test('a logged entry is readable back with the right level/source/message', () async {
      await log.error('TestSource', 'something broke');
      final entries = await log.readAll();
      expect(entries, hasLength(1));
      expect(entries.first.level, LogLevel.error);
      expect(entries.first.source, 'TestSource');
      expect(entries.first.message, 'something broke');
    });

    test('info/warning/error all write at the right level', () async {
      await log.info('S', 'i');
      await log.warning('S', 'w');
      await log.error('S', 'e');
      final entries = await log.readAll();
      expect(entries.map((e) => e.level).toSet(), {LogLevel.info, LogLevel.warning, LogLevel.error});
    });

    test('readAll returns newest entries first', () async {
      await log.info('S', 'first');
      await log.info('S', 'second');
      await log.info('S', 'third');
      final entries = await log.readAll();
      expect(entries.map((e) => e.message).toList(), ['third', 'second', 'first']);
    });

    test('clear empties the log', () async {
      await log.info('S', 'x');
      await log.clear();
      expect(await log.readAll(), isEmpty);
    });

    test('trims to maxEntries, keeping only the most recent', () async {
      for (var i = 0; i < LogService.maxEntries + 50; i++) {
        await log.info('S', 'entry-$i');
      }
      final entries = await log.readAll();
      expect(entries.length, LogService.maxEntries);
      // Newest first, so the very last one written should be first.
      expect(entries.first.message, 'entry-${LogService.maxEntries + 49}');
    });
  });

  group('recentIssues', () {
    test('empty when nothing was ever logged', () async {
      expect(await log.recentIssues(), isEmpty);
    });

    test('skips info entries, newest issue first, respects limit', () async {
      await log.info('S', 'info entry');
      await log.warning('S', 'warn 1');
      await log.error('S', 'err 1');
      await log.warning('S', 'warn 2');
      final issues = await log.recentIssues(limit: 2);
      expect(issues.map((e) => e.message).toList(), ['warn 2', 'err 1']);
    });
  });

  group('countsByDay', () {
    test('includes zero-entry days, skips info, buckets today correctly', () async {
      await log.error('S', 'today error');
      await log.warning('S', 'today warning');
      await log.info('S', 'today info (not counted)');
      final trend = await log.countsByDay(days: 3);
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      expect(trend, hasLength(3));
      expect(trend.last.key, todayMidnight);
      expect(trend.last.value, (errors: 1, warnings: 1));
      expect(trend.first.key, todayMidnight.subtract(const Duration(days: 2)));
      expect(trend.first.value, (errors: 0, warnings: 0));
    });

    test('a historical entry lands in its own day, oldest day first (fully synthetic, injected now)', () async {
      // log() always stamps DateTime.now(), so both entries here are
      // written directly as raw lines to simulate a specific historical
      // date without depending on the real wall clock.
      final todayEntry = LogEntry(
        timestamp: DateTime(2026, 3, 10, 8),
        level: LogLevel.warning,
        source: 'S',
        message: 'today warning',
      );
      final yesterdayEntry = LogEntry(
        timestamp: DateTime(2026, 3, 9, 23),
        level: LogLevel.error,
        source: 'S',
        message: 'yesterday error',
      );
      final file = File('${tempDir.path}/jarvis_log.txt');
      await file.writeAsString('${yesterdayEntry.toLine()}\n${todayEntry.toLine()}\n');
      final trend = await log.countsByDay(days: 2, now: DateTime(2026, 3, 10, 9));
      expect(trend, hasLength(2));
      expect(trend.first.key, DateTime(2026, 3, 9));
      expect(trend.first.value, (errors: 1, warnings: 0));
      expect(trend.last.key, DateTime(2026, 3, 10));
      expect(trend.last.value, (errors: 0, warnings: 1));
    });
  });

  group('exportableFile', () {
    test('null before anything was ever logged', () async {
      expect(await log.exportableFile(), isNull);
    });

    test('returns the file once something has been logged', () async {
      await log.info('S', 'x');
      final file = await log.exportableFile();
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
    });
  });

  group('onError', () {
    test('fires for error() but not warning() or info()', () async {
      final seen = <LogEntry>[];
      log.onError = seen.add;

      await log.info('S', 'info');
      await log.warning('S', 'warning');
      expect(seen, isEmpty);

      await log.error('S', 'boom');
      expect(seen, hasLength(1));
      expect(seen.single.level, LogLevel.error);
      expect(seen.single.message, 'boom');
    });

    test('a throwing callback does not prevent error() from completing or logging locally', () async {
      log.onError = (_) => throw StateError('callback exploded');

      await log.error('S', 'still logged');

      final entries = await log.readAll();
      expect(entries.single.message, 'still logged');
    });
  });
}
