import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures a short (~4s) raw mono PCM16 audio sample for voice-tone
/// analysis ("Emotionaler Begleiter" / echte Audio-Tonanalyse).
///
/// Deliberately a standalone, sequential capture — NOT run concurrently
/// with speech_to_text. Only one process typically owns the mic on Android
/// at a time, and this sandbox has no way to verify simultaneous access
/// behavior on real hardware, so callers (see home_screen.dart) must stop
/// any active speech_to_text session first and confirm mic permission via
/// the existing Permission.microphone.request() flow before calling this.
class MoodCaptureService {
  static const captureDuration = Duration(seconds: 4);
  static const sampleRate = 16000;

  // Lazy, not a field initializer, so a test Fake overriding
  // captureSample() never touches the real record platform channel — same
  // pattern as SoundboardService's AudioPlayer.
  AudioRecorder? _recorder;
  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();

  /// Returns raw int16 mono samples at [sampleRate], or null on any
  /// capture failure (denied permission, plugin error, empty stream).
  Future<Int16List?> captureSample() async {
    try {
      final stream = await _audioRecorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: sampleRate, numChannels: 1),
      );
      final bytes = <int>[];
      final subscription = stream.listen(bytes.addAll);
      await Future<void>.delayed(captureDuration);
      await subscription.cancel();
      await _audioRecorder.stop();

      if (bytes.isEmpty) return null;
      final byteData = Uint8List.fromList(bytes);
      final usableLength = byteData.length - (byteData.length % 2);
      if (usableLength == 0) return null;
      return Int16List.sublistView(byteData, 0, usableLength);
    } catch (_) {
      return null;
    }
  }
}
