import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'ai_chat_service.dart';

/// Authoritative, code-tracked state of one Überlebens-RPG playthrough. The
/// AI narrator is told this on every turn and never allowed to invent or
/// change numbers itself — see RpgService's doc comment.
class RpgStats {
  final int day;
  final int health;
  final int hunger;
  final int thirst;
  final int energy;
  final int food;
  final int water;
  final int scrap;
  final bool hasWeapon;
  final bool hasShelter;
  final bool alive;

  const RpgStats({
    required this.day,
    required this.health,
    required this.hunger,
    required this.thirst,
    required this.energy,
    required this.food,
    required this.water,
    required this.scrap,
    required this.hasWeapon,
    required this.hasShelter,
    required this.alive,
  });

  factory RpgStats.initial() => const RpgStats(
    day: 1,
    health: 100,
    hunger: 80,
    thirst: 80,
    energy: 100,
    food: 3,
    water: 3,
    scrap: 0,
    hasWeapon: false,
    hasShelter: false,
    alive: true,
  );

  RpgStats copyWith({
    int? day,
    int? health,
    int? hunger,
    int? thirst,
    int? energy,
    int? food,
    int? water,
    int? scrap,
    bool? hasWeapon,
    bool? hasShelter,
    bool? alive,
  }) => RpgStats(
    day: day ?? this.day,
    health: health ?? this.health,
    hunger: hunger ?? this.hunger,
    thirst: thirst ?? this.thirst,
    energy: energy ?? this.energy,
    food: food ?? this.food,
    water: water ?? this.water,
    scrap: scrap ?? this.scrap,
    hasWeapon: hasWeapon ?? this.hasWeapon,
    hasShelter: hasShelter ?? this.hasShelter,
    alive: alive ?? this.alive,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'health': health,
    'hunger': hunger,
    'thirst': thirst,
    'energy': energy,
    'food': food,
    'water': water,
    'scrap': scrap,
    'hasWeapon': hasWeapon,
    'hasShelter': hasShelter,
    'alive': alive,
  };

  factory RpgStats.fromJson(Map<String, dynamic> json) => RpgStats(
    day: json['day'] as int,
    health: json['health'] as int,
    hunger: json['hunger'] as int,
    thirst: json['thirst'] as int,
    energy: json['energy'] as int,
    food: json['food'] as int,
    water: json['water'] as int,
    scrap: json['scrap'] as int,
    hasWeapon: json['hasWeapon'] as bool,
    hasShelter: json['hasShelter'] as bool,
    alive: json['alive'] as bool,
  );

  /// The single source of truth handed to the AI narrator on every turn —
  /// never the reverse (the AI's reply is never parsed back for numbers).
  String summary() =>
      'Tag $day · Leben $health/100 · Hunger $hunger/100 · Durst $thirst/100 · Energie $energy/100 · '
      'Essen: $food · Wasser: $water · Schrott: $scrap · Waffe: ${hasWeapon ? 'ja' : 'nein'} · '
      'Unterschlupf: ${hasShelter ? 'ja' : 'nein'}';
}

int _clamp(int value) => value.clamp(0, 100);

/// Code-authoritative resource tracking for the Überlebens-RPG mode
/// ("Interaktive Mini-Spiele" / "Textbasierte Quests"). The AI narrator
/// (see ai_chat_service.dart's rpgSystemPrompt) only ever describes the
/// consequences of the exact numbers it is given — it never invents or
/// changes stats itself, and its replies are never parsed back for numbers.
/// All static methods here are pure (no I/O), mirroring
/// CalculatorService.evaluate / GamificationService.levelForXp, so they're
/// trivially unit-testable.
class RpgService {
  static const _statsKey = 'rpg_stats';
  static const _historyKey = 'rpg_history';
  static const _maxHistoryTurns = 12;

  /// Passive resource drain — runs every single turn, whether it was a
  /// recognized action or free-form AI narration, so the world always moves
  /// forward regardless of what the player typed.
  static RpgStats advanceDay(RpgStats s) {
    if (!s.alive) return s;
    var health = s.health;
    final hunger = _clamp(s.hunger - 8);
    final thirst = _clamp(s.thirst - 12);
    final energy = _clamp(s.energy - 6);
    if (hunger == 0) health -= 5;
    if (thirst == 0) health -= 8;
    health = _clamp(health);
    return s.copyWith(day: s.day + 1, health: health, hunger: hunger, thirst: thirst, energy: energy, alive: health > 0);
  }

