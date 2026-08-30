import 'dart:math';
import 'dart:typed_data';

/// Raw acoustic measurements from one captured voice sample — no
/// interpretation, just numbers (see MoodClassifier for the heuristic
/// bucketing on top of this).
class VoiceToneMetrics {
  /// Normalized RMS loudness, roughly 0.0 (silence) .. 1.0 (full-scale).
  final double rmsLevel;

  /// Estimated fundamental frequency (pitch), or null below the silence
  /// threshold / when no clear periodicity is found.
  final double? pitchHz;

  /// Fraction of consecutive sample pairs that cross zero (0.0 .. 1.0) —
  /// a coarse "how fast/energetic is the waveform" proxy.
  final double zeroCrossRate;

  const VoiceToneMetrics({required this.rmsLevel, this.pitchHz, required this.zeroCrossRate});
}

/// Pure, plugin-free acoustic analysis of a captured PCM16 sample — no
/// I/O, so it's fully unit-testable with synthetic waveforms. Pitch
/// estimation is a single offline autocorrelation pass over the whole
/// buffer (not a streaming/real-time algorithm — a few thousand samples is
/// plenty fast for a one-shot ~4s clip run once after capture completes).
class VoiceToneAnalyzer {
  static const _silenceRmsThreshold = 0.01;
  static const _minPitchHz = 75.0; // low end of adult speech F0
  static const _maxPitchHz = 400.0; // high end of adult speech F0

  static VoiceToneMetrics analyze(Int16List samples, {int sampleRate = 16000}) {
    if (samples.isEmpty) {
      return const VoiceToneMetrics(rmsLevel: 0, pitchHz: null, zeroCrossRate: 0);
    }

    final normalized = Float64List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      normalized[i] = samples[i] / 32768.0;
    }

    var sumSquares = 0.0;
    for (final s in normalized) {
      sumSquares += s * s;
    }
    final rms = sqrt(sumSquares / normalized.length);

    var crossings = 0;
    for (var i = 1; i < normalized.length; i++) {
      if ((normalized[i - 1] >= 0) != (normalized[i] >= 0)) crossings++;
    }
    final zeroCrossRate = crossings / normalized.length;

    final pitchHz = rms >= _silenceRmsThreshold ? _estimatePitch(normalized, sampleRate) : null;

    return VoiceToneMetrics(rmsLevel: rms, pitchHz: pitchHz, zeroCrossRate: zeroCrossRate);
  }

  /// Autocorrelation-based F0 estimate over [_minPitchHz, _maxPitchHz].
  /// Returns null if the buffer is too short or no positive-correlation
  /// lag is found (no clear periodicity — e.g. pure noise).
  static double? _estimatePitch(Float64List samples, int sampleRate) {
    final minLag = (sampleRate / _maxPitchHz).floor().clamp(1, samples.length);
    final maxLag = (sampleRate / _minPitchHz).ceil();
    if (maxLag >= samples.length) return null;

    var bestLag = -1;
    var bestCorrelation = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var sum = 0.0;
      final limit = samples.length - lag;
      for (var i = 0; i < limit; i++) {
        sum += samples[i] * samples[i + lag];
      }
      final normalizedSum = sum / limit;
      if (normalizedSum > bestCorrelation) {
        bestCorrelation = normalizedSum;
        bestLag = lag;
      }
    }
    if (bestLag <= 0 || bestCorrelation <= 0) return null;
    return sampleRate / bestLag;
  }
}
