import 'dart:convert';

import 'package:flutter_stellar_wallet_spike/wallet_port.dart';
import 'package:flutter_stellar_wallet_spike/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class FakeBridge implements FreighterBridge {
  FakeBridge(this.wallet, {this.passphrase = stellarTestnetPassphrase});
  final KeyPair wallet;
  String passphrase;
  String? activeAddress;
  Object? signingFailure;
  String Function(String)? signer;
  int signTransactionCalls = 0;

  @override
  Future<WalletSession> connect() async => WalletSession(
    address: activeAddress ?? wallet.accountId,
    networkPassphrase: passphrase,
  );
  @override
  Future<WalletSession> currentSession() => connect();
  int signAuthEntryCalls = 0;
  String? lastPreimageXdr;

  /// Returns the wallet's answer for a preimage. Defaults to Freighter's
  /// documented behavior: an ed25519 signature over sha256(preimage bytes).
  AuthEntrySignature Function(String preimageXdr)? authSigner;

  @override
  Future<AuthEntrySignature> signAuthEntryPreimage(
    String preimageXdr,
    String networkPassphrase,
    String address,
  ) async {
    signAuthEntryCalls++;
    lastPreimageXdr = preimageXdr;
    if (signingFailure case final failure?) throw failure;
    return authSigner?.call(preimageXdr) ??
        AuthEntrySignature(
          signature: signPreimage(wallet, preimageXdr),
          signerAddress: wallet.accountId,
        );
  }

  @override
  Future<String> signTransaction(
    String xdr,
    String networkPassphrase,
    String address,
  ) async {
    signTransactionCalls++;
    if (signingFailure case final failure?) throw failure;
    return signer?.call(xdr) ?? xdr;
  }
}

const destination = 'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV';

Transaction transaction(
  String source,
  String amount, {
  BigInt? muxedId,
  String? operationSource,
}) {
  final payment = PaymentOperationBuilder(
    destination,
    AssetTypeNative(),
    amount,
  );
  if (operationSource != null) payment.setSourceAccount(operationSource);
  return (TransactionBuilder(
    Account(source, BigInt.one, muxedAccountMed25519Id: muxedId),
  )..addOperation(payment.build())).build();
}

String signPreimage(KeyPair key, String preimageXdr) =>
    base64Encode(key.sign(Util.hash(base64Decode(preimageXdr))));

const nativeSac = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';

SorobanAddressCredentials unsignedCredentials(String address) =>
    SorobanAddressCredentials(
      Address.forAccountId(address),
      BigInt.parse('1570470793062724901'),
      4953587,
      XdrSCVal.forVoid(),
    );

/// ADDRESS_V2 (CAP-71) credentials, as SDF Testnet protocol 29 simulates them.
SorobanAuthorizationEntry unsignedV2AuthEntry(String address) =>
    unsignedAuthEntry(
      address,
      credentials: SorobanCredentials.forAddressV2(
        unsignedCredentials(address),
      ),
    );

/// A server-simulated, unsigned legacy address-credential auth entry for a
/// SAC `transfer(from, to, amount)` invocation.
SorobanAuthorizationEntry unsignedAuthEntry(
  String credentialAddress, {
  SorobanCredentials? credentials,
}) {
  final invocation = SorobanAuthorizedInvocation(
    SorobanAuthorizedFunction(
      contractFn: XdrInvokeContractArgs(
        Address.forContractId(nativeSac).toXdr(),
        'transfer',
        [
          Address.forAccountId(credentialAddress).toXdrSCVal(),
          Address.forAccountId(destination).toXdrSCVal(),
          XdrSCVal.forI128Parts(BigInt.zero, BigInt.from(10000000)),
        ],
      ),
    ),
  );
  return SorobanAuthorizationEntry(
    credentials ??
        SorobanCredentials.forAddressLegacy(
          Address.forAccountId(credentialAddress),
          BigInt.from(424242),
          4953189,
          XdrSCVal.forVoid(),
        ),
    invocation,
  );
}

String signWith(KeyPair key, String xdr) {
  final parsed = AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
  parsed.sign(key, Network.TESTNET);
  return parsed.toEnvelopeXdrBase64();
}

