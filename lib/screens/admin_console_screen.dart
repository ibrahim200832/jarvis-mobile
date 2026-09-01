import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_auth_service.dart';
import '../services/api_health_service.dart';
import '../services/backup_export_service.dart';
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
  const AdminConsoleScreen({
    super.key,
    required this.settings,
    required this.onClearAiMemory,
    required this.adminAuth,
  });

  final SettingsService settings;

  /// Empties CommandRouter's rolling AI conversation history — routed in
  /// from home_screen.dart via SettingsScreen, since the router (not this
  /// screen) is what actually holds it.
  final Future<void> Function() onClearAiMemory;

  /// The same instance SettingsScreen used to unlock this screen — needed
  /// here for the idle-auto-logout timer and the "Zugang & Sicherheit"
  /// section's password-change/Zugriffs-Log features.
  final AdminAuthService adminAuth;

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
  final _backup = BackupExportService();
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
  bool _clearingAiMemory = false;
  bool _runningBackup = false;
  ThemeVariant _themeVariant = ThemeVariant.gold;
  bool _forceLocalAiEnabled = false;
  bool _discordWebhookEnabled = false;
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _newPasswordConfirmCtrl = TextEditingController();
  bool _hasAdminCredentials = false;
  bool _changingPassword = false;
  List<LogEntry> _recentLogins = [];

  static const _aiModels = {
    'openai': 'ChatGPT (Standard)',
    'mistral': 'Mistral',
    'llama': 'Llama',
  };

  static const _aiModelTiers = {'smart': 'Intelligent', 'fast': 'Schnell'};

  @override
  void initState() {
    super.initState();
    widget.adminAuth.onIdleTimeout = () {
      if (mounted) Navigator.of(context).pop();
    };
    widget.adminAuth.recordActivity();
    _load();
  }

  @override
  void dispose() {
    widget.adminAuth.stopIdleTimeout();
    super.dispose();
  }

  Future<void> _load() async {
    _aiBackendCtrl.text = await widget.settings.getAiBackendUrl() ?? '';
    _aiHmacSecretCtrl.text = await widget.settings.getAiHmacSecret() ?? '';
    _certPinsCtrl.text = (await widget.settings.getCertPins()).join('\n');
    _aiModel = await widget.settings.getAiModel();
    _systemPromptOverrideCtrl.text =
        await widget.settings.getSystemPromptOverride() ?? '';
    _aiTemperature = await widget.settings.getAiTemperature();
    _maxHistoryTurns = await widget.settings.getMaxHistoryTurns();
    _aiModelTier = await widget.settings.getAiModelTier();
    _todaysRequestCount = await widget.settings.getAiRequestCountToday();
    _themeVariant = await widget.settings.getThemeVariant();
    _forceLocalAiEnabled = await widget.settings.getForceLocalAiEnabled();
    _discordWebhookEnabled = await widget.settings.getDiscordWebhookEnabled();
    _hasAdminCredentials = await widget.settings.hasAdminCredentials();
    _recentLogins = await widget.adminAuth.recentSuccessfulLogins();
    if (mounted) setState(() {});
  }

  /// Persists the choice AND updates the live app immediately via the
  /// shared notifier — see main.dart's JarvisApp, which listens to it.
  Future<void> _setThemeVariant(ThemeVariant variant) async {
    setState(() => _themeVariant = variant);
    await widget.settings.setThemeVariant(variant);
    themeVariantNotifier.value = variant;
  }

  Future<void> _checkHealth() async {
    setState(() => _checkingHealth = true);
    final certPins = _certPinsCtrl.text
        .split(RegExp(r'[\n,]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final result = await _apiHealth.check(
      _aiBackendCtrl.text.trim(),
      certPins: certPins,
    );
    if (!mounted) return;
    setState(() {
      _healthResult = result;
      _checkingHealth = false;
    });
  }

  Future<void> _runDiagnostic() async {
    setState(() => _runningDiagnostic = true);
    final results = await SystemDiagnosticService(
      settings: widget.settings,
    ).runSelfCheck();
    if (!mounted) return;
    setState(() {
      _diagnosticResults = results;
      _runningDiagnostic = false;
    });
  }

  /// Irreversible (the router simply forgets what was said so far), so a
  /// confirmation dialog goes first — unlike the section "Speichern"
  /// buttons above, which only ever overwrite settings the user just typed.
  Future<void> _clearAiMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('KI-Gedächtnis löschen?'),
        content: const Text(
          'JARVIS vergisst den bisherigen Gesprächsverlauf. Das kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearingAiMemory = true);
    await widget.onClearAiMemory();
    if (!mounted) return;
    setState(() => _clearingAiMemory = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('KI-Gedächtnis gelöscht.')));
  }

  /// Mirrors the existing chat command "erstelle jetzt ein backup" —
  /// same BackupExportService, just reachable without going through the AI.
  Future<void> _runBackupNow() async {
    setState(() => _runningBackup = true);
    try {
      await _backup.exportNow();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup erstellt.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _runningBackup = false);
    }
  }

  /// Self-service password change — unlike the initial setup in the
  /// (ungated) Einstellungen screen, this proves the current password
  /// first, since it's reachable while already inside the console.
  Future<void> _changePassword() async {
    final current = _currentPasswordCtrl.text;
    final newPassword = _newPasswordCtrl.text;
    final confirm = _newPasswordConfirmCtrl.text;
    if (current.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte aktuelles und neues Passwort eingeben.'),
        ),
      );
      return;
    }
    if (newPassword != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die beiden neuen Passwörter stimmen nicht überein.'),
        ),
      );
      return;
    }
    setState(() => _changingPassword = true);
    final username = await widget.settings.getAdminUsername();
    final currentCorrect =
        username != null &&
        await widget.settings.verifyAdminCredentials(username, current);
    if (!currentCorrect) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktuelles Passwort ist falsch.')),
      );
      return;
    }
    await widget.settings.setAdminCredentials(username, newPassword);
    if (!mounted) return;
    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _newPasswordConfirmCtrl.clear();
    setState(() => _changingPassword = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Passwort geändert.')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Gespeichert.')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Gespeichert.')));
  }

  /// Trust-on-first-use helper: connects once to the configured AI-backend
  /// host to read its currently-presented certificate's SPKI pin, then lets
  /// the user review and explicitly add it to the pin list — pinning only
  /// activates once at least one pin is saved (see TlsPinningService).
  Future<void> _fetchCurrentPin() async {
    final host = Uri.tryParse(_aiBackendCtrl.text.trim())?.host;
    if (host == null || host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte zuerst eine gültige KI-Server-Adresse eintragen.',
          ),
        ),
      );
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
            SelectableText(
              pin,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Schließen'),
          ),
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
    final palette = Theme.of(context).extension<JarvisPaletteExtension>()!;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => widget.adminAuth.recordActivity(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Admin-Konsole')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'KI-Verhalten',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
                labelText:
                    'System-Prompt (überschreibt JARVIS\' Standard-Persönlichkeit komplett)',
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
                onPressed: () =>
                    setState(() => _systemPromptOverrideCtrl.clear()),
                child: const Text('Zurücksetzen'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Temperatur: ${_aiTemperature.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
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
            Text(
              'Kontext-Länge: $_maxHistoryTurns Gesprächsrunden',
              style: const TextStyle(fontSize: 12),
            ),
            Slider(
              value: _maxHistoryTurns.toDouble(),
              min: 2,
              max: 20,
              divisions: 18,
              label: '$_maxHistoryTurns',
              onChanged: (value) =>
                  setState(() => _maxHistoryTurns = value.round()),
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
            Text(
              'KI-Server & Sicherheit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
                helperText:
                    'Die Worker-URL aus der Cloudflare-Bereitstellung, siehe README',
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint),
              label: const Text('Aktuellen Fingerabdruck anzeigen'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _aiModel,
              decoration: const InputDecoration(
                labelText: 'KI-Modell (kostenlos, ohne Server-Adresse)',
                helperText:
                    'Nur wenn oben keine eigene KI-Server-Adresse eingetragen ist',
                border: OutlineInputBorder(),
              ),
              items: _aiModels.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
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
                helperText:
                    'Nur wirksam mit eigener KI-Server-Adresse oben — "Schnell" nutzt ein kleineres, '
                    'schnelleres Modell auf Kosten der Antwortqualität',
                border: OutlineInputBorder(),
              ),
              items: _aiModelTiers.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
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
            Text(
              'System-Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Anfragen heute: App-interner Zähler, kein echtes Anbieter-Kontingent (Cloudflare zeigt Workers AI '
              'keine Kontingent-Daten gegenüber dem Worker an).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Anfragen heute: $_todaysRequestCount',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkingHealth ? null : _checkHealth,
              icon: _checkingHealth
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
            Text(
              'System-Befehle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _clearingAiMemory ? null : _clearAiMemory,
              icon: _clearingAiMemory
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_alt_outlined),
              label: const Text('KI-Gedächtnis löschen'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _runningBackup ? null : _runBackupNow,
              icon: _runningBackup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_outlined),
              label: const Text('Backup jetzt ausführen'),
            ),
            const SizedBox(height: 24),
            Text(
              'Entwickler-Tools',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _runningDiagnostic ? null : _runDiagnostic,
              icon: _runningDiagnostic
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
                        r.ok
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: r.ok ? Colors.green : palette.error,
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.mutedForeground,
                                ),
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
                  builder: (_) =>
                      LogViewerScreen(logService: LogService(), liveMode: true),
                ),
              ),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Live-Log-Viewer öffnen'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lokale KI erzwingen'),
              subtitle: const Text(
                'Antworten kommen ausschließlich vom Offline-Modell — ohne installiertes Modell gibt es eine '
                'klare Fehlermeldung statt einer stillen Cloud-Anfrage.',
              ),
              value: _forceLocalAiEnabled,
              onChanged: (value) async {
                setState(() => _forceLocalAiEnabled = value);
                await widget.settings.setForceLocalAiEnabled(value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Discord-Bot-Versand'),
              subtitle: const Text(
                'Vorbereitet, noch nicht angebunden — sendet noch keine Nachrichten.',
              ),
              value: _discordWebhookEnabled,
              onChanged: (value) async {
                setState(() => _discordWebhookEnabled = value);
                await widget.settings.setDiscordWebhookEnabled(value);
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Erscheinungsbild',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeVariant>(
              segments: const [
                ButtonSegment(
                  value: ThemeVariant.gold,
                  label: Text('Gold'),
                  icon: Icon(Icons.circle, color: JarvisColors.accent),
                ),
                ButtonSegment(
                  value: ThemeVariant.cyan,
                  label: Text('Dark Cyan'),
                  icon: Icon(Icons.circle, color: JarvisCyanColors.accent),
                ),
              ],
              selected: {_themeVariant},
              onSelectionChanged: (selection) =>
                  _setThemeVariant(selection.first),
            ),
            const SizedBox(height: 24),
            Text(
              'Zugang & Sicherheit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!_hasAdminCredentials)
              const Text(
                'Noch keine Zugangsdaten eingerichtet — leg sie zuerst unter Einstellungen → Admin-Zugang an.',
                style: TextStyle(fontSize: 12),
              )
            else ...[
              Text(
                'Passwort ändern',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Aktuelles Passwort',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Neues Passwort'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordConfirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Neues Passwort bestätigen',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('change-admin-password'),
                onPressed: _changingPassword ? null : _changePassword,
                child: const Text('Passwort ändern'),
              ),
            ],
            const SizedBox(height: 16),
            Text('Zugriffs-Log', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text(
              'Die letzten erfolgreichen Anmeldungen an der Admin-Konsole.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_recentLogins.isEmpty)
              Text(
                'Noch keine Anmeldung protokolliert.',
                style: TextStyle(fontSize: 12, color: palette.mutedForeground),
              )
            else
              ..._recentLogins.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${DateFormat('dd.MM. HH:mm:ss').format(entry.timestamp)} — ${entry.message}',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.mutedForeground,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
