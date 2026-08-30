import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// What happened after one XP-earning action: how much was gained, the
/// resulting level, and anything newly unlocked — so the caller can fold a
/// short " (+5 XP · ...)" suffix onto the normal command reply.
class XpResult {
  final int gained;
  final int totalXp;
  final int level;
  final bool leveledUp;
  final List<String> unlockedAchievementTitles;

  XpResult({
    required this.gained,
    required this.totalXp,
    required this.level,
    required this.leveledUp,
    this.unlockedAchievementTitles = const [],
  });

  String toSuffix() {
    final parts = <String>['+$gained XP'];
    if (leveledUp) parts.add('Level $level erreicht (${GamificationService.rankForLevel(level)})!');
    for (final title in unlockedAchievementTitles) {
      parts.add('Erfolg freigeschaltet: $title!');
    }
    return ' (${parts.join(' · ')})';
  }
}

class _AchievementDef {
  final String id;
  final String title;
  final bool Function(Map<String, int> stats, int level) unlockedWhen;
  const _AchievementDef(this.id, this.title, this.unlockedWhen);
}

/// Everything the Real-Life-RPG dashboard screen needs in one bundle, so it
/// only has to make a single call instead of several round-trips.
class DashboardData {
  final int xp;
  final int level;
  final String rank;
  final int xpForCurrentLevel;
  final int xpForNextLevel;
  final int energy;
  final List<String> unlockedAchievementTitles;
  final List<String> lockedAchievementTitles;
  final String tacticalAdvice;

  DashboardData({
    required this.xp,
    required this.level,
    required this.rank,
    required this.xpForCurrentLevel,
    required this.xpForNextLevel,
    required this.energy,
    required this.unlockedAchievementTitles,
    required this.lockedAchievementTitles,
    required this.tacticalAdvice,
  });

  /// 0.0..1.0 progress within the current level's XP span.
  double get xpProgress {
    final span = xpForNextLevel - xpForCurrentLevel;
    if (span <= 0) return 1.0;
    return ((xp - xpForCurrentLevel) / span).clamp(0.0, 1.0);
  }
}

/// Local, on-device XP/level/achievement system that rewards using JARVIS —
/// notes, timers, self-logged code commits, and simply showing up each day.
/// Purely client-side (SharedPreferences), no account or server needed.
class GamificationService {
  static const _statsKey = 'gamification_stats';
  static const _achievementsKey = 'gamification_achievements';
  static const _lastDailyBonusKey = 'gamification_last_daily_bonus';

  static const dailyBonusXp = 10;
  static const noteXp = 5;
  static const timerXp = 5;
  static const commitXp = 15;
  static const challengeXp = 20;

  /// How much virtual "Energie" (0-100) drains per day without a fresh
  /// "ich habe X stunden geschlafen" report — chosen so one skipped day is
  /// mild (100 -&gt; 85), but a run of neglect visibly matters (~7 days to 0).
  static const energyDecayPerDay = 15;
  static const _defaultEnergy = 70;

  static final List<_AchievementDef> _achievements = [
    _AchievementDef('erste_notiz', 'Erste Notiz', (s, lvl) => (s['notesAdded'] ?? 0) >= 1),
    _AchievementDef('notiz_meister', 'Notiz-Meister', (s, lvl) => (s['notesAdded'] ?? 0) >= 10),
    _AchievementDef('zeitplaner', 'Zeitplaner', (s, lvl) => (s['timersSet'] ?? 0) >= 1),
    _AchievementDef('erster_commit', 'Erster Commit', (s, lvl) => (s['commitsLogged'] ?? 0) >= 1),
    _AchievementDef('commit_serie', 'Commit-Serie', (s, lvl) => (s['commitsLogged'] ?? 0) >= 10),
    _AchievementDef('aufsteiger', 'Aufsteiger (Level 5)', (s, lvl) => lvl >= 5),
    _AchievementDef('veteran', 'Veteran (Level 10)', (s, lvl) => lvl >= 10),
    _AchievementDef('erste_challenge', 'Erste Challenge', (s, lvl) => (s['challengesCompleted'] ?? 0) >= 1),
    _AchievementDef('challenge_serie', 'Challenge-Serie', (s, lvl) => (s['challengesCompleted'] ?? 0) >= 10),
  ];

  /// level = 1 + floor(sqrt(xp / 25)), so each level needs progressively
  /// more XP — no hardcoded threshold table, extends indefinitely.
  static int levelForXp(int xp) => 1 + sqrt(xp / 25).floor();

  static int xpForLevel(int level) => 25 * (level - 1) * (level - 1);

  static String rankForLevel(int level) {
    if (level >= 15) return 'Legende';
    if (level >= 10) return 'Meister';
    if (level >= 7) return 'Experte';
    if (level >= 5) return 'Spezialist';
    if (level >= 3) return 'Assistent';
    return 'Rekrut';
  }

