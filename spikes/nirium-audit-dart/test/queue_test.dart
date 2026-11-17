import 'dart:convert';
import 'dart:io';

import 'package:nirium_audit_spike/nirium_audit.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import 'support.dart';

/// A Nirium node and its IPFS gateway, in memory.
final class _Nirium {
  /// Errors the next anchors throw, first in, first out.
  final failures = <Object>[];

  /// False while a fresh CID has not reached the gateway yet.
  var readable = true;

  /// Rewrites a document before it is stored, to anchor a wrong one.
  Map<String, Object?> Function(Map<String, Object?> doc)? tamper;

  final docs = <String, Map<String, Object?>>{};
  var anchors = 0;

  Future<AuditAnchor> anchor(Map<String, Object?> body) async {
    anchors++;
    if (failures.isNotEmpty) throw failures.removeAt(0);
    var doc = anchoredDoc(body);
    final hash = doc['content_sha256'] as String;
    doc = tamper?.call(doc) ?? doc;
    final cid = cidV0ForFile(utf8.encode(jsonEncode(doc)));
    docs[cid] = doc;
    return AuditAnchor(
      cid: cid,
      contentSha256: hash,
      anchoredAt: '2026-11-07T00:00:00.000Z',
    );
  }

  Future<Map<String, Object?>> read(String cid) async {
    final doc = docs[cid];
    if (!readable || doc == null) {
      throw StateError('no gateway returned $cid');
    }
    return doc;
  }
}

