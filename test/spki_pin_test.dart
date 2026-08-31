import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/spki_pin.dart';

// A real, well-formed leaf certificate (DER, base64-encoded here for easy
// embedding) — captured from a live TLS handshake during development.
// Used purely as a structural fixture to prove the ASN.1 walker correctly
// locates subjectPublicKeyInfo; it is NOT a pin used anywhere in the app.
const _sampleCertDerBase64 =
    'MIIDdTCCAl2gAwIBAgIQY9OsOKHaubQWR3ihrAQg7DANBgkqhkiG9w0BAQsFADBJMRIwEAYDVQQKEwlBbnRocm9waWMxMzAxBgNVBAMTKkVncmVzcyBHYXRld2F5IFNEUyBJc3N1aW5nIENBIChwcm9kdWN0aW9uKTAeFw0yNjA4MzAyMzQ2MzFaFw0yNjA5MjkyMzQ3MzFaMCgxJjAkBgNVBAMMHSouaWJyYWhpbWNvb2wyODE4LndvcmtlcnMuZGV2MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArM5sUvtE0OheZw/cuNR9OUKFh6RmrggOvqC/ZzepggExK6w5wtfXaWuQsltj5gN5vabuMCLefzj9HYvBlSREzow2xaNBoScAifkpIzdmx6ga2EB/rWiNoAUy3pECc4/O43w7rBA6GiMtAvYU+vcRfVy0ITbEZVGlqbJIJM15k6yAoQqk0UBEWDX/VpVf471ct2idLCi2p9VB+Edxjbj4+hSKamDZkqNVdvOJofvoBp+rst6mIPlK1/YDNAsthOc15epQ85agEBwBNRMR0E4T2ti5+bICjhu7H0Cw6DDvC8wsy/ynKWWWmsVnhXOC6xdfa7a9KzAp4P8I313QlBMGcQIDAQABo3oweDAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwHwYDVR0jBBgwFoAUbmjy/opWUsBiuexocoZ88BhOFQIwMAYDVR0RBCkwJ4IlamFydmlzLWFpLmlicmFoaW1jb29sMjgxOC53b3JrZXJzLmRldjANBgkqhkiG9w0BAQsFAAOCAQEAIfqQr9YP1x53sQnFslFd5cIVKsgS8nYd1TbsU8dTcLJlm9tf1FJhJHjtJxUqfdB6fTV9zRsQToBZ1lFcJeomo8Q8o5UYEr4nXGc7UnoWeVvcM5k1Rr8y8U3Fgwfe8+azYhUUCWXHDjiPHO5R5pwhQ/xASvz3nh88mbRMNH/FxiRanWcscRD5Qnu1afX5insOkAiaN2ORdVwbMoMqw4jVQh5q4+YsVFuArdCr420NFSC+RLPYMaRfWo4GniZhJcbNIP0apT60ABf1y2pE4iW1GQejPPPgg3bYpwTMBieJKvyG224gHJhmcqCjAu8cZT1CzbiBBZjl8+sizR247Cj6Mw==';

// Independently computed reference value (NOT from this Dart code):
// `openssl x509 -in cert.pem -noout -pubkey | openssl pkey -pubin -outform DER \
//    | openssl dgst -sha256 -binary | base64` against the same certificate.
const _expectedSpkiPin = 'RSi7mtdNBxQAWWu0plOTJSNBs87ykp+crnI2CTOqsfs=';

void main() {
  group('spkiSha256Base64FromDer', () {
    test('matches an independently openssl-computed SPKI pin for a real certificate', () {
      final der = Uint8List.fromList(base64.decode(_sampleCertDerBase64));
      expect(spkiSha256Base64FromDer(der), _expectedSpkiPin);
    });

    test('returns null for empty input', () {
      expect(spkiSha256Base64FromDer(Uint8List(0)), isNull);
    });

    test('returns null for garbage/non-DER input', () {
      expect(spkiSha256Base64FromDer(Uint8List.fromList(List.filled(50, 0xFF))), isNull);
    });

    test('returns null for a truncated certificate', () {
      final der = Uint8List.fromList(base64.decode(_sampleCertDerBase64));
      final truncated = Uint8List.sublistView(der, 0, der.length ~/ 2);
      expect(spkiSha256Base64FromDer(truncated), isNull);
    });

    test('is deterministic (same input always gives the same pin)', () {
      final der = Uint8List.fromList(base64.decode(_sampleCertDerBase64));
      expect(spkiSha256Base64FromDer(der), spkiSha256Base64FromDer(der));
    });
  });
}
