import 'dart:async';

import 'package:vosk_flutter_fixed/vosk_flutter.dart';

const _modelUrl = 'https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip';
const _sampleRate = 16000;

/// Always-on "Jarvis" wake-word detection via Vosk — an offline, free,
/// account-free speech recognizer (unlike Picovoice Porcupine, which this
/// replaces after Picovoice discontinued free personal-use access). A
/// grammar-constrained recognizer (only "jarvis" plus a catch-all) keeps
/// this lightweight, similar in spirit to a dedicated wake-word engine,
/// rather than running full open-vocabulary transcription.
///
/// This only runs the *detection* — bringing the app to the foreground and
/// starting to actually listen for a command happens in
/// [WakeWordTaskHandler], which hosts this service inside a
/// flutter_foreground_task background isolate so it keeps running even
/// while the app is closed.
class WakeWordService {
  SpeechService? _speechService;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _resultSub;
  bool _triggered = false;

  bool get isListening => _speechService != null;

  /// Downloads the German speech model on first use (cached afterwards)
  /// and starts listening. [onWakeWord] fires whenever "jarvis" is
  /// detected. Returns a human-readable error, or null on success.
  Future<String?> start({required void Function() onWakeWord}) async {
    await stop();
    try {
      final vosk = VoskFlutterPlugin.instance();
      final modelPath = await ModelLoader().loadFromNetwork(_modelUrl);
      final model = await vosk.createModel(modelPath);
      final recognizer = await vosk.createRecognizer(
        model: model,
        sampleRate: _sampleRate,
        grammar: ['jarvis', '[unk]'],
      );
      _speechService = await vosk.initSpeechService(recognizer);

      // onPartial fires repeatedly per utterance — without the _triggered
      // guard "jarvis" could fire more than once for one utterance.
      // onResult marks the end of an utterance (a pause), resetting the
      // guard for the next one.
      _partialSub = _speechService!.onPartial().listen((partial) {
        if (!_triggered && partial.toLowerCase().contains('jarvis')) {
          _triggered = true;
          onWakeWord();
        }
      });
      _resultSub = _speechService!.onResult().listen((_) => _triggered = false);

      await _speechService!.start();
      return null;
    } catch (e) {
      await stop();
      return 'Weckwort-Erkennung konnte nicht gestartet werden: $e';
    }
  }

  Future<void> stop() async {
    await _partialSub?.cancel();
    _partialSub = null;
    await _resultSub?.cancel();
    _resultSub = null;
    await _speechService?.stop();
    _speechService = null;
    _triggered = false;
  }
}
