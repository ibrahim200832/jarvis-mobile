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
}
