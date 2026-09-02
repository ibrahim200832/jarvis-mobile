import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'log_service.dart';
import 'request_signing_service.dart';
import 'settings_service.dart';

/// Reports anonymous per-install error data to the developer's own Worker
/// backend (see worker/ai-proxy.js's `/report-error`/`/remote-config`
/// handlers) and applies any admin-set remote overrides for this
/// installation (Runde 21). Deliberately carries only technical error data
/// — level, source, message, app version, platform — never chat message
/// content.
///
/// Every public method fails soft: try/catch-wrapped with a short timeout,
/// mirroring WebDavSyncService.testConnection — an unreachable/misconfigured
/// telemetry backend must never affect the app itself.
class CrashReportService {
  // The field is deliberately private while the constructor parameter is
  // deliberately public-named; the analyzer's `this._settings` shorthand
  // suggestion would make the named parameter private too, breaking every
  // external `settings: ...` call site.
  CrashReportService({required SettingsService settings, http.Client? client})
    : _settings = settings, // ignore: prefer_initializing_formals
      _client = client ?? http.Client();

  final SettingsService _settings;
  final http.Client _client;

  /// Hard cap on reports sent per app run — protects the Worker/D1 from a
  /// crash loop flooding it with reports. Static so it's shared across
  /// every CrashReportService instance constructed during one run (LogService
  /// calls its onError callback with a freshly-built instance each time).
  static const maxReportsPerSession = 20;
  static int _sentThisSession = 0;

  /// Test-only: the static session counter otherwise persists for the
  /// lifetime of the test process, which would make later tests see an
  /// already-exhausted cap left over from an earlier one.
  @visibleForTesting
  static void resetSessionCountForTest() => _sentThisSession = 0;

  Future<void> reportError(LogEntry entry) async {
    try {
      if (!await _settings.getCrashReportingEnabled()) return;
      if (_sentThisSession >= maxReportsPerSession) return;
      final backendUrl = (await _settings.getTelemetryBackendUrl())?.trim();
      if (backendUrl == null || backendUrl.isEmpty) return;

      final installId = await _settings.getInstallId();
      final info = await PackageInfo.fromPlatform();
      final body = jsonEncode({
        'installId': installId,
        'level': entry.level.name,
        'source': entry.source,
        'message': entry.message,
        'appVersion': '${info.version}+${info.buildNumber}',
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
      final hmacSecret = await _settings.getAiHmacSecret();
      final headers = buildSignedHeaders(backendUrl: backendUrl, body: body, secret: hmacSecret);
      final uri = Uri.parse(backendUrl).replace(path: '/report-error');
      _sentThisSession++;
      await _client.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 8));
    } catch (_) {
      // See class doc: must never affect the app itself.
    }
  }

  /// Called once per app start (fire-and-forget) — fetches any remote
  /// override the admin has set for this specific installation and applies
  /// it locally. A `null` override (the normal case) leaves the local
  /// setting untouched.
  Future<void> applyRemoteOverridesIfAny() async {
    try {
      final backendUrl = (await _settings.getTelemetryBackendUrl())?.trim();
      if (backendUrl == null || backendUrl.isEmpty) return;
      final installId = await _settings.getInstallId();
      final uri = Uri.parse(
        backendUrl,
      ).replace(path: '/remote-config', queryParameters: {'installId': installId});
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final forceLocalAi = data['forceLocalAiEnabled'];
      if (forceLocalAi is bool) {
        await _settings.setForceLocalAiEnabled(forceLocalAi);
      }
    } catch (_) {
      // See class doc: must never affect the app itself.
    }
  }
}
