import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_submission_tracker.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../support/fake_escrow_effects.dart';
import '../support/fake_submission_ledger.dart';
import 'test_tools/serverpod_test_tools.dart';

const _resendAfter = Duration(seconds: 30);
final _seededAt = DateTime.utc(2026, 10, 5, 12);
final _restartAt = _seededAt.add(const Duration(seconds: 10));
final _address = StellarConfig.testnet.simulationSource;

void main() {
  withServerpod('Given submitted records persisted before a restart', (
    sessionBuilder,
    _,
  ) {
    test('a new tracker finishes them and resends each due envelope '
        'once', () async {
      // Before the restart: four records, two of them already sent.
      final before = ServerpodChainSubmissionStore(
        sessionBuilder.build(),
        now: () => _seededAt,
      );
      Future<StoredSubmission> seed(
        int n,
        SubmissionPurpose purpose, {
        Duration validFor = const Duration(minutes: 5),
      }) => before.insertSubmitted(
        purpose: purpose,
        transactionHash: '$n'.padLeft(64, '0'),
        signedEnvelopeXdr: 'envelope-$n',
        validUntil: _seededAt.add(validFor),
        preparationId: 'prep-$n',
      );
      final funded = await seed(1, SubmissionPurpose.fund);
      final neverSent = await seed(2, SubmissionPurpose.createJob);
      final justSent = await seed(3, SubmissionPurpose.fund);
      final expired = await seed(
        4,
        SubmissionPurpose.fund,
        validFor: const Duration(seconds: 5),
      );
      await before.recordSend(funded.id, _seededAt);
      await before.recordSend(justSent.id, _seededAt);

      // After the restart: a new store, tracker and ledger.
      final store = ServerpodChainSubmissionStore(
        sessionBuilder.build(),
        now: () => _restartAt,
      );
      final ledger = FakeSubmissionLedger(closeTime: _restartAt);
      ledger.lookups[funded.transactionHash] = TransactionLookup(
        status: TransactionStatus.success,
        latestLedgerCloseTime: _restartAt,
        jobFunded: JobFundedEvent(
          jobId: 3,
          client: _address,
          amount: BigInt.from(5000000),
          feeBps: 0,
        ),
      );
      final effects = FakeEscrowEffects();
      final tracker = ChainSubmissionTracker(
        ledger: ledger,
        effects: effects,
        now: () => _restartAt,
        resendAfter: _resendAfter,
        log: ignoreChainLog,
      );

      final first = await tracker.pass(store);
      final second = await tracker.pass(store);

      expect(first.listed, 4);
      expect(first.confirmed, 1);
      expect(first.failed, 1);
      expect(first.resent, 1);
      expect(first.waiting, 1);
      expect(second.listed, 2);
      expect(second.resent, 0);
      expect(ledger.resent, ['envelope-2']);
      expect(effects.funded, [funded.id]);

      Future<StoredSubmission> current(StoredSubmission s) async =>
          (await store.findByPreparation(s.preparationId!))!;
      expect((await current(funded)).state, SubmissionState.confirmed);
      expect((await current(expired)).state, SubmissionState.failed);
      expect(
        (await current(expired)).errorCode,
        SubmissionOutcomeCode.preparationExpired,
      );
      final resent = await current(neverSent);
      expect(resent.state, SubmissionState.submitted);
      expect(resent.sendAttempts, 1);
      expect(resent.lastSentAt, _restartAt);
      final waiting = await current(justSent);
      expect(waiting.state, SubmissionState.submitted);
      expect(waiting.sendAttempts, 1);
    });
  });
}
