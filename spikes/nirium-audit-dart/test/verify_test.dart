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
    JobLookup? job,
    String? key,
  }) => verifyReceipt(
    d,
    trustedKey: key ?? signer.address,
    chain: chain,
    job: job ?? job3Lookup(),
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
      expect(check.failures, hasLength(2));
      expect(check.failures.first, contains('was not paid'));
      expect(check.failures.last, startsWith('wallet: record'));
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

    test('the escrow job must name the same agent', () async {
      final check = await verify(
        doc(),
        job: job3Lookup(
          const EscrowJob(agentId: 8, provider: ledgerScoutWallet, state: 3),
        ),
      );
      expect(check.failures, ['agent: record #7, escrow job #8']);
    });

    test('the escrow job must pay the named wallet', () async {
      // A wallet that was paid in the transaction but is not the job's
      // provider (for example a fee) cannot be named as the agent.
      const other = 'GBXHIBZLBY52TEKDSIVNNOK6XEVEEKXKVNPQXBYTH6SFX6ETG5KBWDC3';
      final check = await verify(
        doc(),
        job: job3Lookup(const EscrowJob(agentId: 7, provider: other, state: 3)),
      );
      expect(check.failures.single, startsWith('wallet: record'));
    });

    test('the escrow job must be completed', () async {
      final check = await verify(
        doc(),
        job: job3Lookup(
          const EscrowJob(agentId: 7, provider: ledgerScoutWallet, state: 2),
        ),
      );
      expect(check.failures, ['the escrow job is in state 2, not completed']);
    });

    test('an escrow job that cannot be read fails', () async {
      final check = await verify(
        doc(),
        job: (_, _) async => throw StateError('archived'),
      );
      expect(check.failures.single, contains('escrow job could not be read'));
    });

    test('the live record anchor verifies offline', () async {
      // The bytes Nirium's gateway served on 2026-11-07, with the chain and
      // the escrow job from fixtures.
      final d =
          jsonDecode(utf8.decode(served(recordCid))) as Map<String, Object?>;
      final check = await verify(d, key: spikeAttester);
      expect(check.failures, isEmpty);
      expect((check.record!['agent'] as Map)['registry_id'], '7');
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
              ? http.Response.bytes(served(recordCid), 200)
              : http.Response('rate limited', 429);
        }),
      );
      final got = await reader.read(recordCid);
      expect(got['content_sha256'], startsWith('16db1a9a'));
      expect(asked, ['nirium.myfilebase.com', 'ipfs.io']);
    });

    test('IpfsReader skips a gateway that serves another document', () async {
      final reader = IpfsReader(
        MockClient((request) async {
          if (request.url.host == 'nirium.myfilebase.com') {
            // A valid JSON document, but not the one at this CID.
            return http.Response.bytes(served(hashCid), 200);
          }
          return http.Response.bytes(served(recordCid), 200);
        }),
      );
      final got = await reader.read(recordCid);
      expect(got['record'], isNotNull);
    });

    test('IpfsReader refuses a document no gateway serves intact', () async {
      final tampered = utf8
          .decode(served(recordCid))
          .replaceFirst('0.5000000', '5.0000000');
      final reader = IpfsReader(
        MockClient((_) async => http.Response(tampered, 200)),
      );
      await expectLater(
        reader.read(recordCid),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'm',
            contains('content does not hash to the CID'),
          ),
        ),
      );
    });

    test('IpfsReader refuses a CID it cannot recompute', () async {
      final reader = IpfsReader(
        MockClient((_) async => fail('no request expected')),
      );
      await expectLater(
        reader.read('bafy${'a' * 55}'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('IpfsReader names every gateway when none answers', () async {
      final reader = IpfsReader(
        MockClient((_) async => http.Response('no', 504)),
      );
      await expectLater(
        reader.read(recordCid),
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

    test('SorobanJobReader asks getLedgerEntries for the job key', () async {
      late Map<String, Object?> sent;
      final reader = SorobanJobReader(
        MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, Object?>;
          final entry = fixture('escrow-job3-entry.json');
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'result': {
                'entries': [
                  {'xdr': entry['xdr']},
                ],
              },
            }),
            200,
          );
        }),
      );
      final job = await reader.job(escrow, '3');
      expect(sent['method'], 'getLedgerEntries');
      expect((sent['params'] as Map)['keys'], [jobLedgerKey(escrow, '3')]);
      expect(job.agentId, 7);
    });

    test('SorobanJobReader fails for a job with no live entry', () async {
      final reader = SorobanJobReader(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'result': {'entries': <Object>[]},
            }),
            200,
          ),
        ),
      );
      await expectLater(reader.job(escrow, '3'), throwsStateError);
    });
  });
}
