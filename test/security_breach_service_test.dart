import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/security_breach_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deterministic stand-in for dart:math Random — Random is abstract with
/// only these three methods, so it can be implemented directly for tests
/// that need a fixed roll instead of a real one.
class _FixedRandom implements Random {
  _FixedRandom({this.doubleValue = 0.0, this.intValue = 0});
  final double doubleValue;
  final int intValue;

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => intValue;

  @override
  bool nextBool() => false;
}

void main() {
  group('SecurityBreachChallenge.isCorrect', () {
    final challenge = SecurityBreachService.challenges.firstWhere((c) => c.id == 'sql_injection');

    test('matches the correct option letter, case-insensitively', () {
      expect(challenge.isCorrect('b'), isTrue);
      expect(challenge.isCorrect('B'), isTrue);
    });

    test('matches a free-form sentence containing the keyword phrase', () {
      expect(challenge.isCorrect('das ist eine sql injection'), isTrue);
    });

    test('rejects a wrong option', () {
      expect(challenge.isCorrect('a'), isFalse);
      expect(challenge.isCorrect('buffer overflow'), isFalse);
    });

    test('rejects an empty or whitespace-only answer', () {
      expect(challenge.isCorrect(''), isFalse);
      expect(challenge.isCorrect('   '), isFalse);
    });

    test('does not false-positive-match a short option letter as a mere substring', () {
      final backdoorChallenge = SecurityBreachService.challenges.firstWhere((c) => c.id == 'backdoor_port');
      // "a" isn't accepted for this challenge (correct answer is "c"/4444);
      // a sentence that merely contains the letter "a" somewhere must not count.
      expect(backdoorChallenge.isCorrect('das weiß ich leider nicht genau'), isFalse);
    });
  });

  group('SecurityBreachService.maybeTriggerOnOpen', () {
    late SecurityBreachService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SecurityBreachService();
    });

    test('does not trigger when the random roll is above the probability threshold', () async {
      final result = await service.maybeTriggerOnOpen(
        now: DateTime(2026, 1, 1),
        random: _FixedRandom(doubleValue: 0.99),
      );
      expect(result, isNull);
    });

    test('triggers when the random roll is below the probability threshold', () async {
      final result = await service.maybeTriggerOnOpen(
        now: DateTime(2026, 1, 1),
        random: _FixedRandom(doubleValue: 0.0, intValue: 2),
      );
      expect(result, SecurityBreachService.challenges[2]);
    });

    test('does not trigger twice on the same day even with a favorable roll', () async {
      final first = await service.maybeTriggerOnOpen(now: DateTime(2026, 1, 1), random: _FixedRandom());
      expect(first, isNotNull);

      final second = await service.maybeTriggerOnOpen(now: DateTime(2026, 1, 1, 23, 59), random: _FixedRandom());
      expect(second, isNull);
    });

    test('can trigger again on a new day', () async {
      final first = await service.maybeTriggerOnOpen(now: DateTime(2026, 1, 1), random: _FixedRandom());
      expect(first, isNotNull);

      final second = await service.maybeTriggerOnOpen(now: DateTime(2026, 1, 2), random: _FixedRandom());
      expect(second, isNotNull);
    });
  });

  group('SecurityBreachService.triggerOnDemand', () {
    test('always returns a challenge regardless of probability or the daily gate', () {
      final service = SecurityBreachService();
      final challenge = service.triggerOnDemand(random: _FixedRandom(doubleValue: 0.99, intValue: 1));
      expect(challenge, SecurityBreachService.challenges[1]);
    });
  });
}