void main() {
  late _Nirium nirium;
  late ReceiptStore store;
  late DateTime now;
  var chainUp = true;
  final signer = testSigner();

  Future<EscrowSettlement> chain(String txHash) async {
    if (!chainUp) throw StateError('Horizon: HTTP 503');
    if (txHash != job3Tx) throw const NotASettlement('no complete call');
    return job3();
  }

  ReceiptQueue queue({
    ReceiptStore? on,
    ReceiptSigner? as,
    AnchorMode mode = AnchorMode.record,
    int maxAttempts = 12,
    int maxAnchorsPerPass = 10,
  }) => ReceiptQueue(
    store: on ?? store,
    signer: as ?? signer,
    chain: chain,
    job: job3Lookup(),
    anchor: nirium.anchor,
    read: nirium.read,
    now: () => now,
    mode: mode,
    maxAttempts: maxAttempts,
    maxAnchorsPerPass: maxAnchorsPerPass,
  );

  Future<QueuedReceipt> only() async => (await store.all()).single;

  void wait(Duration time) => now = now.add(time);

  setUp(() {
    nirium = _Nirium();
    store = MemoryReceiptStore();
    now = DateTime.utc(2026, 11, 16, 12);
    chainUp = true;
  });

  group('enqueue', () {
    test('queues a transaction once and calls nothing', () async {
      final q = queue();
      expect(await q.enqueue(job3Tx), isTrue);
      expect(await q.enqueue(' $job3Tx\n'), isFalse);

      final receipt = await only();
      expect(receipt.state, ReceiptState.pending);
      expect(nirium.anchors, 0);
    });

    test('refuses what is not a transaction hash', () async {
      await expectLater(queue().enqueue('job-3'), throwsArgumentError);
      expect(await store.all(), isEmpty);
    });
  });

  group('anchoring', () {
    test('a pending receipt is anchored with the job agent', () async {
      final q = queue();
      await q.enqueue(job3Tx);

      final changed = await q.runOnce();

      expect(changed.single.state, ReceiptState.anchored);
      final receipt = await only();
      expect(nirium.docs.keys, [receipt.cid]);
      expect(receipt.record, job3Record());
      expect(receipt.notBefore, now.add(const Duration(minutes: 15)));
    });

    test('a 429 keeps it pending and the next pass waits', () async {
      nirium.failures.add(const NiriumError(429, 'slow down'));
      final q = queue();
      await q.enqueue(job3Tx);

      await q.runOnce();
      var receipt = await only();
      expect(receipt.state, ReceiptState.pending);
      expect(receipt.attempts, 1);
      expect(receipt.reason, contains('429'));

      // Too early: nothing is sent.
      wait(const Duration(seconds: 29));
      expect(await q.runOnce(), isEmpty);
      expect(nirium.anchors, 1);

      wait(const Duration(seconds: 1));
      await q.runOnce();
      receipt = await only();
      expect(receipt.state, ReceiptState.anchored);
      expect(receipt.attempts, 0);
    });

    test('an outage of Nirium or of the chain is retried', () async {
      nirium.failures.addAll([
        const SocketException('offline'),
        const NiriumError(503, 'down'),
      ]);
      chainUp = false;
      final q = queue();
      await q.enqueue(job3Tx);

      await q.runOnce();
      expect((await only()).reason, contains('chain could not be read'));
      chainUp = true;
      for (var i = 0; i < 2; i++) {
        wait(const Duration(hours: 1));
        await q.runOnce();
        expect((await only()).state, ReceiptState.pending);
      }
      wait(const Duration(hours: 1));
      await q.runOnce();

      expect((await only()).state, ReceiptState.anchored);
    });

    test('the pause doubles from 30 seconds up to an hour', () {
      expect(ReceiptQueue.backoff(1), const Duration(seconds: 30));
      expect(ReceiptQueue.backoff(2), const Duration(seconds: 60));
      expect(ReceiptQueue.backoff(7), const Duration(seconds: 1920));
      expect(ReceiptQueue.backoff(8), const Duration(hours: 1));
      expect(ReceiptQueue.backoff(40), const Duration(hours: 1));
    });

    test('it gives up after the last try', () async {
      nirium.failures.addAll(List.filled(3, const NiriumError(429, '')));
      final q = queue(maxAttempts: 3);
      await q.enqueue(job3Tx);
      for (var i = 0; i < 3; i++) {
        await q.runOnce();
        wait(const Duration(hours: 1));
      }

      final receipt = await only();
      expect(receipt.state, ReceiptState.failed);
      expect(receipt.reason, contains('gave up after 3 tries'));
      expect(await q.runOnce(), isEmpty);
    });

    test('a request Nirium refuses fails at once', () async {
      nirium.failures.add(const NiriumError(400, 'bad signature'));
      final q = queue();
      await q.enqueue(job3Tx);
      await q.runOnce();

      final receipt = await only();
      expect(receipt.state, ReceiptState.failed);
      expect(receipt.reason, contains('400'));
      wait(const Duration(days: 1));
      expect(await q.runOnce(), isEmpty);
      expect(nirium.anchors, 1);
    });

    test('a transaction that is not a settlement fails at once', () async {
      final q = queue();
      await q.enqueue('ab' * 32);
      await q.runOnce();

      final receipt = await only();
      expect(receipt.state, ReceiptState.failed);
      expect(receipt.reason, contains('not a settlement'));
      expect(nirium.anchors, 0);
    });

    test('an anchor of another hash fails', () async {
      final q = ReceiptQueue(
        store: store,
        signer: signer,
        chain: chain,
        job: job3Lookup(),
        anchor: (body) async => const AuditAnchor(
          cid: recordCid,
          contentSha256: 'not-our-hash',
          anchoredAt: '2026-11-07T00:00:00.000Z',
        ),
        read: nirium.read,
        now: () => now,
      );
      await q.enqueue(job3Tx);
      await q.runOnce();

      expect((await only()).state, ReceiptState.failed);
    });

    test('one pass anchors no more than its limit', () async {
      Future<EscrowSettlement> any(String txHash) async => job3();
      final q = ReceiptQueue(
        store: store,
        signer: signer,
        chain: any,
        job: job3Lookup(),
        anchor: nirium.anchor,
        read: nirium.read,
        now: () => now,
        maxAnchorsPerPass: 2,
      );
      for (final digit in ['a', 'b', 'c']) {
        await q.enqueue(digit * 64);
      }

      await q.runOnce();
      expect(nirium.anchors, 2);
      await q.runOnce();
      expect(nirium.anchors, 3);
    });
  });

  group('verifying', () {
    Future<ReceiptQueue> anchored({
      AnchorMode mode = AnchorMode.record,
      int maxAttempts = 12,
    }) async {
      final q = queue(mode: mode, maxAttempts: maxAttempts);
      await q.enqueue(job3Tx);
      await q.runOnce();
      expect((await only()).state, ReceiptState.anchored);
      return q;
    }

    test('it waits 15 minutes, then verifies', () async {
      final q = await anchored();

      wait(const Duration(minutes: 14));
      expect(await q.runOnce(), isEmpty);

      wait(const Duration(minutes: 1));
      await q.runOnce();
      final receipt = await only();
      expect(receipt.state, ReceiptState.verified);
      expect(receipt.reason, isNull);
      expect(nirium.docs, contains(receipt.cid));
    });

    test('a hash-only anchor verifies with the stored record', () async {
      final q = await anchored(mode: AnchorMode.hash);
      expect(nirium.docs.values.single.containsKey('record'), isFalse);

      wait(const Duration(minutes: 15));
      await q.runOnce();

      expect((await only()).state, ReceiptState.verified);
    });

    test('a CID that is not readable yet is tried again', () async {
      final q = await anchored();
      nirium.readable = false;
      wait(const Duration(minutes: 15));
      await q.runOnce();

      var receipt = await only();
      expect(receipt.state, ReceiptState.anchored);
      expect(receipt.attempts, 1);

      nirium.readable = true;
      wait(const Duration(seconds: 30));
      await q.runOnce();
      receipt = await only();
      expect(receipt.state, ReceiptState.verified);
    });

    test('a CID that never becomes readable fails', () async {
      final q = await anchored(maxAttempts: 2);
      nirium.readable = false;
      for (var i = 0; i < 2; i++) {
        wait(const Duration(hours: 1));
        await q.runOnce();
      }

      final receipt = await only();
      expect(receipt.state, ReceiptState.failed);
      expect(receipt.reason, contains('could not be read'));
    });

    test('a chain outage is tried again, not a failure', () async {
      final q = await anchored();
      chainUp = false;
      wait(const Duration(minutes: 15));
      await q.runOnce();
      expect((await only()).state, ReceiptState.anchored);

      chainUp = true;
      wait(const Duration(minutes: 1));
      await q.runOnce();
      expect((await only()).state, ReceiptState.verified);
    });

    test('a document signed by another key is never verified', () async {
      await queue(as: testSigner(9)).enqueue(job3Tx);
      await queue(as: testSigner(9)).runOnce();
      final q = queue();

      wait(const Duration(minutes: 15));
      await q.runOnce();

      final receipt = await only();
      expect(receipt.state, ReceiptState.failed);
      expect(receipt.reason, contains('not by puls3'));
    });

    test('a stored record that was changed is never verified', () async {
      nirium.tamper = (doc) {
        final record = jsonDecode(jsonEncode(doc['record'])) as Map;
        (record['transfers'] as List).first['amount'] = '5.0000000';
        return {...doc, 'record': record};
      };
      final q = await anchored();
      wait(const Duration(minutes: 15));
      await q.runOnce();

      final receipt = await only();
      expect(receipt.state, ReceiptState.failed);
      expect(receipt.reason, contains('content_sha256'));
    });

    test('a job that is not completed is never verified', () async {
      final live = job3Job();
      final q = ReceiptQueue(
        store: store,
        signer: signer,
        chain: chain,
        job: job3Lookup(
          EscrowJob(agentId: live.agentId, provider: live.provider, state: 2),
        ),
        anchor: nirium.anchor,
        read: nirium.read,
        now: () => now,
      );
      await q.enqueue(job3Tx);
      await q.runOnce();
      wait(const Duration(minutes: 15));
      await q.runOnce();

      final receipt = await only();
      expect(receipt.state, ReceiptState.failed);
      expect(receipt.reason, contains('not completed'));
    });
  });

  group('the file store', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('receipt-queue');
      file = File('${directory.path}/queue/receipts.json');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('a restart keeps the queue and finishes the receipt', () async {
      final first = queue(on: FileReceiptStore(file));
      await first.enqueue(job3Tx);
      await first.runOnce();

      // A new process: a new store and a new queue over the same file.
      final second = queue(on: FileReceiptStore(file));
      expect(await second.enqueue(job3Tx), isFalse);
      wait(const Duration(minutes: 15));
      await second.runOnce();

      final receipt = (await FileReceiptStore(file).all()).single;
      expect(receipt.state, ReceiptState.verified);
      expect(receipt.cid, nirium.docs.keys.single);
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });

    test('the file never holds the attesting secret', () async {
      final secret = stellar.StellarPrivateKey.fromBytes(
        List.filled(32, 7),
      ).toBase32();
      nirium.failures.add(const NiriumError(429, ''));
      final q = queue(on: FileReceiptStore(file));
      await q.enqueue(job3Tx);
      await q.runOnce();
      wait(const Duration(minutes: 1));
      await q.runOnce();

      final text = file.readAsStringSync();
      expect(text, contains(job3Tx));
      expect(text, isNot(contains(secret)));
    });

    test('a missing file is an empty queue', () async {
      expect(await FileReceiptStore(file).all(), isEmpty);
    });
  });
}
