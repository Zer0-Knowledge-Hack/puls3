@Tags(['e2e'])
@Timeout(Duration(minutes: 10))
library;

import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/feedback/feedback_endpoint.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/sc_val_json.dart';
import 'package:test/test.dart';

import 'support/contract_event_log.dart';
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

      // The escrow emitted JobSubmitted and JobCompleted for this job (#287).
      final escrow = world.wiring.stellar.escrow.value;
      final escrowEvents = await until(
        'the escrow to report the job events',
        () async {
          final all = await world.events.read(
            escrow,
            startLedger: world.startLedger,
          );
          return all.forJob('job_submitted', hire.jobId).isNotEmpty &&
                  all.forJob('job_completed', hire.jobId).isNotEmpty
              ? all
              : null;
        },
      );
      final submittedEvent = escrowEvents
          .forJob('job_submitted', hire.jobId)
          .single;
      expect(
        readAddress(submittedEvent.data['provider']),
        world.agentAccount.address,
      );
      final completedEvent = escrowEvents
          .forJob('job_completed', hire.jobId)
          .single;
      expect(readAddress(completedEvent.data['evaluator']), job.evaluator);
      expect(readI128(completedEvent.data['payout']), job.budget);
      expect(readI128(completedEvent.data['fee']), BigInt.zero);
      expect(readBool(completedEvent.data['auto_released']), isFalse);

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

      // The reputation registry emitted NewFeedback for this agent and this
      // consumer, in the relayed give_feedback transaction (#287).
      final registry = world.wiring.stellar.reputationRegistry!.value;
      final feedbackEvents = await world.events.read(
        registry,
        startLedger: world.startLedger,
      );
      final given = feedbackEvents
          .where((event) => event.name == 'new_feedback')
          .where((event) => readU32(event.topics[0]) == world.agentId)
          .toList();
      expect(given, hasLength(1));
      expect(given.single.transaction, feedbackHash);
      expect(readAddress(given.single.topics[1]), world.consumer.address);
      expect(readI128(given.single.data['value']), BigInt.from(5));

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
