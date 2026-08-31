import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/widgets/admin_gate_screen.dart';

void main() {
  testWidgets('shows an error and stays open when the PIN is wrong', (tester) async {
    var unlockCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminGateScreen(
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
    expect(find.byType(AdminGateScreen), findsOneWidget);
  });

  testWidgets('does nothing when submitting an empty PIN', (tester) async {
    var unlockCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminGateScreen(onUnlock: (_) async {
          unlockCalls++;
          return false;
        }),
      ),
    );

    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();

    expect(unlockCalls, 0);
  });

  testWidgets('calls onUnlock and pops with true on a correct PIN', (tester) async {
    String? receivedPin;
    bool? poppedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AdminGateScreen(
                    onUnlock: (pin) async {
                      receivedPin = pin;
                      return true;
                    },
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();

    expect(receivedPin, '1234');
    expect(poppedValue, isTrue);
  });

  testWidgets('does not show a biometric button when onBiometricUnlock is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminGateScreen(onUnlock: (_) async => false)),
    );

    expect(find.text('Mit Biometrie entsperren'), findsNothing);
  });

  testWidgets('shows a biometric button that pops with true on success when provided', (tester) async {
    var biometricCalls = 0;
    bool? poppedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AdminGateScreen(
                    onUnlock: (_) async => false,
                    onBiometricUnlock: () async {
                      biometricCalls++;
                      return true;
                    },
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Mit Biometrie entsperren'), findsOneWidget);
    await tester.tap(find.text('Mit Biometrie entsperren'));
    await tester.pumpAndSettle();

    expect(biometricCalls, 1);
    expect(poppedValue, isTrue);
  });

  testWidgets('a failed biometric attempt stays on the gate screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminGateScreen(
          onUnlock: (_) async => false,
          onBiometricUnlock: () async => false,
        ),
      ),
    );

    await tester.tap(find.text('Mit Biometrie entsperren'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminGateScreen), findsOneWidget);
  });
}
