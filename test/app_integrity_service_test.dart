import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/app_integrity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('AppIntegrityService', () {
    test('isSupported is false on a non-Android platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppIntegrityService().isSupported, isFalse);
    });

    test('requestIntegrityToken returns null on a non-Android platform without touching the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final token = await AppIntegrityService().requestIntegrityToken(
        nonce: 'some-nonce',
        cloudProjectNumber: '123456789',
      );
      expect(token, isNull);
    });

    test('requestIntegrityToken returns null when no cloud project number is configured', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final token = await AppIntegrityService().requestIntegrityToken(nonce: 'some-nonce', cloudProjectNumber: '');
      expect(token, isNull);
    });

    test('requestIntegrityToken degrades gracefully (returns null, does not throw) when the native side is unavailable', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      // No MethodChannel mock is registered in this test environment, so
      // the underlying platform call fails — requestIntegrityToken must
      // catch that and return null rather than letting the exception
      // propagate.
      final token = await AppIntegrityService().requestIntegrityToken(
        nonce: 'some-nonce',
        cloudProjectNumber: '123456789',
      );
      expect(token, isNull);
    });
  });
}
