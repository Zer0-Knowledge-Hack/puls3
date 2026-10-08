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
}
