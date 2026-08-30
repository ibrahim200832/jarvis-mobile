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
}
