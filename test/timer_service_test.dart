import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/timer_service.dart';

void main() {
  group('TimerService.parse', () {
    test('extracts minutes with no label', () {
      final parsed = TimerService.parse('5 minuten');
      expect(parsed?.duration, const Duration(minutes: 5));
      expect(parsed?.label, isNull);
    });

    test('extracts a label after " an "', () {
      final parsed = TimerService.parse('10 minuten an die wäsche');
      expect(parsed?.duration, const Duration(minutes: 10));
      expect(parsed?.label, 'die wäsche');
    });

    test('supports seconds and hours', () {
      expect(TimerService.parse('30 sekunden')?.duration, const Duration(seconds: 30));
      expect(TimerService.parse('2 stunden')?.duration, const Duration(hours: 2));
    });

    test('returns null when no duration is present', () {
      expect(TimerService.parse('mach mal was'), isNull);
    });
  });

  group('TimerService.describe', () {
    test('drops seconds once minutes are present', () {
      expect(TimerService.describe(const Duration(minutes: 5, seconds: 30)), '5 Min');
    });

    test('shows seconds under a minute', () {
      expect(TimerService.describe(const Duration(seconds: 45)), '45 Sek');
    });

    test('combines hours and minutes', () {
      expect(TimerService.describe(const Duration(hours: 1, minutes: 5)), '1 Std 5 Min');
    });
  });

  group('TimerService instance behavior', () {
    test('fires onFire once with the label after the duration elapses', () async {
      final timer = TimerService();
      final fired = <String>[];
      timer.onFire = fired.add;

      timer.start(const Duration(milliseconds: 20), label: 'Test');
      expect(timer.list().length, 1);

      await Future.delayed(const Duration(milliseconds: 60));

      expect(fired.length, 1);
      expect(fired.first, contains('Test'));
      expect(timer.list(), isEmpty);
    });

    test('cancelAll stops every running timer and reports the count', () {
      final timer = TimerService();
      timer.start(const Duration(seconds: 30));
      timer.start(const Duration(seconds: 30));

      expect(timer.cancelAll(), 2);
      expect(timer.list(), isEmpty);
    });
  });
}
