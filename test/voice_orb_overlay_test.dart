import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/widgets/voice_orb_overlay.dart';

void main() {
  testWidgets('renders without throwing and can be disposed', (tester) async {
    final amplitude = ValueNotifier<double>(0.0);
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceOrbOverlay(
          state: VoiceOrbState.listening,
          statusText: 'Höre...',
          muted: false,
          onToggleMute: () {},
          onEndCall: () {},
          onReset: () {},
          onOpenCamera: () {},
          amplitude: amplitude,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(VoiceOrbOverlay), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    amplitude.dispose();
  });

  testWidgets('reacts to amplitude changes without throwing, across all states', (tester) async {
    final amplitude = ValueNotifier<double>(0.0);
    for (final state in VoiceOrbState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: VoiceOrbOverlay(
            state: state,
            statusText: 'Status',
            muted: false,
            onToggleMute: () {},
            onEndCall: () {},
            onReset: () {},
            onOpenCamera: () {},
            amplitude: amplitude,
          ),
        ),
      );
      await tester.pump();

      amplitude.value = 1.0;
      await tester.pump();
      amplitude.value = 0.0;
      await tester.pump();
    }
    expect(find.byType(VoiceOrbOverlay), findsOneWidget);
    amplitude.dispose();
  });

  testWidgets('clamps out-of-range amplitude values instead of throwing', (tester) async {
    final amplitude = ValueNotifier<double>(0.0);
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceOrbOverlay(
          state: VoiceOrbState.speaking,
          statusText: 'Status',
          muted: false,
          onToggleMute: () {},
          onEndCall: () {},
          onReset: () {},
          onOpenCamera: () {},
          amplitude: amplitude,
        ),
      ),
    );
    await tester.pump();

    amplitude.value = 5.0; // above 1.0, should be clamped internally
    await tester.pump();
    amplitude.value = -2.0; // below 0.0, should be clamped internally
    await tester.pump();

    expect(find.byType(VoiceOrbOverlay), findsOneWidget);
    amplitude.dispose();
  });
}
