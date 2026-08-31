import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One notification captured by the native NotificationListenerBridgeService
/// (Kotlin side — see android/.../NotificationListenerBridgeService.kt).
class CapturedNotification {
  CapturedNotification({required this.packageName, required this.title, required this.text, required this.postedAt});

  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;

  static CapturedNotification fromJson(Map<String, dynamic> json) => CapturedNotification(
    packageName: json['packageName'] as String? ?? '',
    title: json['title'] as String? ?? '',
    text: json['text'] as String? ?? '',
    postedAt: DateTime.fromMillisecondsSinceEpoch(json['postedAt'] as int? ?? 0),
  );
}

/// Bridges to the native Android NotificationListenerService that captures
/// other apps' notification previews, so JARVIS can summarize them in the
/// evening — Android-only, and a special "Sonderberechtigung" the user
/// grants manually in system settings (`Settings.ACTION_NOTIFICATION_
/// LISTENER_SETTINGS`), NOT a normal permission_handler runtime dialog.
///
/// Degrades gracefully everywhere (empty/false/no-op, never throws) — same
/// try/catch-to-safe-default convention as AppIntegrityService. The native
/// counterpart is a separate build unit, so this works standalone (always
/// reporting "not enabled", capturing nothing) until that lands too.
class NotificationHubService {
  static const _channel = MethodChannel('com.jarvis.mobile.jarvis_mobile/notification_hub');

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isListenerEnabled() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isListenerEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the OS "Benachrichtigungszugriff" settings screen where the user
  /// manually grants (or revokes) this app's listener access — Android has
  /// no way to prompt for this like a normal runtime permission.
  Future<void> openListenerSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openListenerSettings');
    } catch (_) {}
  }

  Future<void> setCaptureEnabled(bool enabled) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setCaptureEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<List<CapturedNotification>> getCaptured() async {
    if (!isSupported) return [];
    try {
      final raw = await _channel.invokeMethod<String>('getCaptured');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => CapturedNotification.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearCaptured() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clearCaptured');
    } catch (_) {}
  }

  /// Pure, local, rule-based digest — no AI call. Groups by app, counts,
  /// shows the most recent preview text per app (truncated). This is the
  /// default digest content, and the only one used when AI summarization
  /// (see AiChatService.askNotificationDigest) is off or no custom backend
  /// is configured — never send this app's real notification previews to
  /// the public pollinations.ai fallback, unlike every other AI feature.
  String buildRuleBasedDigest(List<CapturedNotification> items) {
    if (items.isEmpty) return 'Keine neuen Benachrichtigungen.';
    final byApp = <String, List<CapturedNotification>>{};
    for (final item in items) {
      byApp.putIfAbsent(item.packageName, () => []).add(item);
    }
    final lines = byApp.entries.map((entry) {
      final latest = entry.value.last;
      final preview = latest.text.length > 60 ? '${latest.text.substring(0, 60)}…' : latest.text;
      final count = entry.value.length;
      return '${_appLabel(entry.key)} ($count): $preview';
    });
    return lines.join('\n');
  }

  String _appLabel(String packageName) {
    final segments = packageName.split('.').where((s) => s.isNotEmpty).toList();
    final lastSegment = segments.isEmpty ? packageName : segments.last;
    if (lastSegment.isEmpty) return packageName;
    return lastSegment[0].toUpperCase() + lastSegment.substring(1);
  }
}
