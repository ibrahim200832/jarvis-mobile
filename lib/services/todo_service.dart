import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single to-do item ("neue aufgabe: <text>" / "aufgabe <n> erledigt"),
/// same on-device JSON-list persistence shape as [NotesService] but with an
/// added completion flag, since "offene To-Dos" needs done/pending state
/// that plain notes don't have.
class TodoItem {
  TodoItem({required this.text, this.done = false});

  final String text;
  final bool done;

  TodoItem copyWith({bool? done}) => TodoItem(text: text, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'text': text, 'done': done};

  static TodoItem fromJson(Map<String, dynamic> json) =>
      TodoItem(text: json['text'] as String, done: json['done'] as bool? ?? false);
}

class TodoService {
  static const _key = 'todos';

  Future<List<TodoItem>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TodoItem>> openItems() async {
    final all = await list();
    return all.where((t) => !t.done).toList();
  }

  Future<void> add(String text) async {
    final todos = await list();
    todos.add(TodoItem(text: text));
    await _save(todos);
  }

  /// Flips done/pending for the item at 1-based [index] (as spoken by the
  /// user). Returns the toggled item, or null if the index was out of range.
  Future<TodoItem?> toggleAt(int index) async {
    final todos = await list();
    final zeroBased = index - 1;
    if (zeroBased < 0 || zeroBased >= todos.length) return null;
    final toggled = todos[zeroBased].copyWith(done: !todos[zeroBased].done);
    todos[zeroBased] = toggled;
    await _save(todos);
    return toggled;
  }

  /// Deletes the item at 1-based [index]. Returns the removed item's text,
  /// or null if the index was out of range.
  Future<String?> deleteAt(int index) async {
    final todos = await list();
    final zeroBased = index - 1;
    if (zeroBased < 0 || zeroBased >= todos.length) return null;
    final removed = todos.removeAt(zeroBased);
    await _save(todos);
    return removed.text;
  }

  Future<void> clear() async {
    await _save([]);
  }

  Future<void> _save(List<TodoItem> todos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(todos.map((t) => t.toJson()).toList()));
  }
}
