@Tags(['integration'])
library;

import 'dart:io';

import 'package:puls3_server/src/auth/cli_session_policy.dart';
import 'package:puls3_server/src/auth/jwt_refresh_endpoint.dart';
import 'package:puls3_server/src/auth/wallet_idp.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given CLI sessions (#259)', (sessionBuilder, endpoints) {
    late Jwt jwt;

    setUp(() {
      AuthServices.set(tokenManagerBuilders: [JwtConfigFromPasswords()]);
      jwt = AuthServices.getTokenManager<JwtTokenManager>().jwt;
      JwtRefreshEndpoint.debugNow = null;
    });

    tearDown(() async {
      JwtRefreshEndpoint.debugNow = null;
      final session = sessionBuilder.build();
      for (final user in await AuthUser.db.find(session)) {
        await AuthUser.db.deleteWhere(
          session,
          where: (t) => t.id.equals(user.id!),
        );
      }
    });

    /// A signed-in wallet user: its id and a session builder acting as it.
    Future<(UuidValue, TestSessionBuilder)> signedIn() async {
      final user = await const AuthUsers().create(sessionBuilder.build());
      return (
        user.id,
        sessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            user.id.toString(),
            {},
          ),
        ),
      );
    }

    /// The app's own session for [user], as wallet sign-in issues it.
    Future<String> appSession(UuidValue user) async => (await jwt.createTokens(
      sessionBuilder.build(),
      authUserId: user,
      method: WalletIdp.methodName,
    )).refreshToken!;

    Future<AuthSuccess> refresh(String token) => endpoints.jwtRefresh
        .refreshAccessToken(sessionBuilder, refreshToken: token);

    group('own wallet only', () {
      test('every call needs a login', () async {
        Matcher unauthorized() => throwsA(
          isA<NotAuthorizedException>().having(
            (e) => e.reason,
            'reason',
            AuthenticationFailureReason.unauthenticated,
          ),
        );
        await expectLater(
          endpoints.cliSession.create(sessionBuilder),
          unauthorized(),
        );
        await expectLater(
          endpoints.cliSession.list(sessionBuilder),
          unauthorized(),
        );
        await expectLater(
          endpoints.cliSession.revoke(sessionBuilder, 'x'),
          unauthorized(),
        );
      });

      test('no call takes an argument naming a wallet or a user', () {
        // The generated client is what a program can send.
        final client = File(
          '../puls3_client/lib/src/protocol/client.dart',
        ).readAsStringSync();
        final start = client.indexOf('class EndpointCliSession');
        final end = client.indexOf('\n}\n', start);
        final cliSession = client.substring(start, end);

        expect(cliSession, contains('create()'));
        expect(cliSession, contains('list()'));
        expect(cliSession, contains('revoke(String id)'));
        for (final name in ['wallet', 'authUserId', 'userId', 'consumer']) {
          expect(cliSession, isNot(contains(name)), reason: name);
        }
      });

      test('the session is for the caller', () async {
        final (user, caller) = await signedIn();

        final grant = await endpoints.cliSession.create(caller);
        final row = await RefreshToken.db.findById(
          sessionBuilder.build(),
          refreshTokenIdOf(grant.refreshToken)!,
        );

        expect(row!.authUserId, user);
        expect(row.method, cliSessionMethod);
        expect((await refresh(grant.refreshToken)).authUserId, user);
      });

      test('another wallet cannot list or revoke it', () async {
        final (_, alice) = await signedIn();
        final (_, bob) = await signedIn();
        final grant = await endpoints.cliSession.create(alice);

        expect(await endpoints.cliSession.list(bob), isEmpty);
        expect(await endpoints.cliSession.revoke(bob, grant.id), isFalse);
        expect(await endpoints.cliSession.list(alice), hasLength(1));
      });

      test('revoke cannot touch the app session', () async {
        final (user, caller) = await signedIn();
        final app = await appSession(user);

        final appId = refreshTokenIdOf(app)!.uuid;
        expect(await endpoints.cliSession.revoke(caller, appId), isFalse);
        expect(await refresh(app), isA<AuthSuccess>());
      });
    });

    group('revocable on its own', () {
      test('revoking the CLI session leaves the app working', () async {
        final (user, caller) = await signedIn();
        final app = await appSession(user);
        final grant = await endpoints.cliSession.create(caller);

        expect(await endpoints.cliSession.revoke(caller, grant.id), isTrue);

        await expectLater(
          refresh(grant.refreshToken),
          throwsA(isA<RefreshTokenNotFoundException>()),
        );
        expect(await refresh(app), isA<AuthSuccess>());
      });

      test('ending the app session leaves the CLI working', () async {
        final (user, caller) = await signedIn();
        final app = await appSession(user);
        final grant = await endpoints.cliSession.create(caller);

        await jwt.revokeRefreshToken(
          sessionBuilder.build(),
          refreshTokenId: refreshTokenIdOf(app)!,
        );

        await expectLater(
          refresh(app),
          throwsA(isA<RefreshTokenNotFoundException>()),
        );
        expect(await refresh(grant.refreshToken), isA<AuthSuccess>());
      });
    });

    group('shorter, absolute lifetime', () {
      test('a CLI session refreshes until 72 hours after creation', () async {
        final (_, caller) = await signedIn();
        final grant = await endpoints.cliSession.create(caller);
        final created = grant.expiresAt.subtract(cliSessionLifetime);

        JwtRefreshEndpoint.debugNow = () =>
            created.add(const Duration(hours: 71, minutes: 59));
        final refreshed = await refresh(grant.refreshToken);

        expect(refreshed.refreshToken, isNotNull);
      });

      test('past 72 hours it is refused and deleted, even if refreshed '
          'recently', () async {
        final (_, caller) = await signedIn();
        final grant = await endpoints.cliSession.create(caller);
        final created = grant.expiresAt.subtract(cliSessionLifetime);

        // Refreshed one minute before the limit: that does not extend it.
        JwtRefreshEndpoint.debugNow = () =>
            created.add(const Duration(hours: 71, minutes: 59));
        final rotated = (await refresh(grant.refreshToken)).refreshToken!;

        JwtRefreshEndpoint.debugNow = () => grant.expiresAt;
        await expectLater(
          refresh(rotated),
          throwsA(isA<RefreshTokenExpiredException>()),
        );
        expect(
          await RefreshToken.db.findById(
            sessionBuilder.build(),
            UuidValue.withValidation(grant.id),
          ),
          isNull,
        );
      });

      test('an app session of the same age still refreshes', () async {
        final (user, caller) = await signedIn();
        final app = await appSession(user);
        final grant = await endpoints.cliSession.create(caller);

        JwtRefreshEndpoint.debugNow = () =>
            grant.expiresAt.add(const Duration(hours: 1));

        expect(await refresh(app), isA<AuthSuccess>());
      });
    });

    group('listing', () {
      test('lists the caller\'s CLI sessions with no secret', () async {
        final (_, caller) = await signedIn();
        final grant = await endpoints.cliSession.create(caller);

        final sessions = await endpoints.cliSession.list(caller);

        expect(sessions.single.id, grant.id);
        expect(sessions.single.expiresAt, grant.expiresAt);
        expect(
          sessions.single.toJson().keys,
          unorderedEquals(['id', 'createdAt', 'lastUsedAt', 'expiresAt']),
        );
      });

      test('a wallet keeps at most $maxCliSessions; the oldest goes', () async {
        final (_, caller) = await signedIn();
        final grants = [
          for (var i = 0; i <= maxCliSessions; i++)
            await endpoints.cliSession.create(caller),
        ];

        final ids = [
          for (final s in await endpoints.cliSession.list(caller)) s.id,
        ];

        expect(ids, hasLength(maxCliSessions));
        expect(ids, isNot(contains(grants.first.id)));
        expect(ids, contains(grants.last.id));
      });
    });
  });
}
