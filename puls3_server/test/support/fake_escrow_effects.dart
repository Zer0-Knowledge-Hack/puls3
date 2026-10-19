import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';

/// [EscrowEffects] that answers [result] (or throws [error]) and records
/// the submission ids it was called with, and the events it was given.
final class FakeEscrowEffects implements EscrowEffects {
  EffectResult result = const EffectResult.ok();
  Object? error;

  final created = <int>[];
  final funded = <int>[];
  final feedbackGiven = <int>[];

  /// What [reconcileExpiredFund] answers.
  ExpiredFund expiredFund = const ExpiredFundUnknown();

  /// The submission ids [reconcileExpiredFund] was called with.
  final reconciled = <int>[];

  /// The event list of every [onJobCreated] call, in call order.
  final createdEvents = <List<JobCreatedEvent>>[];

  /// The event list of every [onFunded] call, in call order.
  final fundedEvents = <List<JobFundedEvent>>[];

  @override
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    List<JobCreatedEvent> events,
  ) async {
    created.add(submission.id);
    createdEvents.add(events);
    return _answer();
  }

  @override
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    List<JobFundedEvent> events,
  ) async {
    funded.add(submission.id);
    fundedEvents.add(events);
    return _answer();
  }

  @override
  Future<EffectResult> onFeedbackGiven(StoredSubmission submission) async {
    feedbackGiven.add(submission.id);
    return _answer();
  }

  @override
  Future<ExpiredFund> reconcileExpiredFund(StoredSubmission submission) async {
    reconciled.add(submission.id);
    final failure = error;
    if (failure != null) throw failure;
    return expiredFund;
  }

  EffectResult _answer() {
    final failure = error;
    if (failure != null) throw failure;
    return result;
  }
}
