import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One evening journal entry: what the user said about their day, and
/// JARVIS's reflective/motivating response.
class JournalEntry {
  final DateTime date;
  final String text;
  final String reflection;

  JournalEntry({required this.date, required this.text, required this.reflection});

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'text': text, 'reflection': reflection};

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    date: DateTime.parse(json['date'] as String),
    text: json['text'] as String,
    reflection: json['reflection'] as String,
  );
}

/// Persisted log of evening journal check-ins ("Tägliches Journaling").
/// Deliberately a single-shot reflective exchange, not a stateful
/// multi-turn mode like the story/RPG modes — mirrors NotesService's
/// SharedPreferences-JSON-list pattern.
class JournalService {
  static const _key = 'journal_entries';
  static const _maxEntries = 60;

  Future<List<JournalEntry>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> add(String text, String reflection, {DateTime? now}) async {
    final entries = await list();
    entries.add(JournalEntry(date: now ?? DateTime.now(), text: text, reflection: reflection));
    final trimmed = entries.length > _maxEntries ? entries.sublist(entries.length - _maxEntries) : entries;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<JournalEntry?> latest() async {
    final entries = await list();
    return entries.isEmpty ? null : entries.last;
  }
}
