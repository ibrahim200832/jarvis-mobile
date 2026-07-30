import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/calculator_service.dart';

void main() {
  group('CalculatorService.looksLikeExpression', () {
    test('accepts spoken operator words', () {
      expect(CalculatorService.looksLikeExpression('5 plus 3'), isTrue);
      expect(CalculatorService.looksLikeExpression('12 mal 7'), isTrue);
    });

    test('rejects prose', () {
      expect(CalculatorService.looksLikeExpression('Albert Einstein'), isFalse);
      expect(CalculatorService.looksLikeExpression('photosynthese'), isFalse);
    });
  });

  group('CalculatorService.evaluate', () {
    test('basic operators, including German words', () {
      expect(CalculatorService.evaluate('5 plus 3'), 8.0);
      expect(CalculatorService.evaluate('12 mal 7'), 84.0);
      expect(CalculatorService.evaluate('10 durch 4'), 2.5);
      expect(CalculatorService.evaluate('2 hoch 10'), 1024.0);
    });

    test('operator precedence and parentheses', () {
      expect(CalculatorService.evaluate('2 + 3 * 4'), 14.0);
      expect(CalculatorService.evaluate('(2 + 3) * 4'), 20.0);
    });

    test('unary minus and German decimal comma', () {
      expect(CalculatorService.evaluate('-5 + 2'), -3.0);
      expect(CalculatorService.evaluate('7,5 plus 2,5'), 10.0);
    });

    test('invalid input returns null instead of throwing', () {
      expect(CalculatorService.evaluate('10 / 0'), isNull);
      expect(CalculatorService.evaluate('5 + '), isNull);
      expect(CalculatorService.evaluate('(1 + 2'), isNull);
    });
  });

  group('CalculatorService.format', () {
    test('drops trailing .0 for whole numbers', () {
      expect(CalculatorService.format(8.0), '8');
    });

    test('keeps decimals otherwise', () {
      expect(CalculatorService.format(2.5), '2.5');
    });
  });
}
