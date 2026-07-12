import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String apkUrl;

  UpdateInfo({required this.version, required this.apkUrl});
}

/// Checks a small JSON manifest hosted alongside the website for a newer
/// APK build than the one currently installed, so sideloaded installs (no
/// Play Store) can still be notified about updates.
class UpdateService {
  static const _versionUrl = 'https://ibrahim200832.github.io/jarvis-mobile/downloads/version.json';

  Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await http.get(Uri.parse(_versionUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final latestVersion = json['version'] as String;
      final apkUrl = json['apkUrl'] as String;
      if (_buildNumber(latestVersion) > _buildNumber(info.version)) {
        return UpdateInfo(version: latestVersion, apkUrl: apkUrl);
      }
    } catch (_) {
      // Update checks are best-effort; silently skip on any network/parse error.
    }
    return null;
  }

  int _buildNumber(String version) => int.tryParse(version.split('.').last) ?? 0;
}
