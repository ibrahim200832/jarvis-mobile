import 'package:battery_plus/battery_plus.dart';

/// Reads basic on-device info (currently: battery level) for the
/// "geräteinfo"/"akkustand" voice command. Returns null if unavailable
/// (e.g. unsupported browser on web) so callers can show a friendly message.
class DeviceInfoService {
  final _battery = Battery();

  Future<int?> batteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }
}
