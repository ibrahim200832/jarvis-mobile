import 'dart:async';

/// One running countdown, e.g. started via "timer für 5 minuten" or
/// "erinnere mich in 10 minuten an die wäsche".
class ActiveTimer {
  ActiveTimer(this.id, this.label, this.startedAt, this.duration);

  final String id;
  final String label;
  final DateTime startedAt;
  final Duration duration;

  Duration get remaining {
    final left = duration - DateTime.now().difference(startedAt);
    return left.isNegative ? Duration.zero : left;
  }
}

/// A duration (and optional label) parsed out of spoken/typed text, e.g.
/// "10 minuten an die wäsche" -> 10 minutes, label "die wäsche".
class ParsedTimer {
  ParsedTimer(this.duration, this.label);

  final Duration duration;
  final String? label;
}

/// In-app timers/reminders. Deliberately simple (no OS-level notifications,
/// no new dependency): timers only fire while the app is running, announced
/// via [onFire] — the UI hooks this up to speak the message and add it to
/// the chat, the same way it already does for every other JARVIS reply.
class TimerService {
  final _active = <String, ActiveTimer>{};
  final _handles = <String, Timer>{};
  int _counter = 0;

  /// Called (with a human-readable message) whenever a timer fires.
  void Function(String message)? onFire;

  ActiveTimer start(Duration duration, {String? label}) {
    final id = 't${_counter++}';
    final name = (label == null || label.trim().isEmpty)
        ? 'Timer'
        : label.trim();
    final active = ActiveTimer(id, name, DateTime.now(), duration);
    _active[id] = active;
    _handles[id] = Timer(duration, () {
      _active.remove(id);
      _handles.remove(id);
      onFire?.call('⏰ „$name" ist abgelaufen!');
    });
    return active;
  }

  List<ActiveTimer> list() => _active.values.toList(growable: false);

  /// Cancels every running timer and returns how many were cancelled.
  int cancelAll() {
    final count = _handles.length;
    for (final timer in _handles.values) {
      timer.cancel();
    }
    _handles.clear();
    _active.clear();
    return count;
  }

  static final _durationPattern = RegExp(
    r'(\d+)\s*(sekunden?|sek\.?|minuten?|min\.?|stunden?|std\.?|h\b)',
  );

  /// Extracts a duration (and optional label after " an ") from free text,
  /// or null if no recognizable time span is present.
  static ParsedTimer? parse(String input) {
    final match = _durationPattern.firstMatch(input.toLowerCase());
    if (match == null) return null;

    final amount = int.parse(match.group(1)!);
    final unit = match.group(2)!;
    final Duration duration;
    if (unit.startsWith('sek')) {
      duration = Duration(seconds: amount);
    } else if (unit.startsWith('stu') ||
        unit.startsWith('std') ||
        unit == 'h') {
      duration = Duration(hours: amount);
    } else {
      duration = Duration(minutes: amount);
    }

    final anIndex = input.toLowerCase().indexOf(' an ');
    final label = anIndex == -1 ? null : input.substring(anIndex + 4).trim();
    return ParsedTimer(duration, label);
  }

  /// Formats a duration the way a person would say it, e.g. "5 Min 30 Sek".
  static String describe(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final parts = <String>[
      if (hours > 0) '$hours Std',
      if (minutes > 0) '$minutes Min',
      if (hours == 0 && minutes == 0) '$seconds Sek',
    ];
    return parts.join(' ');
  }
}
