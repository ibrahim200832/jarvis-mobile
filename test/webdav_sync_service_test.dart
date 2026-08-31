import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_mobile/services/backup_export_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorageService extends SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  late Directory tempDir;
  late BackupExportService backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('jarvis_webdav_test_');
    backup = BackupExportService(directoryOverride: tempDir, secureStorage: _FakeSecureStorageService());
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('upload', () {
    test('PUTs the already-encrypted snapshot with Basic auth — the server never sees plaintext', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes', '["Geheime Notiz die niemand lesen soll"]');

      http.BaseRequest? captured;
      List<int>? capturedBody;
      // MockClient's plain constructor only exposes the decoded body for
      // non-streaming requests; capture raw bytes via a streaming handler
      // instead so we can assert on them precisely.
      final streamingClient = MockClient.streaming((request, bodyStream) async {
        captured = request;
        capturedBody = await bodyStream.expand((chunk) => chunk).toList();
        return http.StreamedResponse(Stream.value(<int>[]), 201);
      });
      final service = WebDavSyncService(client: streamingClient, backup: backup);

      await service.upload(baseUrl: 'https://cloud.example.com/dav', username: 'nutzer', password: 'geheim');

      expect(captured!.method, 'PUT');
      expect(captured!.url.toString(), 'https://cloud.example.com/dav/${WebDavSyncService.remoteFileName}');
      expect(captured!.headers['Authorization'], 'Basic ${base64Encode(utf8.encode('nutzer:geheim'))}');
      expect(capturedBody, isNotNull);
      final bodyAsLatin1 = String.fromCharCodes(capturedBody!);
      expect(bodyAsLatin1, isNot(contains('Geheime Notiz')));
    });

    test('a base URL without a trailing slash is still handled correctly', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response('', 201);
      });
      final service = WebDavSyncService(client: client, backup: backup);

      await service.upload(baseUrl: 'https://cloud.example.com/dav', username: 'u', password: 'p');

      expect(requestedUri.toString(), 'https://cloud.example.com/dav/${WebDavSyncService.remoteFileName}');
    });

    test('throws on a non-2xx response', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final service = WebDavSyncService(client: client, backup: backup);

      expect(
        () => service.upload(baseUrl: 'https://cloud.example.com/dav/', username: 'u', password: 'p'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('download', () {
    test('downloads and restores the encrypted snapshot', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes', '["Original vom Server"]');
      final snapshot = await backup.buildEncryptedSnapshot();

      // Simulate the data changing locally before the download/restore.
      await prefs.setString('notes', '["Lokal überschrieben"]');

      final client = MockClient((request) async => http.Response.bytes(snapshot, 200));
      final service = WebDavSyncService(client: client, backup: backup);

      await service.download(baseUrl: 'https://cloud.example.com/dav/', username: 'u', password: 'p');

      expect(prefs.getString('notes'), '["Original vom Server"]');
    });

    test('a 404 reports that no backup exists yet', () async {
      final client = MockClient((request) async => http.Response('', 404));
      final service = WebDavSyncService(client: client, backup: backup);

      expect(
        () => service.download(baseUrl: 'https://cloud.example.com/dav/', username: 'u', password: 'p'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws on other non-2xx responses', () async {
      final client = MockClient((request) async => http.Response('', 503));
      final service = WebDavSyncService(client: client, backup: backup);

      expect(
        () => service.download(baseUrl: 'https://cloud.example.com/dav/', username: 'u', password: 'p'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('testConnection', () {
    test('true for a successful PROPFIND', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PROPFIND');
        expect(request.headers['Depth'], '0');
        return http.Response('', 207);
      });
      final service = WebDavSyncService(client: client, backup: backup);

      expect(await service.testConnection(baseUrl: 'https://cloud.example.com/dav/', username: 'u', password: 'p'), isTrue);
    });

    test('false for an auth failure', () async {
      final client = MockClient((request) async => http.Response('', 401));
      final service = WebDavSyncService(client: client, backup: backup);

      expect(await service.testConnection(baseUrl: 'https://cloud.example.com/dav/', username: 'u', password: 'p'), isFalse);
    });

    test('false when the request throws', () async {
      final client = MockClient((request) async => throw Exception('connection refused'));
      final service = WebDavSyncService(client: client, backup: backup);

      expect(await service.testConnection(baseUrl: 'https://cloud.example.com/dav/', username: 'u', password: 'p'), isFalse);
    });
  });
}
