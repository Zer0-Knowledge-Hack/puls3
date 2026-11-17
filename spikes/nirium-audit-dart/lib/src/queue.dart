import 'dart:convert';
import 'dart:io';

import 'clients.dart';
import 'escrow_job.dart';
import 'receipt.dart';
import 'settlement.dart';
import 'verify.dart';

/// Where a queued receipt is.
enum ReceiptState {
  /// Waiting to be anchored. A retry keeps it here.
  pending,

  /// Anchored on Nirium, with a CID, and waiting to be verified from IPFS.
  anchored,

  /// Read back from IPFS and checked against the chain. Only this state may
  /// be shown to a user.
  verified,

  /// It will never verify. [QueuedReceipt.reason] says why.
  failed,
}

/// One receipt in the queue, for the `complete` transaction [txHash].
///
/// It holds only public chain data and the CID, never the attesting key.
final class QueuedReceipt {
  const QueuedReceipt({
    required this.txHash,
    required this.state,
    required this.notBefore,
    this.attempts = 0,
    this.cid,
    this.record,
    this.reason,
  });

  factory QueuedReceipt.fromJson(Map<String, Object?> json) => QueuedReceipt(
    txHash: json['tx'] as String,
    state: ReceiptState.values.byName(json['state'] as String),
    notBefore: DateTime.parse(json['not_before'] as String),
    attempts: json['attempts'] as int? ?? 0,
    cid: json['cid'] as String?,
    record: json['record'] as Map<String, Object?>?,
    reason: json['reason'] as String?,
  );

  final String txHash;
  final ReceiptState state;

  /// The next pass may work on this receipt from this moment (UTC).
  final DateTime notBefore;

  /// Failed tries of the current step (anchor or verify) so far.
  final int attempts;

  /// The IPFS CID, from [ReceiptState.anchored] on.
  final String? cid;

  /// The record that was anchored. A hash-only anchor cannot be verified
  /// without it.
  final Map<String, Object?>? record;

  /// The last error of a retry, or why the receipt failed.
  final String? reason;

  Map<String, Object?> toJson() => {
    'tx': txHash,
    'state': state.name,
    'not_before': notBefore.toUtc().toIso8601String(),
    'attempts': attempts,
    'cid': ?cid,
    'record': ?record,
    'reason': ?reason,
  };
}

/// Keeps the queue. It must survive a restart.
abstract interface class ReceiptStore {
  Future<List<QueuedReceipt>> all();

  /// Adds [receipt], or replaces the one with the same transaction.
  Future<void> save(QueuedReceipt receipt);
}

/// A [ReceiptStore] in one JSON file, rewritten through a temporary file so
/// a crash in the middle of a write leaves the old queue intact.
final class FileReceiptStore implements ReceiptStore {
  FileReceiptStore(this._file);

  final File _file;

  @override
  Future<List<QueuedReceipt>> all() async {
    if (!_file.existsSync()) return [];
    final json = jsonDecode(await _file.readAsString()) as Map<String, Object?>;
    return [
      for (final item in json['receipts'] as List)
        QueuedReceipt.fromJson(item as Map<String, Object?>),
    ];
  }

  @override
  Future<void> save(QueuedReceipt receipt) async {
    final receipts = await all();
    final at = receipts.indexWhere((r) => r.txHash == receipt.txHash);
    if (at < 0) {
      receipts.add(receipt);
    } else {
      receipts[at] = receipt;
    }
    _file.parent.createSync(recursive: true);
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'receipts': [for (final r in receipts) r.toJson()],
      }),
      flush: true,
    );
    await temporary.rename(_file.path);
  }
}

/// A [ReceiptStore] in memory, for tests.
final class MemoryReceiptStore implements ReceiptStore {
  final _receipts = <String, QueuedReceipt>{};

  @override
  Future<List<QueuedReceipt>> all() async => _receipts.values.toList();

