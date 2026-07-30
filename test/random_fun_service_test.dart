import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/random_fun_service.dart';

void main() {
  final fun = RandomFunService();

  test('flipCoin only returns Kopf or Zahl', () {
    for (var i = 0; i < 50; i++) {
      expect(['Kopf', 'Zahl'], contains(fun.flipCoin()));
    }
  });

  test('rollDice defaults to a 6-sided die', () {
    for (var i = 0; i < 50; i++) {
      final roll = fun.rollDice();
      expect(roll, inInclusiveRange(1, 6));
    }
  });

  test('rollDice supports a custom number of sides', () {
    for (var i = 0; i < 50; i++) {
      final roll = fun.rollDice(sides: 20);
      expect(roll, inInclusiveRange(1, 20));
    }
  });

  test('randomInRange stays within the given bounds', () {
    for (var i = 0; i < 50; i++) {
      final value = fun.randomInRange(5, 10);
      expect(value, inInclusiveRange(5, 10));
    }
  });

  test('randomInRange tolerates swapped bounds', () {
    for (var i = 0; i < 50; i++) {
      final value = fun.randomInRange(10, 5);
      expect(value, inInclusiveRange(5, 10));
    }
  });
}
