import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/todo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('list() is empty when nothing has been saved yet', () async {
    final todos = TodoService();
    expect(await todos.list(), isEmpty);
  });

  test('add() appends an open to-do, preserving insertion order', () async {
    final todos = TodoService();
    await todos.add('müll rausbringen');
    await todos.add('wäsche waschen');

    final all = await todos.list();
    expect(all.map((t) => t.text), ['müll rausbringen', 'wäsche waschen']);
    expect(all.every((t) => !t.done), isTrue);
  });

  test('openItems() excludes done items', () async {
    final todos = TodoService();
    await todos.add('erste');
    await todos.add('zweite');
    await todos.toggleAt(1);

    final open = await todos.openItems();
    expect(open.map((t) => t.text), ['zweite']);
  });

  test('toggleAt() flips done state and is reversible', () async {
    final todos = TodoService();
    await todos.add('einzige');

    final toggledOn = await todos.toggleAt(1);
    expect(toggledOn?.done, isTrue);
    expect((await todos.list()).single.done, isTrue);

    final toggledOff = await todos.toggleAt(1);
    expect(toggledOff?.done, isFalse);
    expect((await todos.list()).single.done, isFalse);
  });

  test('toggleAt() returns null for an out-of-range index', () async {
    final todos = TodoService();
    await todos.add('einzige');

    expect(await todos.toggleAt(0), isNull);
    expect(await todos.toggleAt(5), isNull);
  });

  test('deleteAt() removes the item at the given 1-based index', () async {
    final todos = TodoService();
    await todos.add('erste');
    await todos.add('zweite');
    await todos.add('dritte');

    final removed = await todos.deleteAt(2);

    expect(removed, 'zweite');
    expect((await todos.list()).map((t) => t.text), ['erste', 'dritte']);
  });

  test('deleteAt() returns null for an out-of-range index', () async {
    final todos = TodoService();
    await todos.add('einzige');

    expect(await todos.deleteAt(0), isNull);
    expect(await todos.deleteAt(5), isNull);
    expect((await todos.list()).length, 1);
  });

  test('clear() removes every to-do', () async {
    final todos = TodoService();
    await todos.add('a');
    await todos.add('b');

    await todos.clear();

    expect(await todos.list(), isEmpty);
  });

  test('persists across separate TodoService instances (same mock prefs)', () async {
    await TodoService().add('geteilter zustand');
    expect((await TodoService().list()).single.text, 'geteilter zustand');
  });
}
