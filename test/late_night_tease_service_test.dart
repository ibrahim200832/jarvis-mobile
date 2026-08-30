import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/late_night_tease_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LateNightTeaseService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = LateNightTeaseService();
  });

  group('isLateNight', () {
    test('23:30 is late night', () {
      expect(service.isLateNight(DateTime(2026, 1, 1, 23, 30)), isTrue);
    });

    test('02:00 is late night', () {
      expect(service.isLateNight(DateTime(2026, 1, 1, 2, 0)), isTrue);
    });

    test('14:00 is not late night', () {
      expect(service.isLateNight(DateTime(2026, 1, 1, 14, 0)), isFalse);
    });

    test('05:00 is not late night (boundary)', () {
      expect(service.isLateNight(DateTime(2026, 1, 1, 5, 0)), isFalse);
    });
  });

  group('looksLikeCoding', () {
    test('detects German/English coding keywords', () {
      expect(service.looksLikeCoding('ich schreibe gerade code'), isTrue);
      expect(service.looksLikeCoding('flutter widget bauen'), isTrue);
      expect(service.looksLikeCoding('git commit machen'), isTrue);
    });

    test('does not false-positive on unrelated text', () {
      expect(service.looksLikeCoding('wie ist das wetter'), isFalse);
    });
  });

  group('maybeTease', () {
    test('returns null when not late night', () async {
      final result = await service.maybeTease('standard', 'ich programmiere', now: DateTime(2026, 1, 1, 14, 0));
      expect(result, isNull);
    });

    test('returns null when text does not look like coding', () async {
      final result = await service.maybeTease('standard', 'wie spät ist es', now: DateTime(2026, 1, 1, 23, 30));
      expect(result, isNull);
    });

    test('returns a tease when late night + coding text', () async {
      final result = await service.maybeTease('standard', 'ich debugge einen bug', now: DateTime(2026, 1, 1, 23, 30));
      expect(result, isNotNull);
    });

    test('only teases once per continuous night', () async {
      final first = await service.maybeTease('standard', 'code schreiben', now: DateTime(2026, 1, 1, 23, 30));
      final second = await service.maybeTease('standard', 'code schreiben', now: DateTime(2026, 1, 2, 2, 0));
      expect(first, isNotNull);
      expect(second, isNull, reason: '00:00-04:59 counts as part of the previous night');
    });

    test('teases again on a later, different night', () async {
      final first = await service.maybeTease('standard', 'code schreiben', now: DateTime(2026, 1, 1, 23, 30));
      final second = await service.maybeTease('standard', 'code schreiben', now: DateTime(2026, 1, 2, 23, 30));
      expect(first, isNotNull);
      expect(second, isNotNull);
    });

    test('returns the persona-specific line', () async {
      final result = await service.maybeTease(
        'drill_sergeant',
        'commit gemacht',
        now: DateTime(2026, 1, 1, 23, 30),
      );
      expect(result, contains('SOLDAT'));
    });

    test('falls back to standard line for an unknown persona', () async {
      final result = await service.maybeTease('unknown', 'commit gemacht', now: DateTime(2026, 1, 1, 23, 30));
      expect(result, isNotNull);
    });
  });
}
