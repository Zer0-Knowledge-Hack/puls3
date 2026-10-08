@Tags(['integration'])
library;

import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/serverpod_escrow_preparation_store.dart';
import 'package:test/test.dart';

import '../support/escrow_preparation_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

final _at = DateTime.utc(2026, 10, 7, 12);
final _validUntil = _at.add(const Duration(minutes: 5));
const _envelope = 'AAAAAgAAAAA=';

void main() {
  withServerpod('Given ServerpodEscrowPreparationStore', (sessionBuilder, _) {
    escrowPreparationStoreContract(
      (now) =>
          ServerpodEscrowPreparationStore(sessionBuilder.build(), now: now),
    );
  });

  // The race needs real concurrent transactions, so this group commits and
  // deletes its own rows.
  withServerpod(
    'Given prepare and submit racing on one preparation',
    (sessionBuilder, _) {
      // Hire ids far from any real data; every row is deleted afterwards.
      const hireId = 960001;
      const rounds = 12;
      final hashes = [for (var i = 0; i < 24; i++) '$i'.padLeft(64, 'e')];

      ServerpodEscrowPreparationStore preparations() =>
          ServerpodEscrowPreparationStore(
            sessionBuilder.build(),
            now: () => _at,
          );
      ServerpodChainSubmissionStore submissions() =>
          ServerpodChainSubmissionStore(sessionBuilder.build(), now: () => _at);

      tearDown(() async {
        final session = sessionBuilder.build();
        await EscrowPreparation.db.deleteWhere(
          session,
          where: (t) => t.hireId.equals(hireId) | t.hireId.equals(hireId + 1),
        );
        await ChainSubmission.db.deleteWhere(
          session,
          where: (t) => t.transaction.inSet(hashes.toSet()),
        );
      });

      test('exactly one of supersede and claim wins, every time', () async {
        final setup = preparations();
        // One preparation per round, so supersedeCurrent targets exactly it.
        var claimWins = 0;
        var supersedeWins = 0;
        for (var round = 0; round < rounds; round++) {
          final hire = hireId + 1;
          final id = 'round-$round';
          await setup.insert(
            newPreparation(id, hireId: hire, hash: id.padLeft(64, 'c')),
          );
          final results = await Future.wait([
            preparations().inTransaction(
              (tx) => preparations().claim(id, transaction: tx),
            ),
            preparations().inTransaction(
              (tx) => preparations().supersedeCurrent(hire, transaction: tx),
            ),
          ]);
          final claimed = results[0] as bool;
          final superseded = (results[1] as int) == 1;

          expect(claimed != superseded, isTrue, reason: 'round $round');
          final row = (await setup.findByPreparationId(id))!;
          expect(row.submittedAt != null, claimed);
          expect(row.supersededAt != null, superseded);
          claimed ? claimWins++ : supersedeWins++;
          // Free the hire for the next round.
          await EscrowPreparation.db.deleteWhere(
            sessionBuilder.build(),
            where: (t) => t.preparationId.equals(id),
          );
        }
        expect(claimWins + supersedeWins, rounds);
      });

      test('claim 0 rows after supersession is the superseded signal and '
          'writes no submission', () async {
        final prep = preparations();
        await prep.insert(newPreparation('race-a', hireId: hireId));
        await prep.supersedeCurrent(hireId);

        final recorded = await prep.inTransaction((tx) async {
          if (!await prep.claim('race-a', transaction: tx)) return null;
          return submissions().insertSubmitted(
            purpose: SubmissionPurpose.fund,
            transactionHash: hashes[0],
            signedEnvelopeXdr: _envelope,
            validUntil: _validUntil,
            preparationId: 'race-a',
            transaction: tx,
          );
        });

        expect(recorded, isNull);
        expect(await submissions().findByPreparation('race-a'), isNull);
      });

      test('concurrent identical submits: one records, the loser rolls back '
          'and re-reads the winner', () async {
        final prep = preparations();
        await prep.insert(newPreparation('race-b', hireId: hireId));

        Future<Object> submit(String hash) async {
          final store = preparations();
          final chain = submissions();
          try {
            return await store.inTransaction((tx) async {
              if (!await store.claim('race-b', transaction: tx)) {
                return 'superseded';
              }
              return chain.insertSubmitted(
                purpose: SubmissionPurpose.fund,
                transactionHash: hash,
                signedEnvelopeXdr: _envelope,
                validUntil: _validUntil,
                preparationId: 'race-b',
                transaction: tx,
              );
            });
          } on ChainSubmissionConflict catch (e) {
            expect(e.index, ChainSubmissionIndex.preparationId);
            return (await chain.findByPreparation('race-b'))!;
          }
        }

        final results = await Future.wait([
          submit(hashes[1]),
          submit(hashes[2]),
        ]);

        expect(results.every((r) => r is StoredSubmission), isTrue);
        final ids = results.cast<StoredSubmission>().map((s) => s.id).toSet();
        expect(ids, hasLength(1), reason: 'both callers see one record');
        final rows = await ChainSubmission.db.find(
          sessionBuilder.build(),
          where: (t) => t.preparationId.equals('race-b'),
        );
        expect(rows, hasLength(1));
        final claimed = await prep.findByPreparationId('race-b');
        expect(claimed!.submittedAt, isNotNull);
      });

      test('a transaction-hash conflict rolls the claim back', () async {
        final prep = preparations();
        await prep.insert(newPreparation('race-c', hireId: hireId));
        await submissions().insertSubmitted(
          purpose: SubmissionPurpose.fund,
          transactionHash: hashes[3],
          signedEnvelopeXdr: _envelope,
          validUntil: _validUntil,
          preparationId: 'race-other',
        );

        await expectLater(
          prep.inTransaction((tx) async {
            await prep.claim('race-c', transaction: tx);
            await submissions().insertSubmitted(
              purpose: SubmissionPurpose.fund,
              transactionHash: hashes[3],
              signedEnvelopeXdr: _envelope,
              validUntil: _validUntil,
              preparationId: 'race-c',
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

        expect((await prep.findByPreparationId('race-c'))!.submittedAt, isNull);
        expect(await submissions().findByPreparation('race-c'), isNull);
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
