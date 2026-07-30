import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/notes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('list() is empty when nothing has been saved yet', () async {
    final notes = NotesService();
    expect(await notes.list(), isEmpty);
  });

  test('add() appends a note, preserving insertion order', () async {
    final notes = NotesService();
    await notes.add('kaufe milch');
    await notes.add('wäsche waschen');

    expect(await notes.list(), ['kaufe milch', 'wäsche waschen']);
  });

  test('deleteAt() removes the note at the given 1-based index', () async {
    final notes = NotesService();
    await notes.add('erste');
    await notes.add('zweite');
    await notes.add('dritte');

    final removed = await notes.deleteAt(2);

    expect(removed, 'zweite');
    expect(await notes.list(), ['erste', 'dritte']);
  });

  test('deleteAt() returns null for an out-of-range index', () async {
    final notes = NotesService();
    await notes.add('einzige');

    expect(await notes.deleteAt(0), isNull);
    expect(await notes.deleteAt(5), isNull);
    expect(await notes.list(), ['einzige']);
  });

  test('clear() removes every note', () async {
    final notes = NotesService();
    await notes.add('a');
    await notes.add('b');

    await notes.clear();

    expect(await notes.list(), isEmpty);
  });

  test('persists across separate NotesService instances (same mock prefs)', () async {
    await NotesService().add('geteilter zustand');
    expect(await NotesService().list(), ['geteilter zustand']);
  });
}
