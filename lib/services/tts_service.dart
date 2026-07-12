import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Wraps text-to-speech playback so JARVIS can talk back, mirroring the
/// pyttsx3 voice output used in the original desktop assistant.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Speaks and resolves once playback has actually finished (or was
  /// stopped/errored), so callers can chain an action — like reopening the
  /// microphone for the next turn of a call — right after JARVIS stops talking.
  Future<void> speakAndWait(String text) async {
    await _ensureInit();
    await _tts.stop();
    final completer = Completer<void>();
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setCancelHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setErrorHandler((_) {
      if (!completer.isCompleted) completer.complete();
    });
    await _tts.speak(text);
    await completer.future;
  }

  Future<void> stop() => _tts.stop();
}
