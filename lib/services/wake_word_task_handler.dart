import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wake_word_overlay.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final accessKey = prefs.getString('picovoice_access_key') ?? '';
    await _wakeWordService.start(
      accessKey: accessKey,
      onWakeWord: () async {
        FlutterForegroundTask.sendDataToMain('wake_word_detected');
        // Ist die App schon offen, reicht die stille "wake_word_detected"-
        // Meldung oben — das kleine Popup ist nur für den Fall gedacht, dass
        // die App gerade geschlossen/im Hintergrund ist.
        if (!await FlutterOverlayWindow.isActive() && await FlutterOverlayWindow.isPermissionGranted()) {
          await FlutterOverlayWindow.showOverlay(
            height: 70,
            width: 220,
            alignment: OverlayAlignment.topCenter,
            startPosition: const OverlayPosition(0, 80),
            flag: OverlayFlag.defaultFlag,
            positionGravity: PositionGravity.auto,
            overlayTitle: 'JARVIS',
            overlayContent: 'Ja, Meister?',
          );
        }
      },
    );
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
