// Sep10Verifier: the checks that run before a challenge is consumed.
import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/auth/challenge_store.dart';
import 'package:puls3_server/src/auth/sep10_verifier.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show Puls3ApiException;
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_sep10_codec.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import '../../support/in_memory_challenge_store.dart';

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
  final serverAccount = _accountOf(serverKey);
  final wallet = _accountOf(walletKey);
  final otherWallet = _accountOf(otherKey);
  final signerAAccount = _accountOf(signerA);
  final signerBAccount = _accountOf(signerB);
  final nonce = Uint8List.fromList(List<int>.generate(48, (i) => i + 1));
  final now = DateTime.utc(2026, 10, 9, 12);
  const network = 'Test SDF Network ; September 2015';

  final codec = StellarSep10Codec(
    signingKey: serverKey.toBase32(),
    homeDomain: 'puls3.app',
    webAuthDomain: 'auth.puls3.app',
    networkPassphrase: network,
  );

  BuiltChallenge challengeFor(StellarAddress account) => codec.build(
    wallet: account,
    nonce: nonce,
    now: now,
  );

  Sep10Verifier verifierFor({
    required InMemoryChallengeStore store,
    required _Chain chain,
    DateTime? clock,
  }) => Sep10Verifier(
    codec: codec,
    store: store,
    chain: chain,
    serverAccount: serverAccount,
    now: () => clock ?? now,
  );

  Future<InMemoryChallengeStore> issued({
    DateTime? expiresAt,
    bool consumed = false,
    StellarAddress? account,
  }) async {
    final store = InMemoryChallengeStore(now: () => now);
    final owner = account ?? wallet;
    final built = challengeFor(owner);
    await store.insert(
      NewChallenge(
        challengeId: 'ch-1',
        wallet: owner.value,
        challengeXdr: built.envelopeXdr,
        transactionHash: hexOf(built.hash),
        expiresAt: expiresAt ?? now.add(const Duration(seconds: 900)),
      ),
    );
    if (consumed) await store.consume('ch-1');
    return store;
  }

  Future<StoredChallenge> verify(
    Sep10Verifier verifier,
    String signed, {
    String id = 'ch-1',
    String? account,
  }) => verifier.verify(
    challengeId: id,
    wallet: account ?? wallet.value,
    signedChallengeXdr: signed,
  );

  test('a master key that meets the medium threshold is accepted', () async {
    final store = await issued();
    final chain = _Chain(
      AccountAuthority(masterWeight: 1, mediumThreshold: 1, signers: {}),
    );
    final signed = _sign(challengeFor(wallet), clients: [walletKey]);

    final accepted = await verify(
      verifierFor(store: store, chain: chain),
      signed,
    );

    expect(accepted.challengeId, 'ch-1');
    expect(accepted.consumedAt, isNull);
    expect(chain.reads, [wallet]);
  });

  test(
    'two signers that together meet the medium threshold are accepted',
    () async {
      final store = await issued();
      final chain = _Chain(
        AccountAuthority(
          masterWeight: 0,
          mediumThreshold: 2,
          signers: {signerAAccount: 1, signerBAccount: 1},
        ),
      );
      final signed = _sign(
        challengeFor(wallet),
        clients: [signerA, signerB],
      );

      await verify(verifierFor(store: store, chain: chain), signed);

      expect((await store.find('ch-1'))!.consumedAt, isNull);
    },
  );

  test('a medium threshold of 0 accepts any positive weight', () async {
    final store = await issued();
    final chain = _Chain(
      AccountAuthority(masterWeight: 1, mediumThreshold: 0, signers: {}),
    );

    await verify(
      verifierFor(store: store, chain: chain),
      _sign(challengeFor(wallet), clients: [walletKey]),
    );
  });

  test('an unknown challenge fails before the wallet is parsed', () async {
    final store = InMemoryChallengeStore(now: () => now);
    final chain = _Chain(null);

    await expectLater(
      verify(
        verifierFor(store: store, chain: chain),
        'ignored',
        id: 'missing',
        account: 'not-an-address',
      ),
      throwsA(_code('ChallengeNotFound')),
    );
    expect(chain.reads, isEmpty);
  });

  test('a malformed wallet fails before consumed or mismatch', () async {
    final store = await issued(consumed: true);

    await expectLater(
      verify(
        verifierFor(store: store, chain: _Chain(null)),
        'ignored',
        account: 'not-an-address',
      ),
      throwsA(_code('InvalidStellarAddress')),
    );
  });

  test('a different wallet is a mismatch and stays unconsumed', () async {
    final store = await issued();

    await expectLater(
      verify(
        verifierFor(store: store, chain: _Chain(null)),
        _sign(challengeFor(otherWallet), clients: [otherKey]),
        account: otherWallet.value,
      ),
      throwsA(_reason('walletMismatch')),
    );
    expect((await store.find('ch-1'))!.consumedAt, isNull);
  });

  test('a consumed challenge fails before an expired one', () async {
    final store = await issued(consumed: true);

    await expectLater(
      verify(
        verifierFor(
          store: store,
          chain: _Chain(null),
          clock: now.add(const Duration(hours: 1)),
        ),
        _sign(challengeFor(wallet), clients: [walletKey]),
      ),
      throwsA(_code('ChallengeConsumed')),
    );
  });

  test('an expiry equal to now is expired', () async {
    final store = await issued(expiresAt: now);

    await expectLater(
      verify(
        verifierFor(store: store, chain: _Chain(null)),
        _sign(challengeFor(wallet), clients: [walletKey]),
      ),
      throwsA(_code('ChallengeExpired')),
    );
  });

  test('malformed XDR is rejected', () async {
    final store = await issued();
    final cases = [
      '',
      '***not base64***',
      base64Encode([0, 0, 0, 5]),
    ];

    for (final signed in cases) {
      await expectLater(
        verify(verifierFor(store: store, chain: _Chain(null)), signed),
        throwsA(_reason('malformed')),
        reason: signed,
      );
    }
  });

  test('a body that is not the stored challenge is tampered', () async {
    final store = await issued();
    final built = challengeFor(wallet);
    final decoded =
        stellar.Envelope.fromXdr(base64Decode(built.envelopeXdr))
            as stellar.TransactionV1Envelope;
    final tx = decoded.tx;
    final cases = {
      'source': tx.copyWith(
        sourceAccount: stellar.MuxedAccount.fromBase32Address(wallet.value),
      ),
      'sequence': tx.copyWith(seqNum: BigInt.one),
      'time bounds': tx.copyWith(
        cond: stellar.PrecondTime(
          stellar.TimeBounds(minTime: BigInt.one, maxTime: BigInt.two),
        ),
      ),
      'first op': tx.copyWith(
        operations: [
          stellar.Operation(
            sourceAccount: tx.operations.first.sourceAccount,
            body: stellar.ManageDataOperation(
              dataName: 'other auth',
              dataValue: utf8.encode('changed'),
            ),
          ),
          tx.operations[1],
        ],
      ),
      'extra op': tx.copyWith(
        operations: [
          ...tx.operations,
          stellar.Operation(
            sourceAccount: stellar.MuxedAccount.fromBase32Address(
              wallet.value,
            ),
            body: stellar.ManageDataOperation(
              dataName: 'extra',
              dataValue: utf8.encode('no'),
            ),
          ),
        ],
      ),
    };

    for (final entry in cases.entries) {
      final chain = _Chain.unavailable();
      await expectLater(
        verify(
          verifierFor(store: store, chain: chain),
          _rebuilt(entry.value, serverKey, network),
        ),
        throwsA(_reason('tampered')),
        reason: entry.key,
      );
      expect(chain.reads, isEmpty, reason: entry.key);
    }
  });

  test(
    'a missing, replaced or corrupted server signature is rejected',
    () async {
      final store = await issued();
      final built = challengeFor(wallet);
      final cases = [
        _sign(built, includeServer: false, clients: [walletKey]),
        _sign(built, serverReplacement: otherKey, clients: [walletKey]),
        _sign(built, corruptServer: true, clients: [walletKey]),
      ];

      for (final signed in cases) {
        await expectLater(
          verify(verifierFor(store: store, chain: _Chain(null)), signed),
          throwsA(_reason('serverSignature')),
        );
      }
    },
  );

  test(
    'an unreadable chain fails closed with no master-key fallback',
    () async {
      final store = await issued();
      final chain = _Chain.unavailable();

      await expectLater(
        verify(
          verifierFor(store: store, chain: chain),
          _sign(challengeFor(wallet), clients: [walletKey]),
        ),
        throwsA(_code('AuthenticationUnavailable')),
      );
      expect((await store.find('ch-1'))!.consumedAt, isNull);
    },
  );

  test('a signature by someone who is not a signer does not count', () async {
    final store = await issued();
    final chain = _Chain(
      AccountAuthority(masterWeight: 1, mediumThreshold: 1, signers: {}),
    );

    await expectLater(
      verify(
        verifierFor(store: store, chain: chain),
        _sign(challengeFor(wallet), clients: [otherKey]),
      ),
      throwsA(_reason('noClientSignature')),
    );
  });

  test('the server signature does not count toward weight', () async {
    final store = await issued();
    final chain = _Chain(
      AccountAuthority(
        masterWeight: 0,
        mediumThreshold: 1,
        signers: {serverAccount: 10},
      ),
    );

    await expectLater(
      verify(
        verifierFor(store: store, chain: chain),
        challengeFor(wallet).envelopeXdr,
      ),
      throwsA(_reason('noClientSignature')),
    );
  });

  test('weight below the medium threshold is rejected', () async {
    final store = await issued();
    final chain = _Chain(
      AccountAuthority(
        masterWeight: 0,
        mediumThreshold: 2,
        signers: {signerAAccount: 1, signerBAccount: 1},
      ),
    );

    await expectLater(
      verify(
        verifierFor(store: store, chain: chain),
        _sign(challengeFor(wallet), clients: [signerA]),
      ),
      throwsA(_reason('insufficientWeight')),
    );
    expect((await store.find('ch-1'))!.consumedAt, isNull);
  });

  test('an unfunded account needs exactly one master signature', () async {
    final store = await issued();
    final chain = _Chain(null);
    final built = challengeFor(wallet);

    await verify(
      verifierFor(store: store, chain: chain),
      _sign(built, clients: [walletKey]),
    );

    await expectLater(
      verify(
        verifierFor(store: store, chain: chain),
        _sign(built, clients: [walletKey, signerA]),
      ),
      throwsA(_reason('invalidClientSignature')),
    );
    await expectLater(
      verify(
        verifierFor(store: store, chain: chain),
        _sign(built, clients: [otherKey]),
      ),
      throwsA(_reason('invalidClientSignature')),
    );
  });

  test(
    'a wrong-network client signature leaves the body and fails closed',
    () async {
      final store = await issued();
      final built = challengeFor(wallet);
      final decoded =
          stellar.Envelope.fromXdr(base64Decode(built.envelopeXdr))
              as stellar.TransactionV1Envelope;
      final wrongHash = Uint8List.fromList(
        stellar.TransactionSignaturePayload(
          networkId: stellar.StellarNetwork.fromPassphrase(
            'Public Global Stellar Network ; September 2015',
          ).passphraseHash,
          taggedTransaction: decoded.tx,
        ).txHash(),
      );
      final chain = _Chain(
        AccountAuthority(masterWeight: 1, mediumThreshold: 1, signers: {}),
      );

      await expectLater(
        verify(
          verifierFor(store: store, chain: chain),
          _sign(built, clients: [walletKey], clientDigest: wrongHash),
        ),
        throwsA(_reason('noClientSignature')),
      );
      expect((await store.find('ch-1'))!.consumedAt, isNull);
    },
  );
}

