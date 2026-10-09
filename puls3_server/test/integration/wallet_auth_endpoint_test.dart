@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/auth/wallet_auth_config.dart';
import 'package:puls3_server/src/auth/wallet_auth_endpoint.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  final serverKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 7),
  );
  final walletKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 9),
  );
  final otherKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 3),
  );
  final signerA = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 4),
  );
  final signerB = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 5),
  );
  final wallet = _address(walletKey);
  final otherWallet = _address(otherKey);
  final now = DateTime.utc(2026, 10, 9, 12);
  const network = 'Test SDF Network ; September 2015';
  final config = WalletAuthConfig(
    signingKey: serverKey.toBase32(),
    serverAccount: _address(serverKey),
    homeDomain: 'puls3.app',
    webAuthDomain: 'auth.puls3.app',
    networkPassphrase: network,
  );
  final master = AccountAuthority(
    masterWeight: 1,
    mediumThreshold: 1,
    signers: {},
  );

  withServerpod(
    'Given WalletAuthEndpoint',
    (sessionBuilder, _) {
      final endpoint = WalletAuthEndpoint();

      setUp(() {
        WalletAuthEndpoint.debugConfig = config;
        WalletAuthEndpoint.debugNow = () => now;
        WalletAuthEndpoint.debugChain = _Chain(master);
        WalletAuthEndpoint.capturedLogs = [];
      });

      tearDown(() async {
        WalletAuthEndpoint.resetDebug();
        final session = sessionBuilder.build();
        await DatabaseRateLimiter(
          RateLimiterConfig(
            domain: 'puls3_wallet',
            source: 'challenge',
            maxAttempts: 5,
            timeframe: const Duration(minutes: 1),
          ),
        ).deleteAttempts(session);
        await WalletChallengeRecord.db.deleteWhere(
          session,
          where: (t) => t.challengeId.notEquals(''),
        );
        final accounts = await WalletAccount.db.find(session);
        for (final row in accounts) {
          await AuthUser.db.deleteWhere(
            session,
            where: (t) => t.id.equals(row.authUserId),
          );
        }
      });

      test('a challenge expires in 15 minutes and two calls differ', () async {
        final session = sessionBuilder.build();
        final first = await endpoint.createChallenge(session, wallet);
        final second = await endpoint.createChallenge(session, wallet);

        expect(first.wallet, wallet);
        expect(first.networkPassphrase, network);
        expect(
          first.expiresAt.toUtc(),
          now.add(const Duration(seconds: 900)),
        );
        expect(second.challengeId, isNot(first.challengeId));
        expect(_nonce(second.payload), isNot(_nonce(first.payload)));
        expect(
          await WalletChallengeRecord.db.count(session),
          2,
        );
      });

      test('a bad address persists nothing', () async {
        final session = sessionBuilder.build();

        await expectLater(
          endpoint.createChallenge(session, 'not-an-address'),
          throwsA(_code('InvalidStellarAddress')),
        );
        expect(await WalletChallengeRecord.db.count(session), 0);
      });

      test(
        'the sixth challenge in a minute is limited and persists nothing',
        () async {
          final session = sessionBuilder.build();
          for (var i = 0; i < 5; i++) {
            await endpoint.createChallenge(session, wallet);
          }

          await expectLater(
            endpoint.createChallenge(session, wallet),
            throwsA(_code('ChallengeRateLimited')),
          );
          expect(
            await WalletChallengeRecord.db.count(
              session,
              where: (t) => t.wallet.equals(wallet),
            ),
            5,
          );
          final other = await endpoint.createChallenge(session, otherWallet);
          expect(other.wallet, otherWallet);
        },
      );

      test('missing config persists nothing', () async {
        WalletAuthEndpoint.debugConfig = null;
        final session = sessionBuilder.build();

        await expectLater(
          endpoint.createChallenge(session, wallet),
          throwsA(_code('AuthenticationUnavailable')),
        );
        expect(await WalletChallengeRecord.db.count(session), 0);
      });

      test('a signed-in caller can challenge another wallet', () async {
        final authed = sessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            const Uuid().v4(),
            {},
          ),
        );

        final challenge = await endpoint.createChallenge(
          authed.build(),
          otherWallet,
        );

        expect(challenge.wallet, otherWallet);
      });

      test('a signed challenge returns a session and is consumed', () async {
        final session = sessionBuilder.build();
        final challenge = await endpoint.createChallenge(session, wallet);
        final signed = _sign(challenge.payload, [walletKey], network);

        final success = await endpoint.verifyChallenge(
          session,
          challenge.challengeId,
          wallet,
          signed,
        );

        expect(success.authUserId, isNotNull);
        expect(success.token, isNotEmpty);
        expect(success.refreshToken, isNotEmpty);
        final row = await WalletChallengeRecord.db.findFirstRow(
          session,
          where: (t) => t.challengeId.equals(challenge.challengeId),
        );
        expect(row!.consumedAt, isNotNull);
        final account = await WalletAccount.db.findFirstRow(
          session,
          where: (t) => t.wallet.equals(wallet),
        );
        expect(account!.authUserId, success.authUserId);
      });

      test(
        'two signers that meet the medium threshold get a session',
        () async {
          WalletAuthEndpoint.debugChain = _Chain(
            AccountAuthority(
              masterWeight: 0,
              mediumThreshold: 2,
              signers: {_addressOf(signerA): 1, _addressOf(signerB): 1},
            ),
          );
          final session = sessionBuilder.build();
          final challenge = await endpoint.createChallenge(session, wallet);

          final success = await endpoint.verifyChallenge(
            session,
            challenge.challengeId,
            wallet,
            _sign(challenge.payload, [signerA, signerB], network),
          );

          expect(success.token, isNotEmpty);
        },
      );

      test(
        'verifier failures persist no user and leave the challenge',
        () async {
          final session = sessionBuilder.build();
          final challenge = await endpoint.createChallenge(session, wallet);
          final signed = _sign(challenge.payload, [walletKey], network);
          final cases = <String, Future<void> Function()>{
            'malformed': () => endpoint.verifyChallenge(
              session,
              challenge.challengeId,
              wallet,
              '***',
            ),
            'walletMismatch': () => endpoint.verifyChallenge(
              session,
              challenge.challengeId,
              otherWallet,
              signed,
            ),
            'noClientSignature': () => endpoint.verifyChallenge(
              session,
              challenge.challengeId,
              wallet,
              challenge.payload,
            ),
            'serverSignature': () => endpoint.verifyChallenge(
              session,
              challenge.challengeId,
              wallet,
              _sign(
                challenge.payload,
                [walletKey],
                network,
                includeServer: false,
              ),
            ),
            'tampered': () => endpoint.verifyChallenge(
              session,
              challenge.challengeId,
              wallet,
              _tamper(challenge.payload, serverKey, network),
            ),
            'ChallengeNotFound': () => endpoint.verifyChallenge(
              session,
              'missing',
              wallet,
              signed,
            ),
          };

          for (final entry in cases.entries) {
            await expectLater(
              entry.value(),
              throwsA(
                entry.key == 'ChallengeNotFound'
                    ? _code('ChallengeNotFound')
                    : _reason(entry.key),
              ),
              reason: entry.key,
            );
          }
          expect(await WalletAccount.db.count(session), 0);
          expect(await AuthUser.db.count(session), 0);
          final row = await WalletChallengeRecord.db.findFirstRow(
            session,
            where: (t) => t.challengeId.equals(challenge.challengeId),
          );
          expect(row!.consumedAt, isNull);
        },
      );

      test(
        'an unreadable chain does not fall back to the master key',
        () async {
          WalletAuthEndpoint.debugChain = _Chain.down();
          final session = sessionBuilder.build();
          final challenge = await endpoint.createChallenge(session, wallet);

          await expectLater(
            endpoint.verifyChallenge(
              session,
              challenge.challengeId,
              wallet,
              _sign(challenge.payload, [walletKey], network),
            ),
            throwsA(_code('AuthenticationUnavailable')),
          );
          expect(await WalletAccount.db.count(session), 0);
        },
      );

      test(
        'low weight and an unfunded foreign signature persist nothing',
        () async {
          final session = sessionBuilder.build();
          WalletAuthEndpoint.debugChain = _Chain(
            AccountAuthority(
              masterWeight: 0,
              mediumThreshold: 2,
              signers: {_addressOf(signerA): 1},
            ),
          );
          final low = await endpoint.createChallenge(session, wallet);
          await expectLater(
            endpoint.verifyChallenge(
              session,
              low.challengeId,
              wallet,
              _sign(low.payload, [signerA], network),
            ),
            throwsA(_reason('insufficientWeight')),
          );

          WalletAuthEndpoint.debugChain = _Chain(null);
          final unfunded = await endpoint.createChallenge(session, otherWallet);
          await expectLater(
            endpoint.verifyChallenge(
              session,
              unfunded.challengeId,
              otherWallet,
              _sign(unfunded.payload, [walletKey], network),
            ),
            throwsA(_reason('invalidClientSignature')),
          );
          expect(await WalletAccount.db.count(session), 0);
        },
      );

      test('an expired challenge is rejected', () async {
        final session = sessionBuilder.build();
        final challenge = await endpoint.createChallenge(session, wallet);
        WalletAuthEndpoint.debugNow = () =>
            now.add(const Duration(seconds: 900));

        await expectLater(
          endpoint.verifyChallenge(
            session,
            challenge.challengeId,
            wallet,
            _sign(challenge.payload, [walletKey], network),
          ),
          throwsA(_code('ChallengeExpired')),
        );
      });

      test('a second verify is consumed', () async {
        final session = sessionBuilder.build();
        final challenge = await endpoint.createChallenge(session, wallet);
        final signed = _sign(challenge.payload, [walletKey], network);
        await endpoint.verifyChallenge(
          session,
          challenge.challengeId,
          wallet,
          signed,
        );

        await expectLater(
          endpoint.verifyChallenge(
            session,
            challenge.challengeId,
            wallet,
            signed,
          ),
          throwsA(_code('ChallengeConsumed')),
        );
      });

      test('a token failure rolls the consume back', () async {
        final session = sessionBuilder.build();
        final challenge = await endpoint.createChallenge(session, wallet);
        WalletAuthEndpoint.debugTokens = const _ThrowingTokens();

        await expectLater(
          endpoint.verifyChallenge(
            session,
            challenge.challengeId,
            wallet,
            _sign(challenge.payload, [walletKey], network),
          ),
          throwsA(isA<StateError>()),
        );
        final row = await WalletChallengeRecord.db.findFirstRow(
          session,
          where: (t) => t.challengeId.equals(challenge.challengeId),
        );
        expect(row!.consumedAt, isNull);
        expect(await WalletAccount.db.count(session), 0);
      });

      test('verifying wallet B while holding A returns B', () async {
        final session = sessionBuilder.build();
        final challengeA = await endpoint.createChallenge(session, wallet);
        final successA = await endpoint.verifyChallenge(
          session,
          challengeA.challengeId,
          wallet,
          _sign(challengeA.payload, [walletKey], network),
        );
        final authed = sessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            successA.authUserId.toString(),
            {},
          ),
        );
        final challengeB = await endpoint.createChallenge(
          authed.build(),
          otherWallet,
        );

        final successB = await endpoint.verifyChallenge(
          authed.build(),
          challengeB.challengeId,
          otherWallet,
          _sign(challengeB.payload, [otherKey], network),
        );

        expect(successB.authUserId, isNot(successA.authUserId));
      });

      test(
        'logs and errors omit the key, the token and the signed XDR',
        () async {
          final session = sessionBuilder.build();
          final challenge = await endpoint.createChallenge(session, wallet);
          final signed = _sign(challenge.payload, [walletKey], network);
          final success = await endpoint.verifyChallenge(
            session,
            challenge.challengeId,
            wallet,
            signed,
          );
          Object? failure;
          try {
            await endpoint.verifyChallenge(
              session,
              challenge.challengeId,
              wallet,
              signed,
            );
          } catch (error) {
            failure = error;
          }

          final text = [
            ...WalletAuthEndpoint.capturedLogs!,
            failure.toString(),
          ].join('\n');
          expect(text, isNot(contains(config.signingKey)));
          expect(text, isNot(contains(success.token)));
          expect(text, isNot(contains(signed)));
          expect(failure, _code('ChallengeConsumed'));
        },
      );

      test('two concurrent verifies issue one session', () async {
        final challenge = await endpoint.createChallenge(
          sessionBuilder.build(),
          wallet,
        );
        final signed = _sign(challenge.payload, [walletKey], network);

        final outcomes = await Future.wait([
          _attempt(
            endpoint,
            sessionBuilder.build(),
            challenge.challengeId,
            wallet,
            signed,
          ),
          _attempt(
            endpoint,
            sessionBuilder.build(),
            challenge.challengeId,
            wallet,
            signed,
          ),
        ]);

        expect(outcomes.whereType<AuthSuccess>(), hasLength(1));
        expect(
          outcomes.whereType<Puls3ApiException>().single.code,
          'ChallengeConsumed',
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

Future<Object> _attempt(
  WalletAuthEndpoint endpoint,
  Session session,
  String challengeId,
  String wallet,
  String signed,
) async {
  try {
    return await endpoint.verifyChallenge(
      session,
      challengeId,
      wallet,
      signed,
    );
  } catch (error) {
    return error;
  }
}

String _address(stellar.StellarPrivateKey key) =>
    key.toPublicKey().toAddress().address;

StellarAddress _addressOf(stellar.StellarPrivateKey key) =>
    StellarAddress.parse(_address(key));

String _nonce(String xdr) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(xdr))
          as stellar.TransactionV1Envelope;
  final body = decoded.tx.operations.first.body as stellar.ManageDataOperation;
  return base64Encode(body.dataValue!);
}

String _sign(
  String xdr,
  List<stellar.StellarPrivateKey> clients,
  String network, {
  bool includeServer = true,
}) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(xdr))
          as stellar.TransactionV1Envelope;
  final hash = Uint8List.fromList(
    stellar.TransactionSignaturePayload(
      networkId: stellar.StellarNetwork.fromPassphrase(network).passphraseHash,
      taggedTransaction: decoded.tx,
    ).txHash(),
  );
  final signatures = <stellar.DecoratedSignature>[
    if (includeServer) decoded.signatures.single,
    for (final key in clients) key.sign(hash),
  ];
  return base64Encode(
    stellar.TransactionV1Envelope(
      tx: decoded.tx,
      signatures: signatures,
    ).toVariantXDR(),
  );
}

