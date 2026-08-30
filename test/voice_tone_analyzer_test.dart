import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/voice_tone_analyzer.dart';

Int16List _sineWave({
  required double freqHz,
  required int sampleRate,
  required int durationMs,
  double amplitude = 0.5,
}) {
  final n = (sampleRate * durationMs / 1000).round();
  final samples = Int16List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    samples[i] = (amplitude * 32767 * sin(2 * pi * freqHz * t)).round();
  }
  return samples;
}

Int16List _silence(int n) => Int16List(n);

void main() {
  const sampleRate = 16000;

  group('analyze - RMS', () {
    test('silence has near-zero RMS', () {
      final metrics = VoiceToneAnalyzer.analyze(_silence(4000), sampleRate: sampleRate);
      expect(metrics.rmsLevel, lessThan(0.001));
    });

    test('a known-amplitude sine wave has the expected RMS (amplitude/sqrt(2))', () {
      final samples = _sineWave(freqHz: 150, sampleRate: sampleRate, durationMs: 500, amplitude: 0.5);
      final metrics = VoiceToneAnalyzer.analyze(samples, sampleRate: sampleRate);
      expect(metrics.rmsLevel, closeTo(0.5 / sqrt(2), 0.02));
    });
  });

  group('analyze - pitch', () {
    test('estimates a 150Hz sine wave within a few Hz', () {
      final samples = _sineWave(freqHz: 150, sampleRate: sampleRate, durationMs: 800, amplitude: 0.6);
      final metrics = VoiceToneAnalyzer.analyze(samples, sampleRate: sampleRate);
      expect(metrics.pitchHz, isNotNull);
      expect(metrics.pitchHz, closeTo(150, 10));
    });

    test('estimates a 250Hz sine wave within a few Hz', () {
      final samples = _sineWave(freqHz: 250, sampleRate: sampleRate, durationMs: 800, amplitude: 0.6);
      final metrics = VoiceToneAnalyzer.analyze(samples, sampleRate: sampleRate);
      expect(metrics.pitchHz, isNotNull);
      expect(metrics.pitchHz, closeTo(250, 15));
    });

    test('silence has no pitch estimate', () {
      final metrics = VoiceToneAnalyzer.analyze(_silence(4000), sampleRate: sampleRate);
      expect(metrics.pitchHz, isNull);
    });
  });

  group('analyze - zero crossing rate', () {
    test('a rapidly alternating square wave has a near-maximal crossing rate', () {
      final samples = Int16List.fromList(List.generate(2000, (i) => i.isEven ? 20000 : -20000));
      final metrics = VoiceToneAnalyzer.analyze(samples, sampleRate: sampleRate);
      expect(metrics.zeroCrossRate, greaterThan(0.9));
    });

    test('a constant DC signal has zero crossing rate', () {
      final samples = Int16List.fromList(List.filled(2000, 5000));
      final metrics = VoiceToneAnalyzer.analyze(samples, sampleRate: sampleRate);
      expect(metrics.zeroCrossRate, 0);
    });
  });

  test('empty input returns zeroed metrics without throwing', () {
    final metrics = VoiceToneAnalyzer.analyze(Int16List(0));
    expect(metrics.rmsLevel, 0);
    expect(metrics.pitchHz, isNull);
    expect(metrics.zeroCrossRate, 0);
  });
}
