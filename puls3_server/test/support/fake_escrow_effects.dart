import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';

/// [EscrowEffects] that answers [result] (or throws [error]) and records
/// the submission ids it was called with.
final class FakeEscrowEffects implements EscrowEffects {
  EffectResult result = const EffectResult.ok();
  Object? error;

  final created = <int>[];
  final funded = <int>[];

  @override
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    JobCreatedEvent event,
  ) async {
    created.add(submission.id);
    return _answer();
  }

  @override
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    JobFundedEvent event,
  ) async {
    funded.add(submission.id);
    return _answer();
  }

  EffectResult _answer() {
    final failure = error;
    if (failure != null) throw failure;
    return result;
  }
}
