import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/challenge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ChallengeService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ChallengeService();
  });

  test('current() returns a non-empty challenge', () async {
    final challenge = await service.current(now: DateTime(2026, 1, 1));
    expect(challenge.text, isNotEmpty);
  });

  test('current() returns the same challenge for the same day', () async {
    final first = await service.current(now: DateTime(2026, 1, 1, 8));
    final second = await service.current(now: DateTime(2026, 1, 1, 20));
    expect(first.id, second.id);
  });

  test('current() rolls over to a new challenge on a new day', () async {
    final results = <String>{};
    for (var day = 1; day <= 15; day++) {
      final challenge = await service.current(now: DateTime(2026, 1, day));
      results.add(challenge.id);
    }
    // With 12 challenges and 15 distinct days, expect more than one distinct
    // challenge id to show up (not a strict guarantee for every seed, but a
    // reasonable sanity check that rollover actually changes the pick).
    expect(results.length, greaterThan(1));
  });

  test('isCompletedToday() is false before marking, true after', () async {
    final now = DateTime(2026, 1, 1);
    expect(await service.isCompletedToday(now: now), isFalse);
    await service.markCompleted(now: now);
    expect(await service.isCompletedToday(now: now), isTrue);
  });

  test('markCompleted() is idempotent within the same day', () async {
    final now = DateTime(2026, 1, 1);
    await service.markCompleted(now: now);
    await service.markCompleted(now: now);
    expect(await service.isCompletedToday(now: now), isTrue);
  });

  test('completion does not carry over to a new day', () async {
    await service.markCompleted(now: DateTime(2026, 1, 1));
    expect(await service.isCompletedToday(now: DateTime(2026, 1, 2)), isFalse);
  });
}
