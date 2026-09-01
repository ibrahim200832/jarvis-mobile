import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';
import 'package:jarvis_mobile/widgets/admin_gate_screen.dart';

void main() {
  testWidgets('shows an error and stays open when the PIN is wrong', (tester) async {
    var unlockCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: AdminGateScreen(
          hasPinConfigured: true,
          hasPasswordConfigured: false,
          checkLockout: () async => null,
          onUnlock: (pin) async {
            unlockCalls++;
            return pin == '1234';
          },
          onLogin: (_, _) async => false,
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Admin-PIN'), '0000');
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
        theme: buildJarvisTheme(),
        home: AdminGateScreen(
          hasPinConfigured: true,
          hasPasswordConfigured: false,
          checkLockout: () async => null,
          onUnlock: (_) async {
            unlockCalls++;
            return false;
          },
          onLogin: (_, _) async => false,
        ),
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
        theme: buildJarvisTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AdminGateScreen(
                    hasPinConfigured: true,
                    hasPasswordConfigured: false,
                    checkLockout: () async => null,
                    onUnlock: (pin) async {
                      receivedPin = pin;
                      return true;
                    },
                    onLogin: (_, _) async => false,
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
    await tester.enterText(find.widgetWithText(TextField, 'Admin-PIN'), '1234');
    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();

    expect(receivedPin, '1234');
    expect(poppedValue, isTrue);
  });

  testWidgets('does not show a biometric button when onBiometricUnlock is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: AdminGateScreen(
          hasPinConfigured: true,
          hasPasswordConfigured: false,
          checkLockout: () async => null,
          onUnlock: (_) async => false,
          onLogin: (_, _) async => false,
        ),
      ),
    );

    expect(find.text('Mit Biometrie entsperren'), findsNothing);
  });

  testWidgets('shows a biometric button that pops with true on success when provided', (tester) async {
    var biometricCalls = 0;
    bool? poppedValue;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AdminGateScreen(
                    hasPinConfigured: true,
                    hasPasswordConfigured: false,
                    checkLockout: () async => null,
                    onUnlock: (_) async => false,
                    onLogin: (_, _) async => false,
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
        theme: buildJarvisTheme(),
        home: AdminGateScreen(
          hasPinConfigured: true,
          hasPasswordConfigured: false,
          checkLockout: () async => null,
          onUnlock: (_) async => false,
          onLogin: (_, _) async => false,
          onBiometricUnlock: () async => false,
        ),
      ),
    );

    await tester.tap(find.text('Mit Biometrie entsperren'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminGateScreen), findsOneWidget);
  });

  group('username/password login', () {
    testWidgets('the login form is hidden when hasPasswordConfigured is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            hasPinConfigured: true,
            hasPasswordConfigured: false,
            checkLockout: () async => null,
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );

      expect(find.text('Benutzername'), findsNothing);
      expect(find.text('Anmelden'), findsNothing);
    });

    testWidgets('the PIN form is hidden when hasPinConfigured is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            hasPinConfigured: false,
            hasPasswordConfigured: true,
            checkLockout: () async => null,
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );

      expect(find.text('Admin-PIN'), findsNothing);
      expect(find.text('Entsperren'), findsNothing);
    });

    testWidgets('shows a divider when both PIN and password are configured', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            hasPinConfigured: true,
            hasPasswordConfigured: true,
            checkLockout: () async => null,
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );

      expect(find.text('oder'), findsOneWidget);
      expect(find.text('Admin-PIN'), findsOneWidget);
      expect(find.text('Benutzername'), findsOneWidget);
    });

    testWidgets('calls onLogin and pops with true on correct credentials', (tester) async {
      String? receivedUsername;
      String? receivedPassword;
      bool? poppedValue;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedValue = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AdminGateScreen(
                      hasPinConfigured: false,
                      hasPasswordConfigured: true,
                      checkLockout: () async => null,
                      onUnlock: (_) async => false,
                      onLogin: (username, password) async {
                        receivedUsername = username;
                        receivedPassword = password;
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
      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'ibrahim');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'hunter2');
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();

      expect(receivedUsername, 'ibrahim');
      expect(receivedPassword, 'hunter2');
      expect(poppedValue, isTrue);
    });

    testWidgets('shows a generic error on wrong credentials without revealing which field was wrong', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            hasPinConfigured: false,
            hasPasswordConfigured: true,
            checkLockout: () async => null,
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'ibrahim');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'wrong');
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Falscher Benutzername oder falsches Passwort'), findsOneWidget);
    });

    testWidgets('does nothing when submitting with an empty username or password', (tester) async {
      var loginCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            hasPinConfigured: false,
            hasPasswordConfigured: true,
            checkLockout: () async => null,
            onUnlock: (_) async => false,
            onLogin: (_, _) async {
              loginCalls++;
              return false;
            },
          ),
        ),
      );

      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();

      expect(loginCalls, 0);
    });
  });

  group('lockout', () {
    testWidgets('shows a countdown message and hides all inputs while locked out', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            hasPinConfigured: true,
            hasPasswordConfigured: true,
            checkLockout: () async => const Duration(minutes: 3),
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Zu viele Fehlversuche'), findsOneWidget);
      expect(find.text('Admin-PIN'), findsNothing);
      expect(find.text('Benutzername'), findsNothing);
      expect(find.text('Mit Biometrie entsperren'), findsNothing);
    });

    testWidgets('a wrong PIN attempt re-checks lockout and shows the countdown once triggered', (tester) async {
      var locked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            hasPinConfigured: true,
            hasPasswordConfigured: false,
            checkLockout: () async => locked ? const Duration(minutes: 5) : null,
            onUnlock: (_) async {
              locked = true;
              return false;
            },
            onLogin: (_, _) async => false,
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Admin-PIN'), '0000');
      await tester.tap(find.text('Entsperren'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Zu viele Fehlversuche'), findsOneWidget);
    });
  });
}
