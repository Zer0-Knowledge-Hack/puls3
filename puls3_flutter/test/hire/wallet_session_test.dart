import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/hire/server_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart'
    show AuthSuccess;

const _alice = 'GALICE';
const _bob = 'GBOB';

/// The server side of SEP-10 sign-in, in memory: it issues one challenge per
/// call and answers [verify] with a session for the signer.
class FakeWalletAuth {
  final created = <String>[];
  final verified = <(String, String, String)>[];
  var _next = 1;

  /// When set, the next challenge is issued for this wallet instead.
  String? issueForWallet;

  /// When set, [verify] fails with it once.
  Object? verifyFailure;

  Future<WalletChallenge> create(String wallet) async {
    created.add(wallet);
    final forWallet = issueForWallet ?? wallet;
    issueForWallet = null;
    return WalletChallenge(
      challengeId: 'c${_next++}',
      wallet: forWallet,
      payload: 'challenge-for-$forWallet',
      networkPassphrase: stellarTestnetPassphrase,
      expiresAt: DateTime.utc(2026, 10, 10, 12),
    );
  }

  Future<AuthSuccess> verify(String id, String wallet, String signed) async {
    final failure = verifyFailure;
    if (failure != null) {
      verifyFailure = null;
      throw failure;
    }
    verified.add((id, wallet, signed));
    return AuthSuccess(
      authStrategy: 'jwt',
      token: 'token-for-$wallet',
      authUserId: UuidValue.fromString(
        '7d3a1f2e-0c4b-4b6a-9e1d-0a1b2c3d4e5f',
      ),
      scopeNames: const {},
    );
  }
}

