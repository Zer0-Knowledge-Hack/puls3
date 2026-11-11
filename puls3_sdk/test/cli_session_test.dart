import 'dart:convert';
import 'dart:io';

import 'package:puls3_client/puls3_client.dart'
    show
        RefreshAuthKeyResult,
        SerializableException,
        ServerpodClientNetworkException;
import 'package:puls3_sdk/puls3_sdk.dart';
import 'package:test/test.dart';

/// What the server answers to a refused refresh token.
final class _Refused extends SerializableException {}

/// A refresh endpoint that rotates `r0` to `r1` to `r2`... and remembers
/// every token it was shown.
final class _FakeServer {
  _FakeServer();

  Object? error;
  final shown = <String>[];
  var _next = 1;

  Future<RefreshedTokens> refresh(String token) async {
    shown.add(token);
    final failure = error;
    if (failure != null) throw failure;
    final n = _next++;
    return (
      accessToken: 'access-$n',
      accessTokenExpiresAt: DateTime.utc(2026, 11, 11, 12, 10),
      refreshToken: 'refresh-$n',
    );
  }
}

void main() {
  late Directory dir;
  late File file;
  late _FakeServer server;
  var now = DateTime.utc(2026, 11, 11, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('puls3_session_');
    file = File('${dir.path}${Platform.pathSeparator}session.json');
    server = _FakeServer();
    now = DateTime.utc(2026, 11, 11, 12);
  });

  tearDown(() => dir.delete(recursive: true));

  Future<CliSession?> load({String? seed}) => CliSession.load(
    file,
    seed: seed,
    refresh: server.refresh,
    now: () => now,
  );

  Map<String, Object?> saved() =>
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

  test('no seed and no saved session is no session', () async {
    expect(await load(), isNull);
    expect(file.existsSync(), isFalse);
  });

  test('a seed is saved in a user-only file', () async {
    final session = await load(seed: 'seed-token');

    expect(session, isNotNull);
    expect(saved()['refreshToken'], 'seed-token');
    if (!Platform.isWindows) {
      // rw------- : only the user can read or write it.
      expect(file.statSync().mode & 0x1FF, 0x180);
    }
  });

  test('the first call refreshes with the seed and saves the rotation', () async {
    final session = (await load(seed: 'seed-token'))!;

    expect(await session.authHeaderValue, 'Bearer access-1');
    expect(server.shown, ['seed-token']);
    expect(saved()['refreshToken'], 'refresh-1');
    if (!Platform.isWindows) {
      expect(file.statSync().mode & 0x1FF, 0x180);
    }
  });

  test('seed, refresh, restart, refresh: the rotation survives', () async {
    final first = (await load(seed: 'seed-token'))!;
    await first.authHeaderValue;

    // A new process, with the same PULS3_REFRESH_TOKEN still set.
    final second = (await load(seed: 'seed-token'))!;
    expect(
      await second.refreshAuthKey(force: true),
      RefreshAuthKeyResult.success,
    );

    // The used seed is never shown again: the server would revoke the
    // session for a reused token.
    expect(server.shown, ['seed-token', 'refresh-1']);
    expect(saved()['refreshToken'], 'refresh-2');
  });

  test('a newly copied seed replaces the saved session', () async {
    final first = (await load(seed: 'seed-token'))!;
    await first.authHeaderValue;

    final second = (await load(seed: 'new-seed'))!;
    await second.refreshAuthKey(force: true);

    expect(server.shown.last, 'new-seed');
  });

  test('a valid access token is not refreshed', () async {
    final session = (await load(seed: 'seed-token'))!;
    await session.authHeaderValue;

    expect(await session.refreshAuthKey(), RefreshAuthKeyResult.skipped);
    expect(await session.authHeaderValue, 'Bearer access-1');
    expect(server.shown, hasLength(1));

    // 30 seconds before it expires, it is refreshed.
    now = DateTime.utc(2026, 11, 11, 12, 9, 40);
    expect(await session.authHeaderValue, 'Bearer access-2');
  });

  test('concurrent calls refresh once', () async {
    final session = (await load(seed: 'seed-token'))!;

    await Future.wait([
      session.authHeaderValue,
      session.authHeaderValue,
      session.authHeaderValue,
    ]);

    expect(server.shown, ['seed-token']);
  });

  test('a refused session is dropped, with its file', () async {
    final session = (await load(seed: 'seed-token'))!;
    server.error = _Refused();

    expect(
      await session.refreshAuthKey(force: true),
      RefreshAuthKeyResult.failedUnauthorized,
    );
    expect(session.isUsable, isFalse);
    expect(file.existsSync(), isFalse);
    expect(await session.authHeaderValue, isNull);
  });

  test('an unreachable server keeps the session for the next try', () async {
    final session = (await load(seed: 'seed-token'))!;
    server.error = ServerpodClientNetworkException('offline');

    expect(
      await session.refreshAuthKey(force: true),
      RefreshAuthKeyResult.failedOther,
    );
    expect(session.isUsable, isTrue);
    expect(saved()['refreshToken'], 'seed-token');
  });

  test('a damaged file is no session, not a crash', () async {
    file.writeAsStringSync('not json');
    expect(await load(), isNull);
  });

  test('no token appears in toString', () async {
    final session = (await load(seed: 'seed-token'))!;
    await session.authHeaderValue;

    expect('$session', isNot(contains('seed-token')));
    expect('$session', isNot(contains('refresh-1')));
    expect('$session', isNot(contains('access-1')));
  });

  group('defaultSessionFile', () {
    test('PULS3_SESSION_FILE wins', () {
      expect(
        defaultSessionFile({
          sessionFileVariable: '/tmp/s.json',
          'HOME': '/home/u',
        }),
        '/tmp/s.json',
      );
    });

    test('nothing set is null', () {
      expect(defaultSessionFile(const {}), isNull);
    });

    test('a POSIX home is ~/.config/puls3/session.json', () {
      if (Platform.isWindows) return;
      expect(
        defaultSessionFile({'HOME': '/home/u'}),
        '/home/u/.config/puls3/session.json',
      );
      expect(
        defaultSessionFile({'HOME': '/home/u', 'XDG_CONFIG_HOME': '/cfg'}),
        '/cfg/puls3/session.json',
      );
    });
  });
}
