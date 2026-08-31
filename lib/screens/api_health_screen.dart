import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_health_service.dart';
import '../services/settings_service.dart';
import '../theme/jarvis_theme.dart';
import '../widgets/glass_container.dart';

/// Live status view for the user's own Cloudflare Worker (Einstellungen →
/// API-Health-Monitor): reachability, round-trip latency, and when it was
/// last checked. Deliberately does not show "API quota" — Cloudflare only
/// exposes that in its own account dashboard, not to the Worker itself, so
/// claiming a number here would just be fabricated.
class ApiHealthScreen extends StatefulWidget {
  const ApiHealthScreen({super.key, required this.apiHealth, required this.settings});

  final ApiHealthService apiHealth;
  final SettingsService settings;

  @override
  State<ApiHealthScreen> createState() => _ApiHealthScreenState();
}

class _ApiHealthScreenState extends State<ApiHealthScreen> {
  String? _backendUrl;
  ApiHealthResult? _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    final backendUrl = await widget.settings.getAiBackendUrl();
    final certPins = await widget.settings.getCertPins();
    final result = await widget.apiHealth.check(backendUrl ?? '', certPins: certPins);
    if (!mounted) return;
    setState(() {
      _backendUrl = backendUrl;
      _result = result;
      _checking = false;
    });
  }

  Color _statusColor(ApiHealthResult result) => result.reachable ? const Color(0xFF6FCF97) : JarvisColors.error;

  String _statusText(ApiHealthResult result) {
    if (result.error == 'Kein eigener Server konfiguriert.') return 'Kein eigener Server konfiguriert';
    return result.reachable ? 'Erreichbar' : 'Nicht erreichbar';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('API-Health-Monitor'),
        actions: [IconButton(onPressed: _checking ? null : _refresh, icon: const Icon(Icons.refresh), tooltip: 'Jetzt prüfen')],
      ),
      body: result == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: _statusColor(result), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _checking ? 'Prüfe…' : _statusText(result),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: _statusColor(result)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Server: ${(_backendUrl == null || _backendUrl!.isEmpty) ? '— (kostenloser Fallback aktiv) —' : _backendUrl}'),
                      if (result.latency != null) ...[
                        const SizedBox(height: 8),
                        Text('Latenz: ${result.latency!.inMilliseconds} ms'),
                      ],
                      if (result.statusCode != null) ...[
                        const SizedBox(height: 8),
                        Text('HTTP-Status: ${result.statusCode}'),
                      ],
                      if (!result.reachable && result.error != null && result.error != 'Kein eigener Server konfiguriert.') ...[
                        const SizedBox(height: 8),
                        Text('Fehler: ${result.error}', style: const TextStyle(color: JarvisColors.error)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Zuletzt geprüft: ${DateFormat('dd.MM. HH:mm:ss').format(result.checkedAt)}',
                        style: const TextStyle(color: JarvisColors.mutedForeground, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const GlassContainer(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Hinweis: Diese Ansicht prüft nur, ob dein Worker antwortet, und misst die '
                    'Round-Trip-Latenz. Verbrauchte API-Quotas werden von Cloudflare ausschließlich '
                    'im eigenen Account-Dashboard angezeigt — die App selbst hat darauf keinen '
                    'Zugriff und kann sie deshalb hier nicht ehrlich beziffern.',
                    style: TextStyle(color: JarvisColors.mutedForeground, fontSize: 13),
                  ),
                ),
              ],
            ),
    );
  }
}
