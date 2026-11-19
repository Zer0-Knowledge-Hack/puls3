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

  /// The submission ids [onChildJobCreated] was called with.
  final childCreated = <int>[];

  /// The `child_job_created` events of every [onChildJobCreated] call.
  final childCreatedEvents = <List<ChildJobCreatedEvent>>[];

  /// Every [onChildJobFailed] call as `(submission id, code)`, in order.
  final childFailed = <(int, String)>[];

  /// Thrown by [onChildJobFailed] when set.
  Object? childFailedError;

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
  Future<EffectResult> onChildJobCreated(
    StoredSubmission submission,
    List<ChildJobCreatedEvent> children, {
    required List<JobCreatedEvent> created,
    required List<JobFundedEvent> funded,
  }) async {
    childCreated.add(submission.id);
    childCreatedEvents.add(children);
    return _answer();
  }

  @override
  Future<void> onChildJobFailed(
    StoredSubmission submission,
    String code,
  ) async {
    final failure = childFailedError;
    if (failure != null) throw failure;
    childFailed.add((submission.id, code));
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