StellarAddress _accountOf(stellar.StellarPrivateKey key) =>
    StellarAddress.parse(key.toPublicKey().toAddress().address);

String _sign(
  BuiltChallenge challenge, {
  List<stellar.StellarPrivateKey> clients = const [],
  bool includeServer = true,
  bool corruptServer = false,
  stellar.StellarPrivateKey? serverReplacement,
  Uint8List? clientDigest,
}) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(challenge.envelopeXdr))
          as stellar.TransactionV1Envelope;
  final signatures = <stellar.DecoratedSignature>[];
  if (includeServer) {
    final server = decoded.signatures.single;
    if (corruptServer) {
      signatures.add(
        stellar.DecoratedSignature(
          hint: server.hint,
          signature: Uint8List.fromList([
            ...server.signature.sublist(0, server.signature.length - 1),
            server.signature.last ^ 0xff,
          ]),
        ),
      );
    } else if (serverReplacement != null) {
      signatures.add(serverReplacement.sign(challenge.hash));
    } else {
      signatures.add(server);
    }
  }
  final digest = clientDigest ?? challenge.hash;
  for (final key in clients) {
    signatures.add(key.sign(digest));
  }
  return base64Encode(
    stellar.TransactionV1Envelope(
      tx: decoded.tx,
      signatures: signatures,
    ).toVariantXDR(),
  );
}

String _rebuilt(
  stellar.StellarTransactionV1 tx,
  stellar.StellarPrivateKey serverKey,
  String network,
) {
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

Matcher _reason(String reason) => isA<Puls3ApiException>().having(
  (error) => error.details?['reason'],
  'reason',
  reason,
);

final class _Chain implements ChainAccounts {
  _Chain(this.authority);

  _Chain.unavailable() : authority = null, throwUnavailable = true;

  final AccountAuthority? authority;
  final reads = <StellarAddress>[];
  var throwUnavailable = false;

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async {
    reads.add(account);
    if (throwUnavailable) throw chainUnavailable();
    return authority;
  }

  @override
  Future<int> sequenceOf(StellarAddress account) => throw UnimplementedError();

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) =>
      throw UnimplementedError();
}
