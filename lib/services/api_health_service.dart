import 'package:http/http.dart' as http;

import 'tls_pinning_service.dart';

/// Result of a single reachability/latency probe against the configured AI
/// backend Worker.
class ApiHealthResult {
  ApiHealthResult({required this.reachable, required this.checkedAt, this.statusCode, this.latency, this.error});

  final bool reachable;
  final DateTime checkedAt;
  final int? statusCode;
  final Duration? latency;
  final String? error;
}

/// Pings the user's own Cloudflare Worker to report reachability and
/// round-trip latency (Einstellungen → API-Health-Monitor).
///
/// Uses a plain OPTIONS request: the Worker answers it immediately, before
/// its HMAC-signature check (see worker/ai-proxy.js), so this works
/// regardless of whether request signing is configured — a genuine
/// reachability probe, not a full authenticated call. Reuses
/// [TlsPinningService] so the health check respects the same certificate
/// pin the user configured for real requests.
///
/// Honest limitation: Cloudflare does not expose Workers request-quota
/// usage to the Worker itself, only via the Cloudflare account dashboard —
/// so this service deliberately does not claim to report quota numbers.
class ApiHealthService {
  ApiHealthService({TlsPinningService? tlsPinning, http.Client Function()? unpinnedClientFactory})
    : _tlsPinning = tlsPinning ?? TlsPinningService(),
      _unpinnedClientFactory = unpinnedClientFactory ?? http.Client.new;

  final TlsPinningService _tlsPinning;
  final http.Client Function() _unpinnedClientFactory;

  Future<ApiHealthResult> check(String backendUrl, {List<String> certPins = const [], Duration timeout = const Duration(seconds: 10)}) async {
    final trimmed = backendUrl.trim();
    if (trimmed.isEmpty) {
      return ApiHealthResult(reachable: false, checkedAt: DateTime.now(), error: 'Kein eigener Server konfiguriert.');
    }
    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e) {
      return ApiHealthResult(reachable: false, checkedAt: DateTime.now(), error: 'Ungültige Server-Adresse: $e');
    }

    final client = certPins.isEmpty ? _unpinnedClientFactory() : _tlsPinning.pinnedClient(certPins);
    final stopwatch = Stopwatch()..start();
    try {
      final res = await client.send(http.Request('OPTIONS', uri)).timeout(timeout);
      await res.stream.drain<void>();
      stopwatch.stop();
      return ApiHealthResult(
        reachable: true,
        checkedAt: DateTime.now(),
        statusCode: res.statusCode,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ApiHealthResult(
        reachable: false,
        checkedAt: DateTime.now(),
        latency: stopwatch.elapsed,
        error: e.toString(),
      );
    } finally {
      client.close();
    }
  }
}
