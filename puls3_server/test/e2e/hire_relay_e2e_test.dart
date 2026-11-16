@Tags(['e2e'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:test/test.dart';

import 'support/e2e_world.dart';

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
      expect(
        {
          for (final row in rows)
            if (row.state == SubmissionState.confirmed) row.transactionHash,
        },
        containsAll([createHash, fundHash]),
      );
      final fundedJob = (await world.wiring.ledger.escrowJob(jobId))!;
      expect(fundedJob.state, EscrowJobState.funded);
    },
  );
}
