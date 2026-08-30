import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/mood_classifier.dart';
import 'package:jarvis_mobile/services/voice_tone_analyzer.dart';

void main() {
  group('classify', () {
    test('loud + high pitch + fast -> stressed', () {
      const m = VoiceToneMetrics(rmsLevel: 0.3, pitchHz: 250, zeroCrossRate: 0.2);
      expect(MoodClassifier.classify(m), VoiceMood.stressed);
    });

    test('loud alone (not high-pitched/fast) -> energetic', () {
      const m = VoiceToneMetrics(rmsLevel: 0.3, pitchHz: 130, zeroCrossRate: 0.05);
      expect(MoodClassifier.classify(m), VoiceMood.energetic);
    });

    test('quiet + low pitch -> low', () {
      const m = VoiceToneMetrics(rmsLevel: 0.01, pitchHz: 90, zeroCrossRate: 0.02);
      expect(MoodClassifier.classify(m), VoiceMood.low);
    });

    test('quiet without low pitch -> calm', () {
      const m = VoiceToneMetrics(rmsLevel: 0.01, pitchHz: 180, zeroCrossRate: 0.02);
      expect(MoodClassifier.classify(m), VoiceMood.calm);
    });

    test('quiet with no pitch reading -> calm', () {
      const m = VoiceToneMetrics(rmsLevel: 0.01, zeroCrossRate: 0.02);
      expect(MoodClassifier.classify(m), VoiceMood.calm);
    });

    test('moderate everything -> neutral', () {
      const m = VoiceToneMetrics(rmsLevel: 0.06, pitchHz: 150, zeroCrossRate: 0.06);
      expect(MoodClassifier.classify(m), VoiceMood.neutral);
    });
  });

  group('sarcasmDelta signs', () {
    test('stressed and low are negative (more empathetic/less sarcastic)', () {
      expect(VoiceMood.stressed.sarcasmDelta, lessThan(0));
      expect(VoiceMood.low.sarcasmDelta, lessThan(0));
    });

    test('energetic is positive', () {
      expect(VoiceMood.energetic.sarcasmDelta, greaterThan(0));
    });

    test('calm and neutral are zero', () {
      expect(VoiceMood.calm.sarcasmDelta, 0);
      expect(VoiceMood.neutral.sarcasmDelta, 0);
    });
  });

  test('every mood has a non-empty label', () {
    for (final mood in VoiceMood.values) {
      expect(mood.label, isNotEmpty);
    }
  });
}
