import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/notification_hub_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('isSupported is false on a non-Android platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(NotificationHubService().isSupported, isFalse);
  });

  test('every method degrades gracefully instead of throwing when unsupported', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final hub = NotificationHubService();

    expect(await hub.isListenerEnabled(), isFalse);
    await hub.openListenerSettings();
    await hub.setCaptureEnabled(true);
    expect(await hub.getCaptured(), isEmpty);
    await hub.clearCaptured();
  });

  test('degrades gracefully (no throw) on Android too, when the native side is unavailable', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // No MethodChannel mock is registered in this test environment, so the
    // underlying platform call fails — every method must catch that and
    // fall back to its safe default rather than letting the exception
    // propagate, same convention as AppIntegrityService.
    final hub = NotificationHubService();

    expect(hub.isSupported, isTrue);
    expect(await hub.isListenerEnabled(), isFalse);
    await hub.openListenerSettings();
    await hub.setCaptureEnabled(true);
    expect(await hub.getCaptured(), isEmpty);
    await hub.clearCaptured();
  });

  group('buildRuleBasedDigest', () {
    test('reports no notifications for an empty list', () {
      expect(NotificationHubService().buildRuleBasedDigest([]), 'Keine neuen Benachrichtigungen.');
    });

    test('groups by app and counts entries', () {
      final items = [
        CapturedNotification(
          packageName: 'com.whatsapp',
          title: 'Anna',
          text: 'Hey, bist du da?',
          postedAt: DateTime(2026, 1, 1, 10, 0),
        ),
        CapturedNotification(
          packageName: 'com.whatsapp',
          title: 'Familie',
          text: 'Wer bringt den Kuchen mit?',
          postedAt: DateTime(2026, 1, 1, 10, 5),
        ),
        CapturedNotification(
          packageName: 'com.google.android.gm',
          title: 'Rechnung',
          text: 'Deine Rechnung ist da.',
          postedAt: DateTime(2026, 1, 1, 9, 0),
        ),
      ];

      final digest = NotificationHubService().buildRuleBasedDigest(items);

      expect(digest, contains('Whatsapp (2)'));
      expect(digest, contains('Gm (1)'));
      // Shows the most recent preview per app.
      expect(digest, contains('Wer bringt den Kuchen mit?'));
    });

    test('truncates a long preview text', () {
      final longText = 'x' * 100;
      final items = [
        CapturedNotification(packageName: 'com.example.app', title: 'Titel', text: longText, postedAt: DateTime(2026, 1, 1)),
      ];

      final digest = NotificationHubService().buildRuleBasedDigest(items);

      expect(digest, contains('…'));
      expect(digest.length, lessThan(longText.length + 20));
    });
  });
}
