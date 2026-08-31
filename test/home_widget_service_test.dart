import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/home_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // kIsWeb can't be overridden at runtime in a VM test (it's a compile-time
  // constant, unlike defaultTargetPlatform) — these tests instead exercise
  // the "not web, but the native home_widget platform channel isn't mocked
  // here" path, which every method must also degrade gracefully on rather
  // than throw, same convention as AppIntegrityService/NotificationHubService.
  test('refresh() does not throw when the native side is unavailable', () async {
    await HomeWidgetService().refresh(statusLine: 'Online, 42ms', openTodoCount: 2);
  });

  test('requestPin() does not throw when the native side is unavailable', () async {
    await HomeWidgetService().requestPin();
  });

  test('isPinSupported() returns false rather than throwing', () async {
    expect(await HomeWidgetService().isPinSupported(), isFalse);
  });

  test('initiallyLaunchedFromWidget() returns null rather than throwing', () async {
    expect(await HomeWidgetService().initiallyLaunchedFromWidget(), isNull);
  });

  test('widgetClicks exposes a stream without throwing synchronously', () {
    expect(HomeWidgetService().widgetClicks, isA<Stream<Uri?>>());
  });
}
