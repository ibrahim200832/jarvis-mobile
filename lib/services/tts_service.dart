import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Wraps text-to-speech playback so JARVIS can talk back, mirroring the
/// pyttsx3 voice output used in the original desktop assistant.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  double _pitch = 1.0;
  double _speechRate = 0.5;
  String? _voiceName;
  String? _voiceLocale;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    if (_voiceName != null && _voiceLocale != null) {
      await _tts.setVoice({'name': _voiceName!, 'locale': _voiceLocale!});
    }
    _initialized = true;
  }

  /// The German system voices available on this device, so the user can
  /// pick a different one in Einstellungen. Falls back to an empty list on
  /// platforms that can't enumerate voices instead of throwing.
  Future<List<Map<String, String>>> getGermanVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return [];
      final voices = raw
          .whereType<Map>()
          .map((v) => v.map((key, value) => MapEntry(key.toString(), value.toString())))
          .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('de'))
          .toList()
        ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      return voices;
    } catch (_) {
      return [];
    }
  }

  /// Applies a chosen voice + pitch/speech rate. If TTS has already spoken
  /// once (already initialized), the change is applied live so a "Testen"
  /// preview in Einstellungen hears it immediately; otherwise it's picked up
  /// on the next _ensureInit().
  Future<void> applyVoiceSettings({
    String? voiceName,
    String? voiceLocale,
    required double pitch,
    required double speechRate,
  }) async {
    _voiceName = voiceName;
    _voiceLocale = voiceLocale;
    _pitch = pitch;
    _speechRate = speechRate;
    if (!_initialized) return;
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(speechRate);
    if (voiceName != null && voiceLocale != null) {
      await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
    }
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
