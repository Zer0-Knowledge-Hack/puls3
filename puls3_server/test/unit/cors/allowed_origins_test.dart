import 'dart:io';

import 'package:puls3_server/src/cors/allowed_origins.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

const _app = 'https://puls3-4lw.pages.dev';

void main() {
  group('AllowedOrigins.fromEnvironment', () {
    test(
      'allows only loopback origins when PULS3_ALLOWED_ORIGINS is unset',
      () {
        final origins = AllowedOrigins.fromEnvironment(const {});

        expect(origins.configured, isEmpty);
        expect(origins.allows('http://localhost:54321'), isTrue);
        expect(origins.allows('http://127.0.0.1:8080'), isTrue);
        expect(origins.allows('http://[::1]:3000'), isTrue);
        expect(origins.allows('https://localhost'), isTrue);
        expect(origins.allows(_app), isFalse);
      },
    );

    test('reads a comma-separated list and normalizes each origin', () {
      final origins = AllowedOrigins.fromEnvironment(const {
        'PULS3_ALLOWED_ORIGINS':
            ' https://PULS3-4lw.pages.dev/ ,,'
            'https://demo.example.com:8443',
      });

      expect(origins.configured, [_app, 'https://demo.example.com:8443']);
      expect(origins.allows(_app), isTrue);
      expect(origins.allows('https://demo.example.com:8443'), isTrue);
      expect(origins.allows('http://localhost:54321'), isTrue);
    });

    test('rejects a value that is not a bare http(s) origin', () {
      for (final value in [
        'puls3-4lw.pages.dev',
        'ftp://files.example.com',
        'https://example.com/app',
        'https://example.com?x=1',
        'https://user@example.com',
        '*',
      ]) {
        expect(
          () =>
              AllowedOrigins.fromEnvironment({'PULS3_ALLOWED_ORIGINS': value}),
          throwsArgumentError,
          reason: value,
        );
      }
    });
  });

  group('AllowedOrigins.allows', () {
    final origins = AllowedOrigins.fromEnvironment(const {
      'PULS3_ALLOWED_ORIGINS': _app,
    });

    test('matches the exact origin only', () {
      expect(origins.allows('https://PULS3-4lw.pages.dev'), isTrue);
      expect(origins.allows('http://puls3-4lw.pages.dev'), isFalse);
      expect(origins.allows('https://evil.puls3-4lw.pages.dev'), isFalse);
      expect(origins.allows('https://puls3-4lw.pages.dev.evil.com'), isFalse);
      expect(origins.allows('https://puls3-4lw.pages.dev:8443'), isFalse);
    });

    test('rejects opaque and malformed origins', () {
      for (final value in ['null', '', 'not a url', 'file:///tmp']) {
        expect(origins.allows(value), isFalse, reason: value);
      }
    });
  });

  group('originGate', () {
    late RelicServer server;
    late HttpClient client;
    late int calls;

    setUp(() async {
      calls = 0;
      final app = RelicApp()
        ..use(
          '/',
          originGate(
            AllowedOrigins.fromEnvironment(const {
              'PULS3_ALLOWED_ORIGINS': _app,
            }),
          ),
        )
        ..any('/**', (req) {
          calls++;
          return Response.ok(body: Body.fromString('ok'));
        });
      server = await app.serve(port: 0);
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    Future<HttpClientResponse> send(String method, {String? origin}) async {
      final request = await client.openUrl(
        method,
        Uri.parse('http://localhost:${server.port}/health'),
      );
      if (origin != null) request.headers.set('origin', origin);
      final response = await request.close();
      await response.drain<void>();
      return response;
    }

    test(
      'passes a request without an Origin header through unchanged',
      () async {
        final response = await send('POST');

        expect(response.statusCode, 200);
        expect(calls, 1);
        expect(response.headers.value('access-control-allow-origin'), isNull);
      },
    );

    test('echoes an allowed origin and varies on Origin', () async {
      final response = await send('POST', origin: _app);

      expect(response.statusCode, 200);
      expect(calls, 1);
      expect(response.headers.value('access-control-allow-origin'), _app);
      expect(response.headers.value('vary'), contains('Origin'));
    });

    test('allows a loopback origin', () async {
      final response = await send('POST', origin: 'http://localhost:61234');

      expect(response.statusCode, 200);
      expect(
        response.headers.value('access-control-allow-origin'),
        'http://localhost:61234',
      );
    });

    test('rejects a disallowed origin before the handler runs', () async {
      final response = await send('POST', origin: 'https://evil.example.com');

      expect(response.statusCode, 403);
      expect(calls, 0);
      expect(response.headers.value('access-control-allow-origin'), isNull);
    });

    test('leaves preflight requests to Serverpod', () async {
      final response = await send(
        'OPTIONS',
        origin: 'https://evil.example.com',
      );

      expect(response.statusCode, 200);
      expect(calls, 1);
    });
  });
}
