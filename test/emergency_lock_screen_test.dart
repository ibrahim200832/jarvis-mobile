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

    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '0000');
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

    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '1234');
    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();

    expect(receivedPin, '1234');
    expect(find.text('Falsche PIN'), findsNothing);
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'PIN'));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('does nothing when submitting an empty PIN', (tester) async {
    var unlockCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: EmergencyLockScreen(
          hasPinConfigured: true,
          hasPasswordConfigured: false,
          checkLockout: () async => null,
          onUnlock: (pin) async {
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

  group('username/password login', () {
    testWidgets('the login form is hidden when hasPasswordConfigured is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: EmergencyLockScreen(
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
          home: EmergencyLockScreen(
            hasPinConfigured: false,
            hasPasswordConfigured: true,
            checkLockout: () async => null,
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );

      expect(find.text('PIN'), findsNothing);
      expect(find.text('Entsperren'), findsNothing);
    });

    testWidgets('shows a divider when both PIN and password are configured', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: EmergencyLockScreen(
            hasPinConfigured: true,
            hasPasswordConfigured: true,
            checkLockout: () async => null,
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );

      expect(find.text('oder'), findsOneWidget);
      expect(find.text('PIN'), findsOneWidget);
      expect(find.text('Benutzername'), findsOneWidget);
    });

    testWidgets('calls onLogin with the entered credentials and clears the fields on success', (tester) async {
      String? receivedUsername;
      String? receivedPassword;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: EmergencyLockScreen(
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

      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'ibrahim');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'hunter2');
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();

      expect(receivedUsername, 'ibrahim');
      expect(receivedPassword, 'hunter2');
      final usernameField = tester.widget<TextField>(find.widgetWithText(TextField, 'Benutzername'));
      expect(usernameField.controller!.text, isEmpty);
    });

    testWidgets('shows a generic error on wrong credentials without revealing which field was wrong', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: EmergencyLockScreen(
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
          home: EmergencyLockScreen(
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
    testWidgets('checks the lockout once on entry, before any failed attempt', (tester) async {
      var checkCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: EmergencyLockScreen(
            hasPinConfigured: true,
            hasPasswordConfigured: false,
            checkLockout: () async {
              checkCalls++;
              return const Duration(minutes: 4);
            },
            onUnlock: (_) async => false,
            onLogin: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(checkCalls, 1);
      expect(find.textContaining('Zu viele Fehlversuche'), findsOneWidget);
      expect(find.text('PIN'), findsNothing);
      expect(find.text('Benutzername'), findsNothing);
    });

    testWidgets('a wrong PIN attempt re-checks lockout and shows the countdown once triggered', (tester) async {
      var locked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: EmergencyLockScreen(
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

      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '0000');
      await tester.tap(find.text('Entsperren'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Zu viele Fehlversuche'), findsOneWidget);
    });
  });
}