String _tamper(
  String xdr,
  stellar.StellarPrivateKey serverKey,
  String network,
) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(xdr))
          as stellar.TransactionV1Envelope;
  final tx = decoded.tx.copyWith(seqNum: BigInt.one);
  final hash = Uint8List.fromList(
    stellar.TransactionSignaturePayload(
      networkId: stellar.StellarNetwork.fromPassphrase(network).passphraseHash,
      taggedTransaction: tx,
    ).txHash(),
  );
  return base64Encode(
    stellar.TransactionV1Envelope(
      tx: tx,
      signatures: [serverKey.sign(hash)],
    ).toVariantXDR(),
  );
}

Matcher _code(String code) => isA<Puls3ApiException>().having(
  (error) => error.code,
  'code',
  code,
);

Matcher _reason(String reason) => isA<Puls3ApiException>()
    .having((error) => error.code, 'code', 'InvalidWalletSignature')
    .having((error) => error.details?['reason'], 'reason', reason);

final class _Chain implements ChainAccounts {
  _Chain(this.authority);

  _Chain.down() : authority = null, down = true;

  final AccountAuthority? authority;
  var down = false;

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async {
    if (down) throw chainUnavailable();
    return authority;
  }

  @override
  Future<int> sequenceOf(StellarAddress account) => throw UnimplementedError();

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) =>
      throw UnimplementedError();
}

final class _ThrowingTokens extends TokenManager {
  const _ThrowingTokens();

  @override
  Future<AuthSuccess> createToken(
    Session session, {
    required UuidValue authUserId,
    required String method,
    Set<Scope>? scopes,
    Transaction? transaction,
  }) {
    throw StateError('token issuance failed');
  }

  @override
  Future<List<TokenInfo>> listTokens(
    Session session, {
    required UuidValue? authUserId,
    String? method,
    String? tokenIssuer,
    Transaction? transaction,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeAllTokens(
    Session session, {
    required UuidValue? authUserId,
    Transaction? transaction,
    String? method,
    String? tokenIssuer,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeToken(
    Session session, {
    required String tokenId,
    Transaction? transaction,
    String? tokenIssuer,
  }) => throw UnimplementedError();

  @override
  Future<AuthenticationInfo?> validateToken(Session session, String token) =>
      throw UnimplementedError();
}