  static ({RpgStats stats, String message}) eat(RpgStats s) {
    if (s.food <= 0) return (stats: s, message: 'Du hast keine Nahrung mehr übrig.');
    final stats = s.copyWith(food: s.food - 1, hunger: _clamp(s.hunger + 35));
    return (stats: stats, message: 'Du isst eine Portion Nahrung. Hunger gestillt.');
  }

  static ({RpgStats stats, String message}) drink(RpgStats s) {
    if (s.water <= 0) return (stats: s, message: 'Du hast kein Wasser mehr übrig.');
    final stats = s.copyWith(water: s.water - 1, thirst: _clamp(s.thirst + 40));
    return (stats: stats, message: 'Du trinkst eine Portion Wasser. Durst gestillt.');
  }

  static ({RpgStats stats, String message}) rest(RpgStats s) {
    final energyGain = s.hasShelter ? 45 : 25;
    final stats = s.copyWith(energy: _clamp(s.energy + energyGain));
    return (
      stats: stats,
      message: s.hasShelter ? 'Du ruhst dich sicher in deinem Unterschlupf aus.' : 'Du ruhst dich notdürftig aus.',
    );
  }

  static ({RpgStats stats, String message}) scavenge(RpgStats s, {Random? random}) {
    final rng = random ?? Random();
    final roll = rng.nextInt(100);
    if (roll < 15) {
      final stats = s.copyWith(health: _clamp(s.health - 10));
      return (stats: stats, message: 'Beim Durchsuchen einer Ruine verletzt du dich. -10 Leben.');
    }
    if (roll < 45) {
      final stats = s.copyWith(scrap: s.scrap + 1);
      return (stats: stats, message: 'Du findest ein Stück Schrott.');
    }
    if (roll < 75) {
      final stats = s.copyWith(food: s.food + 1);
      return (stats: stats, message: 'Du findest eine Portion Nahrung.');
    }
    if (roll < 95) {
      final stats = s.copyWith(water: s.water + 1);
      return (stats: stats, message: 'Du findest eine Portion Wasser.');
    }
    final stats = s.copyWith(scrap: s.scrap + 3, food: s.food + 1, water: s.water + 1);
    return (stats: stats, message: 'Ein seltener Fund: Schrott, Nahrung und Wasser!');
  }

  static ({RpgStats stats, String message}) craftWeapon(RpgStats s) {
    if (s.hasWeapon) return (stats: s, message: 'Du hast bereits eine Waffe.');
    if (s.scrap < 3) return (stats: s, message: 'Du brauchst mindestens 3 Schrott, um eine Waffe zu bauen.');
    final stats = s.copyWith(scrap: s.scrap - 3, hasWeapon: true);
    return (stats: stats, message: 'Du baust dir aus Schrott eine improvisierte Waffe.');
  }

  static ({RpgStats stats, String message}) buildShelter(RpgStats s) {
    if (s.hasShelter) return (stats: s, message: 'Du hast bereits einen Unterschlupf.');
    if (s.scrap < 5) return (stats: s, message: 'Du brauchst mindestens 5 Schrott, um einen Unterschlupf zu bauen.');
    final stats = s.copyWith(scrap: s.scrap - 5, hasShelter: true);
    return (stats: stats, message: 'Du errichtest einen provisorischen Unterschlupf.');
  }

  Future<RpgStats?> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null || raw.isEmpty) return null;
    return RpgStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveStats(RpgStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  Future<RpgStats> startNewRun() async {
    final stats = RpgStats.initial();
    await saveStats(stats);
    await saveHistory(const []);
    return stats;
  }

  Future<List<AiTurn>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey);
    if (raw == null) return [];
    return raw.map((s) {
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      return AiTurn(role: decoded['role'] as String, content: decoded['content'] as String);
    }).toList();
  }

  Future<void> saveHistory(List<AiTurn> history) async {
    final trimmed = history.length > _maxHistoryTurns * 2
        ? history.sublist(history.length - _maxHistoryTurns * 2)
        : history;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, trimmed.map((t) => jsonEncode(t.toJson())).toList());
  }
}
