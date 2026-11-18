@Tags(['e2e'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/sc_val_json.dart';
import 'package:test/test.dart';

import 'support/contract_event_log.dart';
import 'support/e2e_world.dart';
import 'support/local_sandbox.dart' show until;

/// F1 and F5 on the local sandbox (#255): a consumer creates and funds a hire
/// using only the hire endpoint, and signs the unsigned XDR it receives
/// unchanged. The server side is the real stack; only the wallet is played by
/// the test.
void main() {
  late E2eWorld world;

  setUpAll(() async => world = await E2eWorld.start());
  tearDownAll(() async => world.stop());

  test(
    'a consumer creates and funds a hire with the XDR signed unchanged',
    () async {
      final consumer = world.consumer.address.value;

      final created = await world.endpoint.createHire(
        world.session,
        world.agentId,
        consumer,
        'e2e relay proof for issue #255',
        'e2e-${DateTime.now().microsecondsSinceEpoch}',
      );
      final hireId = created.hire.id;
      final createPrepared = created.preparedCreateJob!;
      final unsignedCreate = createPrepared.unsignedTransactionXdr!;

      // The server refuses an envelope whose body was touched, and stores or
      // sends nothing for it.
      final tampered = base64Decode(
        world.consumer.sign(world.codec, unsignedCreate),
      );
      tampered[71] ^= 0x01; // last byte of the time bounds maxTime
      await expectLater(
        world.endpoint.submitEscrowCall(
          world.session,
          hireId,
          createPrepared.preparationId,
          base64Encode(tampered),
        ),
        throwsA(
          isA<Puls3ApiException>()
              .having((e) => e.code, 'code', 'EnvelopeMismatch')
              .having((e) => e.details?['field'], 'field', 'timeBounds'),
        ),
      );
      expect(
        await world.submissions.findByPreparation(createPrepared.preparationId),
        isNull,
      );

      // create_job: relayed once, and a second submit returns the same record.
      final signedCreate = world.consumer.sign(world.codec, unsignedCreate);
      final createDetail = await world.endpoint.submitEscrowCall(
        world.session,
        hireId,
        createPrepared.preparationId,
        signedCreate,
      );
      final createHash = createDetail.escrowSubmission!.transaction;
      expect(createHash, createPrepared.transaction);
      final again = await world.endpoint.submitEscrowCall(
        world.session,
        hireId,
        createPrepared.preparationId,
        signedCreate,
      );
      expect(again.escrowSubmission!.transaction, createHash);

      await world.confirmed(createPrepared.preparationId);
      final opened = await world.hireIn(hireId, HireStatus.open);
      expect(opened.jobId, isNotNull);
      final jobId = opened.jobId!;

      // On chain the job exists, unfunded, for this consumer and this agent.
      final openJob = (await world.wiring.ledger.escrowJob(jobId))!;
      expect(openJob.state, EscrowJobState.open);
      expect(openJob.client, world.consumer.address);
      expect(openJob.provider, world.agentAccount.address);
      expect(openJob.budget, BigInt.from(e2ePriceStroops));

      // fund: prepared, signed unchanged, relayed and confirmed.
      final fundPrepared = await world.endpoint.prepareFund(
        world.session,
        hireId,
      );
      final fundDetail = await world.endpoint.submitEscrowCall(
        world.session,
        hireId,
        fundPrepared.preparationId,
        world.consumer.sign(world.codec, fundPrepared.unsignedTransactionXdr!),
      );
      final fundHash = fundDetail.escrowSubmission!.transaction;
      expect(fundHash, fundPrepared.transaction);
      await world.confirmed(fundPrepared.preparationId);

      final funded = await world.hireIn(hireId, HireStatus.funded);
      expect(funded.paymentTransaction, fundHash);

      // The database records both relayed transactions as confirmed, and the
      // escrow holds the job as funded.
      final rows = await world.submissions.listByHire(hireId);
      expect({
        for (final row in rows)
          if (row.state == SubmissionState.confirmed) row.transactionHash,
      }, containsAll([createHash, fundHash]));
      final fundedJob = (await world.wiring.ledger.escrowJob(jobId))!;
      expect(fundedJob.state, EscrowJobState.funded);

      // The escrow also emitted both events, for this job and these accounts,
      // in the transactions the server relayed (#287).
      final escrow = world.wiring.stellar.escrow.value;
      final events = await until(
        'the escrow to report both job events',
        () async {
          final all = await world.events.read(
            escrow,
            startLedger: world.startLedger,
          );
          return all.forJob('job_created', jobId).isNotEmpty &&
                  all.forJob('job_funded', jobId).isNotEmpty
              ? all
              : null;
        },
      );
      final created$ = events.forJob('job_created', jobId);
      expect(created$, hasLength(1));
      final createdEvent = created$.single;
      expect(createdEvent.transaction, createHash);
      expect(readAddress(createdEvent.data['client']), world.consumer.address);
      expect(
        readAddress(createdEvent.data['provider']),
        world.agentAccount.address,
      );
      expect(readU32(createdEvent.data['agent_id']), world.agentId);
      expect(
        readI128(createdEvent.data['budget']),
        BigInt.from(e2ePriceStroops),
      );

      final funded$ = events.forJob('job_funded', jobId);
      expect(funded$, hasLength(1));
      final fundedEvent = funded$.single;
      expect(fundedEvent.transaction, fundHash);
      expect(readAddress(fundedEvent.data['client']), world.consumer.address);
      expect(
        readI128(fundedEvent.data['amount']),
        BigInt.from(e2ePriceStroops),
      );
    },
  );
}
