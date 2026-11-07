import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nirium_audit_spike/nirium_audit.dart';
import 'package:test/test.dart';

import 'support.dart';

Future<EscrowSettlement> _job3Chain(String txHash) async {
  if (txHash != job3Tx) throw StateError('unknown transaction $txHash');
  return job3();
}

void main() {
  final signer = testSigner();

  Map<String, Object?> doc({AnchorMode mode = AnchorMode.record}) =>
      anchoredDoc(anchorBody(job3Record(), signer: signer, mode: mode));

  Future<ReceiptCheck> verify(
    Map<String, Object?> d, {
    Map<String, Object?>? local,
    SettlementLookup chain = _job3Chain,
    String? key,
  }) => verifyReceipt(
    d,
    trustedKey: key ?? signer.address,
    chain: chain,
    localRecord: local,
  );

  group('verifyReceipt', () {
    test('a record-mode receipt for job 3 verifies', () async {
      final check = await verify(doc());
      expect(check.failures, isEmpty);
      expect(check.ok, isTrue);
    });

    test('a hash-only receipt verifies with the local record', () async {
      final check = await verify(
        doc(mode: AnchorMode.hash),
        local: job3Record(),
      );
      expect(check.failures, isEmpty);
    });

    test('a hash-only receipt without the record does not verify', () async {
      final check = await verify(doc(mode: AnchorMode.hash));
      expect(check.ok, isFalse);
      expect(check.failures.single, contains('hash-only'));
    });

    test('a changed amount fails the hash and the chain', () async {
      final d = doc();
      final record = d['record'] as Map<String, Object?>;
      (record['transfers'] as List).first['amount'] = '5.0000000';
      final check = await verify(d);
      expect(check.ok, isFalse);
      expect(
        check.failures,
        containsAll([
          'content_sha256 does not match the record',
          'the attestation signature does not cover this record',
        ]),
      );
      expect(check.failures.any((f) => f.startsWith('transfers:')), isTrue);
    });

    test('a record re-signed to claim another agent fails on chain', () async {
      // An attacker who holds the key still cannot name an unpaid agent.
      final record = job3Record();
      (record['agent'] as Map)['wallet'] =
          'GBXHIBZLBY52TEKDSIVNNOK6XEVEEKXKVNPQXBYTH6SFX6ETG5KBWDC3';
      final d = anchoredDoc(
        anchorBody(record, signer: signer, mode: AnchorMode.record),
      );
      final check = await verify(d);
      expect(check.failures.single, contains('was not paid'));
    });

    test('a hash-only receipt fails for a changed local record', () async {
      final local = job3Record()..['job_id'] = '4';
      final check = await verify(doc(mode: AnchorMode.hash), local: local);
      expect(
        check.failures,
        contains('content_sha256 does not match the record'),
      );
      expect(check.failures.any((f) => f.startsWith('job_id:')), isTrue);
    });

    test('a wrong signature does not verify', () async {
      final d = doc();
      (d['agent'] as Map)['signature'] = testSigner(
        8,
      ).sign(d['content_sha256'] as String);
      final check = await verify(d);
      expect(check.failures, [
        'the attestation signature does not cover this record',
      ]);
    });

    test('a receipt attested by another key is not puls3', () async {
      final other = testSigner(8);
      final d = anchoredDoc(
        anchorBody(job3Record(), signer: other, mode: AnchorMode.record),
      );
      final check = await verify(d);
      expect(check.failures.single, startsWith('attested by ${other.address}'));
    });

    test('an unattested receipt does not verify', () async {
      // Nirium's verifier accepts this; a puls3 receipt must be signed.
      final d = doc()..remove('agent');
      final check = await verify(d);
      expect(check.failures, ['the receipt is not attested']);
    });

    test('a transaction that is not this settlement fails', () async {
      final check = await verify(
        doc(),
        chain: (_) async => throw const NotASettlement('not a complete'),
      );
      expect(check.failures.single, contains('not a settlement'));
    });

    test('an extra field in the record is refused', () async {
      final record = job3Record()..['prompt'] = 'summarize my invoices';
      final d = anchoredDoc(
        anchorBody(record, signer: signer, mode: AnchorMode.record),
      );
      final check = await verify(d);
      expect(check.failures.single, contains('extra fields: {prompt}'));
    });

    test('a stored record out of canonical order is reported', () async {
      final d = doc();
      final record = d['record'] as Map<String, Object?>;
      d['record'] = {
        for (final k in record.keys.toList().reversed) k: record[k],
      };
      final check = await verify(d);
      expect(check.failures, [
        'the stored record is not in canonical key order',
      ]);
    });

    test('a record on another network is refused', () async {
      final d = doc()..['network'] = 'stellar:pubnet';
      final check = await verify(d);
      expect(check.failures.single, contains('anchored on stellar:pubnet'));
    });
  });

  group('NiriumAuditClient', () {
    test('posts JSON to /api/audit/log and reads the anchor', () async {
      late http.Request sent;
      final client = NiriumAuditClient(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'cid': 'bafy${'a' * 55}',
              'content_sha256': 'f' * 64,
              'anchoredAt': '2026-11-07T00:00:00.000Z',
              'attestedBy': signer.address,
            }),
            200,
          );
        }),
      );
      final anchor = await client.anchor({'hash': 'sha-256:${'f' * 64}'});
      expect(sent.method, 'POST');
      expect('${sent.url}', 'https://nirium-agent.fly.dev/api/audit/log');
      expect(sent.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {'hash': 'sha-256:${'f' * 64}'});
      expect(anchor.contentSha256, 'f' * 64);
      expect(anchor.attestedBy, signer.address);
    });

    test('a 429 is a rate-limited NiriumError', () async {
      final client = NiriumAuditClient(
        MockClient((_) async => http.Response('slow down', 429)),
      );
      await expectLater(
        client.anchor({}),
        throwsA(isA<NiriumError>().having((e) => e.rateLimited, 'rate', true)),
      );
    });
  });

  group('readers', () {
    test('IpfsReader falls back to the next gateway', () async {
      final asked = <String>[];
      final reader = IpfsReader(
        MockClient((request) async {
          asked.add(request.url.host);
          return request.url.host == 'ipfs.io'
              ? http.Response(jsonEncode(doc()), 200)
              : http.Response('rate limited', 429);
        }),
      );
      final got = await reader.read('Qm${'a' * 44}');
      expect(got['content_sha256'], doc()['content_sha256']);
      expect(asked, ['nirium.myfilebase.com', 'ipfs.io']);
    });

    test('IpfsReader names every gateway when none answers', () async {
      final reader = IpfsReader(
        MockClient((_) async => http.Response('no', 504)),
      );
      await expectLater(
        reader.read('Qm${'a' * 44}'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'm',
            contains('dweb.link: HTTP 504'),
          ),
        ),
      );
    });

    test('HorizonReader reads job 3 from the two endpoints', () async {
      final reader = HorizonReader(
        MockClient((request) async {
          final path = request.url.path;
          if (path == '/transactions/$job3Tx') {
            return http.Response(
              jsonEncode(fixture('complete-job3-tx.json')),
              200,
            );
          }
          if (path == '/transactions/$job3Tx/operations') {
            return http.Response(
              jsonEncode(fixture('complete-job3-ops.json')),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );
      final s = await reader.settlement(job3Tx);
      expect(s.jobId, '3');
      expect(s.transfers.single.to, ledgerScoutWallet);
    });
  });
}
