import 'voice_tone_analyzer.dart';

/// Heuristic mood bucket derived from raw voice-tone metrics — explicitly
/// a heuristic, not a trained model or clinically validated measure.
enum VoiceMood { stressed, energetic, calm, low, neutral }

/// Buckets [VoiceToneMetrics] into a coarse mood guess. The numeric
/// thresholds below are a reasonable first-pass starting point, not
/// derived from any calibration dataset — there is no way to validate them
/// without real recorded voices, which this development sandbox doesn't
/// have. They should be sanity-checked against real recordings and
/// iterated at implementation/QA time on a real device.
class MoodClassifier {
  static const _loudRms = 0.12;
  static const _quietRms = 0.03;
  static const _highPitchHz = 200.0;
  static const _lowPitchHz = 110.0;
  static const _fastZeroCrossRate = 0.12;

  static VoiceMood classify(VoiceToneMetrics m) {
    final loud = m.rmsLevel >= _loudRms;
    final quiet = m.rmsLevel <= _quietRms;
    final highPitch = m.pitchHz != null && m.pitchHz! >= _highPitchHz;
    final lowPitch = m.pitchHz != null && m.pitchHz! <= _lowPitchHz;
    final fast = m.zeroCrossRate >= _fastZeroCrossRate;

    if (loud && highPitch && fast) return VoiceMood.stressed;
    if (loud) return VoiceMood.energetic;
    if (quiet && lowPitch) return VoiceMood.low;
    if (quiet) return VoiceMood.calm;
    return VoiceMood.neutral;
  }
}

extension VoiceMoodInfo on VoiceMood {
  /// How much this mood nudges the effective sarcasm level for subsequent
  /// AI replies (see CommandRouter._sessionMood), clamped into [0, 1] at
  /// the point of use.
  double get sarcasmDelta => switch (this) {
    VoiceMood.stressed => -0.3,
    VoiceMood.low => -0.15,
    VoiceMood.energetic => 0.1,
    VoiceMood.calm => 0.0,
    VoiceMood.neutral => 0.0,
  };

  String get label => switch (this) {
    VoiceMood.stressed => 'gestresst',
    VoiceMood.energetic => 'energiegeladen',
    VoiceMood.calm => 'ruhig',
    VoiceMood.low => 'niedergeschlagen',
    VoiceMood.neutral => 'neutral',
  };
}
