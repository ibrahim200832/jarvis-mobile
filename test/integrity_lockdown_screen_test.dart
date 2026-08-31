import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/widgets/integrity_lockdown_screen.dart';

void main() {
  testWidgets('shows the lockdown message with no way to dismiss it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IntegrityLockdownScreen()));

    expect(find.text('Sicherheitsprüfung fehlgeschlagen'), findsOneWidget);
    expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
    // No button, no way to proceed — a bare Scaffold with only static text.
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
