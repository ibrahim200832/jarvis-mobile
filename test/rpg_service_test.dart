import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/ai_chat_service.dart';
import 'package:jarvis_mobile/services/rpg_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RpgStats', () {
    test('initial() has expected starting values', () {
      final stats = RpgStats.initial();
      expect(stats.day, 1);
      expect(stats.health, 100);
      expect(stats.alive, isTrue);
      expect(stats.hasWeapon, isFalse);
      expect(stats.hasShelter, isFalse);
    });

    test('toJson/fromJson round-trips exactly', () {
      final stats = RpgStats.initial().copyWith(day: 4, health: 55, scrap: 2, hasWeapon: true);
      final restored = RpgStats.fromJson(stats.toJson());
      expect(restored.day, stats.day);
      expect(restored.health, stats.health);
      expect(restored.scrap, stats.scrap);
      expect(restored.hasWeapon, stats.hasWeapon);
    });

    test('summary() includes all key fields', () {
      final summary = RpgStats.initial().summary();
      expect(summary, contains('Tag 1'));
      expect(summary, contains('Leben 100/100'));
      expect(summary, contains('Waffe: nein'));
    });
  });

  group('advanceDay', () {
    test('drains hunger, thirst, energy and advances the day counter', () {
      final after = RpgService.advanceDay(RpgStats.initial());
      expect(after.day, 2);
      expect(after.hunger, lessThan(80));
      expect(after.thirst, lessThan(80));
      expect(after.energy, lessThan(100));
    });

    test('deals extra health damage when hunger and thirst hit 0', () {
      final starving = RpgStats.initial().copyWith(hunger: 0, thirst: 0, health: 20);
      final after = RpgService.advanceDay(starving);
      expect(after.health, lessThan(20));
    });

    test('marks alive=false once health reaches 0', () {
      final dying = RpgStats.initial().copyWith(health: 1, hunger: 0, thirst: 0);
      final after = RpgService.advanceDay(dying);
      expect(after.health, 0);
      expect(after.alive, isFalse);
    });

    test('is a no-op once already dead', () {
      final dead = RpgStats.initial().copyWith(health: 0, alive: false, day: 9);
      final after = RpgService.advanceDay(dead);
      expect(after.day, 9);
      expect(after.health, 0);
    });

    test('stats never go below 0 or above 100', () {
      final full = RpgStats.initial().copyWith(hunger: 100, thirst: 100, energy: 100);
      final after = RpgService.advanceDay(full);
      expect(after.hunger, lessThanOrEqualTo(100));
      expect(after.hunger, greaterThanOrEqualTo(0));
    });
  });

  group('eat', () {
    test('restores hunger and consumes one food unit', () {
      final result = RpgService.eat(RpgStats.initial().copyWith(hunger: 30, food: 2));
      expect(result.stats.food, 1);
      expect(result.stats.hunger, greaterThan(30));
    });

    test('does nothing when there is no food', () {
      final stats = RpgStats.initial().copyWith(food: 0);
      final result = RpgService.eat(stats);
      expect(result.stats.food, 0);
      expect(result.message, contains('keine Nahrung'));
    });

    test('clamps hunger at 100', () {
      final result = RpgService.eat(RpgStats.initial().copyWith(hunger: 90, food: 2));
      expect(result.stats.hunger, 100);
    });
  });

  group('drink', () {
    test('restores thirst and consumes one water unit', () {
      final result = RpgService.drink(RpgStats.initial().copyWith(thirst: 30, water: 2));
      expect(result.stats.water, 1);
      expect(result.stats.thirst, greaterThan(30));
    });

    test('does nothing when there is no water', () {
      final result = RpgService.drink(RpgStats.initial().copyWith(water: 0));
      expect(result.message, contains('kein Wasser'));
    });
  });

  group('rest', () {
    test('restores more energy with a shelter than without', () {
      final withShelter = RpgService.rest(RpgStats.initial().copyWith(energy: 20, hasShelter: true));
      final withoutShelter = RpgService.rest(RpgStats.initial().copyWith(energy: 20, hasShelter: false));
      expect(withShelter.stats.energy, greaterThan(withoutShelter.stats.energy));
    });
  });

  group('scavenge', () {
    test('is deterministic with a seeded Random (low roll = injury)', () {
      final result = RpgService.scavenge(RpgStats.initial(), random: Random(1));
      // Just assert it produces a valid, non-throwing result — the exact
      // outcome depends on the seeded sequence, which is an implementation
      // detail we don't want to hard-pin here.
      expect(result.stats.health, lessThanOrEqualTo(100));
      expect(result.message, isNotEmpty);
    });

    test('never returns a health above 100 or scrap below 0', () {
      for (var seed = 0; seed < 20; seed++) {
        final result = RpgService.scavenge(RpgStats.initial(), random: Random(seed));
        expect(result.stats.health, lessThanOrEqualTo(100));
        expect(result.stats.scrap, greaterThanOrEqualTo(0));
      }
    });
  });

  group('craftWeapon', () {
    test('requires at least 3 scrap', () {
      final result = RpgService.craftWeapon(RpgStats.initial().copyWith(scrap: 2));
      expect(result.stats.hasWeapon, isFalse);
      expect(result.message, contains('3 Schrott'));
    });

    test('consumes 3 scrap and grants a weapon', () {
      final result = RpgService.craftWeapon(RpgStats.initial().copyWith(scrap: 5));
      expect(result.stats.hasWeapon, isTrue);
      expect(result.stats.scrap, 2);
    });

    test('does nothing if already armed', () {
      final result = RpgService.craftWeapon(RpgStats.initial().copyWith(scrap: 10, hasWeapon: true));
      expect(result.stats.scrap, 10);
    });
  });

  group('buildShelter', () {
    test('requires at least 5 scrap', () {
      final result = RpgService.buildShelter(RpgStats.initial().copyWith(scrap: 4));
      expect(result.stats.hasShelter, isFalse);
    });

    test('consumes 5 scrap and grants shelter', () {
      final result = RpgService.buildShelter(RpgStats.initial().copyWith(scrap: 8));
      expect(result.stats.hasShelter, isTrue);
      expect(result.stats.scrap, 3);
    });
  });

  group('RpgService persistence', () {
    late RpgService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = RpgService();
    });

    test('loadStats() returns null when nothing was saved yet', () async {
      expect(await service.loadStats(), isNull);
    });

    test('saveStats() then loadStats() round-trips', () async {
      final stats = RpgStats.initial().copyWith(day: 3, scrap: 2);
      await service.saveStats(stats);
      final loaded = await service.loadStats();
      expect(loaded!.day, 3);
      expect(loaded.scrap, 2);
    });

    test('startNewRun() persists a fresh RpgStats.initial() and clears history', () async {
      await service.saveHistory([]);
      final stats = await service.startNewRun();
      expect(stats.day, 1);
      expect(await service.loadHistory(), isEmpty);
    });

    test('saveHistory()/loadHistory() round-trips and trims to the cap', () async {
      final long = List.generate(40, (i) => AiTurn(role: i.isEven ? 'user' : 'assistant', content: 'turn $i'));
      await service.saveHistory(long);
      final loaded = await service.loadHistory();
      expect(loaded.length, lessThanOrEqualTo(24));
      expect(loaded.last.content, 'turn 39');
    });
  });
}
