import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';
import 'package:jarvis_mobile/widgets/emergency_lock_screen.dart';

void main() {
  testWidgets('shows an error and stays locked when the PIN is wrong', (tester) async {
    var unlockCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: EmergencyLockScreen(
          onUnlock: (pin) async {
            unlockCalls++;
            return pin == '1234';
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();

    expect(unlockCalls, 1);
    expect(find.text('Falsche PIN'), findsOneWidget);
    expect(find.byType(EmergencyLockScreen), findsOneWidget);
  });

  testWidgets('calls onUnlock with the entered PIN and clears the field on success', (tester) async {
    String? receivedPin;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: EmergencyLockScreen(
          onUnlock: (pin) async {
            receivedPin = pin;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();

    expect(receivedPin, '1234');
    expect(find.text('Falsche PIN'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('does nothing when submitting an empty PIN', (tester) async {
    var unlockCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: EmergencyLockScreen(
          onUnlock: (pin) async {
            unlockCalls++;
            return false;
          },
        ),
      ),
    );

    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();

    expect(unlockCalls, 0);
  });
}
