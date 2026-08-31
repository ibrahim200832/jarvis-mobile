import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Severity of one logged event — mirrors the common debug/info/warning/
/// error shape without pulling in a full third-party logging package.
enum LogLevel { info, warning, error }

/// One line in the on-device log file: when it happened, how severe it
/// was, which part of the app it came from, and a short message.
class LogEntry {
  LogEntry({required this.timestamp, required this.level, required this.source, required this.message});

  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  /// Single-line, human-readable representation, also the on-disk format —
  /// deliberately plain text (not JSON) so the file itself is directly
  /// readable/greppable if pulled off the device.
  String toLine() => '${timestamp.toIso8601String()}\t${level.name.toUpperCase()}\t$source\t$message';

  /// Parses one line written by [toLine]; returns null for anything that
  /// doesn't match (e.g. a stray blank line), so a corrupted/partial file
  /// never crashes the log viewer.
  static LogEntry? tryParse(String line) {
    final parts = line.split('\t');
    if (parts.length < 4) return null;
    final timestamp = DateTime.tryParse(parts[0]);
    final level = LogLevel.values.where((l) => l.name.toUpperCase() == parts[1]).firstOrNull;
    if (timestamp == null || level == null) return null;
    return LogEntry(timestamp: timestamp, level: level, source: parts[2], message: parts.sublist(3).join('\t'));
  }
}

/// Local, on-device crash/error log — a plain text file capped at
/// [maxEntries] lines (oldest dropped first), so `flutter run`-less
/// debugging of a real device is possible: catch Flutter framework errors
/// and uncaught async errors (see main.dart), plus API timeouts/failures
/// logged explicitly from services (see AiChatService), then review them
/// via Einstellungen → Log-Viewer without needing a connected debugger.
///
/// Every public method swallows its own errors — a logger that itself
/// crashes the app it's trying to help debug would be worse than no
/// logger at all.
class LogService {
  // The field is deliberately private while the constructor parameter is
  // deliberately public-named; the analyzer's `this._directoryOverride`
  // shorthand suggestion would make the named parameter private too,
  // breaking every external `directoryOverride: ...` call site.
  // ignore: prefer_initializing_formals
  LogService({Directory? directoryOverride}) : _directoryOverride = directoryOverride;

  final Directory? _directoryOverride;
  static const maxEntries = 500;
  static const _fileName = 'jarvis_log.txt';

  Future<File> _logFile() async {
    final dir = _directoryOverride ?? await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> log(LogLevel level, String source, String message) async {
    try {
      final file = await _logFile();
      final entry = LogEntry(timestamp: DateTime.now(), level: level, source: source, message: message);
      await file.create(recursive: true);
      await file.writeAsString('${entry.toLine()}\n', mode: FileMode.append, flush: true);
      await _trimIfNeeded(file);
    } catch (_) {
      // See class doc: logging must never throw.
    }
  }

  Future<void> info(String source, String message) => log(LogLevel.info, source, message);
  Future<void> warning(String source, String message) => log(LogLevel.warning, source, message);
  Future<void> error(String source, String message) => log(LogLevel.error, source, message);

  /// Newest entries first.
  Future<List<LogEntry>> readAll() async {
    try {
      final file = await _logFile();
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      return lines.map(LogEntry.tryParse).whereType<LogEntry>().toList().reversed.toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clear() async {
    try {
      final file = await _logFile();
      if (await file.exists()) await file.writeAsString('');
    } catch (_) {
      // See class doc: logging must never throw.
    }
  }

  Future<void> _trimIfNeeded(File file) async {
    final lines = await file.readAsLines();
    if (lines.length <= maxEntries) return;
    final trimmed = lines.sublist(lines.length - maxEntries);
    await file.writeAsString('${trimmed.join('\n')}\n');
  }
}
