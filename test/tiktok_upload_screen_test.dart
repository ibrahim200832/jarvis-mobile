import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/screens/tiktok_upload_screen.dart';
import 'package:jarvis_mobile/services/tiktok_upload_service.dart';

class FakeTikTokUploadService extends TikTokUploadService {
  bool connected = true;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<TikTokCreatorInfo?> getCreatorInfo(String backendUrl) async =>
      TikTokCreatorInfo('testuser', const ['SELF_ONLY', 'MUTUAL_FOLLOW_FRIENDS'], 60);
}

void main() {
  testWidgets('shows a connect hint instead of the form when not connected', (tester) async {
    final service = FakeTikTokUploadService()..connected = false;
    await tester.pumpWidget(MaterialApp(home: TikTokUploadScreen(uploadService: service, backendUrl: 'https://x')));
    await tester.pumpAndSettle();

    expect(find.text('Bitte zuerst in den Einstellungen mit TikTok verbinden.'), findsOneWidget);
    expect(find.text('Video auswählen'), findsNothing);
  });

  testWidgets('builds the privacy dropdown from creator_info when connected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TikTokUploadScreen(uploadService: FakeTikTokUploadService(), backendUrl: 'https://x')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verbunden als @testuser'), findsOneWidget);
    expect(find.text('Video auswählen'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Nur ich (privat)'), findsWidgets);
    expect(find.text('Nur Freunde'), findsOneWidget);
  });

  testWidgets('upload button stays disabled until a privacy level is chosen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TikTokUploadScreen(uploadService: FakeTikTokUploadService(), backendUrl: 'https://x')),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Auf TikTok hochladen'));
    expect(button.onPressed, isNull);
  });
}
