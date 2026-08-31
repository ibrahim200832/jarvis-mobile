import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backup_export_service.dart';

/// Syncs the encrypted local backup (see BackupExportService) to and from
/// the user's own WebDAV server, so it's a real off-device copy — the
/// user's choice over GitHub Gists, per explicit decision.
///
/// This is genuine end-to-end encryption, not just "encryption in
/// transit": BackupExportService.buildEncryptedSnapshot() already produces
/// AES-256 ciphertext under a key that never leaves this device (see
/// SecureStorageService) *before* a single byte is sent anywhere — the
/// WebDAV server (and anyone who compromises it) only ever stores and
/// serves opaque encrypted bytes, never the plaintext data.
///
/// WebDAV itself is just HTTP with a few extra verbs (PUT to upload, GET to
/// download, PROPFIND to check reachability), so this talks to it directly
/// via `package:http` with HTTP Basic Auth rather than pulling in a
/// dedicated WebDAV client package for three verbs.
class WebDavSyncService {
  WebDavSyncService({http.Client? client, BackupExportService? backup})
    : _client = client ?? http.Client(),
      _backup = backup ?? BackupExportService();

  final http.Client _client;
  final BackupExportService _backup;

  static const remoteFileName = 'jarvis_backup.zip.enc';

  Uri _fileUri(String baseUrl) {
    final normalized = baseUrl.trim().endsWith('/') ? baseUrl.trim() : '${baseUrl.trim()}/';
    return Uri.parse('$normalized$remoteFileName');
  }

  Map<String, String> _authHeader(String username, String password) => {
    'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
  };

  /// Uploads a freshly-built, already-encrypted snapshot via WebDAV PUT.
  Future<void> upload({required String baseUrl, required String username, required String password}) async {
    final bytes = await _backup.buildEncryptedSnapshot();
    final res = await _client
        .put(
          _fileUri(baseUrl),
          headers: {..._authHeader(username, password), 'Content-Type': 'application/octet-stream'},
          body: bytes,
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV-Upload fehlgeschlagen (Code ${res.statusCode}).');
    }
  }

  /// Downloads and restores the encrypted snapshot from the WebDAV server.
  Future<void> download({required String baseUrl, required String username, required String password}) async {
    final res = await _client
        .get(_fileUri(baseUrl), headers: _authHeader(username, password))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 404) {
      throw StateError('Auf dem WebDAV-Server liegt noch kein Backup.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV-Download fehlgeschlagen (Code ${res.statusCode}).');
    }
    await _backup.restoreFromBytes(res.bodyBytes);
  }

  /// Reachability/credentials check via WebDAV PROPFIND (Depth: 0) against
  /// the base URL — the standard, side-effect-free way to verify a WebDAV
  /// connection, mirroring HomeAssistantService.testConnection.
  Future<bool> testConnection({required String baseUrl, required String username, required String password}) async {
    try {
      final request = http.Request('PROPFIND', Uri.parse(baseUrl.trim()))
        ..headers.addAll({..._authHeader(username, password), 'Depth': '0'});
      final streamed = await _client.send(request).timeout(const Duration(seconds: 10));
      return streamed.statusCode >= 200 && streamed.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
