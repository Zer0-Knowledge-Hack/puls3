import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:test/test.dart';

import '../../support/escrow_preparation_store_contract.dart';
import '../../support/in_memory_chain_submission_store.dart';
import '../../support/in_memory_escrow_preparation_store.dart';

void main() {
  group('InMemoryEscrowPreparationStore', () {
    escrowPreparationStoreContract(
      (now) => InMemoryEscrowPreparationStore(now: now),
    );

    // The same claim-then-record semantics the Serverpod integration test
    // proves on PostgreSQL, against the fakes the service tests use.
    test('a conflicting record rolls the claim back and the winner is '
        're-read by preparation', () async {
      final preparations = InMemoryEscrowPreparationStore();
      final submissions = InMemoryChainSubmissionStore();
      await preparations.insert(newPreparation('prep-1'));
      await preparations.insert(newPreparation('prep-2', hireId: 8));
      final winner = await submissions.insertSubmitted(
        purpose: SubmissionPurpose.fund,
        transactionHash: 'prep-1'.padLeft(64, 'a'),
        signedEnvelopeXdr: 'AAAAAgAAAAA=',
        validUntil: DateTime.utc(2026, 10, 7, 12, 5),
        preparationId: 'prep-1',
      );

      // Same transaction hash as the winner: an InternalError conflict.
      await expectLater(
        preparations.inTransaction((tx) async {
          expect(await preparations.claim('prep-2', transaction: tx), isTrue);
          await submissions.insertSubmitted(
            purpose: SubmissionPurpose.fund,
            transactionHash: winner.transactionHash,
            signedEnvelopeXdr: 'AAAAAgAAAAA=',
            validUntil: DateTime.utc(2026, 10, 7, 12, 5),
            preparationId: 'prep-2',
            transaction: tx,
          );
        }),
        throwsA(
          isA<ChainSubmissionConflict>().having(
            (e) => e.index,
            'index',
            ChainSubmissionIndex.transaction,
          ),
        ),
      );
      expect(
        (await preparations.findByPreparationId('prep-2'))!.submittedAt,
        isNull,
      );

      // Same preparation id: the loser re-reads the winner's record.
      await expectLater(
        preparations.inTransaction((tx) async {
          await preparations.claim('prep-1', transaction: tx);
          await submissions.insertSubmitted(
            purpose: SubmissionPurpose.fund,
            transactionHash: 'c' * 64,
            signedEnvelopeXdr: 'AAAAAgAAAAA=',
            validUntil: DateTime.utc(2026, 10, 7, 12, 5),
            preparationId: 'prep-1',
            transaction: tx,
          );
        }),
        throwsA(
          isA<ChainSubmissionConflict>().having(
            (e) => e.index,
            'index',
            ChainSubmissionIndex.preparationId,
          ),
        ),
      );
      expect((await submissions.findByPreparation('prep-1'))!.id, winner.id);
    });
  });
}
