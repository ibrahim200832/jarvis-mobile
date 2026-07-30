import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple on-device notes list ("notiz: <text>" / "meine notizen"),
/// replacing the desktop app's Contacts.txt-style plain-text scratch file
/// with a small persisted JSON list.
class NotesService {
  static const _key = 'notes';

  Future<List<String>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>();
  }

  Future<void> add(String text) async {
    final notes = await list();
    notes.add(text);
    await _save(notes);
  }

  /// Deletes the note at 1-based [index] (as spoken by the user). Returns
  /// the removed note, or null if the index was out of range.
  Future<String?> deleteAt(int index) async {
    final notes = await list();
    final zeroBased = index - 1;
    if (zeroBased < 0 || zeroBased >= notes.length) return null;
    final removed = notes.removeAt(zeroBased);
    await _save(notes);
    return removed;
  }

  Future<void> clear() async {
    await _save([]);
  }

  Future<void> _save(List<String> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(notes));
  }
}
