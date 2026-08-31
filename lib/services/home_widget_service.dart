import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Bridges to the native Android home-screen widget (see Einheit 9 —
/// android/.../JarvisWidgetProvider.kt, the native counterpart this pushes
/// data to). Deliberately kIsWeb-gated: home_widget has no web platform
/// implementation at all (Android/iOS only, confirmed from the package's
/// own pubspec), same convention as BackgroundTaskService's workmanager
/// gating — every method below degrades to a predictable no-op on web
/// instead of touching a plugin that isn't wired up for this app's web
/// target.
class HomeWidgetService {
  static const _androidWidgetName = 'JarvisWidgetProvider';
  static const _keyStatusLine = 'status_line';
  static const _keyOpenTodoCount = 'open_todo_count';

  /// Pushes fresh content to the widget's storage and asks Android to
  /// redraw it. Same data DashboardNotificationService already computes
  /// (status/latency line + open-to-do count) — one combined status
  /// string rather than duplicating that formatting here.
  Future<void> refresh({required String statusLine, required int openTodoCount}) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<String>(_keyStatusLine, statusLine);
      await HomeWidget.saveWidgetData<int>(_keyOpenTodoCount, openTodoCount);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (_) {}
  }

  /// Fires whenever the user taps the widget while the app is already
  /// running. Empty (never-emitting) stream on web/unsupported.
  Stream<Uri?> get widgetClicks {
    if (kIsWeb) return const Stream.empty();
    return HomeWidget.widgetClicked;
  }

  /// Checks whether the app was cold-started by tapping the widget —
  /// call once on startup, separately from [widgetClicks] which only
  /// covers taps while already running.
  Future<Uri?> initiallyLaunchedFromWidget() async {
    if (kIsWeb) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  Future<bool> isPinSupported() async {
    if (kIsWeb) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the launcher to offer pinning the widget to the home screen —
  /// only supported on some Android launchers (API 26+); a no-op
  /// everywhere else, including when [isPinSupported] would say false.
  Future<void> requestPin() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.requestPinWidget(androidName: _androidWidgetName);
    } catch (_) {}
  }
}
