import 'dart:math';

/// Local joke bank, replacing the `pyjokes` dependency from the desktop app
/// (no network needed, works fully offline).
class JokeService {
  static const _jokes = [
    'Warum ist der Informatiker beim Autofahren so entspannt? Er hat immer ein Backup.',
    'Es gibt 10 Arten von Menschen: die, die Binär verstehen, und die, die es nicht verstehen.',
    'Ein SQL-Query kommt in eine Bar, geht zu zwei Tischen und fragt: "Darf ich mich JOINen?"',
    'Warum reden Programmierer nicht gerne? Weil sie lieber committen als sich zu unterhalten.',
    '99 kleine Bugs in der Software, 99 kleine Bugs. Einen behoben, neu kompiliert - 127 kleine Bugs in der Software.',
    'Wie viele Programmierer braucht man, um eine Glühbirne zu wechseln? Keinen, das ist ein Hardware-Problem.',
    'Warum benutzen Programmierer gerne dunkle Themes? Weil Licht Bugs anzieht.',
  ];

  final _rng = Random();

  String randomJoke() => _jokes[_rng.nextInt(_jokes.length)];
}
