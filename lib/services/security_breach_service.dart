import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// One fixed "firewall defense" mini-challenge: a short breach scenario plus
/// a small set of accepted (normalized) answers. Entirely local and
/// deterministic — no AI call, so it's fully offline and unit-testable.
class SecurityBreachChallenge {
  final String id;
  final String prompt;
  final List<String> acceptedAnswers;
  final String explanation;

  const SecurityBreachChallenge({
    required this.id,
    required this.prompt,
    required this.acceptedAnswers,
    required this.explanation,
  });

  static String _normalize(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß \-]'), '');

  /// True if [answer] matches one of the accepted answers — either as a
  /// standalone token (for short options like "b") or as a contained phrase
  /// (for multi-word keywords like "sql injection"), so free-form replies
  /// like "ich glaube b" or "das ist eine sql injection" both count.
  bool isCorrect(String answer) {
    final normalized = _normalize(answer);
    if (normalized.isEmpty) return false;
    final tokens = normalized.split(RegExp(r'\s+'));
    for (final accepted in acceptedAnswers) {
      if (accepted.contains(' ')) {
        if (normalized.contains(accepted)) return true;
      } else if (tokens.contains(accepted)) {
        return true;
      }
    }
    return false;
  }
}

/// Occasional, opt-out-able "security breach" mini-game: JARVIS shows a
/// short, fixed multiple-choice defense scenario in chat, and the next
/// message is treated as the answer (see CommandRouter._handleBreachAnswer).
/// Success awards XP via GamificationService. Purely local flavor text over a
/// fixed question bank — no AI call, no real system is ever touched.
class SecurityBreachService {
  static const _lastTriggerDayKey = 'security_breach_last_trigger_day';

  /// Chance per app open (once the once-per-day gate below already allows
  /// it) that a breach challenge fires — kept low so it stays a rare
  /// surprise, not a daily interruption.
  static const triggerProbability = 0.2;

  static const List<SecurityBreachChallenge> challenges = [
    SecurityBreachChallenge(
      id: 'backdoor_port',
      prompt: '🚨 SICHERHEITSBRUCH ERKANNT 🚨\n'
          'Ein Portscan trifft gleichzeitig auf Port 22 (SSH), 80 (HTTP) und 4444 (bekannter Backdoor-Port). '
          'Welchen blockierst du sofort?\nA) 22\nB) 80\nC) 4444',
      acceptedAnswers: ['c', '4444', 'backdoor'],
      explanation:
          'Port 4444 ist ein klassischer Backdoor-/Metasploit-Standardport — SSH und HTTP allein sind kein Alarmsignal.',
    ),
    SecurityBreachChallenge(
      id: 'sql_injection',
      prompt: '🚨 SICHERHEITSBRUCH ERKANNT 🚨\n'
          'Eingehende Anfrage im Log: "\' OR \'1\'=\'1\' --". Um welche Angriffsart handelt es sich?\n'
          'A) Cross-Site-Scripting\nB) SQL-Injection\nC) Buffer Overflow',
      acceptedAnswers: ['b', 'sql-injection', 'sql injection', 'sqlinjection'],
      explanation: 'Klassisches SQL-Injection-Muster: die Bedingung wird immer wahr, um eine Anmeldeprüfung zu umgehen.',
    ),
    SecurityBreachChallenge(
      id: 'phishing_mail',
      prompt: '🚨 SICHERHEITSBRUCH ERKANNT 🚨\n'
          'Eine E-Mail von "support@paypa1.com" fordert dich auf, sofort dein Passwort einzugeben. Was tust du?\n'
          'A) Link anklicken und Passwort eingeben\nB) Löschen/melden, Link ignorieren\nC) Antworten und nachfragen',
      acceptedAnswers: ['b', 'löschen', 'melden', 'ignorieren'],
      explanation: 'Die "1" statt "l" in "paypa1.com" ist ein klassischer Phishing-Trick — nie auf verdächtige Links klicken.',
    ),
    SecurityBreachChallenge(
      id: 'weak_password',
      prompt: '🚨 SICHERHEITSBRUCH ERKANNT 🚨\n'
          'Ein Login-Versuch mit dem Passwort "123456" war erfolgreich. Wichtigste Sofortmaßnahme?\n'
          'A) Nichts tun, war nur ein Test\nB) Passwort ändern und 2FA aktivieren\nC) Systemprotokoll löschen',
      acceptedAnswers: ['b', 'passwort ändern', 'passwort andern', '2fa'],
      explanation: 'Ein triviales Passwort ist die häufigste Einfallstür — sofort ändern und Zwei-Faktor-Authentifizierung aktivieren.',
    ),
    SecurityBreachChallenge(
      id: 'ddos',
      prompt: '🚨 SICHERHEITSBRUCH ERKANNT 🚨\n'
          'Tausende Anfragen aus derselben IP-Range fluten den Server gleichzeitig. Was liegt am ehesten vor?\n'
          'A) DDoS-Angriff\nB) Normaler Traffic-Anstieg\nC) Softwarefehler',
      acceptedAnswers: ['a', 'ddos'],
      explanation: 'Eine plötzliche Flut gleichartiger Anfragen aus einer IP-Range ist das Lehrbuch-Muster eines (D)DoS-Angriffs.',
    ),
  ];

  static int _dayIndex(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  SecurityBreachChallenge randomChallenge({Random? random}) {
    final rng = random ?? Random();
    return challenges[rng.nextInt(challenges.length)];
  }

  Future<bool> _alreadyTriggeredToday(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastTriggerDayKey) == _dayIndex(now);
  }

  Future<void> _markTriggeredToday(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTriggerDayKey, _dayIndex(now));
  }

  /// Called once per app open. Rolls the dice only if no breach has already
  /// fired today; on a hit, marks today as used and returns a random
  /// challenge — otherwise null. The caller (home_screen.dart) is
  /// responsible for checking the Einstellungen opt-out first.
  Future<SecurityBreachChallenge?> maybeTriggerOnOpen({DateTime? now, Random? random}) async {
    final effectiveNow = now ?? DateTime.now();
    if (await _alreadyTriggeredToday(effectiveNow)) return null;
    final rng = random ?? Random();
    if (rng.nextDouble() >= triggerProbability) return null;
    await _markTriggeredToday(effectiveNow);
    return randomChallenge(random: rng);
  }

  /// Explicit on-demand trigger (chat command) — bypasses the daily gate and
  /// probability roll entirely, since the user asked for it directly.
  SecurityBreachChallenge triggerOnDemand({Random? random}) => randomChallenge(random: random);
}
