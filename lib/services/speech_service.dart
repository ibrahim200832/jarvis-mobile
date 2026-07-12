import 'package:speech_to_text/speech_to_text.dart';

/// Wraps on-device speech recognition, replacing the `SpeechRecognition` +
/// `PyAudio` microphone listening loop from the desktop JARVIS.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    _available = await _stt.initialize();
    return _available;
  }

  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'de_DE',
  }) async {
    if (!_available) {
      final ok = await init();
      if (!ok) return;
    }
    await _stt.listen(
      listenOptions: SpeechListenOptions(localeId: localeId, partialResults: true),
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();
}
