import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nirium_audit_spike/nirium_audit.dart';
import 'package:test/test.dart';

import 'support.dart';

Future<EscrowSettlement> _chain(String txHash) async {
  if (txHash != job3Tx) throw const NotASettlement('no complete call');
  return job3();
}

void main() {
  late http.Client client;
  setUp(() => client = http.Client());
  tearDown(() => client.close());

  group('LocalNiriumNode', () {
    late LocalNiriumNode node;
    setUp(() async => node = await LocalNiriumNode.start());
    tearDown(() => node.close());

    Map<String, Object?> body({AnchorMode mode = AnchorMode.record}) =>
        anchorBody(job3Record(), signer: testSigner(), mode: mode, tag: 't');

    test('listens on the loopback address only', () {
      expect(node.url.host, 'localhost');
      expect(node.gateway.path, '/ipfs/');
    });

    test('anchors a record and serves it at its real CID', () async {
      final anchor = await NiriumAuditClient(
        client,
        node: node.url,
      ).anchor(body());

      expect(anchor.contentSha256, contentSha256(job3Record()));
      expect(anchor.attestedBy, testSigner().address);
      final served = await client.get(node.gateway.resolve(anchor.cid));
      expect(cidV0ForFile(served.bodyBytes), anchor.cid);

      // The real reader accepts it, and the verifier trusts it.
      final doc = await IpfsReader(
        client,
        gateways: [node.gateway],
      ).read(anchor.cid);
      final check = await verifyReceipt(
        doc,
        trustedKey: testSigner().address,
        chain: _chain,
        job: job3Lookup(),
      );
      expect(check.failures, isEmpty);
    });

    test('a hash-only anchor stores no record', () async {
      final anchor = await NiriumAuditClient(
        client,
        node: node.url,
      ).anchor(body(mode: AnchorMode.hash));
      final doc = await IpfsReader(
        client,
        gateways: [node.gateway],
      ).read(anchor.cid);

      expect(doc.containsKey('record'), isFalse);
      expect(doc['content_sha256'], contentSha256(job3Record()));
    });

    test('refuses the next anchors with 429, then accepts', () async {
      node.rateLimitNext = 1;
      final nirium = NiriumAuditClient(client, node: node.url);

      await expectLater(
        nirium.anchor(body()),
        throwsA(isA<NiriumError>().having((e) => e.rateLimited, '429', true)),
      );
      await nirium.anchor(body());
      expect(node.anchored, 1);
      expect(node.log, [
        'POST /api/audit/log → 429',
        'POST /api/audit/log → 200',
      ]);
    });

    test('a body with no record and no hash is a 400', () async {
      await expectLater(
        NiriumAuditClient(client, node: node.url).anchor({'tag': 't'}),
        throwsA(isA<NiriumError>().having((e) => e.status, 'status', 400)),
      );
      final response = await client.post(
        node.url.resolve('api/audit/log'),
        body: 'not json',
      );
      expect(response.statusCode, 400);
      expect(node.anchored, 0);
    });

    test('a held document is a 404 until it is released', () async {
      final anchor = await NiriumAuditClient(
        client,
        node: node.url,
      ).anchor(body());
      final reader = IpfsReader(client, gateways: [node.gateway]);

      node.holdDocuments = true;
      await expectLater(reader.read(anchor.cid), throwsStateError);
      node.holdDocuments = false;
      expect(await reader.read(anchor.cid), isNotEmpty);
    });

    test('other bytes are refused by the reader', () async {
      final anchor = await NiriumAuditClient(
        client,
        node: node.url,
      ).anchor(body());
      node.serveOtherBytes = true;

      await expectLater(
        IpfsReader(client, gateways: [node.gateway]).read(anchor.cid),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('does not hash to the CID'),
          ),
        ),
      );
    });

    test('an unknown CID and an unknown path are 404', () async {
      expect(
        (await client.get(node.gateway.resolve(recordCid))).statusCode,
        404,
      );
      expect((await client.get(node.url.resolve('other'))).statusCode, 404);
    });
  });

  group('runSandbox', () {
    late Directory directory;
    setUp(() => directory = Directory.systemTemp.createTempSync('sandbox'));
    tearDown(() => directory.deleteSync(recursive: true));

    test('every scenario ends in the state it expects', () async {
      var chainReads = 0;
      final lines = <String>[];
      final results = await runSandbox(
        txHash: job3Tx,
        signer: testSigner(),
        chain: (tx) {
          chainReads++;
          return _chain(tx);
        },
        job: job3Lookup(),
        nodeClient: client,
        directory: directory,
        log: lines.add,
      );

      expect([for (final r in results) r.scenario], SandboxScenario.values);
      for (final result in results) {
        expect(result.ok, isTrue, reason: '${result.scenario.name}: $lines');
      }
      expect(chainReads, 1);

      ScenarioResult of(SandboxScenario s) =>
          results.firstWhere((r) => r.scenario == s);
      expect(of(SandboxScenario.happy).passes, 2);
      expect(
        of(SandboxScenario.rateLimit).requests.where((r) => r.endsWith('429')),
        hasLength(2),
      );
      expect(
        of(SandboxScenario.outage).requests.first,
        'POST /api/audit/log → 503',
      );
      expect(
        of(SandboxScenario.slowIpfs).requests.where((r) => r.endsWith('404')),
        hasLength(2),
      );
      expect(
        of(SandboxScenario.otherBytes).receipt.reason,
        contains('gave up after 12 tries'),
      );
      expect(
        of(SandboxScenario.otherKey).receipt.reason,
        contains('not by puls3'),
      );
    });

    test('a hash-only run verifies with the record of the queue', () async {
      final results = await runSandbox(
        txHash: job3Tx,
        signer: testSigner(),
        chain: _chain,
        job: job3Lookup(),
        nodeClient: client,
        directory: directory,
        scenarios: [SandboxScenario.happy, SandboxScenario.restart],
        mode: AnchorMode.hash,
      );

      expect(results.every((r) => r.ok), isTrue);
    });

    test('the queue files hold the receipt and never the key', () async {
      await runSandbox(
        txHash: job3Tx,
        signer: testSigner(),
        chain: _chain,
        job: job3Lookup(),
        nodeClient: client,
        directory: directory,
        scenarios: [SandboxScenario.happy],
      );

      final text = File('${directory.path}/happy.json').readAsStringSync();
      final receipt =
          ((jsonDecode(text) as Map)['receipts'] as List).single as Map;
      expect(receipt['state'], 'verified');
      expect(text, isNot(contains(RegExp(r'\bS[A-Z2-7]{55}\b'))));
    });

    test('a transaction that is not a settlement fails at once', () async {
      final results = await runSandbox(
        txHash: 'ab' * 32,
        signer: testSigner(),
        chain: _chain,
        job: job3Lookup(),
        nodeClient: client,
        directory: directory,
        scenarios: [SandboxScenario.happy],
      );

      expect(results.single.ok, isFalse);
      expect(results.single.receipt.state, ReceiptState.failed);
      expect(results.single.requests, isEmpty);
    });
  });
}