void main() {
  late KeyPair walletKey;
  late FakeBridge bridge;
  late FreighterWallet wallet;

  setUp(() {
    walletKey = KeyPair.random();
    bridge = FakeBridge(walletKey);
    wallet = FreighterWallet(bridge);
  });

  test('rejects a non-Testnet wallet', () async {
    bridge.passphrase = Network.PUBLIC.networkPassphrase;
    await expectLater(wallet.connect(), throwsA(isA<WrongNetwork>()));
  });

  test('rejects when the active account changes before signing', () async {
    await wallet.connect();
    bridge.activeAddress = KeyPair.random().accountId;
    await expectLater(
      wallet.signTransaction(
        transaction(walletKey.accountId, '1').toEnvelopeXdrBase64(),
      ),
      throwsA(isA<WalletAccountChanged>()),
    );
  });

  test('rejects an unchanged envelope', () async {
    await wallet.connect();
    await expectLater(
      wallet.signTransaction(
        transaction(walletKey.accountId, '1').toEnvelopeXdrBase64(),
      ),
      throwsA(isA<InvalidEnvelope>()),
    );
  });

  test(
    'rejects an envelope containing only a pre-existing signature',
    () async {
      final unsigned = transaction(walletKey.accountId, '1')
        ..sign(walletKey, Network.TESTNET);
      await wallet.connect();
      await expectLater(
        wallet.signTransaction(unsigned.toEnvelopeXdrBase64()),
        throwsA(isA<InvalidEnvelope>()),
      );
    },
  );

  test('rejects a new valid signature from an unrelated signer', () async {
    bridge.signer = (xdr) {
      final parsed =
          AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
      parsed.sign(KeyPair.random(), Network.TESTNET);
      return parsed.toEnvelopeXdrBase64();
    };
    await wallet.connect();
    await expectLater(
      wallet.signTransaction(
        transaction(walletKey.accountId, '1').toEnvelopeXdrBase64(),
      ),
      throwsA(isA<InvalidEnvelope>()),
    );
  });

  test(
    'accepts one newly added Testnet signature from connected wallet',
    () async {
      bridge.signer = (xdr) {
        final parsed =
            AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
        parsed.sign(walletKey, Network.TESTNET);
        return parsed.toEnvelopeXdrBase64();
      };
      await wallet.connect();
      expect(
        await wallet.signTransaction(
          transaction(walletKey.accountId, '1').toEnvelopeXdrBase64(),
        ),
        isNotEmpty,
      );
    },
  );

  test('rejects a semantically modified signed envelope', () async {
    bridge.signer = (_) {
      final changed = transaction(walletKey.accountId, '2')
        ..sign(walletKey, Network.TESTNET);
      return changed.toEnvelopeXdrBase64();
    };
    await wallet.connect();
    await expectLater(
      wallet.signTransaction(
        transaction(walletKey.accountId, '1').toEnvelopeXdrBase64(),
      ),
      throwsA(isA<ModifiedEnvelope>()),
    );
  });

  test('reports wallet rejection', () async {
    bridge.signingFailure = const WalletRejected('user rejected');
    await wallet.connect();
    await expectLater(
      wallet.signTransaction(
        transaction(walletKey.accountId, '1').toEnvelopeXdrBase64(),
      ),
      throwsA(isA<WalletRejected>()),
    );
  });

  test('requires wallet connection', () async {
    await expectLater(
      wallet.signTransaction('x'),
      throwsA(isA<WalletUnavailable>()),
    );
  });

  group('source-account binding', () {
    test('rejects a transaction whose source is another account '
        'without prompting the wallet', () async {
      await wallet.connect();
      await expectLater(
        wallet.signTransaction(
          transaction(KeyPair.random().accountId, '1').toEnvelopeXdrBase64(),
        ),
        throwsA(isA<PayloadAccountMismatch>()),
      );
      expect(bridge.signTransactionCalls, 0);
    });

    test('rejects an operation whose explicit source is another account '
        'without prompting the wallet', () async {
      await wallet.connect();
      await expectLater(
        wallet.signTransaction(
          transaction(
            walletKey.accountId,
            '1',
            operationSource: KeyPair.random().accountId,
          ).toEnvelopeXdrBase64(),
        ),
        throwsA(isA<PayloadAccountMismatch>()),
      );
      expect(bridge.signTransactionCalls, 0);
    });

    test('accepts muxed sources backed by the connected account', () async {
      bridge.signer = (xdr) => signWith(walletKey, xdr);
      await wallet.connect();
      final muxedTx = transaction(
        walletKey.accountId,
        '1',
        muxedId: BigInt.from(68),
        operationSource: MuxedAccount(
          walletKey.accountId,
          BigInt.from(7),
        ).accountId,
      );
      expect(muxedTx.sourceAccount.accountId, startsWith('M'));
      expect(
        await wallet.signTransaction(muxedTx.toEnvelopeXdrBase64()),
        isNotEmpty,
      );
      expect(bridge.signTransactionCalls, 1);
    });
  });

  group('auth-entry signing', () {
    test('sends the Testnet authorization preimage and attaches a verified '
        'signature exactly like the SDK signer', () async {
      await wallet.connect();
      final entry = unsignedAuthEntry(walletKey.accountId);

      final signedXdr = await wallet.signAuthEntry(
        entry.toBase64EncodedXdrString(),
      );

      final expectedPreimage = XdrDataOutputStream();
      XdrHashIDPreimage.encode(
        expectedPreimage,
        entry.buildPreimage(Network.TESTNET),
      );
      expect(bridge.lastPreimageXdr, base64Encode(expectedPreimage.bytes));
      final preimage = XdrHashIDPreimage.decode(
        XdrDataInputStream(base64Decode(bridge.lastPreimageXdr!)),
      );
      expect(
        preimage.type,
        XdrEnvelopeType.ENVELOPE_TYPE_SOROBAN_AUTHORIZATION,
      );

      final sdkSigned = unsignedAuthEntry(walletKey.accountId)
        ..sign(walletKey, Network.TESTNET);
      expect(signedXdr, sdkSigned.toBase64EncodedXdrString());

      final signed = SorobanAuthorizationEntry.fromBase64EncodedXdr(signedXdr);
      final signatureMap =
          signed.credentials.addressCredentials!.signature.vec!.single.map!;
      final signatureBytes = signatureMap
          .singleWhere((e) => e.key.sym == 'signature')
          .val
          .bytes!
          .sCBytes;
      expect(
        walletKey.verify(
          Util.hash(base64Decode(bridge.lastPreimageXdr!)),
          signatureBytes,
        ),
        isTrue,
      );
    });

    test('rejects credentials for another account without prompting', () async {
      await wallet.connect();
      await expectLater(
        wallet.signAuthEntry(
          unsignedAuthEntry(
            KeyPair.random().accountId,
          ).toBase64EncodedXdrString(),
        ),
        throwsA(isA<PayloadAccountMismatch>()),
      );
      expect(bridge.signAuthEntryCalls, 0);
    });

    group('ADDRESS_V2 credentials', () {
      test('signs the address-bound preimage and keeps the V2 arm, '
          'byte-identical to the SDK signer', () async {
        await wallet.connect();
        final entry = unsignedV2AuthEntry(walletKey.accountId);

        final signedXdr = await wallet.signAuthEntry(
          entry.toBase64EncodedXdrString(),
        );

        final preimage = XdrHashIDPreimage.decode(
          XdrDataInputStream(base64Decode(bridge.lastPreimageXdr!)),
        );
        expect(
          preimage.type,
          XdrEnvelopeType.ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS,
        );
        expect(
          Address.fromXdr(
            preimage.sorobanAuthorizationWithAddress!.address,
          ).accountId,
          walletKey.accountId,
        );
        final sdkSigned = unsignedV2AuthEntry(walletKey.accountId)
          ..sign(walletKey, Network.TESTNET);
        expect(signedXdr, sdkSigned.toBase64EncodedXdrString());
        expect(
          SorobanAuthorizationEntry.fromBase64EncodedXdr(
            signedXdr,
          ).credentials.arm,
          XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS_V2,
        );
      });

      test(
        'rejects V2 credentials for another account without prompting',
        () async {
          await wallet.connect();
          await expectLater(
            wallet.signAuthEntry(
              unsignedV2AuthEntry(
                KeyPair.random().accountId,
              ).toBase64EncodedXdrString(),
            ),
            throwsA(isA<PayloadAccountMismatch>()),
          );
          expect(bridge.signAuthEntryCalls, 0);
        },
      );

      test(
        'rejects a signature over the legacy preimage for a V2 entry',
        () async {
          final legacyPreimage = XdrDataOutputStream();
          XdrHashIDPreimage.encode(
            legacyPreimage,
            unsignedAuthEntry(
              walletKey.accountId,
            ).buildPreimage(Network.TESTNET),
          );
          bridge.authSigner = (_) => AuthEntrySignature(
            signature: signPreimage(
              walletKey,
              base64Encode(legacyPreimage.bytes),
            ),
            signerAddress: walletKey.accountId,
          );
          await wallet.connect();
          await expectLater(
            wallet.signAuthEntry(
              unsignedV2AuthEntry(
                walletKey.accountId,
              ).toBase64EncodedXdrString(),
            ),
            throwsA(isA<InvalidEnvelope>()),
          );
        },
      );

      test('rejects a foreign-key signature for a V2 entry', () async {
        final foreign = KeyPair.random();
        bridge.authSigner = (preimage) => AuthEntrySignature(
          signature: signPreimage(foreign, preimage),
          signerAddress: walletKey.accountId,
        );
        await wallet.connect();
        await expectLater(
          wallet.signAuthEntry(
            unsignedV2AuthEntry(walletKey.accountId).toBase64EncodedXdrString(),
          ),
          throwsA(isA<InvalidEnvelope>()),
        );
      });
    });

    test(
      'rejects ADDRESS_WITH_DELEGATES credentials without prompting',
      () async {
        await wallet.connect();
        await expectLater(
          wallet.signAuthEntry(
            unsignedAuthEntry(
              walletKey.accountId,
              credentials: SorobanCredentials.forAddressWithDelegates(
                SorobanAddressCredentialsWithDelegates(
                  unsignedCredentials(walletKey.accountId),
                  [],
                ),
              ),
            ).toBase64EncodedXdrString(),
          ),
          throwsA(isA<UnsupportedAuthCredentials>()),
        );
        expect(bridge.signAuthEntryCalls, 0);
      },
    );

    test('rejects source-account credentials without prompting', () async {
      await wallet.connect();
      await expectLater(
        wallet.signAuthEntry(
          unsignedAuthEntry(
            walletKey.accountId,
            credentials: SorobanCredentials.forSourceAccount(),
          ).toBase64EncodedXdrString(),
        ),
        throwsA(isA<InvalidEnvelope>()),
      );
      expect(bridge.signAuthEntryCalls, 0);
    });

    test('rejects a signature made by a foreign key', () async {
      final foreign = KeyPair.random();
      bridge.authSigner = (preimage) => AuthEntrySignature(
        signature: signPreimage(foreign, preimage),
        signerAddress: walletKey.accountId,
      );
      await wallet.connect();
      await expectLater(
        wallet.signAuthEntry(
          unsignedAuthEntry(walletKey.accountId).toBase64EncodedXdrString(),
        ),
        throwsA(isA<InvalidEnvelope>()),
      );
    });

    test('rejects a signature that is not 64 bytes', () async {
      bridge.authSigner = (_) =>
          AuthEntrySignature(signature: base64Encode(List.filled(32, 1)));
      await wallet.connect();
      await expectLater(
        wallet.signAuthEntry(
          unsignedAuthEntry(walletKey.accountId).toBase64EncodedXdrString(),
        ),
        throwsA(isA<InvalidEnvelope>()),
      );
    });

    test('rejects a signature that is not base64', () async {
      bridge.authSigner = (_) =>
          const AuthEntrySignature(signature: 'not base64!');
      await wallet.connect();
      await expectLater(
        wallet.signAuthEntry(
          unsignedAuthEntry(walletKey.accountId).toBase64EncodedXdrString(),
        ),
        throwsA(isA<InvalidEnvelope>()),
      );
    });

    test(
      'rejects a wallet-reported signer that differs from the session',
      () async {
        bridge.authSigner = (preimage) => AuthEntrySignature(
          signature: signPreimage(walletKey, preimage),
          signerAddress: KeyPair.random().accountId,
        );
        await wallet.connect();
        await expectLater(
          wallet.signAuthEntry(
            unsignedAuthEntry(walletKey.accountId).toBase64EncodedXdrString(),
          ),
          throwsA(isA<WalletAccountChanged>()),
        );
      },
    );

    test('rejects malformed auth-entry XDR without prompting', () async {
      await wallet.connect();
      for (final input in ['', 'AAAA', 'not-xdr']) {
        await expectLater(
          wallet.signAuthEntry(input),
          throwsA(isA<InvalidEnvelope>()),
        );
      }
      expect(bridge.signAuthEntryCalls, 0);
    });
  });
}
