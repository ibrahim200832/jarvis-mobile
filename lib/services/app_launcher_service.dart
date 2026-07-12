import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

/// Lists and opens installed apps by voice, replacing the desktop
/// `os.startfile` / `subprocess` app-opening commands (Android only —
/// iOS and the web don't allow third-party apps to enumerate or launch
/// each other).
class AppLauncherService {
  List<AppInfo>? _cache;

  Future<List<AppInfo>> installedApps({bool refresh = false}) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw Exception('Apps öffnen wird auf dieser Plattform aus Sicherheitsgründen nicht unterstützt.');
    }
    if (_cache != null && !refresh) return _cache!;
    _cache = await InstalledApps.getInstalledApps(excludeSystemApps: true, withIcon: true);
    return _cache!;
  }

  Future<AppInfo?> findByName(String name) async {
    final apps = await installedApps();
    final needle = name.toLowerCase().trim();
    for (final app in apps) {
      if (app.name.toLowerCase() == needle) return app;
    }
    for (final app in apps) {
      if (app.name.toLowerCase().contains(needle)) return app;
    }
    return null;
  }

  Future<bool> open(String packageName) async {
    final ok = await InstalledApps.startApp(packageName);
    return ok ?? false;
  }
}
