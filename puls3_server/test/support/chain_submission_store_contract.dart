import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_submission_tracker.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:test/test.dart';

import 'fake_escrow_effects.dart';
import 'fake_submission_ledger.dart';

/// Builds a store whose clock is [now]. Called inside each test body.
typedef ChainSubmissionStoreFactory =
    ChainSubmissionStore Function(DateTime Function() now);

const _txA = '43cd3e847c1a8d11d13f9611b7a2d677d2919323c6f2a74c76b9e289f6652437';
const _txB = '652a575b5d85814c19a4fed0f7d21f40acb35a399c4008d450877ee83e8b31ab';
const _txC = '0000000000000000000000000000000000000000000000000000000000000001';
const _envelope = 'AAAAAgAAAAA=';

final _validUntil = DateTime.utc(2026, 10, 5, 12, 5);

/// The behavior every [ChainSubmissionStore] shares. Run it from a
/// `group` (unit) or inside `withServerpod` (integration).
void chainSubmissionStoreContract(ChainSubmissionStoreFactory build) {
  late DateTime clock;
  late ChainSubmissionStore repo;

  setUp(() {
    clock = DateTime.utc(2026, 10, 5, 12);
  });

  ChainSubmissionStore create() => repo = build(() => clock);

  Future<StoredSubmission> insert({
    String transactionHash = _txA,
    String? preparationId = 'prep-1',
    SubmissionPurpose purpose = SubmissionPurpose.fund,
    int? hireId = 7,
  }) => repo.insertSubmitted(
    purpose: purpose,
    transactionHash: transactionHash,
    signedEnvelopeXdr: _envelope,
    validUntil: _validUntil,
    preparationId: preparationId,
    hireId: hireId,
    explorerUrl: 'https://stellar.expert/explorer/testnet/tx/$transactionHash',
  );

  test('insertSubmitted stores a submitted record with every field', () async {
    create();

    final stored = await insert();

    expect(stored.id, isPositive);
    expect(stored.preparationId, 'prep-1');
    expect(stored.purpose, SubmissionPurpose.fund);
    expect(stored.transactionHash, _txA);
    expect(stored.state, SubmissionState.submitted);
    expect(stored.errorCode, isNull);
    expect(
      stored.explorerUrl,
      'https://stellar.expert/explorer/testnet/tx/$_txA',
    );
    expect(stored.hireId, 7);
    expect(stored.signedEnvelopeXdr, _envelope);
    expect(stored.validUntil, _validUntil);
    expect(stored.lastSentAt, isNull);
    expect(stored.sendAttempts, 0);
    expect(stored.createdAt, clock);
    expect(stored.updatedAt, clock);
    expect(stored.lastCheckedAt, clock);
  });

  test('findByPreparation returns the stored record or null', () async {
    create();
    final stored = await insert();

    final found = await repo.findByPreparation('prep-1');

    expect(found, isNotNull);
    expect(found!.id, stored.id);
    expect(found.transactionHash, _txA);
    expect(found.purpose, SubmissionPurpose.fund);
    expect(await repo.findByPreparation('prep-unknown'), isNull);
  });

  test('a second record for the same preparation is a conflict', () async {
    create();
    await insert();

    await expectLater(
      insert(transactionHash: _txB),
      throwsA(
        isA<ChainSubmissionConflict>().having(
          (e) => e.index,
          'index',
          ChainSubmissionIndex.preparationId,
        ),
      ),
    );
  });

  test('a second record for the same transaction is a conflict', () async {
    create();
    await insert();

    await expectLater(
      insert(preparationId: 'prep-2'),
      throwsA(
        isA<ChainSubmissionConflict>().having(
          (e) => e.index,
          'index',
          ChainSubmissionIndex.transaction,
        ),
      ),
    );
  });

  test('server-signed records without a preparation do not conflict', () async {
    create();

    final release = await insert(
      preparationId: null,
      purpose: SubmissionPurpose.release,
    );
    final refund = await insert(
      transactionHash: _txB,
      preparationId: null,
      purpose: SubmissionPurpose.claimRefund,
    );

    expect(release.preparationId, isNull);
    expect(refund.preparationId, isNull);
    expect(refund.id, isNot(release.id));
  });

  test('markConfirmed transitions only a submitted record', () async {
    create();
    final stored = await insert();
    clock = clock.add(const Duration(seconds: 30));

    expect(await repo.markConfirmed(stored.id), isTrue);
    final confirmed = (await repo.findByPreparation('prep-1'))!;
    expect(confirmed.state, SubmissionState.confirmed);
    expect(confirmed.errorCode, isNull);
    expect(confirmed.updatedAt, clock);

    clock = clock.add(const Duration(seconds: 30));
    expect(await repo.markConfirmed(stored.id), isFalse);
    expect(
      await repo.markFailed(stored.id, SubmissionOutcomeCode.jobMismatch),
      isFalse,
    );
    final unchanged = (await repo.findByPreparation('prep-1'))!;
    expect(unchanged.state, SubmissionState.confirmed);
    expect(unchanged.errorCode, isNull);
    expect(unchanged.updatedAt, confirmed.updatedAt);
  });

  test('markFailed transitions only a submitted record', () async {
    create();
    final stored = await insert();
    clock = clock.add(const Duration(seconds: 30));

    expect(
      await repo.markFailed(
        stored.id,
        SubmissionOutcomeCode.submissionRejected,
      ),
      isTrue,
    );
    final failed = (await repo.findByPreparation('prep-1'))!;
    expect(failed.state, SubmissionState.failed);
    expect(failed.errorCode, SubmissionOutcomeCode.submissionRejected);
    expect(failed.updatedAt, clock);

    expect(await repo.markConfirmed(stored.id), isFalse);
    expect(
      await repo.markFailed(stored.id, SubmissionOutcomeCode.transactionFailed),
      isFalse,
    );
    final unchanged = (await repo.findByPreparation('prep-1'))!;
    expect(unchanged.state, SubmissionState.failed);
    expect(unchanged.errorCode, SubmissionOutcomeCode.submissionRejected);
  });

  test('transitions of an unknown id change nothing', () async {
    create();

    expect(await repo.markConfirmed(999999), isFalse);
    expect(
      await repo.markFailed(999999, SubmissionOutcomeCode.transactionFailed),
      isFalse,
    );
    expect(await repo.recordSend(999999, clock), isFalse);
    expect(await repo.recordCheck(999999, clock), isFalse);
  });

  test('recordCheck keeps the last check time and nothing else', () async {
    create();
    final stored = await insert();
    final checkedAt = clock.add(const Duration(seconds: 5));

    expect(await repo.recordCheck(stored.id, checkedAt), isTrue);

    final checked = (await repo.findByPreparation('prep-1'))!;
    expect(checked.lastCheckedAt, checkedAt);
    expect(checked.state, SubmissionState.submitted);
    expect(checked.updatedAt, stored.updatedAt);
    expect(checked.sendAttempts, 0);
    expect(checked.lastSentAt, isNull);
  });

  test('recordCheck changes only a submitted record', () async {
    create();
    final stored = await insert();
    await repo.markFailed(stored.id, SubmissionOutcomeCode.transactionFailed);

    expect(
      await repo.recordCheck(stored.id, clock.add(const Duration(minutes: 1))),
      isFalse,
    );

    final unchanged = (await repo.findByPreparation('prep-1'))!;
    expect(unchanged.lastCheckedAt, stored.lastCheckedAt);
  });

  test('recordSend counts attempts and keeps the last send time', () async {
    create();
    final stored = await insert();
    final first = clock.add(const Duration(seconds: 1));
    final second = clock.add(const Duration(seconds: 9));

    expect(await repo.recordSend(stored.id, first), isTrue);
    expect(await repo.recordSend(stored.id, second), isTrue);

    final sent = (await repo.findByPreparation('prep-1'))!;
    expect(sent.sendAttempts, 2);
    expect(sent.lastSentAt, second);
    expect(sent.state, SubmissionState.submitted);
    expect(sent.updatedAt, stored.updatedAt);
  });

  test('listSubmitted returns only submitted records, oldest update '
      'first, up to limit', () async {
    create();
    final first = await insert(preparationId: 'prep-1', transactionHash: _txA);
    clock = clock.add(const Duration(seconds: 1));
    final second = await insert(
      preparationId: 'prep-2',
      transactionHash: _txB,
    );
    clock = clock.add(const Duration(seconds: 1));
    final third = await insert(preparationId: 'prep-3', transactionHash: _txC);
    clock = clock.add(const Duration(seconds: 1));
    await repo.markConfirmed(second.id);

    final all = await repo.listSubmitted();
    final limited = await repo.listSubmitted(limit: 1);

    expect(all.map((s) => s.id), [first.id, third.id]);
    expect(limited.map((s) => s.id), [first.id]);
  });

  test('listSubmitted rejects a limit below 1', () async {
    create();

    expect(() => repo.listSubmitted(limit: 0), throwsArgumentError);
  });

  test('listSubmitted lists the least recently checked records '
      'first', () async {
    create();
    final a = await insert(preparationId: 'prep-1', transactionHash: _txA);
    final b = await insert(preparationId: 'prep-2', transactionHash: _txB);
    final c = await insert(preparationId: 'prep-3', transactionHash: _txC);
    await repo.recordCheck(a.id, clock.add(const Duration(seconds: 2)));
    await repo.recordCheck(b.id, clock.add(const Duration(seconds: 1)));

    final listed = await repo.listSubmitted();

    expect(listed.map((s) => s.id), [c.id, b.id, a.id]);
  });

  test('listSubmitted does not order by sends', () async {
    create();
    final a = await insert(preparationId: 'prep-1', transactionHash: _txA);
    final b = await insert(preparationId: 'prep-2', transactionHash: _txB);
    await repo.recordSend(a.id, clock.add(const Duration(seconds: 1)));

    final listed = await repo.listSubmitted();

    expect(listed.map((s) => s.id), [a.id, b.id]);
  });

  test('listSubmitted lists a record behind limit more recently checked '
      'ones', () async {
    create();
    final a = await insert(preparationId: 'prep-1', transactionHash: _txA);
    clock = clock.add(const Duration(seconds: 1));
    final b = await insert(preparationId: 'prep-2', transactionHash: _txB);
    clock = clock.add(const Duration(seconds: 1));
    final c = await insert(preparationId: 'prep-3', transactionHash: _txC);

    final first = await repo.listSubmitted(limit: 2);
    for (final s in first) {
      await repo.recordCheck(s.id, clock.add(const Duration(minutes: 1)));
    }
    final second = await repo.listSubmitted(limit: 2);

    expect(first.map((s) => s.id), [a.id, b.id]);
    expect(second.map((s) => s.id), [c.id, a.id]);
  });

  test('limit or more untracked records do not starve a fund record '
      '(REL-001)', () async {
    create();
    final release = await insert(
      preparationId: null,
      purpose: SubmissionPurpose.release,
    );
    final refund = await insert(
      transactionHash: _txB,
      preparationId: null,
      purpose: SubmissionPurpose.claimRefund,
    );
    clock = clock.add(const Duration(seconds: 1));
    final fund = await insert(transactionHash: _txC);
    final ledger = FakeSubmissionLedger(closeTime: clock);
    final tracker = ChainSubmissionTracker(
      ledger: ledger,
      effects: FakeEscrowEffects(),
      now: () => clock,
      batchLimit: 2,
      log: ignoreChainLog,
    );
    clock = clock.add(const Duration(minutes: 1));

    final first = await tracker.pass(repo);
    final next = await repo.listSubmitted(limit: 2);
    await tracker.pass(repo);

    expect(first.untracked, 2);
    expect(next.map((s) => s.id), [fund.id, release.id]);
    expect(next.map((s) => s.id), isNot(contains(refund.id)));
    expect(ledger.lookedUp, [fund.transactionHash]);
  });

  test('recordSend changes only a submitted record', () async {
    create();
    final stored = await insert();
    await repo.markConfirmed(stored.id);

    expect(await repo.recordSend(stored.id, clock), isFalse);

    final unchanged = (await repo.findByPreparation('prep-1'))!;
    expect(unchanged.sendAttempts, 0);
    expect(unchanged.lastSentAt, isNull);
  });

  test('insertSubmitted requires a preparation for wallet-signed '
      'purposes', () async {
    create();

    for (final purpose in SubmissionPurpose.values.where(
      (p) => !p.isServerSigned,
    )) {
      expect(
        () => insert(preparationId: null, purpose: purpose),
        throwsArgumentError,
        reason: purpose.wireName,
      );
    }
    expect(await repo.listSubmitted(), isEmpty);
  });

  test('insertSubmitted rejects a preparation for server-signed '
      'purposes', () async {
    create();

    for (final purpose in SubmissionPurpose.values.where(
      (p) => p.isServerSigned,
    )) {
      expect(
        () => insert(preparationId: 'prep-x', purpose: purpose),
        throwsArgumentError,
        reason: purpose.wireName,
      );
    }
    expect(await repo.listSubmitted(), isEmpty);
  });

  test('markFailed rejects an unknown outcome code', () async {
    create();
    final stored = await insert();

    expect(() => repo.markFailed(stored.id, 'Oops'), throwsArgumentError);

    final unchanged = (await repo.findByPreparation('prep-1'))!;
    expect(unchanged.state, SubmissionState.submitted);
  });

  test(
    'listByHire returns every record of the hire in insertion order',
    () async {
      create();
      final first = await insert();
      final other = await insert(
        transactionHash: _txB,
        preparationId: 'prep-2',
        hireId: 8,
      );
      final second = await insert(
        transactionHash: _txC,
        preparationId: 'prep-3',
        purpose: SubmissionPurpose.createJob,
      );
      await repo.markFailed(first.id, SubmissionOutcomeCode.submissionRejected);

      final seven = await repo.listByHire(7);

      expect(seven.map((r) => r.id), [first.id, second.id]);
      expect(seven.first.state, SubmissionState.failed);
      expect((await repo.listByHire(8)).map((r) => r.id), [other.id]);
    },
  );

  test('listByHire is empty for a hire without records', () async {
    create();
    await insert();

    expect(await repo.listByHire(99), isEmpty);
  });

  test('toProtocol exposes the client fields with wire names', () async {
    create();
    final stored = await insert();

    final protocol = stored.toProtocol();

    expect(protocol.id, stored.id);
    expect(protocol.preparationId, 'prep-1');
    expect(protocol.purpose, 'fund');
    expect(protocol.transaction, _txA);
    expect(protocol.state, 'submitted');
    expect(protocol.errorCode, isNull);
    expect(protocol.explorerUrl, stored.explorerUrl);
    expect(protocol.updatedAt, stored.updatedAt);
    expect(protocol.signedEnvelopeXdr, isNull);
    expect(protocol.hireId, isNull);
  });
}
