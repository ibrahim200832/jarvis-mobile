import 'package:shared_preferences/shared_preferences.dart';

/// Kontextabhängige Reaktion: a one-off, once-per-night, persona-flavored
/// tease appended to JARVIS's reply when the user is clearly still coding
/// deep in the night. Pure SharedPreferences, no platform channel — no Fake
/// subclass needed in tests.
class LateNightTeaseService {
  static const _lastTeaseNightKey = 'late_night_tease_last_night';

  static const _codingKeywords = [
    'code',
    'coden',
    'commit',
    'programmier',
    'debugg',
    'flutter',
    'dart',
    'git',
    'bug',
    'compile',
    'kompilier',
  ];

  static const _teaseLines = {
    'drill_sergeant': 'SOLDAT! Es ist tiefste Nacht und du tippst noch Code — ab ins Bett, marsch!',
    'gaming_buddy': 'Alter, es ist mitten in der Nacht und du grindest noch Code statt zu pennen? Krass.',
    'butler': 'Verzeihung, gnädiger Herr, aber es ist eine höchst ungewöhnliche Stunde für Programmierarbeit.',
    'standard': 'Chef, es ist tiefste Nacht und du programmierst noch — soll ich den Kaffee nachlegen oder '
        'lieber den Notarzt rufen?',
  };

  bool isLateNight([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    return hour >= 23 || hour < 5;
  }

  bool looksLikeCoding(String lowerText) => _codingKeywords.any((k) => lowerText.contains(k));

  /// Bucket so 00:00-04:59 counts as part of the previous evening's "night"
  /// (one tease per continuous late-night stretch, not one per calendar day).
  String _nightKey(DateTime now) {
    final effective = now.hour < 5 ? now.subtract(const Duration(days: 1)) : now;
    return effective.toIso8601String().substring(0, 10);
  }

  /// Returns a tease line if it's late night, the text looks coding-related,
  /// and this "night" hasn't already been teased — else null.
  Future<String?> maybeTease(String persona, String lowerText, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    if (!isLateNight(effectiveNow) || !looksLikeCoding(lowerText)) return null;

    final prefs = await SharedPreferences.getInstance();
    final nightKey = _nightKey(effectiveNow);
    if (prefs.getString(_lastTeaseNightKey) == nightKey) return null;
    await prefs.setString(_lastTeaseNightKey, nightKey);

    return _teaseLines[persona] ?? _teaseLines['standard']!;
  }
}