  Future<Map<String, int>> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null || raw.isEmpty) return {'xp': 0};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<void> _saveStats(Map<String, int> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats));
  }

  Future<Set<String>> _loadUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_achievementsKey) ?? const []).toSet();
  }

  Future<void> _saveUnlocked(Set<String> unlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_achievementsKey, unlocked.toList());
  }

  Future<XpResult> _award(int amount, {String? statKey}) async {
    final stats = await _loadStats();
    final beforeLevel = levelForXp(stats['xp'] ?? 0);
    if (statKey != null) stats[statKey] = (stats[statKey] ?? 0) + 1;
    final afterXp = (stats['xp'] ?? 0) + amount;
    stats['xp'] = afterXp;
    await _saveStats(stats);

    final afterLevel = levelForXp(afterXp);
    final unlocked = await _loadUnlocked();
    final newlyUnlocked = <String>[];
    for (final a in _achievements) {
      if (!unlocked.contains(a.id) && a.unlockedWhen(stats, afterLevel)) {
        unlocked.add(a.id);
        newlyUnlocked.add(a.title);
      }
    }
    if (newlyUnlocked.isNotEmpty) await _saveUnlocked(unlocked);

    return XpResult(
      gained: amount,
      totalXp: afterXp,
      level: afterLevel,
      leveledUp: afterLevel > beforeLevel,
      unlockedAchievementTitles: newlyUnlocked,
    );
  }

  Future<XpResult> awardForNote() => _award(noteXp, statKey: 'notesAdded');
  Future<XpResult> awardForTimer() => _award(timerXp, statKey: 'timersSet');
  Future<XpResult> logCommit() => _award(commitXp, statKey: 'commitsLogged');
  Future<XpResult> awardForChallenge() => _award(challengeXp, statKey: 'challengesCompleted');

  /// Once per calendar day: a small "thanks for using JARVIS today" bonus.
  /// Returns null if already claimed today.
  Future<XpResult?> claimDailyBonusIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString(_lastDailyBonusKey) == today) return null;
    await prefs.setString(_lastDailyBonusKey, today);
    return _award(dailyBonusXp);
  }

  Future<String> statusText() async {
    final stats = await _loadStats();
    final xp = stats['xp'] ?? 0;
    final level = levelForXp(xp);
    final nextLevelXp = xpForLevel(level + 1);
    final unlocked = await _loadUnlocked();
    final unlockedTitles = _achievements.where((a) => unlocked.contains(a.id)).map((a) => a.title).toList();
    final achievementsText = unlockedTitles.isEmpty
        ? 'Noch keine Erfolge freigeschaltet.'
        : 'Erfolge: ${unlockedTitles.join(', ')}.';
    return 'Level $level (${rankForLevel(level)}), $xp XP gesamt, noch ${nextLevelXp - xp} XP bis Level ${level + 1}. '
        '$achievementsText';
  }

  static int _dayIndex(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Manual sleep report ("ich habe 6 stunden geschlafen") — there's no
  /// health-sensor access set up, so this is entirely self-reported.
  /// 8 hours maps to full (100) energy; anything above clamps at 100.
  Future<int> setSleepHours(double hours, {DateTime? now}) async {
    final stats = await _loadStats();
    final energy = ((hours / 8.0) * 100).round().clamp(0, 100);
    stats['energyBase'] = energy;
    stats['energyUpdateDay'] = _dayIndex(now ?? DateTime.now());
    await _saveStats(stats);
    return energy;
  }

  /// Current energy, decaying by [energyDecayPerDay] per day since the last
  /// sleep report (or a neutral default if none was ever given).
  Future<int> getEnergy({DateTime? now}) async {
    final stats = await _loadStats();
    final base = stats['energyBase'];
    if (base == null) return _defaultEnergy;
    final lastUpdateDay = stats['energyUpdateDay'] ?? _dayIndex(now ?? DateTime.now());
    final daysSince = _dayIndex(now ?? DateTime.now()) - lastUpdateDay;
    if (daysSince <= 0) return base.clamp(0, 100);
    return (base - daysSince * energyDecayPerDay).clamp(0, 100);
  }

  /// Deterministic, rule-based "Charakter-Optimierung" tip — no AI call, so
  /// it's fully testable and always available offline.
  static String _tacticalAdvice(Map<String, int> stats, int level, int energy) {
    if (energy < 30) {
      return 'Energie kritisch niedrig ($energy%). Empfehlung: Schlaf nachholen, bevor du weitercodest.';
    }
    if (energy < 60) {
      return 'Energie unter der Hälfte ($energy%). Eine kurze Pause würde deine Effizienz steigern.';
    }
    if ((stats['notesAdded'] ?? 0) == 0) {
      return 'Noch keine Notizen geloggt. Nutze JARVIS, um offene Aufgaben festzuhalten.';
    }
    if ((stats['commitsLogged'] ?? 0) < (stats['notesAdded'] ?? 0)) {
      return 'Du sammelst mehr Notizen als Commits. Zeit, ein paar Ideen in Code umzusetzen.';
    }
    if (level < 5) {
      return 'Solide Basis, Rekrut. Sammle weiter XP durch Notizen, Timer und Commits, um aufzusteigen.';
    }
    return 'Alle Werte im grünen Bereich. Weiter so.';
  }

  Future<DashboardData> dashboardData({DateTime? now}) async {
    final stats = await _loadStats();
    final xp = stats['xp'] ?? 0;
    final level = levelForXp(xp);
    final energy = await getEnergy(now: now);
    final unlocked = await _loadUnlocked();
    final unlockedTitles = _achievements.where((a) => unlocked.contains(a.id)).map((a) => a.title).toList();
    final lockedTitles = _achievements.where((a) => !unlocked.contains(a.id)).map((a) => a.title).toList();

    return DashboardData(
      xp: xp,
      level: level,
      rank: rankForLevel(level),
      xpForCurrentLevel: xpForLevel(level),
      xpForNextLevel: xpForLevel(level + 1),
      energy: energy,
      unlockedAchievementTitles: unlockedTitles,
      lockedAchievementTitles: lockedTitles,
      tacticalAdvice: _tacticalAdvice(stats, level, energy),
    );
  }
}