  @override
  Future<void> save(QueuedReceipt receipt) async =>
      _receipts[receipt.txHash] = receipt;
}

/// Anchors a body from `anchorBody` (`NiriumAuditClient.anchor`).
typedef AnchorCall = Future<AuditAnchor> Function(Map<String, Object?> body);

/// Reads the document at a CID (`IpfsReader.read`).
typedef DocumentRead = Future<Map<String, Object?>> Function(String cid);

/// Anchors a receipt for each settled hire, away from the hire itself, and
/// verifies it later (#274).
///
/// A hire calls only [enqueue], which writes one row and calls nothing else.
/// [runOnce] does the work, from a timer. So a Nirium outage, a 429 or a
/// restart delays a receipt and never touches the hire:
///
/// - **pending → anchored.** The record is built from the confirmed
///   transaction and the escrow job, signed, and anchored. A 429, a 5xx or a
///   network error is retried with a growing pause. Another 4xx, or a
///   transaction that is not a settlement, fails at once.
/// - **anchored → verified.** A CID cannot be read right after anchoring (the
///   spike read 0 of 20 at once and 20 of 20 after 5 to 15 minutes), so the
///   first try waits [verifyDelay]. A document that is not readable yet, or a
///   chain that does not answer, is retried. A document that is readable and
///   wrong fails: it never becomes verified.
///
/// A step that keeps failing gives up after [maxAttempts].
final class ReceiptQueue {
  ReceiptQueue({
    required this._store,
    required this._signer,
    required this._chain,
    required this._job,
    required this._anchor,
    required this._read,
    DateTime Function()? now,
    this.mode = AnchorMode.record,
    this.tag,
    this.verifyDelay = const Duration(minutes: 15),
    this.maxAttempts = 12,
    this.maxAnchorsPerPass = 10,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final ReceiptStore _store;
  final ReceiptSigner _signer;
  final SettlementLookup _chain;
  final JobLookup _job;
  final AnchorCall _anchor;
  final DocumentRead _read;
  final DateTime Function() _now;

  final AnchorMode mode;
  final String? tag;

  /// How long after anchoring the first verification runs.
  final Duration verifyDelay;

  /// Tries of one step before the receipt fails.
  final int maxAttempts;

  /// Anchors in one pass. Nirium allows 20 a minute for each IP.
  final int maxAnchorsPerPass;

  /// The pause after the [attempts]-th failed try: 30 s, doubling, up to 1 h.
  static Duration backoff(int attempts) {
    final seconds = 30 * (1 << (attempts - 1).clamp(0, 7));
    return Duration(seconds: seconds > 3600 ? 3600 : seconds);
  }

  /// Queues a receipt for the confirmed `complete` transaction [txHash].
  /// Returns false when it is already queued, in any state.
  Future<bool> enqueue(String txHash) async {
    final hash = txHash.trim();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw ArgumentError.value(txHash, 'txHash', 'is not a transaction hash');
    }
    if ((await _store.all()).any((r) => r.txHash == hash)) return false;
    await _store.save(
      QueuedReceipt(
        txHash: hash,
        state: ReceiptState.pending,
        notBefore: _now(),
      ),
    );
    return true;
  }

  /// One pass over every receipt that is due. Returns the ones it changed.
  /// It never throws for one receipt: the error goes to its `reason`.
  Future<List<QueuedReceipt>> runOnce() async {
    final changed = <QueuedReceipt>[];
    var anchors = 0;
    for (final receipt in await _store.all()) {
      if (receipt.notBefore.isAfter(_now())) continue;
      final QueuedReceipt next;
      switch (receipt.state) {
        case ReceiptState.pending:
          if (anchors >= maxAnchorsPerPass) continue;
          anchors++;
          next = await _anchorStep(receipt);
        case ReceiptState.anchored:
          next = await _verifyStep(receipt);
        case ReceiptState.verified || ReceiptState.failed:
          continue;
      }
      await _store.save(next);
      changed.add(next);
    }
    return changed;
  }

  Future<QueuedReceipt> _anchorStep(QueuedReceipt receipt) async {
    final Map<String, Object?> record;
    try {
      final settlement = await _chain(receipt.txHash);
      final job = await _job(settlement.escrowContract, settlement.jobId);
      record = receiptRecord(
        settlement,
        agentRegistryId: job.agentId,
        agentWallet: job.provider,
      );
    } on NotASettlement catch (e) {
      return _fail(receipt, 'not a settlement: ${e.message}');
    } on ArgumentError catch (e) {
      return _fail(receipt, 'no receipt for this transaction: ${e.message}');
    } on Object catch (e) {
      return _retry(receipt, 'the chain could not be read: $e');
    }

    final AuditAnchor anchor;
    try {
      anchor = await _anchor(
        anchorBody(record, signer: _signer, mode: mode, tag: tag),
      );
    } on NiriumError catch (e) {
      if (e.rateLimited || e.status >= 500) {
        return _retry(receipt, 'Nirium answered ${e.status}');
      }
      return _fail(receipt, 'Nirium refused the anchor: ${e.status} ${e.body}');
    } on Object catch (e) {
      return _retry(receipt, 'Nirium could not be reached: ${e.runtimeType}');
    }
    if (anchor.contentSha256 != contentSha256(record)) {
      return _fail(receipt, 'Nirium anchored another hash (${anchor.cid})');
    }
    return QueuedReceipt(
      txHash: receipt.txHash,
      state: ReceiptState.anchored,
      notBefore: _now().add(verifyDelay),
      cid: anchor.cid,
      record: record,
    );
  }

  Future<QueuedReceipt> _verifyStep(QueuedReceipt receipt) async {
    final Map<String, Object?> doc;
    try {
      doc = await _read(receipt.cid!);
    } on ArgumentError catch (e) {
      return _fail(receipt, 'the CID cannot be checked: ${e.message}');
    } on Object catch (e) {
      // Not propagated yet, or a gateway served other bytes: both look the
      // same from here, and neither is a verified receipt.
      return _retry(receipt, 'the document could not be read: $e');
    }

    // The verifier reports an unreadable chain as a failure. Here that is a
    // reason to try again, not a wrong receipt.
    var outage = false;
    final check = await verifyReceipt(
      doc,
      trustedKey: _signer.address,
      localRecord: receipt.record,
      chain: (tx) async {
        try {
          return await _chain(tx);
        } on NotASettlement {
          rethrow;
        } on Object {
          outage = true;
          rethrow;
        }
      },
      job: (escrow, jobId) async {
        try {
          return await _job(escrow, jobId);
        } on Object {
          outage = true;
          rethrow;
        }
      },
    );
    if (check.ok) {
      return QueuedReceipt(
        txHash: receipt.txHash,
        state: ReceiptState.verified,
        notBefore: _now(),
        cid: receipt.cid,
        record: receipt.record,
      );
    }
    final why = check.failures.join('; ');
    return outage ? _retry(receipt, why) : _fail(receipt, why);
  }

  QueuedReceipt _retry(QueuedReceipt receipt, String reason) {
    final attempts = receipt.attempts + 1;
    if (attempts >= maxAttempts) {
      return _fail(receipt, 'gave up after $attempts tries: $reason');
    }
    return QueuedReceipt(
      txHash: receipt.txHash,
      state: receipt.state,
      notBefore: _now().add(backoff(attempts)),
      attempts: attempts,
      cid: receipt.cid,
      record: receipt.record,
      reason: reason,
    );
  }

  QueuedReceipt _fail(QueuedReceipt receipt, String reason) => QueuedReceipt(
    txHash: receipt.txHash,
    state: ReceiptState.failed,
    notBefore: _now(),
    attempts: receipt.attempts,
    cid: receipt.cid,
    record: receipt.record,
    reason: reason,
  );
}
