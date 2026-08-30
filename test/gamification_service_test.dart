import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/gamification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GamificationService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = GamificationService();
  });

  group('getEnergy / setSleepHours', () {
    test('defaults to a neutral 70 when nothing was ever reported', () async {
      expect(await service.getEnergy(), 70);
    });

    test('8 hours of sleep maps to full energy', () async {
      final energy = await service.setSleepHours(8, now: DateTime(2026, 1, 1));
      expect(energy, 100);
      expect(await service.getEnergy(now: DateTime(2026, 1, 1)), 100);
    });

    test('4 hours of sleep maps to half energy', () async {
      final energy = await service.setSleepHours(4, now: DateTime(2026, 1, 1));
      expect(energy, 50);
    });

    test('more than 8 hours still clamps at 100', () async {
      final energy = await service.setSleepHours(10, now: DateTime(2026, 1, 1));
      expect(energy, 100);
    });

    test('0 hours clamps at 0', () async {
      final energy = await service.setSleepHours(0, now: DateTime(2026, 1, 1));
      expect(energy, 0);
    });

    test('energy decays by energyDecayPerDay per elapsed day', () async {
      await service.setSleepHours(8, now: DateTime(2026, 1, 1));
      final nextDay = await service.getEnergy(now: DateTime(2026, 1, 2));
      expect(nextDay, 100 - GamificationService.energyDecayPerDay);
    });

    test('energy never decays below 0', () async {
      await service.setSleepHours(8, now: DateTime(2026, 1, 1));
      final farLater = await service.getEnergy(now: DateTime(2026, 2, 1));
      expect(farLater, 0);
    });

    test('same-day reads do not decay', () async {
      await service.setSleepHours(8, now: DateTime(2026, 1, 1, 7));
      final laterSameDay = await service.getEnergy(now: DateTime(2026, 1, 1, 22));
      expect(laterSameDay, 100);
    });
  });

  group('dashboardData', () {
    test('reflects current level/xp/rank', () async {
      await service.awardForNote();
      final data = await service.dashboardData();
      expect(data.xp, GamificationService.noteXp);
      expect(data.level, GamificationService.levelForXp(GamificationService.noteXp));
    });

    test('xpProgress is between 0 and 1', () async {
      await service.awardForNote();
      final data = await service.dashboardData();
      expect(data.xpProgress, greaterThanOrEqualTo(0.0));
      expect(data.xpProgress, lessThanOrEqualTo(1.0));
    });

    test('tacticalAdvice mentions low energy when energy is critical', () async {
      await service.setSleepHours(1, now: DateTime(2026, 1, 1));
      final data = await service.dashboardData(now: DateTime(2026, 1, 1));
      expect(data.tacticalAdvice, contains('Energie kritisch niedrig'));
    });

    test('tacticalAdvice does not mention energy when energy is high', () async {
      await service.setSleepHours(8, now: DateTime(2026, 1, 1));
      final data = await service.dashboardData(now: DateTime(2026, 1, 1));
      expect(data.tacticalAdvice, isNot(contains('Energie')));
    });

    test('locked and unlocked achievement lists partition all achievements', () async {
      final data = await service.dashboardData();
      expect(data.unlockedAchievementTitles, isEmpty);
      expect(data.lockedAchievementTitles, isNotEmpty);
    });

    test('unlocked achievements move from locked to unlocked after being earned', () async {
      await service.awardForNote();
      final data = await service.dashboardData();
      expect(data.unlockedAchievementTitles, contains('Erste Notiz'));
      expect(data.lockedAchievementTitles, isNot(contains('Erste Notiz')));
    });
  });
}
