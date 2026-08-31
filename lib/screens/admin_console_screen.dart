import 'package:flutter/material.dart';

import '../services/api_health_service.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';
import '../services/system_diagnostic_service.dart';
import '../services/tls_pinning_service.dart';
import '../theme/jarvis_theme.dart';
import 'log_viewer_screen.dart';

/// Advanced/sensitive settings gated behind the Admin-PIN (see
/// AdminAuthService/AdminGateScreen) — reachable only via the
/// "Admin-Einstellungen" button in the normal settings screen. Filled in
/// section by section across Runde 15's units; other services it needs are
/// constructed inline at point of use here, matching the rest of this
/// app's screens-navigated-from-settings convention rather than growing
/// this constructor with every new section.
///
/// Unlike the normal settings screen (one shared "Speichern" button for
/// every field on the page), each section here saves independently — this
/// screen is reached far less often, and a single shared save button would
/// mean re-navigating through the PIN gate just to tweak one field.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  final _aiBackendCtrl = TextEditingController();
  final _aiHmacSecretCtrl = TextEditingController();
  final _certPinsCtrl = TextEditingController();
  final _systemPromptOverrideCtrl = TextEditingController();
  final _tlsPinning = TlsPinningService();
  final _apiHealth = ApiHealthService();
  String _aiModel = 'openai';
  double _aiTemperature = 0.3;
  int _maxHistoryTurns = 8;
  String _aiModelTier = 'smart';
  int _todaysRequestCount = 0;
  ApiHealthResult? _healthResult;
  bool _checkingHealth = false;
  List<DiagnosticResult>? _diagnosticResults;
  bool _runningDiagnostic = false;
  bool _checkingCertPin = false;
  bool _savingServerSection = false;
  bool _savingBehaviorSection = false;

  static const _aiModels = {
    'openai': 'ChatGPT (Standard)',
    'mistral': 'Mistral',
    'llama': 'Llama',
  };

  static const _aiModelTiers = {
    'smart': 'Intelligent',
    'fast': 'Schnell',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _aiBackendCtrl.text = await widget.settings.getAiBackendUrl() ?? '';
    _aiHmacSecretCtrl.text = await widget.settings.getAiHmacSecret() ?? '';
    _certPinsCtrl.text = (await widget.settings.getCertPins()).join('\n');
    _aiModel = await widget.settings.getAiModel();
    _systemPromptOverrideCtrl.text = await widget.settings.getSystemPromptOverride() ?? '';
    _aiTemperature = await widget.settings.getAiTemperature();
    _maxHistoryTurns = await widget.settings.getMaxHistoryTurns();
    _aiModelTier = await widget.settings.getAiModelTier();
    _todaysRequestCount = await widget.settings.getAiRequestCountToday();
    if (mounted) setState(() {});
  }

  Future<void> _checkHealth() async {
    setState(() => _checkingHealth = true);
    final certPins = _certPinsCtrl.text
        .split(RegExp(r'[\n,]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final result = await _apiHealth.check(_aiBackendCtrl.text.trim(), certPins: certPins);
    if (!mounted) return;
    setState(() {
      _healthResult = result;
      _checkingHealth = false;
    });
  }

  Future<void> _runDiagnostic() async {
    setState(() => _runningDiagnostic = true);
    final results = await SystemDiagnosticService(settings: widget.settings).runSelfCheck();
    if (!mounted) return;
    setState(() {
      _diagnosticResults = results;
      _runningDiagnostic = false;
    });
  }

  Future<void> _saveBehaviorSection() async {
    setState(() => _savingBehaviorSection = true);
    final override = _systemPromptOverrideCtrl.text.trim();
    if (override.isEmpty) {
      await widget.settings.clearSystemPromptOverride();
    } else {
      await widget.settings.setSystemPromptOverride(override);
    }
    await widget.settings.setAiTemperature(_aiTemperature);
    await widget.settings.setMaxHistoryTurns(_maxHistoryTurns);
    if (!mounted) return;
    setState(() => _savingBehaviorSection = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert.')));
  }

  Future<void> _saveServerSection() async {
    setState(() => _savingServerSection = true);
    await widget.settings.setAiBackendUrl(_aiBackendCtrl.text.trim());
    if (_aiHmacSecretCtrl.text.trim().isEmpty) {
      await widget.settings.clearAiHmacSecret();
    } else {
      await widget.settings.setAiHmacSecret(_aiHmacSecretCtrl.text.trim());
    }
    final certPins = _certPinsCtrl.text
        .split(RegExp(r'[\n,]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    await widget.settings.setCertPins(certPins);
    await widget.settings.setAiModel(_aiModel);
    await widget.settings.setAiModelTier(_aiModelTier);
    if (!mounted) return;
    setState(() => _savingServerSection = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert.')));
  }

  /// Trust-on-first-use helper: connects once to the configured AI-backend
  /// host to read its currently-presented certificate's SPKI pin, then lets
  /// the user review and explicitly add it to the pin list — pinning only
  /// activates once at least one pin is saved (see TlsPinningService).
  Future<void> _fetchCurrentPin() async {
    final host = Uri.tryParse(_aiBackendCtrl.text.trim())?.host;
    if (host == null || host.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte zuerst eine gültige KI-Server-Adresse eintragen.')));
      return;
    }
    setState(() => _checkingCertPin = true);
    final pin = await _tlsPinning.currentPin(host);
    if (!mounted) return;
    setState(() => _checkingCertPin = false);
    if (pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fingerabdruck konnte nicht ermittelt werden (Server nicht erreichbar, oder im Web-Build, wo das '
            'aus dem Browser heraus technisch nicht möglich ist).',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aktueller Zertifikats-Fingerabdruck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Für $host:'),
            const SizedBox(height: 8),
            SelectableText(pin, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 12),
            const Text(
              'Nur übernehmen, wenn du dieser Verbindung gerade vertraust (z. B. direkt nach dem Deploy). '
              'Rotiert Cloudflare später das Zertifikat, muss hier ein neuer Fingerabdruck ergänzt werden, '
              'sonst verweigert die App die Verbindung.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Schließen')),
          TextButton(
            onPressed: () {
              final existing = _certPinsCtrl.text.trim();
              _certPinsCtrl.text = existing.isEmpty ? pin : '$existing\n$pin';
              Navigator.pop(dialogContext);
            },
            child: const Text('Als Pin übernehmen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin-Konsole')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('KI-Verhalten', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Nur wenn eine eigene KI-Server-Adresse eingetragen ist (siehe unten) — der kostenlose Gratis-'
            'Fallback übernimmt nur den Prompt, keine Temperatur.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _systemPromptOverrideCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'System-Prompt (überschreibt JARVIS\' Standard-Persönlichkeit komplett)',
              helperText:
                  'Leer lassen, um JARVIS\' normale Persönlichkeit/Persona/Sarkasmus-Einstellung zu behalten. '
                  'Gilt nur für normale Gespräche, nicht für Textadventure/RPG/Tagebuch/Benachrichtigungs-Digest.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _systemPromptOverrideCtrl.clear()),
              child: const Text('Zurücksetzen'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Temperatur: ${_aiTemperature.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
          Slider(
            value: _aiTemperature,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: _aiTemperature.toStringAsFixed(2),
            onChanged: (value) => setState(() => _aiTemperature = value),
          ),
          const Text(
            '0,0 = präzise/vorhersagbar, 1,0 = kreativer/verspielter.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text('Kontext-Länge: $_maxHistoryTurns Gesprächsrunden', style: const TextStyle(fontSize: 12)),
          Slider(
            value: _maxHistoryTurns.toDouble(),
            min: 2,
            max: 20,
            divisions: 18,
            label: '$_maxHistoryTurns',
            onChanged: (value) => setState(() => _maxHistoryTurns = value.round()),
          ),
          const Text(
            'Wie viele vergangene Gesprächsrunden JARVIS sich merkt. Mehr = besserer Kontext bei '
            'Rückfragen, aber längere/teurere Anfragen an die KI.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-behavior-section'),
            onPressed: _savingBehaviorSection ? null : _saveBehaviorSection,
            child: const Text('Speichern'),
          ),
          const SizedBox(height: 24),
          Text('KI-Server & Sicherheit', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Aus den normalen Einstellungen hierher verschoben — sensible/fortgeschrittene Werte.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aiBackendCtrl,
            decoration: const InputDecoration(
              labelText: 'KI-Server-Adresse (für freie Gespräche)',
              helperText: 'Die Worker-URL aus der Cloudflare-Bereitstellung, siehe README',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _aiHmacSecretCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'KI-Server-Schlüssel (Request-Signierung)',
              helperText:
                  'Optional. Muss exakt mit dem HMAC_SECRET im Worker übereinstimmen (siehe README) — '
                  'sobald dort gesetzt, lehnt der Worker unsignierte/gefälschte Anfragen ab.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _certPinsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'TLS-Zertifikat-Pins (Certificate Pinning)',
              helperText:
                  'Optional, ein Fingerabdruck pro Zeile. Leer = normale TLS-Prüfung (aus). Nur auf Handy/Desktop '
                  'wirksam, nicht im Web-Build. Rotiert das Zertifikat, verweigert die App die Verbindung, bis '
                  'hier ein neuer Fingerabdruck ergänzt wird — deshalb am besten zwei Pins gleichzeitig pflegen.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _checkingCertPin ? null : _fetchCurrentPin,
            icon: _checkingCertPin
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.fingerprint),
            label: const Text('Aktuellen Fingerabdruck anzeigen'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _aiModel,
            decoration: const InputDecoration(
              labelText: 'KI-Modell (kostenlos, ohne Server-Adresse)',
              helperText: 'Nur wenn oben keine eigene KI-Server-Adresse eingetragen ist',
              border: OutlineInputBorder(),
            ),
            items: _aiModels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _aiModel = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _aiModelTier,
            decoration: const InputDecoration(
              labelText: 'Modell-Geschwindigkeit (eigener KI-Server)',
              helperText: 'Nur wirksam mit eigener KI-Server-Adresse oben — "Schnell" nutzt ein kleineres, '
                  'schnelleres Modell auf Kosten der Antwortqualität',
              border: OutlineInputBorder(),
            ),
            items: _aiModelTiers.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _aiModelTier = value);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-server-section'),
            onPressed: _savingServerSection ? null : _saveServerSection,
            child: const Text('Speichern'),
          ),
          const SizedBox(height: 24),
          Text('System-Status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Anfragen heute: App-interner Zähler, kein echtes Anbieter-Kontingent (Cloudflare zeigt Workers AI '
            'keine Kontingent-Daten gegenüber dem Worker an).',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text('Anfragen heute: $_todaysRequestCount', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _checkingHealth ? null : _checkHealth,
            icon: _checkingHealth
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.monitor_heart_outlined),
            label: const Text('Latenz jetzt prüfen'),
          ),
          if (_healthResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _healthResult!.reachable
                  ? 'Online, ${_healthResult!.latency?.inMilliseconds}ms'
                  : 'Nicht erreichbar${_healthResult!.error != null ? ': ${_healthResult!.error}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          Text('Entwickler-Tools', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _runningDiagnostic ? null : _runDiagnostic,
            icon: _runningDiagnostic
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.health_and_safety_outlined),
            label: const Text('Selbsttest ausführen'),
          ),
          if (_diagnosticResults != null) ...[
            const SizedBox(height: 8),
            ..._diagnosticResults!.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: r.ok ? Colors.green : JarvisColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.label, style: const TextStyle(fontSize: 13)),
                          if (r.detail != null)
                            Text(
                              r.detail!,
                              style: const TextStyle(fontSize: 11, color: JarvisColors.mutedForeground),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LogViewerScreen(logService: LogService(), liveMode: true),
              ),
            ),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Live-Log-Viewer öffnen'),
          ),
        ],
      ),
    );
  }
}
