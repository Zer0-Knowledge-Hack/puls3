import 'package:puls3_domain/puls3_domain.dart' show HireStatus;

import '../chain/chain_submission_store.dart';
import '../chain/submission_values.dart';
import 'agent_hire_service.dart';
import 'hire_lifecycle_store.dart';

/// Runs the hired agent's work and sends its `submit`. In production the
/// agent runtime does this on its own once the hire is funded; the testnet
/// tool passes a local stand-in.
typedef AgentHireDelivery = Future<void> Function(HireRow hire);

/// [AgentHireChain] over the chain tracker's submission rows (#312).
///
/// It only reads: the chain tracker confirms submissions and applies their
/// escrow effects to the hire, and the agent runtime sends the hired
/// agent's `submit` with its custodied key (#208).
final class TrackerAgentHireChain implements AgentHireChain {
  TrackerAgentHireChain({
    required HireLifecycleStore hires,
    required ChainSubmissionStore submissions,
    AgentHireDelivery? deliver,
    this.confirmationTimeout = const Duration(minutes: 4),
    this.deliveryTimeout = const Duration(minutes: 15),
    this.pollInterval = const Duration(seconds: 2),
  }) : _hires = hires,
       _submissions = submissions,
       _deliver = deliver;

  final HireLifecycleStore _hires;
  final ChainSubmissionStore _submissions;
  final AgentHireDelivery? _deliver;
  final Duration confirmationTimeout;
  final Duration deliveryTimeout;
  final Duration pollInterval;

  @override
  Future<String> confirmed(String preparationId) async {
    final stored = await _until(
      'submission $preparationId',
      confirmationTimeout,
      () async {
        final row = await _submissions.findByPreparation(preparationId);
        if (row?.state == SubmissionState.failed) {
          throw AgentHireFailed('$preparationId failed: ${row!.errorCode}');
        }
        return row?.state == SubmissionState.confirmed ? row : null;
      },
    );
    // Wait for the escrow effects the next step depends on.
    final hireId = stored.hireId!;
    await _until(
      'hire $hireId to reflect ${stored.purpose.name}',
      confirmationTimeout,
      () async {
        final hire = await _hires.findHire(hireId);
        return switch (stored.purpose) {
          SubmissionPurpose.createJob => hire?.jobId,
          SubmissionPurpose.fund =>
            hire?.status == HireStatus.funded ? true : null,
          SubmissionPurpose.complete =>
            hire?.status == HireStatus.completed ? true : null,
          _ => true,
        };
      },
    );
    return stored.transactionHash;
  }

  @override
  Future<String> delivered(int hireId) async {
    final deliver = _deliver;
    if (deliver != null) {
      final hire = await _hires.findHire(hireId);
      if (hire == null) throw AgentHireFailed('hire $hireId is missing');
      await deliver(hire);
    }
    final submit = await _until(
      'the submit of hire $hireId',
      deliveryTimeout,
      () async {
        final rows = await _submissions.listByHire(hireId);
        final row = rows
            .where((r) => r.purpose == SubmissionPurpose.submit)
            .lastOrNull;
        if (row?.state == SubmissionState.failed) {
          throw AgentHireFailed('submit failed: ${row!.errorCode}');
        }
        return row?.state == SubmissionState.confirmed ? row : null;
      },
    );
    await _until(
      'hire $hireId to be submitted',
      confirmationTimeout,
      () async {
        final row = await _hires.findHire(hireId);
        return row?.status == HireStatus.submitted ? true : null;
      },
    );
    return submit.transactionHash;
  }

  Future<T> _until<T>(
    String what,
    Duration timeout,
    Future<T?> Function() probe,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final value = await probe();
      if (value != null) return value;
      if (!DateTime.now().isBefore(deadline)) {
        throw AgentHireFailed('timed out waiting for $what');
      }
      await Future<void>.delayed(pollInterval);
    }
  }
}
