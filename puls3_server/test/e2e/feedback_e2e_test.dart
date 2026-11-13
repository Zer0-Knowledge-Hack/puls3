@Tags(['e2e'])
library;

import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/agent/agent_catalog_wiring.dart';
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/auth/wallet_auth_endpoint.dart';
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart' show ScArg;
import 'package:serverpod/serverpod.dart' show Serverpod;
import 'package:test/test.dart';

import '../integration/test_tools/serverpod_test_tools.dart';
import 'support/e2e_auth.dart';
import 'support/e2e_flows.dart';
import 'support/e2e_sandbox.dart';

/// F6 and F7 against the local sandbox (#255): the agent submits, the
/// consumer completes (the local approval window is a day, so the suite does
/// not wait for a release), then rates the hire, and the catalog counts it.
void main() {
  withServerpod(
    'Given a funded hire on the local Soroban sandbox',
    (sessionBuilder, endpoints) {
      late E2eSandbox sandbox;
      late E2eAccount consumer;
      late E2eAccount agent;
      late int agentId;
      late dynamic tracker;

      setUpAll(() async {
        sandbox = await E2eSandbox.start();
        consumer = await sandbox.fundedAccount();
        agent = await sandbox.fundedAccount();
        agentId = await sandbox.registerAgent(
          agent,
          name: 'E2E Feedback Agent',
          priceStroops: 5000000,
        );
        HireEndpoint.sessionWallet = null;
        HireEndpoint.servicesBuilder = (session) =>
            sandbox.wiring.servicesOn(session);
        AgentEndpoint.service = AgentCatalogService(sandbox.wiring.ledger);
        tracker = startChainTracker(Serverpod.instance, sandbox.env);
        expect(tracker, isNotNull, reason: 'the chain tracker did not start');
      });

      tearDownAll(() async {
        await tracker?.stop();
        HireEndpoint.servicesBuilder = null;
        AgentEndpoint.service = null;
        WalletAuthEndpoint.resetDebug();
      });

      test(
        'the agent submits, the consumer completes and rates, '
        'and the catalog counts the rating',
        () async {
          final tokens = useSandboxAuth(sandbox, E2eAccount.random());
          final authed = await signIn(
            sandbox,
            sessionBuilder,
            tokens,
            consumer,
          );
          final session = sessionBuilder.build();
          final hires = ServerpodHireRepository(session);
          final submissions = ServerpodChainSubmissionStore(session);
          final funded = await createFundedHire(
            sandbox: sandbox,
            endpoints: endpoints,
            authed: authed,
            session: session,
            consumer: consumer,
            agentId: agentId,
          );
          final hireId = funded.hireId;
          final jobId = funded.jobId;
          Future<AgentSummary> catalogAgent() async {
            // The production catalog reader (index, on-chain fallback and
            // reputation). Its reputation cache lives for the process, so it
            // is cleared to read the registry as it is now.
            resetChainCatalog();
            final reader = buildAgentCatalogReader(
              session,
              environment: sandbox.env,
            );
            return (await reader.list()).singleWhere(
              (a) => a.registryId == agentId,
            );
          }

          final before = await catalogAgent();

          // F6: the agent submits. The server signs `submit` with a custodied
          // key in production, so the fixture signs it and records it the way
          // `AgentSubmitSender` does, which is what moves the hire.
          final sent = await sandbox.call(
            agent,
            contract: sandbox.wiring.stellar.escrow,
            function: 'submit',
            args: [
              ScArg.address(agent.address),
              ScArg.u64(jobId),
              ScArg.bytes32(Uint8List.fromList(List.filled(32, 0xe2))),
            ],
          );
          await submissions.insertSubmitted(
            purpose: SubmissionPurpose.submit,
            transactionHash: sent.hash,
            signedEnvelopeXdr: sent.signedXdr,
            validUntil: sent.validUntil,
            hireId: hireId,
          );
          await until('the hire to read submitted', () async {
            final row = await hires.findHire(hireId);
            return row?.status == HireStatus.submitted ? row : null;
          });
          expect(
            (await sandbox.wiring.ledger.escrowJob(jobId))!.state,
            EscrowJobState.submitted,
          );

          // The consumer completes, signing the prepared envelope unchanged.
          final complete = await endpoints.hire.prepareComplete(authed, hireId);
          final completeDetail = await endpoints.hire.submitEscrowCall(
            authed,
            hireId,
            complete.preparationId,
            sandbox.sign(consumer, complete.unsignedTransactionXdr!),
          );
          expect(
            completeDetail.escrowSubmission!.transaction,
            complete.transaction,
          );
          await until('the hire to complete', () async {
            final row = await hires.findHire(hireId);
            return row?.status == HireStatus.completed ? row : null;
          });
          expect(
            (await endpoints.hire.getHire(
              authed,
              hireId,
              consumer.address.value,
            )).hire.feedbackReference,
            isNull,
          );
          final completeRow = await submissions.findByPreparation(
            complete.preparationId,
          );
          expect(completeRow!.state, SubmissionState.confirmed);
          expect(completeRow.purpose, SubmissionPurpose.complete);
          expect(
            (await sandbox.wiring.ledger.escrowJob(jobId))!.state,
            EscrowJobState.completed,
          );

          // F7: eligibility, prepareFeedback, relay give_feedback.
          final eligibility = await endpoints.feedback.getFeedbackEligibility(
            authed,
            hireId,
            consumer.address.value,
          );
          expect(eligibility.eligible, isTrue);
          final prepared = await endpoints.feedback.prepareFeedback(
            authed,
            hireId,
            5,
            'e2e feedback',
          );
          final detail = await endpoints.feedback.submitFeedback(
            authed,
            hireId,
            prepared.preparationId,
            sandbox.sign(consumer, prepared.unsignedTransactionXdr!),
          );
          final feedbackHash = detail.feedbackSubmission!.transaction;
          expect(feedbackHash, prepared.transaction);

          final rated = await until('the hire to be rated', () async {
            final current = await endpoints.hire.getHire(
              authed,
              hireId,
              consumer.address.value,
            );
            return current.hire.feedbackReference == null ? null : current;
          });
          expect(rated.hire.feedbackReference, feedbackHash);
          final feedbackRow = await until(
            'give_feedback to be confirmed',
            () async {
              final row = await submissions.findByPreparation(
                prepared.preparationId,
              );
              return row?.state == SubmissionState.confirmed ? row : null;
            },
          );
          expect(feedbackRow.purpose, SubmissionPurpose.giveFeedback);
          final lookup = await sandbox.wiring.sender.lookup(feedbackHash);
          expect(lookup.status.name, 'success');

          // The catalog reads the new rating from the reputation registry.
          final after = await until(
            'the catalog to count the rating',
            () async {
              final current = await catalogAgent();
              return current.paidHireCount > before.paidHireCount
                  ? current
                  : null;
            },
          );
          expect(after.paidHireCount, before.paidHireCount + 1);
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
