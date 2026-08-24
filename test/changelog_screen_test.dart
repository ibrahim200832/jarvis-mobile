import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/screens/changelog_screen.dart';

void main() {
  testWidgets('renders every CHANGELOG.md section with its bullets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChangelogScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Änderungsverlauf'), findsOneWidget);
    expect(find.text('Aktuell'), findsOneWidget);
    expect(find.text('Ältere Änderungen'), findsOneWidget);
    expect(find.textContaining('spürbar klüger'), findsOneWidget);
  });
}