void main() {
  late FakeWalletAuth server;
  late AuthSuccess? stored;
  late List<SignInChallenge> signedChallenges;
  late WalletSession session;

  Future<String> sign(SignInChallenge challenge) async {
    signedChallenges.add(challenge);
    return 'signed:${challenge.transactionXdr}';
  }

  WalletSession build({String? serverKey, String? homeDomain}) => WalletSession(
    createChallenge: server.create,
    verifyChallenge: server.verify,
    isAuthenticated: () => stored != null,
    storeSession: (auth) async => stored = auth,
    serverSigningKey: serverKey,
    homeDomain: homeDomain,
  );

  setUp(() {
    server = FakeWalletAuth();
    stored = null;
    signedChallenges = [];
    session = build();
  });

  test(
    'signs in: challenge, wallet signature, verify, session stored',
    () async {
      await session.ensureSignedIn(_alice, sign);

      expect(server.created, [_alice]);
      expect(signedChallenges.single.transactionXdr, 'challenge-for-$_alice');
      expect(
        signedChallenges.single.networkPassphrase,
        stellarTestnetPassphrase,
      );
      expect(server.verified.single, (
        'c1',
        _alice,
        'signed:challenge-for-$_alice',
      ));
      expect(stored?.token, 'token-for-$_alice');
    },
  );

  test('passes the server key and home domain to the wallet check', () async {
    session = build(serverKey: 'GSERVER', homeDomain: 'puls3.example');

    await session.ensureSignedIn(_alice, sign);

    expect(signedChallenges.single.serverSigningKey, 'GSERVER');
    expect(signedChallenges.single.homeDomain, 'puls3.example');
  });

  test('reuses the session of the same wallet: no second signature', () async {
    await session.ensureSignedIn(_alice, sign);
    await session.ensureSignedIn(_alice, sign);

    expect(server.created, [_alice]);
    expect(signedChallenges, hasLength(1));
  });

  test('another wallet drops the old session and signs in again', () async {
    await session.ensureSignedIn(_alice, sign);
    await session.ensureSignedIn(_bob, sign);

    expect(server.created, [_alice, _bob]);
    expect(stored?.token, 'token-for-$_bob');
  });

  test('a session restored for an unknown wallet is not trusted', () async {
    stored = AuthSuccess(
      authStrategy: 'jwt',
      token: 'restored',
      authUserId: UuidValue.fromString('7d3a1f2e-0c4b-4b6a-9e1d-0a1b2c3d4e5f'),
      scopeNames: const {},
    );

    await session.ensureSignedIn(_alice, sign);

    expect(server.created, [_alice]);
    expect(stored?.token, 'token-for-$_alice');
  });

  test('a challenge issued for another wallet is never signed', () async {
    server.issueForWallet = _bob;

    await expectLater(
      session.ensureSignedIn(_alice, sign),
      throwsA(isA<WalletInvalidPayload>()),
    );
    expect(signedChallenges, isEmpty);
    expect(stored, isNull);
  });

  test('a declined signature stores no session', () async {
    await expectLater(
      session.ensureSignedIn(
        _alice,
        (_) async => throw const WalletSignatureRejected(),
      ),
      throwsA(isA<WalletSignatureRejected>()),
    );
    expect(server.verified, isEmpty);
    expect(stored, isNull);
  });

  test('a refused verification stores no session and the next try signs '
      'again', () async {
    server.verifyFailure = Puls3ApiException(code: 'InvalidWalletSignature');
    await expectLater(
      session.ensureSignedIn(_alice, sign),
      throwsA(isA<Puls3ApiException>()),
    );
    expect(stored, isNull);

    await session.ensureSignedIn(_alice, sign);
    expect(server.created, [_alice, _alice]);
    expect(stored?.token, 'token-for-$_alice');
  });

  test('forget drops the session so the next call signs in', () async {
    await session.ensureSignedIn(_alice, sign);
    await session.forget();
    expect(stored, isNull);

    await session.ensureSignedIn(_alice, sign);
    expect(server.created, [_alice, _alice]);
  });

  group('ServerHireGateway sign-in', () {
    ServerHireGateway gateway(WalletSession? walletSession) =>
        ServerHireGateway(
          createHire: (_, _, _, _) => throw UnimplementedError(),
          prepareCreateJob: (_) => throw UnimplementedError(),
          prepareFund: (_) => throw UnimplementedError(),
          submitEscrowCall: (_, _, _) => throw UnimplementedError(),
          session: walletSession,
        );

    test('signs in through the session', () async {
      await gateway(session).ensureSignedIn(_alice, sign);
      expect(stored?.token, 'token-for-$_alice');
    });

    test('without a session there is nothing to sign', () async {
      await gateway(null).ensureSignedIn(_alice, sign);
      expect(signedChallenges, isEmpty);
    });

    test('a refused challenge or signature is HireSignInFailed', () async {
      for (final code in [
        'ChallengeNotFound',
        'ChallengeExpired',
        'ChallengeConsumed',
        'InvalidWalletSignature',
      ]) {
        server.verifyFailure = Puls3ApiException(code: code);
        await expectLater(
          gateway(session).ensureSignedIn(_alice, sign),
          throwsA(isA<HireSignInFailed>()),
          reason: code,
        );
      }
    });

    test('too many attempts and a server without sign-in are mapped', () async {
      server.verifyFailure = Puls3ApiException(code: 'ChallengeRateLimited');
      await expectLater(
        gateway(session).ensureSignedIn(_alice, sign),
        throwsA(
          isA<HireBackendUnavailable>().having(
            (e) => e.message,
            'message',
            contains('Too many sign-in attempts'),
          ),
        ),
      );
      server.verifyFailure = Puls3ApiException(
        code: 'AuthenticationUnavailable',
      );
      await expectLater(
        gateway(session).ensureSignedIn(_alice, sign),
        throwsA(isA<HireNotSignedIn>()),
      );
    });

    test('a wallet failure reaches the flow unchanged', () async {
      await expectLater(
        gateway(session).ensureSignedIn(
          _alice,
          (_) async => throw const WalletSignatureRejected(),
        ),
        throwsA(isA<WalletSignatureRejected>()),
      );
    });

    test('forgetSession drops the stored session', () async {
      await gateway(session).ensureSignedIn(_alice, sign);
      await gateway(session).forgetSession();
      expect(stored, isNull);
    });
  });
}
