import 'package:flutter_test/flutter_test.dart';

import 'package:jarvis_mobile/main.dart';

void main() {
  testWidgets('App starts and shows the JARVIS home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    await tester.pump();

    expect(find.text('J.A.R.V.I.S.'), findsOneWidget);
  });
}
