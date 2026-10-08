import 'dart:convert';

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
}
