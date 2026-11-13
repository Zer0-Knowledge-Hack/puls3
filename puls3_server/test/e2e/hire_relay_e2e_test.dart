@Tags(['e2e'])
library;

import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/auth/wallet_auth_endpoint.dart';
import 'package:serverpod/serverpod.dart' show Serverpod;
import 'package:test/test.dart';

import '../integration/test_tools/serverpod_test_tools.dart';
import 'support/e2e_auth.dart';
import 'support/e2e_sandbox.dart';

/// F1 and F5 against the local sandbox (#255): sign in with a wallet, create
/// a hire, relay `create_job`, then `prepareFund` and relay `fund`, with
/// every transaction signed unchanged by an ephemeral consumer key.
void main() {
  withServerpod(
    'Given the local Soroban sandbox',
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
        final serverAccount = E2eAccount.random();
        agentId = await sandbox.registerAgent(
          agent,
          name: 'E2E Relay Agent',
          priceStroops: 5000000,
        );
        useSandboxAuth(sandbox, serverAccount);
        HireEndpoint.sessionWallet = null;
        HireEndpoint.servicesBuilder = (session) =>
            sandbox.wiring.servicesOn(session);
        tracker = startChainTracker(Serverpod.instance, sandbox.env);
        expect(tracker, isNotNull, reason: 'the chain tracker did not start');
      });

      tearDownAll(() async {
        await tracker?.stop();
        HireEndpoint.servicesBuilder = null;
        WalletAuthEndpoint.resetDebug();
      });

      test(
        'a signed-in consumer creates and funds a hire through the relay',
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

          // F1: createHire returns an unsigned create_job.
          final created = await endpoints.hire.createHire(
            authed,
            agentId,
            consumer.address.value,
            'e2e hire relay',
            'e2e-${DateTime.now().millisecondsSinceEpoch}',
          );
          final hireId = created.hire.id;
          expect(created.hire.consumer, consumer.address.value);
          final prepared =
              created.preparedCreateJob ??
              await endpoints.hire.prepareCreateJob(authed, hireId);
          final unsigned = prepared.unsignedTransactionXdr!;

          // The relay refuses a changed envelope and stores nothing for it.
          final tampered = base64Decode(sandbox.sign(consumer, unsigned));
          tampered[71] ^= 0x01;
          await expectLater(
            endpoints.hire.submitEscrowCall(
              authed,
              hireId,
              prepared.preparationId,
              base64Encode(tampered),
            ),
            throwsA(
              isA<Puls3ApiException>().having(
                (e) => e.code,
                'code',
                'EnvelopeMismatch',
              ),
            ),
          );
          expect(
            await submissions.findByPreparation(prepared.preparationId),
            isNull,
          );

          // Relay create_job unchanged; a second submit is idempotent.
          final signedCreate = sandbox.sign(consumer, unsigned);
          final createDetail = await endpoints.hire.submitEscrowCall(
            authed,
            hireId,
            prepared.preparationId,
            signedCreate,
          );
          final createHash = createDetail.escrowSubmission!.transaction;
          expect(createHash, prepared.transaction);
          final again = await endpoints.hire.submitEscrowCall(
            authed,
            hireId,
            prepared.preparationId,
            signedCreate,
          );
          expect(again.escrowSubmission!.transaction, createHash);

          final opened = await until(
            'the hire to open with a job id',
            () async {
              final row = await hires.findHire(hireId);
              return row?.jobId != null && row?.status == HireStatus.open
                  ? row
                  : null;
            },
          );
          final jobId = opened.jobId!;
          final createRow = await submissions.findByPreparation(
            prepared.preparationId,
          );
          expect(createRow!.state, SubmissionState.confirmed);
          expect(createRow.purpose, SubmissionPurpose.createJob);
          final createLookup = await sandbox.wiring.sender.lookup(createHash);
          expect(createLookup.jobCreated.map((e) => e.jobId), contains(jobId));

          // F5: prepareFund, relay fund unchanged.
          final fundPrepared = await endpoints.hire.prepareFund(authed, hireId);
          final signedFund = sandbox.sign(
            consumer,
            fundPrepared.unsignedTransactionXdr!,
          );
          final fundDetail = await endpoints.hire.submitEscrowCall(
            authed,
            hireId,
            fundPrepared.preparationId,
            signedFund,
          );
          final fundHash = fundDetail.escrowSubmission!.transaction;
          expect(fundHash, fundPrepared.transaction);
          final fundAgain = await endpoints.hire.submitEscrowCall(
            authed,
            hireId,
            fundPrepared.preparationId,
            signedFund,
          );
          expect(fundAgain.escrowSubmission!.transaction, fundHash);

          final funded = await until('the hire to be funded', () async {
            final row = await hires.findHire(hireId);
            return row?.status == HireStatus.funded ? row : null;
          });
          expect(funded.paymentTransaction, fundHash);
          final fundRow = await submissions.findByPreparation(
            fundPrepared.preparationId,
          );
          expect(fundRow!.state, SubmissionState.confirmed);
          expect(fundRow.purpose, SubmissionPurpose.fund);

          // On chain: the funded event and the escrow job state.
          final fundLookup = await sandbox.wiring.sender.lookup(fundHash);
          expect(fundLookup.jobFunded.map((e) => e.jobId), contains(jobId));
          final job = (await sandbox.wiring.ledger.escrowJob(jobId))!;
          expect(job.state, EscrowJobState.funded);
          expect(job.client, consumer.address);
          expect(job.provider, agent.address);
          expect(job.budget, BigInt.from(5000000));
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
