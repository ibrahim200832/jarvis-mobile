import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Detects two accelerometer-based gestures for hands-free control: the
/// phone being flipped face-down (and back up), and being shaken.
///
/// Lives outside CommandRouter (like SpeechService/TtsService) since it's
/// live sensor plumbing driven by home_screen.dart's lifecycle, not a
/// dispatched chat command. The stream source is injectable so the
/// detection logic itself is unit-testable with synthetic event sequences,
/// without touching the real sensors_plus platform channel.
class MotionActionsService {
  MotionActionsService({Stream<AccelerometerEvent> Function()? streamFactory})
    : _streamFactory = streamFactory ?? accelerometerEventStream;

  final Stream<AccelerometerEvent> Function() _streamFactory;
  StreamSubscription<AccelerometerEvent>? _subscription;

  // Face-down detection: z-axis acceleration (including gravity) points
  // roughly opposite gravity when the screen faces down, so a strongly
  // negative z while the device is otherwise level ("flat") means
  // face-down. Hysteresis (different enter/exit thresholds) avoids
  // flickering while the phone is being turned through the boundary.
  static const _faceDownZThreshold = -8.5;
  static const _faceUpZThreshold = -4.0;
  static const _flatXyMagnitudeThreshold = 3.0;
  static const _faceDownSustain = Duration(milliseconds: 600);

  bool _isFaceDown = false;
  DateTime? _faceDownCandidateSince;

  // Shake detection: count how often the acceleration magnitude deviates
  // sharply from resting gravity (~9.8 m/s^2) within a short rolling
  // window - a single spike could just be picking the phone up, several
  // in quick succession is a shake. A cooldown after firing avoids
  // repeat-triggering on the same shake gesture.
  static const _shakeDeviationThreshold = 12.0;
  static const _shakeWindow = Duration(seconds: 1);
  static const _shakeMinCrossings = 3;
  static const _shakeCooldown = Duration(milliseconds: 1500);

  final List<DateTime> _shakeCrossings = [];
  DateTime? _lastShakeFiredAt;

  void start({
    required void Function() onFaceDown,
    required void Function() onFaceUp,
    required void Function() onShake,
  }) {
    _subscription?.cancel();
    _isFaceDown = false;
    _faceDownCandidateSince = null;
    _shakeCrossings.clear();
    _lastShakeFiredAt = null;
    _subscription = _streamFactory().listen((event) {
      _handleFaceDown(event, onFaceDown: onFaceDown, onFaceUp: onFaceUp);
      _handleShake(event, onShake: onShake);
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleFaceDown(
    AccelerometerEvent event, {
    required void Function() onFaceDown,
    required void Function() onFaceUp,
  }) {
    final isFlat = math.sqrt(event.x * event.x + event.y * event.y) < _flatXyMagnitudeThreshold;

    if (event.z < _faceDownZThreshold && isFlat) {
      if (_isFaceDown) return;
      _faceDownCandidateSince ??= event.timestamp;
      if (event.timestamp.difference(_faceDownCandidateSince!) >= _faceDownSustain) {
        _isFaceDown = true;
        onFaceDown();
      }
      return;
    }

    if (event.z > _faceUpZThreshold) {
      _faceDownCandidateSince = null;
      if (_isFaceDown) {
        _isFaceDown = false;
        onFaceUp();
      }
    }
    // Between the two thresholds: ambiguous/transitional reading, neither
    // confirm nor reset the candidate timer.
  }

  void _handleShake(AccelerometerEvent event, {required void Function() onShake}) {
    if (_lastShakeFiredAt != null && event.timestamp.difference(_lastShakeFiredAt!) < _shakeCooldown) {
      return;
    }

    final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final deviation = (magnitude - 9.8).abs();
    if (deviation <= _shakeDeviationThreshold) return;

    _shakeCrossings.add(event.timestamp);
    _shakeCrossings.removeWhere((t) => event.timestamp.difference(t) > _shakeWindow);

    if (_shakeCrossings.length >= _shakeMinCrossings) {
      _shakeCrossings.clear();
      _lastShakeFiredAt = event.timestamp;
      onShake();
    }
  }
}
