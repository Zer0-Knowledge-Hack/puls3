import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/app_config.dart';

void main() {
  group('resolveApiUrl', () {
    const bundled = '{"apiUrl": "http://localhost:8080"}';

    test('uses the bundled config.json when no override is set', () {
      expect(resolveApiUrl(bundled, override: ''), 'http://localhost:8080');
    });

    test('PULS3_API_URL override wins over config.json', () {
      expect(
        resolveApiUrl(bundled, override: 'https://api.puls3.example/'),
        'https://api.puls3.example/',
      );
    });

    test('a blank override is ignored', () {
      expect(resolveApiUrl(bundled, override: '  '), 'http://localhost:8080');
    });

    test('fails clearly when neither source has a URL', () {
      expect(
        () => resolveApiUrl('{}', override: ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('PULS3_API_URL'),
          ),
        ),
      );
    });

    test('defaults to the compile-time PULS3_API_URL (unset in tests)', () {
      expect(apiUrlOverride, isEmpty);
      expect(resolveApiUrl(bundled), 'http://localhost:8080');
    });
  });

  group('readAuthConfig (#136)', () {
    test('reads the server key and home domain the server publishes', () {
      final auth = readAuthConfig(
        '{"apiUrl":"https://x","auth":{"serverSigningKey":"GSERVER",'
        '"homeDomain":"puls3.example","webAuthDomain":"puls3.example"}}',
      );
      expect(auth.serverSigningKey, 'GSERVER');
      expect(auth.homeDomain, 'puls3.example');
    });

    test('a static build config without auth gives nulls', () {
      final auth = readAuthConfig('{"apiUrl":"http://localhost:8080"}');
      expect(auth.serverSigningKey, isNull);
      expect(auth.homeDomain, isNull);
    });

    test('empty values count as missing', () {
      final auth = readAuthConfig(
        '{"auth":{"serverSigningKey":"","homeDomain":""}}',
      );
      expect(auth.serverSigningKey, isNull);
      expect(auth.homeDomain, isNull);
    });
  });
}
