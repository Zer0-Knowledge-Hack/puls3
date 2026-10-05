import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../support/chain_submission_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

final _at = DateTime.utc(2026, 10, 5, 12);

ChainSubmission _row(
  String transaction, {
  String purpose = 'fund',
  String? signedEnvelopeXdr = 'AAAAAgAAAAA=',
}) => ChainSubmission(
  preparationId: 'prep-$transaction',
  purpose: purpose,
  transaction: transaction,
  state: 'submitted',
  updatedAt: _at,
  signedEnvelopeXdr: signedEnvelopeXdr,
  validUntil: _at.add(const Duration(minutes: 5)),
  sendAttempts: 0,
  createdAt: _at,
);

void main() {
  withServerpod('Given ServerpodChainSubmissionStore', (
    sessionBuilder,
    _,
  ) {
    chainSubmissionStoreContract(
      (now) => ServerpodChainSubmissionStore(
        sessionBuilder.build(),
        now: now,
      ),
    );

    test('listSubmitted skips unreadable rows and fails them so they '
        'never block the batch', () async {
      final session = sessionBuilder.build();
      final store = ServerpodChainSubmissionStore(session, now: () => _at);
      final unknownPurpose = await ChainSubmission.db.insertRow(
        session,
        _row('a' * 64, purpose: 'teleport'),
      );
      final noEnvelope = await ChainSubmission.db.insertRow(
        session,
        _row('b' * 64, signedEnvelopeXdr: null),
      );
      final valid = await ChainSubmission.db.insertRow(session, _row('c' * 64));

      final listed = await store.listSubmitted();

      expect(listed.map((s) => s.id), [valid.id]);
      for (final id in [unknownPurpose.id!, noEnvelope.id!]) {
        final row = (await ChainSubmission.db.findById(session, id))!;
        expect(row.state, SubmissionState.failed.wireName);
        expect(row.errorCode, SubmissionOutcomeCode.escrowCallFailed);
      }
      expect((await store.listSubmitted()).map((s) => s.id), [valid.id]);
    });
  });

  // Concurrent calls need real transactions, so this group commits and
  // deletes its own row.
  withServerpod(
    'Given two ServerpodChainSubmissionStore sessions',
    (
      sessionBuilder,
      _,
    ) {
      tearDown(() async {
        await ChainSubmission.db.deleteWhere(
          sessionBuilder.build(),
          where: (t) => t.transaction.equals('d' * 64),
        );
      });

      test('concurrent confirm and fail: exactly one wins', () async {
        final first = ServerpodChainSubmissionStore(
          sessionBuilder.build(),
          now: () => _at,
        );
        final second = ServerpodChainSubmissionStore(
          sessionBuilder.build(),
          now: () => _at,
        );
        final stored = await first.insertSubmitted(
          purpose: SubmissionPurpose.fund,
          transactionHash: 'd' * 64,
          signedEnvelopeXdr: 'AAAAAgAAAAA=',
          validUntil: _at.add(const Duration(minutes: 5)),
          preparationId: 'prep-race',
        );

        final results = await Future.wait([
          first.markConfirmed(stored.id),
          second.markFailed(stored.id, SubmissionOutcomeCode.transactionFailed),
        ]);

        expect(results.where((changed) => changed), hasLength(1));
        final row = (await first.findByPreparation('prep-race'))!;
        expect(
          row.state,
          results.first ? SubmissionState.confirmed : SubmissionState.failed,
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
