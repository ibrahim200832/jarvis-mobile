import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/journal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late JournalService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = JournalService();
  });

  test('list() is empty when nothing was saved yet', () async {
    expect(await service.list(), isEmpty);
  });

  test('add() appends an entry with the given text and reflection', () async {
    await service.add('guter tag', 'Schön zu hören!', now: DateTime(2026, 1, 1));
    final entries = await service.list();
    expect(entries.length, 1);
    expect(entries.first.text, 'guter tag');
    expect(entries.first.reflection, 'Schön zu hören!');
  });

  test('entries preserve insertion order', () async {
    await service.add('tag eins', 'r1', now: DateTime(2026, 1, 1));
    await service.add('tag zwei', 'r2', now: DateTime(2026, 1, 2));
    final entries = await service.list();
    expect(entries[0].text, 'tag eins');
    expect(entries[1].text, 'tag zwei');
  });

  test('latest() returns the most recently added entry', () async {
    await service.add('alt', 'r1', now: DateTime(2026, 1, 1));
    await service.add('neu', 'r2', now: DateTime(2026, 1, 2));
    final latest = await service.latest();
    expect(latest!.text, 'neu');
  });

  test('latest() returns null when there are no entries', () async {
    expect(await service.latest(), isNull);
  });

  test('list is capped at 60 entries, dropping the oldest', () async {
    for (var i = 0; i < 65; i++) {
      await service.add('tag $i', 'r$i', now: DateTime(2026, 1, 1).add(Duration(days: i)));
    }
    final entries = await service.list();
    expect(entries.length, 60);
    expect(entries.first.text, 'tag 5');
    expect(entries.last.text, 'tag 64');
  });

  test('toJson/fromJson round-trips correctly', () async {
    await service.add('roundtrip', 'reflection', now: DateTime(2026, 3, 15, 20, 30));
    final entries = await service.list();
    expect(entries.first.date, DateTime(2026, 3, 15, 20, 30));
  });
}
