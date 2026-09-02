import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/telemetry_admin_service.dart';
import '../theme/jarvis_theme.dart';

/// Admin-Konsole: lists every installation that has ever reported an error
/// or checked in (Runde 21) — reachable by owner and helper accounts alike,
/// same as the rest of the console. Tapping one opens its recent errors and
/// a control to remotely force "Lokale KI erzwingen" on/off for just that
/// installation.
class TelemetryScreen extends StatefulWidget {
  const TelemetryScreen({super.key, required this.telemetryAdmin});

  final TelemetryAdminService telemetryAdmin;

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  List<InstallSummary> _installs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final installs = await widget.telemetryAdmin.listInstalls();
    if (!mounted) return;
    setState(() {
      _installs = installs;
      _loading = false;
    });
  }

  String _shortId(String id) => id.length <= 12 ? id : '${id.substring(0, 12)}…';

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<JarvisPaletteExtension>()!;
    final dateFormat = DateFormat('dd.MM. HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installationen & Fehler anderer Nutzer'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Aktualisieren'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _installs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Installation gemeldet — oder der Telemetrie-Admin-Schlüssel ist hier nicht (korrekt) '
                  'eingetragen (siehe "KI-Server & Sicherheit" oben).',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _installs.length,
              itemBuilder: (context, index) {
                final install = _installs[index];
                return ListTile(
                  title: Text(_shortId(install.installId)),
                  subtitle: Text(
                    '${install.platform ?? '?'} · v${install.appVersion ?? '?'} · zuletzt '
                    '${dateFormat.format(install.lastSeen)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (install.errorCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${install.errorCount}',
                            style: TextStyle(color: palette.error, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _InstallDetailScreen(telemetryAdmin: widget.telemetryAdmin, install: install),
                      ),
                    );
                    if (mounted) unawaited(_load());
                  },
                );
              },
            ),
    );
  }
}

class _InstallDetailScreen extends StatefulWidget {
  const _InstallDetailScreen({required this.telemetryAdmin, required this.install});

  final TelemetryAdminService telemetryAdmin;
  final InstallSummary install;

  @override
  State<_InstallDetailScreen> createState() => _InstallDetailScreenState();
}

class _InstallDetailScreenState extends State<_InstallDetailScreen> {
  List<InstallError> _errors = [];
  bool _loading = true;
  bool? _override;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _override = widget.install.forceLocalAiEnabled;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final errors = await widget.telemetryAdmin.getInstallErrors(widget.install.installId);
    if (!mounted) return;
    setState(() {
      _errors = errors;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final success = await widget.telemetryAdmin.setRemoteOverride(
      widget.install.installId,
      forceLocalAi: _override,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(success ? 'Gespeichert.' : 'Fehlgeschlagen.')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<JarvisPaletteExtension>()!;
    final dateFormat = DateFormat('dd.MM. HH:mm:ss');
    return Scaffold(
      appBar: AppBar(title: Text(widget.install.installId)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Lokale KI erzwingen (fernsteuern)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Keine Übersteuerung')),
              ButtonSegment(value: true, label: Text('An')),
              ButtonSegment(value: false, label: Text('Aus')),
            ],
            selected: {_override},
            onSelectionChanged: (selection) => setState(() => _override = selection.first),
          ),
          const SizedBox(height: 8),
          const Text('Wirkt beim nächsten App-Start dieser Installation.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-remote-override'),
            onPressed: _saving ? null : _save,
            child: const Text('Übernehmen'),
          ),
          const SizedBox(height: 24),
          Text('Letzte Fehler', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_errors.isEmpty)
            Text('Keine Fehler protokolliert.', style: TextStyle(color: palette.mutedForeground))
          else
            ..._errors.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          e.level.toUpperCase(),
                          style: TextStyle(
                            color: e.level == 'error' ? palette.error : Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateFormat.format(e.createdAt),
                          style: TextStyle(color: palette.mutedForeground, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.source, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    Text(e.message, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
