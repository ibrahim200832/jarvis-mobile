import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// One row from the Worker's `/admin/installs` — a single anonymous
/// installation, never tied to any account or personal data.
class InstallSummary {
  InstallSummary({
    required this.installId,
    required this.firstSeen,
    required this.lastSeen,
    required this.appVersion,
    required this.platform,
    required this.errorCount,
    required this.forceLocalAiEnabled,
  });

  final String installId;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? appVersion;
  final String? platform;
  final int errorCount;
  final bool? forceLocalAiEnabled;

  static InstallSummary fromJson(Map<String, dynamic> json) => InstallSummary(
    installId: json['installId'] as String,
    firstSeen: DateTime.fromMillisecondsSinceEpoch(json['firstSeen'] as int),
    lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int),
    appVersion: json['appVersion'] as String?,
    platform: json['platform'] as String?,
    errorCount: json['errorCount'] as int,
    forceLocalAiEnabled: json['forceLocalAiEnabled'] as bool?,
  );
}

/// One row from `/admin/installs/:id/errors`.
class InstallError {
  InstallError({required this.level, required this.source, required this.message, required this.createdAt});

  final String level;
  final String source;
  final String message;
  final DateTime createdAt;

  static InstallError fromJson(Map<String, dynamic> json) => InstallError(
    level: json['level'] as String,
    source: json['source'] as String,
    message: json['message'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );
}

/// Admin-only queries against the Worker's `/admin/installs*` endpoints (see
/// worker/ai-proxy.js) — lists every installation that has ever reported an
/// error or checked in, its recent errors, and lets the owner/a helper set a
/// remote override for one installation (Runde 21).
///
/// Every request carries the X-Jarvis-Admin-Key header (see
/// SettingsService.getAdminApiKey) — the Worker rejects anything without the
/// exact matching secret, regardless of HMAC signing state, since this is
/// the one class of endpoint that exposes every installation's data. Every
/// method fails soft (empty list / false) on any error — a reachability
/// problem here must never crash the Admin-Konsole.
class TelemetryAdminService {
  TelemetryAdminService({required SettingsService settings, http.Client? client})
    : _settings = settings, // ignore: prefer_initializing_formals
      _client = client ?? http.Client();

  final SettingsService _settings;
  final http.Client _client;

  Future<Map<String, String>?> _headers() async {
    final adminKey = await _settings.getAdminApiKey();
    if (adminKey == null || adminKey.isEmpty) return null;
    return {'X-Jarvis-Admin-Key': adminKey, 'Content-Type': 'application/json'};
  }

  Future<Uri?> _uri(String path) async {
    final backendUrl = (await _settings.getTelemetryBackendUrl())?.trim();
    if (backendUrl == null || backendUrl.isEmpty) return null;
    return Uri.parse(backendUrl).replace(path: path);
  }

  Future<List<InstallSummary>> listInstalls() async {
    try {
      final headers = await _headers();
      final uri = await _uri('/admin/installs');
      if (headers == null || uri == null) return [];
      final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final installs = (data['installs'] as List).cast<Map<String, dynamic>>();
      return installs.map(InstallSummary.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<InstallError>> getInstallErrors(String installId) async {
    try {
      final headers = await _headers();
      final uri = await _uri('/admin/installs/${Uri.encodeComponent(installId)}/errors');
      if (headers == null || uri == null) return [];
      final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final errors = (data['errors'] as List).cast<Map<String, dynamic>>();
      return errors.map(InstallError.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  /// Sets (or clears, with `forceLocalAi: null`) the remote override for one
  /// installation. Returns whether the request succeeded.
  Future<bool> setRemoteOverride(String installId, {required bool? forceLocalAi}) async {
    try {
      final headers = await _headers();
      final uri = await _uri('/admin/installs/${Uri.encodeComponent(installId)}/config');
      if (headers == null || uri == null) return false;
      final res = await _client
          .post(uri, headers: headers, body: jsonEncode({'forceLocalAiEnabled': forceLocalAi}))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
