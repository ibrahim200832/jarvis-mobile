import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/request_signing_service.dart';

void main() {
  final signer = RequestSigningService();

  group('sign', () {
    test('matches an independently computed reference HMAC-SHA256 (cross-checked against Node crypto)', () {
      final result = signer.sign(
        secret: 'my-test-secret',
        method: 'POST',
        path: '/',
        body: '{"message":"hallo"}',
        now: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
        nonceOverride: 'fixed-nonce-value',
      );
      expect(result.timestamp, '1700000000');
      expect(result.nonce, 'fixed-nonce-value');
      expect(result.signature, '5909fb334173112ca0190804413b7bb251735b08a9119c43a9eed7612ffc3fc7');
    });

    test('changing the body changes the signature', () {
      final a = signer.sign(secret: 's', method: 'POST', path: '/', body: 'one', nonceOverride: 'n');
      final b = signer.sign(secret: 's', method: 'POST', path: '/', body: 'two', nonceOverride: 'n');
      expect(a.signature, isNot(b.signature));
    });

    test('changing the secret changes the signature', () {
      final a = signer.sign(secret: 'secret-a', method: 'POST', path: '/', body: 'x', nonceOverride: 'n');
      final b = signer.sign(secret: 'secret-b', method: 'POST', path: '/', body: 'x', nonceOverride: 'n');
      expect(a.signature, isNot(b.signature));
    });

    test('changing the path changes the signature', () {
      final a = signer.sign(secret: 's', method: 'POST', path: '/a', body: 'x', nonceOverride: 'n');
      final b = signer.sign(secret: 's', method: 'POST', path: '/b', body: 'x', nonceOverride: 'n');
      expect(a.signature, isNot(b.signature));
    });

    test('changing the nonce changes the signature (even with everything else identical)', () {
      final a = signer.sign(secret: 's', method: 'POST', path: '/', body: 'x', nonceOverride: 'nonce-1');
      final b = signer.sign(secret: 's', method: 'POST', path: '/', body: 'x', nonceOverride: 'nonce-2');
      expect(a.signature, isNot(b.signature));
    });

    test('two calls without an explicit nonce produce different random nonces', () {
      final a = signer.sign(secret: 's', method: 'POST', path: '/', body: 'x');
      final b = signer.sign(secret: 's', method: 'POST', path: '/', body: 'x');
      expect(a.nonce, isNot(b.nonce));
    });

    test('toHeaders() produces the three expected header names', () {
      final result = signer.sign(secret: 's', method: 'POST', path: '/', body: 'x', nonceOverride: 'n');
      final headers = result.toHeaders();
      expect(headers.keys, containsAll(['X-Jarvis-Timestamp', 'X-Jarvis-Nonce', 'X-Jarvis-Signature']));
      expect(headers['X-Jarvis-Nonce'], 'n');
    });
  });
}
