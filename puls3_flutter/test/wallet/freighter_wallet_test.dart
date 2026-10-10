import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/wallet/demo_envelope.dart';
import 'package:puls3_flutter/src/wallet/freighter/freighter_bridge.dart';
import 'package:puls3_flutter/src/wallet/freighter/freighter_wallet.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Stands in for the Freighter extension; signs with a real test key.
class FakeBridge implements FreighterBridge {
  FakeBridge(this.key);

  final KeyPair key;
  String network = stellarTestnetPassphrase;
  String? activeAddress;
  Object? failure;
  String Function(String xdr)? signer;
  AuthEntrySignature Function(String preimage)? authSigner;
  int signCalls = 0;
  int authCalls = 0;

  FreighterSession get _session => FreighterSession(
    address: activeAddress ?? key.accountId,
    networkPassphrase: network,
  );

  @override
  Future<FreighterSession> connect() async {
    if (failure case final f?) throw f;
    return _session;
  }

  @override
  Future<FreighterSession> currentSession() async => _session;

  @override
  Future<String> signTransaction(
    String xdr,
    String networkPassphrase,
    String address,
  ) async {
    signCalls++;
    if (failure case final f?) throw f;
    final custom = signer;
    if (custom != null) return custom(xdr);
    final tx = AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
    tx.sign(key, Network.TESTNET);
    return tx.toEnvelopeXdrBase64();
  }

  @override
  Future<AuthEntrySignature> signAuthEntryPreimage(
    String preimageXdr,
    String networkPassphrase,
    String address,
  ) async {
    authCalls++;
    if (failure case final f?) throw f;
    return authSigner?.call(preimageXdr) ??
        AuthEntrySignature(
          signature: base64Encode(
            key.sign(Util.hash(base64Decode(preimageXdr))),
          ),
          signerAddress: key.accountId,
        );
  }
}

const _destination = 'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV';

Transaction _payment(String source, {String? operationSource}) {
  final op = PaymentOperationBuilder(_destination, AssetTypeNative(), '1');
  if (operationSource != null) op.setSourceAccount(operationSource);
  return (TransactionBuilder(
    Account(source, BigInt.one),
  )..addOperation(op.build())).build();
}

SorobanAuthorizationEntry _authEntry(
  String address, {
  int expiration = 4953189,
  SorobanCredentials? credentials,
}) => SorobanAuthorizationEntry(
  credentials ??
      SorobanCredentials.forAddressLegacy(
        Address.forAccountId(address),
        BigInt.from(424242),
        expiration,
        XdrSCVal.forVoid(),
      ),
  SorobanAuthorizedInvocation(
    SorobanAuthorizedFunction(
      contractFn: XdrInvokeContractArgs(
        Address.forContractId(
          'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC',
        ).toXdr(),
        'transfer',
        [
          Address.forAccountId(address).toXdrSCVal(),
          Address.forAccountId(_destination).toXdrSCVal(),
          XdrSCVal.forI128Parts(BigInt.zero, BigInt.from(10000000)),
        ],
      ),
    ),
  ),
);

