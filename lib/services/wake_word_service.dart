import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

/// Always-on "Jarvis" wake-word detection via Picovoice Porcupine — a
/// purpose-built, offline, low-power keyword spotter (unlike
/// [SpeechService], which uses the OS's full speech recognizer and isn't
/// meant to run continuously). "Jarvis" is one of Porcupine's built-in
/// keywords, so no custom model/training is needed, only a free Picovoice
/// AccessKey (see README, Abschnitt "Weckwort ,Jarvis'").
///
/// This only runs the *detection* — bringing the app to the foreground and
/// starting to actually listen for a command happens in
/// [WakeWordTaskHandler], which hosts this service inside a
/// flutter_foreground_task background isolate so it keeps running even
/// while the app is closed.
class WakeWordService {
  PorcupineManager? _manager;

  bool get isListening => _manager != null;

  /// Starts listening for "Jarvis". [onWakeWord] fires (on Porcupine's own
  /// thread) whenever the keyword is detected. Returns a human-readable
  /// error, or null on success.
  Future<String?> start({required String accessKey, required void Function() onWakeWord}) async {
    if (accessKey.trim().isEmpty) return 'Kein Picovoice-AccessKey in den Einstellungen hinterlegt.';
    await stop();
    try {
      _manager = await PorcupineManager.fromBuiltInKeywords(
        accessKey.trim(),
        [BuiltInKeyword.JARVIS],
        (_) => onWakeWord(),
        errorCallback: (_) {},
      );
      await _manager!.start();
      return null;
    } on PorcupineException catch (e) {
      _manager = null;
      return 'Weckwort-Erkennung konnte nicht gestartet werden: ${e.message}';
    }
  }

  Future<void> stop() async {
    await _manager?.stop();
    await _manager?.delete();
    _manager = null;
  }
}
