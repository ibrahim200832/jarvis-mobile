import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jarvis_mobile/screens/youtube_upload_screen.dart';
import 'package:jarvis_mobile/services/youtube_upload_service.dart';

class FakeYoutubeUploadService extends YoutubeUploadService {
  @override
  GoogleSignInAccount? get currentUser => null;

  @override
  Future<String> uploadVideo({
    required Uint8List videoBytes,
    required String title,
    String description = 'Hochgeladen mit JARVIS',
    String privacyStatus = 'private',
    DateTime? publishAt,
  }) async => 'https://youtu.be/fake';
}

void main() {
  testWidgets('defaults to private with all three options visible', (tester) async {
    await tester.pumpWidget(MaterialApp(home: YoutubeUploadScreen(uploadService: FakeYoutubeUploadService())));

    expect(find.text('Privat'), findsOneWidget);
    expect(find.text('Nicht gelistet'), findsOneWidget);
    expect(find.text('Öffentlich'), findsOneWidget);
    expect(find.textContaining('(privat)'), findsOneWidget);
  });

  testWidgets('initialPrivacy preselects the given option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: YoutubeUploadScreen(uploadService: FakeYoutubeUploadService(), initialPrivacy: 'public')),
    );

    expect(find.textContaining('(öffentlich)'), findsOneWidget);
  });

  testWidgets('initialPublishAt forces private and shows the scheduled label', (tester) async {
    final publishAt = DateTime.now().add(const Duration(days: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: YoutubeUploadScreen(uploadService: FakeYoutubeUploadService(), initialPublishAt: publishAt),
      ),
    );

    expect(find.text('Upload planen'), findsOneWidget);
    expect(find.textContaining('automatisch am'), findsOneWidget);
  });

  testWidgets('clearing the schedule re-enables the privacy selector', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: YoutubeUploadScreen(
          uploadService: FakeYoutubeUploadService(),
          initialPublishAt: DateTime.now().add(const Duration(days: 1)),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.text('Später veröffentlichen (optional)'), findsOneWidget);
  });
}
