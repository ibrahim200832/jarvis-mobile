import 'package:shared_preferences/shared_preferences.dart';

/// One daily mini-challenge JARVIS can drop each morning.
class Challenge {
  final String id;
  final String text;

  const Challenge({required this.id, required this.text});
}

/// Picks a new random-looking (but deterministic per calendar day) mini
/// challenge each day, and tracks whether today's has been completed.
/// SharedPreferences-only — no platform channel, no Fake needed in tests.
class ChallengeService {
  static const _dateKey = 'challenge_current_date';
  static const _idKey = 'challenge_current_id';
  static const _completedDateKey = 'challenge_completed_date';

  static const _challenges = [
    Challenge(id: 'clean_widget', text: 'Schreibe heute einen sauberen Flutter-StatefulWidget ohne zu googlen.'),
    Challenge(id: 'walk_15', text: 'Geh heute 15 Minuten an die frische Luft.'),
    Challenge(id: 'no_todo', text: 'Löse heute ein TODO in deinem Code, das schon länger liegen bleibt.'),
    Challenge(id: 'water', text: 'Trink heute mindestens 2 Liter Wasser.'),
    Challenge(id: 'unit_test', text: 'Schreibe heute einen Unit-Test für eine Funktion ohne bestehende Tests.'),
    Challenge(id: 'no_phone_hour', text: 'Verbringe heute eine Stunde komplett ohne Smartphone.'),
    Challenge(id: 'refactor', text: 'Refaktoriere heute eine Funktion, die dich schon länger stört.'),
    Challenge(id: 'stretch', text: 'Mach heute 5 Minuten Dehnübungen.'),
    Challenge(id: 'read_docs', text: 'Lies heute die Dokumentation eines Pakets, das du bereits benutzt.'),
    Challenge(id: 'declutter', text: 'Räume heute deinen Schreibtisch oder Desktop auf.'),
    Challenge(id: 'commit_msg', text: 'Schreibe heute eine besonders klare, aussagekräftige Commit-Message.'),
    Challenge(id: 'call_friend', text: 'Ruf heute einen Freund oder eine Freundin an, mit der du lange nicht gesprochen hast.'),
  ];

  String _todayKey(DateTime now) => now.toIso8601String().substring(0, 10);

  /// Returns today's challenge, generating (and persisting) a new one if the
  /// stored date doesn't match today.
  Future<Challenge> current({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final today = _todayKey(effectiveNow);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dateKey);
    final storedId = prefs.getString(_idKey);
    if (storedDate == today && storedId != null) {
      return _challenges.firstWhere((c) => c.id == storedId, orElse: () => _challenges.first);
    }
    final index = today.hashCode.abs() % _challenges.length;
    final picked = _challenges[index];
    await prefs.setString(_dateKey, today);
    await prefs.setString(_idKey, picked.id);
    return picked;
  }

  Future<bool> isCompletedToday({DateTime? now}) async {
    final today = _todayKey(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_completedDateKey) == today;
  }

  /// Idempotent: calling this again the same day has no further effect.
  Future<void> markCompleted({DateTime? now}) async {
    final today = _todayKey(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_completedDateKey, today);
  }
}
