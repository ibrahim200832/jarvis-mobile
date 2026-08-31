import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/background_task_service.dart';

void main() {
  test('task names are distinct and non-empty', () {
    expect(BackgroundTaskNames.rssFeedCheck, isNotEmpty);
    expect(BackgroundTaskNames.weeklyBackupExport, isNotEmpty);
    expect(BackgroundTaskNames.rssFeedCheck, isNot(BackgroundTaskNames.weeklyBackupExport));
  });

  group('dispatchBackgroundTask', () {
    test('reports success for the RSS feed check task', () async {
      expect(await dispatchBackgroundTask(BackgroundTaskNames.rssFeedCheck, null), isTrue);
    });

    test('reports success for the weekly backup export task', () async {
      expect(await dispatchBackgroundTask(BackgroundTaskNames.weeklyBackupExport, null), isTrue);
    });

    test('defaults to success for an unknown task name instead of throwing', () async {
      expect(await dispatchBackgroundTask('some_future_task', null), isTrue);
    });
  });
}
