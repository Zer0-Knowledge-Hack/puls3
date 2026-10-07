import 'dart:io';

import 'package:puls3_server/src/cors/allowed_origins.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

const _app = 'https://puls3-4lw.pages.dev';
const _development = 'development';
const _production = 'production';

AllowedOrigins _origins(
  Map<String, String> env, {
  String runMode = _production,
}) => AllowedOrigins.fromEnvironment(env, runMode: runMode);

void main() {
  group('AllowedOrigins.fromEnvironment', () {
    test('allows loopback origins in development only', () {
      final development = _origins(const {}, runMode: _development);

      expect(development.configured, isEmpty);
      expect(development.allows('http://localhost:54321'), isTrue);
      expect(development.allows('http://127.0.0.1:8080'), isTrue);
      expect(development.allows('http://[::1]:3000'), isTrue);
      expect(development.allows('https://localhost'), isTrue);
      expect(development.allows(_app), isFalse);

      for (final runMode in [_production, 'staging', 'test']) {
        final origins = _origins(const {}, runMode: runMode);
        expect(
          origins.allows('http://localhost:54321'),
          isFalse,
          reason: runMode,
        );
        expect(origins.allows('http://127.0.0.1:8080'), isFalse);
        expect(origins.allows('http://[::1]:3000'), isFalse);
      }
    });

    test('a listed loopback origin is allowed in production', () {
      final origins = _origins(const {
        'PULS3_ALLOWED_ORIGINS': 'http://localhost:8082',
      });

      expect(origins.allows('http://localhost:8082'), isTrue);
      expect(origins.allows('http://localhost:54321'), isFalse);
    });

    test('reads a comma-separated list and normalizes each origin', () {
      final origins = _origins(const {
        'PULS3_ALLOWED_ORIGINS':
            ' https://PULS3-4lw.pages.dev/ ,,'
            'https://demo.example.com:8443',
      });

      expect(origins.configured, [_app, 'https://demo.example.com:8443']);
      expect(origins.allows(_app), isTrue);
      expect(origins.allows('https://demo.example.com:8443'), isTrue);
    });

    test('drops a default port and duplicate entries', () {
      final origins = _origins(const {
        'PULS3_ALLOWED_ORIGINS':
            'https://puls3-4lw.pages.dev:443,$_app,$_app/,'
            'http://demo.example.com:80',
      });

      expect(origins.configured, [_app, 'http://demo.example.com']);
      expect(origins.allows('https://puls3-4lw.pages.dev:443'), isTrue);
      expect(origins.allows('http://demo.example.com'), isTrue);
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
          () => _origins({'PULS3_ALLOWED_ORIGINS': value}),
          throwsArgumentError,
          reason: value,
        );
      }
    });
  });

  group('AllowedOrigins.allows', () {
    final origins = _origins(const {
      'PULS3_ALLOWED_ORIGINS': _app,
    }, runMode: _development);

    test('matches the exact origin only', () {
      expect(origins.allows('https://PULS3-4lw.pages.dev'), isTrue);
      expect(origins.allows('http://puls3-4lw.pages.dev'), isFalse);
      expect(origins.allows('https://evil.puls3-4lw.pages.dev'), isFalse);
      expect(origins.allows('https://puls3-4lw.pages.dev.evil.com'), isFalse);
      expect(origins.allows('https://puls3-4lw.pages.dev:8443'), isFalse);
    });

    test('rejects hosts that only look like loopback', () {
      for (final value in [
        'http://localhost.evil.com',
        'http://127.0.0.1.evil.com',
        'http://evil.com#localhost',
        'http://localhost@evil.com',
      ]) {
        expect(origins.allows(value), isFalse, reason: value);
      }
    });

    test('rejects opaque, malformed and multi-valued origins', () {
      for (final value in [
        'null',
        '',
        'not a url',
        'file:///tmp',
        '$_app, https://evil.example.com',
      ]) {
        expect(origins.allows(value), isFalse, reason: value);
      }
    });
  });

  group('originGate', () {
    late RelicServer server;
    late HttpClient client;
    late int calls;

    Future<void> start(Middleware gate, {Headers? handlerHeaders}) async {
      final app = RelicApp()
        ..use('/', gate)
        ..any('/**', (req) {
          calls++;
          return Response.ok(
            body: Body.fromString('ok'),
            headers: handlerHeaders,
          );
        });
      server = await app.serve(port: 0);
    }

    setUp(() {
      calls = 0;
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    Future<HttpClientResponse> send(
      String method, {
      List<String> origins = const [],
    }) async {
      final request = await client.openUrl(
        method,
        Uri.parse('http://localhost:${server.port}/health'),
      );
      for (final origin in origins) {
        request.headers.add('origin', origin);
      }
      final response = await request.close();
      await response.drain<void>();
      return response;
    }

    Middleware gate() => originGate(
      _origins(const {'PULS3_ALLOWED_ORIGINS': _app}, runMode: _development),
    );

    test(
      'passes a request without an Origin header through unchanged',
      () async {
        await start(gate());
        final response = await send('POST');

        expect(response.statusCode, 200);
        expect(calls, 1);
        expect(response.headers.value('access-control-allow-origin'), isNull);
      },
    );

    test('echoes an allowed origin and varies on Origin', () async {
      await start(gate());
      final response = await send('POST', origins: [_app]);

      expect(response.statusCode, 200);
      expect(calls, 1);
      expect(response.headers.value('access-control-allow-origin'), _app);
      expect(response.headers['vary'], ['Origin']);
    });

    test('allows a loopback origin in development', () async {
      await start(gate());
      final response = await send('POST', origins: ['http://localhost:61234']);

      expect(response.statusCode, 200);
      expect(
        response.headers.value('access-control-allow-origin'),
        'http://localhost:61234',
      );
    });

    test('rejects a disallowed origin before the handler runs', () async {
      await start(gate());
      final response = await send(
        'POST',
        origins: ['https://evil.example.com'],
      );

      expect(response.statusCode, 403);
      expect(calls, 0);
      expect(response.headers.value('access-control-allow-origin'), isNull);
    });

    test('rejects a request with several Origin headers', () async {
      await start(gate());
      final response = await send(
        'POST',
        origins: [_app, 'https://evil.example.com'],
      );

      expect(response.statusCode, 403);
      expect(calls, 0);
    });

    test('merges Origin into a Vary header set by the handler', () async {
      await start(
        gate(),
        handlerHeaders: Headers.fromMap(const {
          'vary': ['Accept-Encoding'],
        }),
      );
      final response = await send('POST', origins: [_app]);

      final vary = response.headers['vary']!
          .expand((value) => value.split(','))
          .map((field) => field.trim())
          .toList();
      expect(vary, containsAll(['Accept-Encoding', 'Origin']));
      expect(vary.where((field) => field == 'Origin'), hasLength(1));
    });

    test(
      'replaces an Access-Control-Allow-Origin set by the handler',
      () async {
        await start(
          gate(),
          handlerHeaders: Headers.fromMap(const {
            'access-control-allow-origin': ['*'],
          }),
        );
        final response = await send('POST', origins: [_app]);

        expect(response.headers['access-control-allow-origin'], [_app]);
      },
    );

    test('leaves preflight requests to Serverpod', () async {
      await start(gate());
      final response = await send(
        'OPTIONS',
        origins: ['https://evil.example.com'],
      );

      expect(response.statusCode, 200);
      expect(calls, 1);
    });
  });

  group('originGateFromEnvironment (server wiring)', () {
    late RelicServer server;
    late HttpClient client;

    Future<int> status(
      Map<String, String> env,
      String runMode,
      String origin,
    ) async {
      final logged = <String>[];
      final app = RelicApp()
        ..use(
          '/',
          originGateFromEnvironment(env, runMode: runMode, log: logged.add),
        )
        ..any('/**', (req) => Response.ok());
      server = await app.serve(port: 0);
      try {
        final request = await client.postUrl(
          Uri.parse('http://localhost:${server.port}/health/check'),
        );
        request.headers.set('origin', origin);
        final response = await request.close();
        await response.drain<void>();
        expect(logged, hasLength(1));
        return response.statusCode;
      } finally {
        await server.close();
      }
    }

    setUp(() => client = HttpClient());
    tearDown(() => client.close(force: true));

    test('production allows the listed origin and nothing else', () async {
      const env = {'PULS3_ALLOWED_ORIGINS': _app};

      expect(await status(env, _production, _app), 200);
      expect(await status(env, _production, 'http://localhost:5000'), 403);
      expect(await status(env, _production, 'https://evil.example.com'), 403);
    });

    test('development also allows loopback origins', () async {
      expect(
        await status(const {}, _development, 'http://localhost:5000'),
        200,
      );
      expect(await status(const {}, _development, _app), 403);
    });

    test('logs the policy it applies', () {
      final logged = <String>[];
      originGateFromEnvironment(
        const {'PULS3_ALLOWED_ORIGINS': _app},
        runMode: _production,
        log: logged.add,
      );

      expect(logged.single, contains(_app));
      expect(logged.single, contains('loopback not allowed'));
    });

    test('an invalid list throws', () {
      expect(
        () => originGateFromEnvironment(
          const {'PULS3_ALLOWED_ORIGINS': 'https://example.com/app'},
          runMode: _production,
          log: (_) {},
        ),
        throwsArgumentError,
      );
    });
  });
}
