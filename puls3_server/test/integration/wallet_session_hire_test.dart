@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/auth/wallet_auth_config.dart';
import 'package:puls3_server/src/auth/wallet_auth_endpoint.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';
import '../support/relay_rig.dart';
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

  withServerpod(
    'Given a wallet session on hire',
    (sessionBuilder, endpoints) {
      final hire = HireEndpoint();
      late RelayRig rig;
      late List<String> events;
      late TokenManager tokens;

      setUp(() {
        rig = RelayRig();
        events = [];
        rig.ledger.metadata[7] = {
          'id': Uint8List.fromList(utf8.encode('agt-001')),
          'name': Uint8List.fromList(utf8.encode('Test Agent')),
          'description': Uint8List.fromList(
            utf8.encode('A helpful test agent for verification.'),
          ),
          'skills': Uint8List.fromList(utf8.encode(jsonEncode(['coding']))),
          'priceUsdcStroops': Uint8List.fromList(utf8.encode('5000000')),
          'puls3.manifestVersion': Uint8List.fromList(utf8.encode('1')),
        };
        tokens = JwtConfigFromPasswords().build(authUsers: const AuthUsers());
        AuthServices.set(tokenManagerBuilders: [JwtConfigFromPasswords()]);
        HireEndpoint.sessionWallet = null;
        HireEndpoint.servicesBuilder = (_) {
          events.add('services');
          return HireServices(
            hires: HireService(
              hires: rig.hires,
              preparations: rig.preparations,
              relay: rig.service,
              registry: rig.ledger,
              catalog: AgentCatalogService(rig.ledger),
              config: HireRelayConfig(relayEnvironment()),
              now: () => rig.clock,
            ),
            relay: rig.service,
          );
        };
        WalletAuthEndpoint.debugConfig = config;
        WalletAuthEndpoint.debugNow = () => now;
        WalletAuthEndpoint.debugChain = _Chain();
        WalletAuthEndpoint.debugTokens = tokens;
      });

      tearDown(() async {
        HireEndpoint.sessionWallet = null;
        HireEndpoint.servicesBuilder = null;
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
        final users = await AuthUser.db.find(session);
        for (final user in users) {
          await AuthUser.db.deleteWhere(
            session,
            where: (t) => t.id.equals(user.id!),
          );
        }
      });

      test('the bound wallet is the session wallet', () async {
        final session = sessionBuilder.build();
        final signedIn = await _signIn(session, wallet, walletKey, network);

        final resolved = await const WalletSessionWallet().requireLogin(
          signedIn,
        );

        expect(resolved.value, wallet);
      });

      test('no session is 401, not AuthenticationUnavailable', () async {
        await expectLater(
          const WalletSessionWallet().requireLogin(sessionBuilder.build()),
          throwsA(_unauthorized()),
        );
      });

      test('an auth user without a wallet row is 401', () async {
        final session = sessionBuilder.build();
        final user = await const AuthUsers().create(session);
        final authed = sessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            user.id.toString(),
            {},
          ),
        );

        await expectLater(
          const WalletSessionWallet().requireLogin(authed.build()),
          throwsA(_unauthorized()),
        );
      });

      test(
        'hire requires a login and the production wallet is session-backed',
        () async {
          expect(hire.requireLogin, isTrue);
          HireEndpoint.servicesBuilder = (_) {
            events.add('services');
            throw StateError('no service may be built without a session');
          };

          await expectLater(
            hire.createHire(sessionBuilder.build(), 7, wallet, 'hi', 'req-1'),
            throwsA(_unauthorized()),
          );
          expect(events, isEmpty);
        },
      );

      test('the generated protocol has no email sign-in endpoint', () {
        final server = File(
          'lib/src/generated/endpoints.dart',
        ).readAsStringSync();
        final client = File(
          '../puls3_client/lib/src/protocol/client.dart',
        ).readAsStringSync();

        expect(server, isNot(contains('emailIdp')));
        expect(server, isNot(contains('EmailIdp')));
        expect(client, isNot(contains('emailIdp')));
      });

      test('a hire call with no token is 401 and persists nothing', () async {
        final calls = <Future<Object?> Function()>[
          () => endpoints.hire.createHire(sessionBuilder, 7, wallet, 'hi', 'r'),
          () => endpoints.hire.prepareCreateJob(sessionBuilder, 1),
          () => endpoints.hire.prepareFund(sessionBuilder, 1),
          () => endpoints.hire.prepareComplete(sessionBuilder, 1),
          () => endpoints.hire.prepareReject(sessionBuilder, 1, 'no'),
          () => endpoints.hire.submitEscrowCall(
            sessionBuilder,
            1,
            'prep',
            'AAAA',
          ),
        ];

        for (final call in calls) {
          events.clear();
          await expectLater(
            call(),
            throwsA(isA<ServerpodUnauthenticatedException>()),
          );
          expect(events, isEmpty);
        }
        expect(rig.hires.all, isEmpty);
      });

      test('createHire belongs to the signed-in wallet', () async {
        final session = sessionBuilder.build();
        final authed = await _builder(
          sessionBuilder,
          session,
          tokens,
          wallet,
          walletKey,
          network,
        );

        final created = await endpoints.hire.createHire(
          authed,
          7,
          wallet,
          'hi',
          'req-w',
        );

        expect(created.hire.consumer, wallet);
        expect(rig.hires.all.single.consumer, wallet);
      });

      test('another consumer is WalletMismatch and persists nothing', () async {
        final session = sessionBuilder.build();
        final authed = await _builder(
          sessionBuilder,
          session,
          tokens,
          wallet,
          walletKey,
          network,
        );

        await expectLater(
          endpoints.hire.createHire(authed, 7, otherWallet, 'hi', 'req-v'),
          throwsA(_code('WalletMismatch')),
        );
        expect(rig.hires.all, isEmpty);
      });

      test('another wallet cannot prepare this hire', () async {
        final session = sessionBuilder.build();
        final owner = await _builder(
          sessionBuilder,
          session,
          tokens,
          wallet,
          walletKey,
          network,
        );
        final intruder = await _builder(
          sessionBuilder,
          session,
          tokens,
          otherWallet,
          otherKey,
          network,
        );
        final owned = await rig.hire(status: HireStatus.open, consumer: wallet);

        await expectLater(
          endpoints.hire.prepareFund(intruder, owned.id),
          throwsA(_code('HireNotOwned')),
        );
        await expectLater(
          endpoints.hire.createHire(intruder, 7, wallet, 'hi', 'req-cross'),
          throwsA(_code('WalletMismatch')),
        );
        expect(rig.hires.all, hasLength(1));
        expect(owner, isNotNull);
      });

      test(
        'an unknown or foreign preparation is PreparationNotFound',
        () async {
          final session = sessionBuilder.build();
          final authed = await _builder(
            sessionBuilder,
            session,
            tokens,
            wallet,
            walletKey,
            network,
          );
          final first = await rig.hire(
            status: HireStatus.open,
            consumer: wallet,
          );
          final prepared = await rig.service.prepareFund(
            StellarAddress.parse(wallet),
            first.id,
          );
          final second = await rig.hire(
            status: HireStatus.open,
            consumer: wallet,
          );

          await expectLater(
            endpoints.hire.submitEscrowCall(
              authed,
              first.id,
              'missing-prep',
              'AAAA',
            ),
            throwsA(_code('PreparationNotFound')),
          );
          await expectLater(
            endpoints.hire.submitEscrowCall(
              authed,
              second.id,
              prepared.preparationId,
              'AAAA',
            ),
            throwsA(_code('PreparationNotFound')),
          );
        },
      );

      test('a bad hire id is InvalidHireId or HireNotFound', () async {
        final session = sessionBuilder.build();
        final authed = await _builder(
          sessionBuilder,
          session,
          tokens,
          wallet,
          walletKey,
          network,
        );

        await expectLater(
          endpoints.hire.prepareFund(authed, 0),
          throwsA(_code('InvalidHireId')),
        );
        await expectLater(
          endpoints.hire.prepareFund(authed, 999999),
          throwsA(_code('HireNotFound')),
        );
        expect(rig.hires.all, isEmpty);
      });

      test(
        'sign-in, createHire, sign-out, then hire without a session is 401',
        () async {
          final session = sessionBuilder.build();
          final success = await _issue(session, wallet, walletKey, network);
          final info = await tokens.validateToken(session, success.token);
          final authed = sessionBuilder.copyWith(
            authentication: AuthenticationOverride.authenticationInfo(
              info!.userIdentifier,
              info.scopes,
              authId: info.authId,
            ),
          );

          final created = await endpoints.hire.createHire(
            authed,
            7,
            wallet,
            'hi',
            'req-out',
          );
          expect(created.hire.consumer, wallet);

          // StatusEndpoint.signOutDevice revokes the refresh token of authId.
          // The access JWT stays valid until it expires; the client drops it.
          await AuthServices.instance.tokenManager.revokeToken(
            authed.build(),
            tokenId: info.authId,
          );
          expect(
            await tokens.listTokens(
              session,
              authUserId: UuidValue.withValidation(info.userIdentifier),
            ),
            isEmpty,
          );

          await expectLater(
            endpoints.hire.createHire(
              sessionBuilder,
              7,
              wallet,
              'hi',
              'req-out',
            ),
            throwsA(isA<ServerpodUnauthenticatedException>()),
          );
          expect(rig.hires.all, hasLength(1));
        },
      );

      test(
        'each method resolves the session wallet before any service',
        () async {
          final recorder = _RecordingWallet(
            events,
            StellarAddress.parse(wallet),
          );
          HireEndpoint.sessionWallet = recorder;

          final calls = <Future<Object?> Function()>[
            () =>
                hire.createHire(sessionBuilder.build(), 7, wallet, 'hi', 'r1'),
            () async => hire.prepareCreateJob(
              sessionBuilder.build(),
              (await rig.hire(consumer: wallet)).id,
            ),
            () async => hire.prepareFund(
              sessionBuilder.build(),
              (await rig.hire(status: HireStatus.open, consumer: wallet)).id,
            ),
            () async => hire.prepareComplete(
              sessionBuilder.build(),
              (await rig.hire(
                status: HireStatus.submitted,
                consumer: wallet,
              )).id,
            ),
            () async => hire.prepareReject(
              sessionBuilder.build(),
              (await rig.hire(status: HireStatus.open, consumer: wallet)).id,
              'not what I asked for',
            ),
            () async {
              final row = await rig.hire(
                status: HireStatus.open,
                consumer: wallet,
              );
              final prepared = await rig.service.prepareFund(
                StellarAddress.parse(wallet),
                row.id,
              );
              events.clear();
              recorder.calls = 0;
              return hire.submitEscrowCall(
                sessionBuilder.build(),
                row.id,
                prepared.preparationId,
                FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!),
              );
            },
          ];

          for (final call in calls) {
            events.clear();
            recorder.calls = 0;
            await call();
            expect(recorder.calls, 1);
            expect(events, ['requireLogin', 'services']);
          }
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

Future<Session> _signIn(
  Session session,
  String wallet,
  stellar.StellarPrivateKey key,
  String network,
) async {
  final success = await _issue(session, wallet, key, network);
  final info = await JwtConfigFromPasswords()
      .build(
        authUsers: const AuthUsers(),
      )
      .validateToken(session, success.token);
  session.updateAuthenticated(
    AuthenticationInfo(info!.userIdentifier, info.scopes, authId: info.authId),
  );
  return session;
}

Future<TestSessionBuilder> _builder(
  TestSessionBuilder sessionBuilder,
  Session session,
  TokenManager tokens,
  String wallet,
  stellar.StellarPrivateKey key,
  String network,
) async {
  final success = await _issue(session, wallet, key, network);
  final info = await tokens.validateToken(session, success.token);
  return sessionBuilder.copyWith(
    authentication: AuthenticationOverride.authenticationInfo(
      info!.userIdentifier,
      info.scopes,
      authId: info.authId,
    ),
  );
}

Future<AuthSuccess> _issue(
  Session session,
  String wallet,
  stellar.StellarPrivateKey key,
  String network,
) async {
  final endpoint = WalletAuthEndpoint();
  final challenge = await endpoint.createChallenge(session, wallet);
  return endpoint.verifyChallenge(
    session,
    challenge.challengeId,
    wallet,
    _sign(challenge.payload, key, network),
  );
}

String _address(stellar.StellarPrivateKey key) =>
    key.toPublicKey().toAddress().address;

String _sign(
  String xdr,
  stellar.StellarPrivateKey client,
  String network,
) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(xdr))
          as stellar.TransactionV1Envelope;
  final hash = Uint8List.fromList(
    stellar.TransactionSignaturePayload(
      networkId: stellar.StellarNetwork.fromPassphrase(network).passphraseHash,
      taggedTransaction: decoded.tx,
    ).txHash(),
  );
  return base64Encode(
    stellar.TransactionV1Envelope(
      tx: decoded.tx,
      signatures: [decoded.signatures.single, client.sign(hash)],
    ).toVariantXDR(),
  );
}

Matcher _unauthorized() => isA<NotAuthorizedException>().having(
  (error) => error.reason,
  'reason',
  AuthenticationFailureReason.unauthenticated,
);

Matcher _code(String code) => isA<Puls3ApiException>().having(
  (error) => error.code,
  'code',
  code,
);

final class _Chain implements ChainAccounts {
  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async =>
      const AccountAuthority(masterWeight: 1, mediumThreshold: 1, signers: {});

  @override
  Future<int> sequenceOf(StellarAddress account) => throw UnimplementedError();

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) =>
      throw UnimplementedError();
}

final class _RecordingWallet implements SessionWallet {
  _RecordingWallet(this.events, this.wallet);

  final List<String> events;
  final StellarAddress wallet;
  var calls = 0;

  @override
  Future<StellarAddress> requireLogin(Session session) async {
    calls += 1;
    events.add('requireLogin');
    return wallet;
  }
}
