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
      expect(auth.webAuthDomain, 'puls3.example');
    });

    test('a static build config without auth gives nulls', () {
      final auth = readAuthConfig('{"apiUrl":"http://localhost:8080"}');
      expect(auth.serverSigningKey, isNull);
      expect(auth.homeDomain, isNull);
      expect(auth.webAuthDomain, isNull);
    });

    test('empty values count as missing', () {
      final auth = readAuthConfig(
        '{"auth":{"serverSigningKey":"","homeDomain":"","webAuthDomain":""}}',
      );
      expect(auth.serverSigningKey, isNull);
      expect(auth.homeDomain, isNull);
      expect(auth.webAuthDomain, isNull);
    });

    test('build-time pins win over the file, blank pins do not', () {
      final auth = readAuthConfig(
        '{"auth":{"serverSigningKey":"GFILE","homeDomain":"file.example",'
        '"webAuthDomain":"file.example"}}',
        overrides: const {
          'serverSigningKey': 'GPINNED',
          'homeDomain': ' ',
          'webAuthDomain': 'pinned.example',
        },
      );
      expect(auth.serverSigningKey, 'GPINNED');
      expect(auth.homeDomain, 'file.example');
      expect(auth.webAuthDomain, 'pinned.example');
    });

    test('a static build gets every value from its pins', () {
      final auth = readAuthConfig(
        '{"apiUrl":"https://x"}',
        overrides: const {
          'serverSigningKey': 'GPINNED',
          'homeDomain': 'pinned.example',
          'webAuthDomain': 'pinned.example',
        },
      );
      expect(auth.serverSigningKey, 'GPINNED');
      expect(auth.homeDomain, 'pinned.example');
      expect(auth.webAuthDomain, 'pinned.example');
    });
  });
}