void main() {
  late KeyPair key;
  late FakeBridge bridge;
  late FreighterWallet wallet;

  setUp(() {
    key = KeyPair.random();
    bridge = FakeBridge(key);
    wallet = FreighterWallet(bridge);
  });

  group('connect and network guard', () {
    test('connects on Testnet and exposes address and network', () async {
      expect(await wallet.connect(), key.accountId);
      expect(wallet.address, key.accountId);
      expect(wallet.network, stellarTestnetPassphrase);
      expect(wallet.name, 'Freighter');
    });

    test(
      'refuses a wallet on another network and stays disconnected',
      () async {
        bridge.network = Network.PUBLIC.networkPassphrase;
        // Settle the future before checking the state it leaves behind.
        await expectLater(wallet.connect(), throwsA(isA<WalletWrongNetwork>()));
        expect(wallet.address, isNull);
      },
    );

    test('a declined connection is a typed, recoverable error', () async {
      bridge.failure = const WalletSignatureRejected();
      await expectLater(
        wallet.connect(),
        throwsA(isA<WalletSignatureRejected>()),
      );
      bridge.failure = null;
      expect(await wallet.connect(), key.accountId);
    });

    test('disconnect forgets the session', () async {
      await wallet.connect();
      await wallet.disconnect();
      expect(wallet.address, isNull);
      expect(wallet.network, isNull);
    });
  });

  group('signTransaction returns signed XDR', () {
    test('signs a server-prepared envelope unchanged', () async {
      await wallet.connect();
      final unsigned = _payment(key.accountId);
      final signedXdr = await wallet.signTransaction(
        unsigned.toEnvelopeXdrBase64(),
      );
      final signed =
          AbstractTransaction.fromEnvelopeXdrString(signedXdr) as Transaction;
      expect(signed.toXdrBase64(), unsigned.toXdrBase64());
      expect(
        key.verify(
          signed.hash(Network.TESTNET),
          signed.signatures.single.signature.signature,
        ),
        isTrue,
      );
    });

    test('the demo envelope is valid for the connected account', () async {
      await wallet.connect();
      final signed = await wallet.signTransaction(
        demoEnvelope(key.accountId, note: 'deploy Visa Scout'),
      );
      expect(bridge.signCalls, 1);
      expect(
        AbstractTransaction.fromEnvelopeXdrString(signed),
        isA<Transaction>(),
      );
    });

    test('refuses before the prompt when not connected', () async {
      await expectLater(
        wallet.signTransaction(_payment(key.accountId).toEnvelopeXdrBase64()),
        throwsA(isA<WalletUnavailable>()),
      );
      expect(bridge.signCalls, 0);
    });

    test('refuses another account\'s transaction before the prompt', () async {
      await wallet.connect();
      await expectLater(
        wallet.signTransaction(
          _payment(KeyPair.random().accountId).toEnvelopeXdrBase64(),
        ),
        throwsA(isA<WalletInvalidPayload>()),
      );
      await expectLater(
        wallet.signTransaction(
          _payment(
            key.accountId,
            operationSource: KeyPair.random().accountId,
          ).toEnvelopeXdrBase64(),
        ),
        throwsA(isA<WalletInvalidPayload>()),
      );
      expect(bridge.signCalls, 0);
    });

    test('refuses malformed XDR before the prompt', () async {
      await wallet.connect();
      final valid = base64Decode(_payment(key.accountId).toEnvelopeXdrBase64());
      for (final xdr in [
        '',
        'not base64!',
        base64Encode(valid.sublist(0, valid.length - 8)),
        base64Encode([...valid, 0, 0, 0, 0]),
      ]) {
        await expectLater(
          wallet.signTransaction(xdr),
          throwsA(isA<WalletInvalidPayload>()),
        );
      }
      expect(bridge.signCalls, 0);
    });

    test('#69: refuses a fee-bump envelope before the prompt', () async {
      await wallet.connect();
      final foreign = KeyPair.random();
      final inner = _payment(foreign.accountId)..sign(foreign, Network.TESTNET);
      final feeBump = FeeBumpTransactionBuilder(
        inner,
      ).setBaseFee(200).setFeeAccount(key.accountId).build();
      await expectLater(
        wallet.signTransaction(feeBump.toEnvelopeXdrBase64()),
        throwsA(isA<WalletInvalidPayload>()),
      );
      expect(bridge.signCalls, 0);
    });

    test('detects an account or network switch before the prompt', () async {
      await wallet.connect();
      bridge.activeAddress = KeyPair.random().accountId;
      await expectLater(
        wallet.signTransaction(_payment(key.accountId).toEnvelopeXdrBase64()),
        throwsA(isA<WalletAccountChanged>()),
      );
      bridge.activeAddress = null;
      bridge.network = Network.PUBLIC.networkPassphrase;
      await expectLater(
        wallet.signTransaction(_payment(key.accountId).toEnvelopeXdrBase64()),
        throwsA(isA<WalletWrongNetwork>()),
      );
      expect(bridge.signCalls, 0);
    });

    test('rejects an answer that changed the transaction', () async {
      await wallet.connect();
      bridge.signer = (_) {
        final other = _payment(key.accountId, operationSource: key.accountId)
          ..sign(key, Network.TESTNET);
        return other.toEnvelopeXdrBase64();
      };
      await expectLater(
        wallet.signTransaction(_payment(key.accountId).toEnvelopeXdrBase64()),
        throwsA(isA<WalletInvalidPayload>()),
      );
    });

    test('rejects a signature from another key or for mainnet', () async {
      await wallet.connect();
      bridge.signer = (xdr) {
        final tx =
            AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
        tx.sign(KeyPair.random(), Network.TESTNET);
        return tx.toEnvelopeXdrBase64();
      };
      await expectLater(
        wallet.signTransaction(_payment(key.accountId).toEnvelopeXdrBase64()),
        throwsA(isA<WalletInvalidPayload>()),
      );
      bridge.signer = (xdr) {
        final tx =
            AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
        tx.sign(key, Network.PUBLIC);
        return tx.toEnvelopeXdrBase64();
      };
      await expectLater(
        wallet.signTransaction(_payment(key.accountId).toEnvelopeXdrBase64()),
        throwsA(isA<WalletInvalidPayload>()),
      );
    });

    test('a declined signature is a typed error', () async {
      await wallet.connect();
      bridge.failure = const WalletSignatureRejected();
      await expectLater(
        wallet.signTransaction(_payment(key.accountId).toEnvelopeXdrBase64()),
        throwsA(isA<WalletSignatureRejected>()),
      );
    });
  });

  group('signAuthEntry', () {
    test('signs the preimage like the SDK signer', () async {
      await wallet.connect();
      final signedXdr = await wallet.signAuthEntry(
        _authEntry(key.accountId).toBase64EncodedXdrString(),
      );
      final expected = _authEntry(key.accountId)..sign(key, Network.TESTNET);
      expect(signedXdr, expected.toBase64EncodedXdrString());
    });

    test('#69: refuses an entry without an expiration ledger', () async {
      await wallet.connect();
      await expectLater(
        wallet.signAuthEntry(
          _authEntry(key.accountId, expiration: 0).toBase64EncodedXdrString(),
        ),
        throwsA(isA<WalletInvalidPayload>()),
      );
      expect(bridge.authCalls, 0);
    });

    test('#69: refuses trailing bytes before the prompt', () async {
      await wallet.connect();
      final bytes = base64Decode(
        _authEntry(key.accountId).toBase64EncodedXdrString(),
      );
      await expectLater(
        wallet.signAuthEntry(base64Encode([...bytes, 0, 0, 0, 0])),
        throwsA(isA<WalletInvalidPayload>()),
      );
      expect(bridge.authCalls, 0);
    });

    test('#69: refuses contract-address credentials', () async {
      await wallet.connect();
      final entry = _authEntry(
        key.accountId,
        credentials: SorobanCredentials.forAddressLegacy(
          Address.forContractId(
            'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC',
          ),
          BigInt.one,
          4953189,
          XdrSCVal.forVoid(),
        ),
      );
      await expectLater(
        wallet.signAuthEntry(entry.toBase64EncodedXdrString()),
        throwsA(isA<WalletInvalidPayload>()),
      );
      expect(bridge.authCalls, 0);
    });

    test('refuses another account\'s entry and a foreign signature', () async {
      await wallet.connect();
      await expectLater(
        wallet.signAuthEntry(
          _authEntry(KeyPair.random().accountId).toBase64EncodedXdrString(),
        ),
        throwsA(isA<WalletInvalidPayload>()),
      );
      expect(bridge.authCalls, 0);

      final foreign = KeyPair.random();
      bridge.authSigner = (preimage) => AuthEntrySignature(
        signature: base64Encode(
          foreign.sign(Util.hash(base64Decode(preimage))),
        ),
      );
      await expectLater(
        wallet.signAuthEntry(
          _authEntry(key.accountId).toBase64EncodedXdrString(),
        ),
        throwsA(isA<WalletInvalidPayload>()),
      );
    });
  });

  group('signChallenge: SEP-10 sign-in (#136)', () {
    late KeyPair server;
    const homeDomain = 'puls3-hub-on-stellar.api.serverpod.space';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    /// A challenge shaped like the server's `StellarSep10Codec`: server
    /// source, sequence 0, `<home domain> auth` from the wallet, then
    /// `web_auth_domain` from the server, valid for 900 seconds.
    Transaction challenge({
      String? source,
      String? clientAccount,
      String name = '$homeDomain auth',
      int sequenceBefore = -1,
      int? minTime,
      int? maxTime,
      bool withTimeBounds = true,
      bool extraPayment = false,
      String? secondOperationSource,
    }) {
      final builder =
          TransactionBuilder(
              Account(
                source ?? server.accountId,
                BigInt.from(sequenceBefore),
              ),
            )
            ..addOperation(
              ManageDataOperationBuilder(
                name,
                Uint8List.fromList(List.filled(48, 65)),
              ).setSourceAccount(clientAccount ?? key.accountId).build(),
            )
            ..addOperation(
              ManageDataOperationBuilder(
                    'web_auth_domain',
                    Uint8List.fromList('puls3.dev'.codeUnits),
                  )
                  .setSourceAccount(
                    secondOperationSource ?? source ?? server.accountId,
                  )
                  .build(),
            );
      if (extraPayment) {
        builder.addOperation(
          PaymentOperationBuilder(
            _destination,
            AssetTypeNative(),
            '1',
          ).setSourceAccount(key.accountId).build(),
        );
      }
      if (withTimeBounds) {
        builder.addPreconditions(
          TransactionPreconditions()
            ..timeBounds = TimeBounds(
              minTime ?? now - 10,
              maxTime ?? now + 900,
            ),
        );
      }
      final tx = builder.build();
      tx.sign(server, Network.TESTNET);
      return tx;
    }

    SignInChallenge signIn(
      Transaction tx, {
      String? serverSigningKey,
      String? home,
      String passphrase = stellarTestnetPassphrase,
    }) => SignInChallenge(
      transactionXdr: tx.toEnvelopeXdrBase64(),
      networkPassphrase: passphrase,
      serverSigningKey: serverSigningKey,
      homeDomain: home,
    );

    Matcher refused(String reason) => throwsA(
      isA<WalletInvalidPayload>().having(
        (e) => e.reason,
        'reason',
        contains(reason),
      ),
    );

    setUp(() async {
      server = KeyPair.random();
      await wallet.connect();
    });

    test(
      'signs a valid challenge and returns it signed by the wallet',
      () async {
        final tx = challenge();

        final signedXdr = await wallet.signChallenge(
          signIn(tx, serverSigningKey: server.accountId, home: homeDomain),
        );

        final signed =
            AbstractTransaction.fromEnvelopeXdrString(signedXdr) as Transaction;
        expect(
          signed.toXdrBase64(),
          tx.toXdrBase64(),
          reason: 'body unchanged',
        );
        expect(signed.signatures, hasLength(2), reason: 'server + wallet');
        final hash = signed.hash(Network.TESTNET);
        expect(
          signed.signatures.any(
            (s) => key.verify(hash, s.signature.signature),
          ),
          isTrue,
        );
        expect(bridge.signCalls, 1);
      },
    );

    test(
      'works without the server key and home domain (static builds)',
      () async {
        await wallet.signChallenge(signIn(challenge()));
        expect(bridge.signCalls, 1);
      },
    );

    test('signTransaction would refuse the same challenge: the server is its '
        'source', () {
      expect(
        wallet.signTransaction(challenge().toEnvelopeXdrBase64()),
        throwsA(isA<WalletInvalidPayload>()),
      );
    });

    test('refuses a challenge that could be submitted (sequence not 0)', () {
      expect(
        wallet.signChallenge(signIn(challenge(sequenceBefore: 41))),
        refused('sequence number 0'),
      );
      expect(bridge.signCalls, 0);
    });

    test('refuses a transaction whose source is the wallet itself', () {
      expect(
        wallet.signChallenge(
          signIn(
            challenge(
              source: key.accountId,
              secondOperationSource: key.accountId,
            ),
          ),
        ),
        refused('must come from the server'),
      );
    });

    test('refuses any operation other than manage_data', () {
      expect(
        wallet.signChallenge(signIn(challenge(extraPayment: true))),
        refused('only contain manage_data'),
      );
      expect(bridge.signCalls, 0);
    });

    test('refuses a challenge for another account', () {
      expect(
        wallet.signChallenge(
          signIn(challenge(clientAccount: KeyPair.random().accountId)),
        ),
        refused('not for your account'),
      );
    });

    test('refuses a later operation sourced from another account', () {
      expect(
        wallet.signChallenge(
          signIn(challenge(secondOperationSource: key.accountId)),
        ),
        refused('for another account'),
      );
    });

    test('refuses a first operation that is not "<domain> auth"', () {
      expect(
        wallet.signChallenge(signIn(challenge(name: 'transfer'))),
        refused('not for this server'),
      );
      expect(
        wallet.signChallenge(
          signIn(challenge(), home: 'evil.example'),
        ),
        refused('not for this server'),
      );
    });

    test('refuses a challenge from another server key when it is known', () {
      expect(
        wallet.signChallenge(
          signIn(challenge(), serverSigningKey: KeyPair.random().accountId),
        ),
        refused('not from the puls3 server'),
      );
    });

    test('refuses a challenge without time bounds or outside them', () {
      expect(
        wallet.signChallenge(signIn(challenge(withTimeBounds: false))),
        refused('no expiry'),
      );
      expect(
        wallet.signChallenge(
          signIn(challenge(minTime: now - 2000, maxTime: now - 1000)),
        ),
        refused('expired'),
      );
    });

    test('refuses another network before any prompt', () {
      expect(
        wallet.signChallenge(
          signIn(
            challenge(),
            passphrase: 'Public Global Stellar Network ; September 2015',
          ),
        ),
        throwsA(isA<WalletWrongNetwork>()),
      );
      expect(bridge.signCalls, 0);
    });

    test('refuses a wallet answer that changed the challenge', () async {
      bridge.signer = (_) {
        final other = challenge(name: 'other.example auth');
        other.sign(key, Network.TESTNET);
        return other.toEnvelopeXdrBase64();
      };
      expect(
        wallet.signChallenge(signIn(challenge())),
        refused('changed the transaction'),
      );
    });

    test(
      'refuses a wallet answer with no new signature from the account',
      () async {
        bridge.signer = (xdr) => xdr;
        expect(
          wallet.signChallenge(signIn(challenge())),
          refused('did not add a signature'),
        );
      },
    );
  });
}
