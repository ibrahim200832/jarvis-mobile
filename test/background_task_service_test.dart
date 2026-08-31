import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/background_task_service.dart';
import 'package:jarvis_mobile/services/backup_export_service.dart';
import 'package:jarvis_mobile/services/notification_service.dart';
import 'package:jarvis_mobile/services/rss_feed_service.dart';

/// In-memory stand-ins so dispatchBackgroundTask's RSS branch can be
/// exercised without touching real dart:io/platform-channel plugins under
/// `flutter test` — same convention as command_router_test.dart's fakes.
class _FakeRssFeedService extends RssFeedService {
  List<RssItem> itemsToReturn = [];

  @override
  Future<List<RssItem>> checkForNewItems() async => itemsToReturn;
}

class _FakeBackupExportService extends BackupExportService {
  int exportCount = 0;

  @override
  Future<File> exportNow() async {
    exportCount++;
    final file = File('${Directory.systemTemp.path}/fake_dispatch_backup_test.bin');
    await file.writeAsBytes([0]);
    return file;
  }
}

class _FakeNotificationService extends NotificationService {
  int callCount = 0;
  String? lastTitle;
  String? lastBody;

  @override
  Future<void> showImmediateNotification({required int id, required String title, required String body}) async {
    callCount++;
    lastTitle = title;
    lastBody = body;
  }
}

void main() {
  test('task names are distinct and non-empty', () {
    expect(BackgroundTaskNames.rssFeedCheck, isNotEmpty);
    expect(BackgroundTaskNames.weeklyBackupExport, isNotEmpty);
    expect(BackgroundTaskNames.rssFeedCheck, isNot(BackgroundTaskNames.weeklyBackupExport));
  });

  group('dispatchBackgroundTask', () {
    test('the RSS feed check notifies when new items were found', () async {
      final feeds = _FakeRssFeedService()
        ..itemsToReturn = [RssItem(id: '1', title: 'Neue Meldung', link: 'https://example.com/1', feedTitle: 'Test-Feed')];
      final notifications = _FakeNotificationService();

      final result = await dispatchBackgroundTask(
        BackgroundTaskNames.rssFeedCheck,
        null,
        rssFeedService: feeds,
        notificationService: notifications,
      );

      expect(result, isTrue);
      expect(notifications.callCount, 1);
      expect(notifications.lastBody, 'Neue Meldung');
    });

    test('the RSS feed check stays quiet when there is nothing new', () async {
      final feeds = _FakeRssFeedService();
      final notifications = _FakeNotificationService();

      final result = await dispatchBackgroundTask(
        BackgroundTaskNames.rssFeedCheck,
        null,
        rssFeedService: feeds,
        notificationService: notifications,
      );

      expect(result, isTrue);
      expect(notifications.callCount, 0);
    });

    test('reports success for the weekly backup export task and runs the export', () async {
      final backup = _FakeBackupExportService();

      final result = await dispatchBackgroundTask(
        BackgroundTaskNames.weeklyBackupExport,
        null,
        backupExportService: backup,
      );

      expect(result, isTrue);
      expect(backup.exportCount, 1);
    });

    test('defaults to success for an unknown task name instead of throwing', () async {
      expect(await dispatchBackgroundTask('some_future_task', null), isTrue);
    });
  });
}
