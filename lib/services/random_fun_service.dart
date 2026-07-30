import 'dart:math';

/// Coin flips, dice rolls and random numbers — small, self-contained "fun"
/// commands with no setup or network needed.
class RandomFunService {
  final _rng = Random();

  String flipCoin() => _rng.nextBool() ? 'Kopf' : 'Zahl';

  /// Rolls a die with [sides] faces (default 6).
  int rollDice({int sides = 6}) => _rng.nextInt(sides) + 1;

  /// Random integer in the inclusive range [min, max]. Swaps the bounds if
  /// they were given in the wrong order.
  int randomInRange(int min, int max) {
    final low = min <= max ? min : max;
    final high = min <= max ? max : min;
    return low + _rng.nextInt(high - low + 1);
  }
}
