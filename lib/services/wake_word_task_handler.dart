import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'wake_word_service.dart';

/// Runs the "Jarvis" wake-word detection ([WakeWordService]) inside an
/// Android foreground service, via flutter_foreground_task — this is what
/// keeps it listening even while the JARVIS app itself is closed, same
/// idea as how "Ok Google"/"Hey Siri" work system-wide. iOS doesn't allow
/// this kind of always-on background microphone access, so the wake word
/// only works on Android (see README).
@pragma('vm:entry-point')
void wakeWordTaskEntryPoint() {
  FlutterForegroundTask.setTaskHandler(WakeWordTaskHandler());
}

class WakeWordTaskHandler extends TaskHandler {
  final _wakeWordService = WakeWordService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    final error = await _wakeWordService.start(
      onWakeWord: () {
        FlutterForegroundTask.sendDataToMain('wake_word_detected');
        FlutterForegroundTask.launchApp('/');
      },
    );
    // Starting the foreground service itself (see WakeWordManager) always
    // succeeds — this is the only place that knows whether Vosk actually
    // came up inside this isolate, so it's the only place that can surface
    // a failure instead of leaving a misleading "JARVIS hört zu" notification.
    if (error != null) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'JARVIS: Weckwort-Fehler',
        notificationText: error,
      );
      FlutterForegroundTask.sendDataToMain({'wake_word_error': error});
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _wakeWordService.stop();
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onReceiveData(Object data) {}
}
