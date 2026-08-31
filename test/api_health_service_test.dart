import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jarvis_mobile/services/api_health_service.dart';

void main() {
  test('empty backend URL reports "not configured" without making a request', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('', 200);
    });
    final service = ApiHealthService(unpinnedClientFactory: () => client);

    final result = await service.check('');

    expect(result.reachable, isFalse);
    expect(result.error, 'Kein eigener Server konfiguriert.');
    expect(called, isFalse);
  });

  test('a 200 OPTIONS response reports reachable with status code and latency', () async {
    final client = MockClient((request) async {
      expect(request.method, 'OPTIONS');
      return http.Response('', 200);
    });
    final service = ApiHealthService(unpinnedClientFactory: () => client);

    final result = await service.check('https://example.workers.dev');

    expect(result.reachable, isTrue);
    expect(result.statusCode, 200);
    expect(result.latency, isNotNull);
    expect(result.error, isNull);
  });

  test('a network failure reports unreachable with the error captured', () async {
    final client = MockClient((request) async => throw Exception('connection refused'));
    final service = ApiHealthService(unpinnedClientFactory: () => client);

    final result = await service.check('https://example.workers.dev');

    expect(result.reachable, isFalse);
    expect(result.error, contains('connection refused'));
  });

  test('a slow response that exceeds the timeout reports unreachable', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return http.Response('', 200);
    });
    final service = ApiHealthService(unpinnedClientFactory: () => client);

    final result = await service.check('https://example.workers.dev', timeout: const Duration(milliseconds: 10));

    expect(result.reachable, isFalse);
    expect(result.error, isNotNull);
  });
}
