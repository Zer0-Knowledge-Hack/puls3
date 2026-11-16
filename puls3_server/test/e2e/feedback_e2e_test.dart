@Tags(['e2e'])
@Timeout(Duration(minutes: 10))
library;

import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/feedback/feedback_endpoint.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:test/test.dart';

import 'support/e2e_world.dart';
import 'support/local_sandbox.dart';

/// F6 and F7 on the local sandbox (#255): a funded hire is delivered by the
/// agent, approved by its consumer, and then rated through the server.
void main() {
  late E2eWorld world;

  setUpAll(() async => world = await E2eWorld.start());
  tearDownAll(() async => world.stop());

  test(
    'a delivered hire is approved, rated and counted in the agent reputation',
    () async {
      final hire = await world.fundedHire();
      final consumer = world.consumer.address.value;
      final agentKey = (await world.endpoint.getHire(
        world.session,
        hire.hireId,
        consumer,
      )).agent.id;
      final before = (await AgentEndpoint().get(world.session, agentKey))!;

      // The agent delivers; the escrow reads the job as submitted.
      final submitted = await world.agentSubmits(hire.hireId, hire.jobId);
      expect(submitted.provider, world.agentAccount.address);

      // The consumer approves: complete is prepared, signed unchanged, relayed.
      final complete = await world.endpoint.prepareComplete(
        world.session,
        hire.hireId,
      );
      await world.endpoint.submitEscrowCall(
        world.session,
        hire.hireId,
        complete.preparationId,
        world.consumer.sign(world.codec, complete.unsignedTransactionXdr!),
      );
      await world.confirmed(complete.preparationId);
      await world.hireIn(hire.hireId, HireStatus.completed);
      final job = (await world.wiring.ledger.escrowJob(hire.jobId))!;
      expect(job.state, EscrowJobState.completed);

      // The completed hire is not rated yet and its consumer may rate it.
      final feedback = FeedbackEndpoint();
      final detail = await world.endpoint.getHire(
        world.session,
        hire.hireId,
        consumer,
      );
      expect(detail.hire.feedbackReference, isNull);
      final eligibility = await feedback.getFeedbackEligibility(
        world.session,
        hire.hireId,
        consumer,
      );
      expect(eligibility.eligible, isTrue);

      // give_feedback: prepared, signed unchanged, relayed, confirmed.
      final prepared = await feedback.prepareFeedback(
        world.session,
        hire.hireId,
        5,
        'e2e rating for issue #255',
      );
      final submitDetail = await feedback.submitFeedback(
        world.session,
        hire.hireId,
        prepared.preparationId,
        world.consumer.sign(world.codec, prepared.unsignedTransactionXdr!),
      );
      final feedbackHash = submitDetail.feedbackSubmission!.transaction;
      expect(feedbackHash, prepared.transaction);
      await world.confirmed(prepared.preparationId);

      final rated = await until('the hire to be rated', () async {
        final current = await world.endpoint.getHire(
          world.session,
          hire.hireId,
          consumer,
        );
        if (current.feedbackSubmission?.state ==
            SubmissionState.failed.wireName) {
          throw StateError(
            'give_feedback failed: ${current.feedbackSubmission?.errorCode}',
          );
        }
        return current.hire.feedbackReference == null ? null : current;
      });
      expect(rated.hire.feedbackReference, feedbackHash);

      // The agent catalog counts the new rating.
      final after = await until('the catalog to count the rating', () async {
        final agent = await AgentEndpoint().get(world.session, agentKey);
        return agent != null && agent.paidHireCount > before.paidHireCount
            ? agent
            : null;
      });
      expect(after.paidHireCount, before.paidHireCount + 1);
    },
  );
}
