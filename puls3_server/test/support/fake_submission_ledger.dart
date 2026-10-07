import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';

/// A [SubmissionLedger] that answers from maps and records every call.
///
/// An unknown hash is [TransactionStatus.notFound] at [closeTime]. A
/// [LedgerException] stored as an answer is thrown.
final class FakeSubmissionLedger implements SubmissionLedger {
  FakeSubmissionLedger({this.closeTime});

  /// The chain close time of default `NOT_FOUND` answers.
  DateTime? closeTime;

  /// Answers of [lookup], by hash: a [TransactionLookup] or a
  /// [LedgerException].
  final lookups = <String, Object>{};

  /// Answers of [resend], by envelope: a [SendTransactionResult] or a
  /// [LedgerException]. Unknown envelopes answer `PENDING`.
  final sends = <String, Object>{};

  final lookedUp = <String>[];
  final resent = <String>[];

  @override
  Future<TransactionLookup> lookup(String hash) async {
    lookedUp.add(hash);
    final answer =
        lookups[hash] ??
        TransactionLookup(
          status: TransactionStatus.notFound,
          latestLedgerCloseTime: closeTime,
        );
    if (answer is LedgerException) throw answer;
    return answer as TransactionLookup;
  }

  @override
  Future<SendTransactionResult> resend(String envelopeXdr) async {
    resent.add(envelopeXdr);
    final answer =
        sends[envelopeXdr] ??
        SendTransactionResult(
          status: SendTransactionStatus.pending,
          hash: 'f' * 64,
        );
    if (answer is LedgerException) throw answer;
    return answer as SendTransactionResult;
  }
}
