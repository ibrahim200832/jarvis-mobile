import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/screens/changelog_screen.dart';

void main() {
  testWidgets('renders every CHANGELOG.md section with its bullets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChangelogScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Änderungsverlauf'), findsOneWidget);
    expect(find.text('Aktuell'), findsOneWidget);

    // The later sections may be lazily built off-screen (ListView.builder),
    // so scroll them into view rather than assuming the initial viewport
    // covers the whole (ever-growing) changelog.
    await tester.scrollUntilVisible(find.text('Ältere Änderungen'), 300, scrollable: find.byType(Scrollable));
    expect(find.text('Ältere Änderungen'), findsOneWidget);
    expect(find.textContaining('spürbar klüger'), findsOneWidget);
  });
}
