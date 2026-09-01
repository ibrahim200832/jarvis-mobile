import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';
import 'package:jarvis_mobile/widgets/admin_gate_screen.dart';

void main() {
  testWidgets('calls onLogin with the entered credentials and pops with true on success', (tester) async {
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
                    checkLockout: () async => null,
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
          checkLockout: () async => null,
          onLogin: (_, _) async => false,
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'ibrahim');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'wrong');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();

    expect(find.text('Falscher Benutzername oder falsches Passwort'), findsOneWidget);
    expect(find.byType(AdminGateScreen), findsOneWidget);
  });

  testWidgets('does nothing when submitting with an empty username or password', (tester) async {
    var loginCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildJarvisTheme(),
        home: AdminGateScreen(
          checkLockout: () async => null,
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

  group('lockout', () {
    testWidgets('shows a countdown message and hides the login form while locked out', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            checkLockout: () async => const Duration(minutes: 3),
            onLogin: (_, _) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Zu viele Fehlversuche'), findsOneWidget);
      expect(find.text('Benutzername'), findsNothing);
      expect(find.text('Anmelden'), findsNothing);
    });

    testWidgets('a wrong login attempt re-checks lockout and shows the countdown once triggered', (tester) async {
      var locked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildJarvisTheme(),
          home: AdminGateScreen(
            checkLockout: () async => locked ? const Duration(minutes: 5) : null,
            onLogin: (_, _) async {
              locked = true;
              return false;
            },
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'ibrahim');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'wrong');
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Zu viele Fehlversuche'), findsOneWidget);
    });
  });
}
