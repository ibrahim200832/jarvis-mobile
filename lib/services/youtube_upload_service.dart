import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Handles Google sign-in (with YouTube upload scope) and uploading a video
/// the user picked to their own YouTube channel. Every upload is triggered
/// explicitly by the user picking a file and confirming — nothing happens
/// automatically or in the background, and uploads default to "private" so
/// nothing becomes public without the user changing that themselves in
/// YouTube Studio afterwards.
class YoutubeUploadService {
  YoutubeUploadService({String? webClientId})
      : _googleSignIn = GoogleSignIn(
          scopes: const ['https://www.googleapis.com/auth/youtube.upload'],
          clientId: webClientId,
        );

  final GoogleSignIn _googleSignIn;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.signOut();

  Future<String> uploadVideo({
    required Uint8List videoBytes,
    required String title,
    String description = 'Hochgeladen mit JARVIS',
  }) async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Anmeldung bei Google wurde abgebrochen.');
    }
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null) {
      throw Exception('Kein Zugriffstoken erhalten.');
    }

    final metadata = jsonEncode({
      'snippet': {'title': title, 'description': description},
      'status': {'privacyStatus': 'private'},
    });

    const boundary = 'jarvis-upload-boundary';
    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..add(utf8.encode(metadata))
      ..add(utf8.encode('\r\n--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: video/*\r\n\r\n'))
      ..add(videoBytes)
      ..add(utf8.encode('\r\n--$boundary--'));

    final uri = Uri.https('www.googleapis.com', '/upload/youtube/v3/videos', {
      'uploadType': 'multipart',
      'part': 'snippet,status',
    });

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body.toBytes(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('YouTube-Upload fehlgeschlagen (Code ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final videoId = data['id'] as String?;
    if (videoId == null) {
      throw Exception('YouTube hat keine Video-ID zurückgegeben.');
    }
    return 'https://youtu.be/$videoId';
  }
}
