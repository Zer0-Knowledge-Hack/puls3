import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nirium_audit_spike/nirium_audit.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('ScVal and strkey', () {
    test('decodes the job 3 complete call from Horizon', () {
      final params = [
        for (final p
            in ((fixture('complete-job3-ops.json')['_embedded']
                        as Map)['records']
                    as List)
                .first['parameters'])
          decodeScVal(base64.decode(p['value'] as String)),
      ];
      expect(params[0], escrow);
      expect(params[1], 'complete');
      expect(params[2], startsWith('G'));
      expect(params[3], BigInt.from(3));
      expect(params[4], isNull); // Bytes: not decoded
    });

    test('encodes the same G address as stellar_dart', () {
      final key = stellar.StellarPrivateKey.fromBytes(List.filled(32, 9));
      final public = key.toPublicKey();
      expect(
        encodeStrkey(public.toBytes(), contract: false),
        public.toAddress().baseAddress,
      );
    });

    test('rejects a truncated ScVal', () {
      expect(
        () => decodeScVal(Uint8List.fromList([0, 0, 0, 5, 0])),
        throwsFormatException,
      );
    });
  });

  group('settlement from Horizon', () {
    test('reads job 3 as a complete that paid Ledger Scout', () {
      final s = job3();
      expect(s.txHash, job3Tx);
      expect(s.escrowContract, escrow);
      expect(s.jobId, '3');
      expect(s.ledger, 5023908);
      expect(s.asset, usdcTestnet);
      expect(s.transfers, [
        const Transfer(to: ledgerScoutWallet, amount: '0.5000000'),
      ]);
    });

    test('a failed transaction is not a settlement', () {
      expect(
        () => EscrowSettlement.fromHorizon(
          network: 'stellar:testnet',
          tx: {...fixture('complete-job3-tx.json'), 'successful': false},
          operations: fixture('complete-job3-ops.json'),
        ),
        throwsA(isA<NotASettlement>()),
      );
    });

    test('a call other than complete is not a settlement', () {
      final ops = fixture('complete-job3-ops.json');
      final op = ((ops['_embedded'] as Map)['records'] as List).first as Map;
      final params = op['parameters'] as List;
      // Sym "fund" in place of "complete".
      params[1] = {'type': 'Sym', 'value': 'AAAADwAAAARmdW5k'};
      expect(
        () => EscrowSettlement.fromHorizon(
          network: 'stellar:testnet',
          tx: fixture('complete-job3-tx.json'),
          operations: ops,
        ),
        throwsA(isA<NotASettlement>()),
      );
    });

    test('an escrow that paid nothing out is not a settlement', () {
      final ops = fixture('complete-job3-ops.json');
      final op = ((ops['_embedded'] as Map)['records'] as List).first as Map;
      op['asset_balance_changes'] = <Object?>[];
      expect(
        () => EscrowSettlement.fromHorizon(
          network: 'stellar:testnet',
          tx: fixture('complete-job3-tx.json'),
          operations: ops,
        ),
        throwsA(isA<NotASettlement>()),
      );
    });
  });

  group('receipt record', () {
    test('holds only the pinned public fields', () {
      final record = job3Record();
      expect(record.keys.toSet(), receiptFields);
      expect(record['agent'], {
        'registry_id': '7',
        'wallet': ledgerScoutWallet,
      });
      // Nothing that could be a prompt, a result, a person or a secret.
      final text = canonicalJson(record);
      for (final word in ['prompt', 'result', 'email', 'client', 'secret']) {
        expect(text.toLowerCase(), isNot(contains(word)), reason: word);
      }
      expect(RegExp(r'"S[A-Z2-7]{55}"').hasMatch(text), isFalse);
    });

    test('refuses an agent wallet the escrow did not pay', () {
      expect(
        () => receiptRecord(
          job3(),
          agentRegistryId: 8,
          agentWallet:
              'GBXHIBZLBY52TEKDSIVNNOK6XEVEEKXKVNPQXBYTH6SFX6ETG5KBWDC3',
        ),
        throwsArgumentError,
      );
    });

    test('canonical JSON sorts keys at every level and has no spaces', () {
      expect(
        canonicalJson({
          'b': '1',
          'a': [
            {'z': '1', 'y': '2'},
          ],
        }),
        '{"a":[{"y":"2","z":"1"}],"b":"1"}',
      );
    });

    test('canonical JSON refuses numbers and non-ASCII text', () {
      expect(() => canonicalJson({'a': 1.5}), throwsArgumentError);
      expect(() => canonicalJson({'a': 'ñ'}), throwsArgumentError);
    });
  });

  group('attestation', () {
    test("verifies Nirium's own attested fixture", () {
      final doc = fixture('valid-audit.json');
      final agent = doc['agent'] as Map<String, Object?>;
      // Nirium hashes JSON.stringify(record) in the stored key order.
      final hash = sha256
          .convert(utf8.encode(jsonEncode(doc['record'])))
          .toString();
      expect(hash, doc['content_sha256']);
      expect(
        verifyAttestation(
          key: agent['key'] as String,
          statement: attestationStatement(hash),
          signature: agent['signature'] as String,
        ),
        isTrue,
      );
    });

    test("verifies Nirium's hash-only fixture", () {
      final doc = fixture('hash-only-audit.json');
      final agent = doc['agent'] as Map<String, Object?>;
      expect(
        verifyAttestation(
          key: agent['key'] as String,
          statement: attestationStatement(doc['content_sha256'] as String),
          signature: agent['signature'] as String,
        ),
        isTrue,
      );
    });

    test('a signature over another hash does not verify', () {
      final signer = testSigner();
      final signature = signer.sign('a' * 64);
      expect(
        verifyAttestation(
          key: signer.address,
          statement: attestationStatement('b' * 64),
          signature: signature,
        ),
        isFalse,
      );
    });

    test('accepts a hex signature and rejects garbage', () {
      final signer = testSigner();
      final hash = 'c' * 64;
      final hex = base64
          .decode(signer.sign(hash))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final statement = attestationStatement(hash);
      expect(
        verifyAttestation(
          key: signer.address,
          statement: statement,
          signature: hex,
        ),
        isTrue,
      );
      expect(
        verifyAttestation(
          key: signer.address,
          statement: statement,
          signature: 'not a signature',
        ),
        isFalse,
      );
      expect(
        verifyAttestation(
          key: 'GNOTAKEY',
          statement: statement,
          signature: hex,
        ),
        isFalse,
      );
    });

    test('toString never shows the secret', () {
      final signer = testSigner();
      expect('$signer', isNot(contains(signer.exportSecret())));
      expect('$signer', contains(signer.address));
    });
  });

  group('anchor body', () {
    test('record mode sends the canonical record and a valid attestation', () {
      final record = job3Record();
      final signer = testSigner();
      final body = anchorBody(
        record,
        signer: signer,
        mode: AnchorMode.record,
        tag: 'puls3-spike-246',
      );
      expect(body.containsKey('hash'), isFalse);
      expect(jsonEncode(body['record']), canonicalJson(record));
      final agent = body['agent'] as Map;
      expect(agent['id'], 'puls3');
      expect(agent['key'], signer.address);
      expect(
        verifyAttestation(
          key: signer.address,
          statement: attestationStatement(contentSha256(record)),
          signature: agent['signature'] as String,
        ),
        isTrue,
      );
    });

    test('hash mode sends only the hash', () {
      final record = job3Record();
      final body = anchorBody(
        record,
        signer: testSigner(),
        mode: AnchorMode.hash,
      );
      expect(body.containsKey('record'), isFalse);
      expect(body.containsKey('tag'), isFalse);
      expect(body['hash'], 'sha-256:${contentSha256(record)}');
      expect(jsonEncode(body), isNot(contains(ledgerScoutWallet)));
    });
  });
}
