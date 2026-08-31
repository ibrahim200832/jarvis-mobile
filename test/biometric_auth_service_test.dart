import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/biometric_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // local_auth's platform channel isn't mocked here — these tests exercise
  // the "native side unavailable" degrade-gracefully path (same convention
  // as HomeWidgetService/NotificationHubService), not real biometric
  // hardware, which no test environment has anyway.
  test('canCheckBiometrics() returns false rather than throwing', () async {
    expect(await BiometricAuthService().canCheckBiometrics(), isFalse);
  });

  test('authenticate() returns false rather than throwing', () async {
    expect(await BiometricAuthService().authenticate(reason: 'Test'), isFalse);
  });
}
