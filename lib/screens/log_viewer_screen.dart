import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';

import '../services/log_service.dart';
import '../theme/jarvis_theme.dart';

/// Shows the local crash/error log (see LogService, main.dart's global
/// error handlers, AiChatService's logged failures) so an issue on a real
/// device can be diagnosed without a connected debugger.
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key, required this.logService, this.liveMode = false});

  final LogService logService;

  /// When true, polls [logService] every couple seconds while this screen
  /// is open instead of relying only on the manual refresh button — used
  /// by the Admin-Konsole's "Live-Log-Viewer" entry point. The normal
  /// entry point from Einstellungen keeps this off (manual refresh only),
  /// unchanged from before.
  final bool liveMode;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<LogEntry> _entries = [];
  bool _loading = true;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.liveMode) {
      // No loading spinner on these periodic refreshes — only the initial
      // load above should show one, otherwise the list would flicker
      // every couple seconds instead of just updating in place.
      _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) => _load(showSpinner: false));
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    final entries = await widget.logService.readAll();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await widget.logService.clear();
    await _load();
  }

  Future<void> _copyAll() async {
    final text = _entries.map((e) => e.toLine()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log in die Zwischenablage kopiert.')));
  }

  Color _colorFor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return JarvisColors.error;
      case LogLevel.warning:
        return JarvisColors.accent;
      case LogLevel.info:
        return JarvisColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM. HH:mm:ss');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.liveMode ? 'Log-Viewer (live)' : 'Log-Viewer'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Aktualisieren'),
          IconButton(onPressed: _entries.isEmpty ? null : _copyAll, icon: const Icon(Icons.copy), tooltip: 'Kopieren'),
          IconButton(onPressed: _entries.isEmpty ? null : _clear, icon: const Icon(Icons.delete_outline), tooltip: 'Leeren'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(child: Text('Keine Log-Einträge vorhanden.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.level.name.toUpperCase(),
                            style: TextStyle(color: _colorFor(entry.level), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateFormat.format(entry.timestamp),
                            style: const TextStyle(color: JarvisColors.mutedForeground, fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.source,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(entry.message, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
