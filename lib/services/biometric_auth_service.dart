import 'package:local_auth/local_auth.dart';

/// Wraps local_auth's device biometric prompt (fingerprint/face) as an
/// alternative way into the Admin-Konsole (see AdminAuthService/
/// AdminGateScreen) — the Admin-PIN always remains the required fallback,
/// this is purely an additional, opt-in path once a PIN already exists.
///
/// Same try/catch-to-safe-default convention as AppIntegrityService/
/// NotificationHubService: every method degrades to false rather than
/// throwing, since a biometric prompt can fail for many benign reasons
/// (no hardware, nothing enrolled, user cancels) that shouldn't crash the
/// settings screen or the admin gate.
class BiometricAuthService {
  final _auth = LocalAuthentication();

  /// Whether the device has biometric hardware AND at least one biometric
  /// enrolled — both are required for the settings toggle to make sense.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system biometric prompt. `biometricOnly: true` — this never
  /// falls back to the device's own PIN/pattern/passcode, since that would
  /// just be a second, redundant unlock path alongside the app's own
  /// Admin-PIN.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}
