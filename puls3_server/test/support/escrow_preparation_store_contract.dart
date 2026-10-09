import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/escrow_preparation_store.dart';
import 'package:test/test.dart';

/// Builds a store whose clock is [now]. Called inside each test body.
typedef EscrowPreparationStoreFactory =
    EscrowPreparationStore Function(DateTime Function() now);

final _validUntil = DateTime.utc(2026, 10, 7, 12, 5);

NewPreparation newPreparation(
  String id, {
  int hireId = 7,
  SubmissionPurpose purpose = SubmissionPurpose.fund,
  String signer = 'GSIGNER',
  String? hash,
  int sequence = 100,
  int? jobExpiredAt,
  String? rejectReason,
}) => NewPreparation(
  preparationId: id,
  hireId: hireId,
  purpose: purpose,
  signer: signer,
  unsignedEnvelopeXdr: 'AAAAAgAAAAA=',
  transactionHash: hash ?? id.padLeft(64, 'a'),
  sequence: sequence,
  validUntil: _validUntil,
  jobExpiredAt: jobExpiredAt,
  rejectReason: rejectReason,
);

/// The behavior every [EscrowPreparationStore] shares. Run it from a
/// `group` (unit) or inside `withServerpod` (integration).
void escrowPreparationStoreContract(EscrowPreparationStoreFactory build) {
  late DateTime clock;
  late EscrowPreparationStore store;

  setUp(() {
    clock = DateTime.utc(2026, 10, 7, 12);
  });

  EscrowPreparationStore create() => store = build(() => clock);

  test('insert stores an open preparation with every field', () async {
    create();

    final stored = await store.insert(
      newPreparation(
        'prep-1',
        purpose: SubmissionPurpose.createJob,
        jobExpiredAt: 1790000000,
      ),
    );

    expect(stored.id, isPositive);
    expect(stored.preparationId, 'prep-1');
    expect(stored.hireId, 7);
    expect(stored.purpose, SubmissionPurpose.createJob);
    expect(stored.signer, 'GSIGNER');
    expect(stored.unsignedEnvelopeXdr, 'AAAAAgAAAAA=');
    expect(stored.transactionHash, 'prep-1'.padLeft(64, 'a'));
    expect(stored.sequence, 100);
    expect(stored.validUntil, _validUntil);
    expect(stored.jobExpiredAt, 1790000000);
    expect(stored.rejectReason, isNull);
    expect(stored.createdAt, clock);
    expect(stored.supersededAt, isNull);
    expect(stored.submittedAt, isNull);
  });

  test('findByPreparationId returns the row, or null when unknown', () async {
    create();
    await store.insert(newPreparation('prep-1', rejectReason: 'no'));

    final found = await store.findByPreparationId('prep-1');

    expect(found!.rejectReason, 'no');
    expect(await store.findByPreparationId('prep-missing'), isNull);
  });

  test(
    'findCurrent is the newest preparation that is not superseded',
    () async {
      create();
      expect(await store.findCurrent(7), isNull);
      await store.insert(newPreparation('prep-1'));
      await store.supersedeCurrent(7);
      await store.insert(newPreparation('prep-2'));
      await store.insert(newPreparation('prep-other', hireId: 8));

      final current = await store.findCurrent(7);

      expect(current!.preparationId, 'prep-2');
    },
  );

  test('supersedeCurrent marks every open preparation of the hire', () async {
    create();
    await store.insert(newPreparation('prep-1'));
    await store.insert(newPreparation('prep-other', hireId: 8));
    clock = clock.add(const Duration(seconds: 3));

    final count = await store.supersedeCurrent(7);

    expect(count, 1);
    final old = await store.findByPreparationId('prep-1');
    expect(old!.supersededAt, clock);
    expect(
      (await store.findByPreparationId('prep-other'))!.supersededAt,
      isNull,
    );
    expect(await store.findCurrent(7), isNull);
  });

  test('supersedeCurrent leaves a claimed preparation alone', () async {
    create();
    await store.insert(newPreparation('prep-1'));
    expect(await store.claim('prep-1'), isTrue);

    final count = await store.supersedeCurrent(7);

    expect(count, 0);
    expect((await store.findByPreparationId('prep-1'))!.supersededAt, isNull);
  });

  test('claim sets submittedAt once for an open preparation', () async {
    create();
    await store.insert(newPreparation('prep-1'));
    clock = clock.add(const Duration(seconds: 9));

    expect(await store.claim('prep-1'), isTrue);

    final claimed = await store.findByPreparationId('prep-1');
    expect(claimed!.submittedAt, clock);
  });

  test('claim of a superseded preparation changes nothing (0 rows)', () async {
    create();
    await store.insert(newPreparation('prep-1'));
    await store.supersedeCurrent(7);

    expect(await store.claim('prep-1'), isFalse);

    expect((await store.findByPreparationId('prep-1'))!.submittedAt, isNull);
  });

  test('claim of an unknown preparation is false', () async {
    create();

    expect(await store.claim('prep-missing'), isFalse);
  });

  test('a second claim of the same preparation is still true', () async {
    // A concurrent identical submit must reach insertSubmitted and lose
    // there on the preparation index, not be reported as superseded.
    create();
    await store.insert(newPreparation('prep-1'));
    expect(await store.claim('prep-1'), isTrue);

    expect(await store.claim('prep-1'), isTrue);
  });

  test('insert rejects a duplicate preparation id', () async {
    create();
    await store.insert(newPreparation('prep-1'));

    expect(
      () => store.insert(newPreparation('prep-1', hash: 'f' * 64)),
      throwsA(isA<EscrowPreparationConflict>()),
    );
  });

  test('inTransaction returns the body result and keeps its writes', () async {
    create();
    await store.insert(newPreparation('prep-1'));

    final won = await store.inTransaction(
      (tx) => store.claim('prep-1', transaction: tx),
    );

    expect(won, isTrue);
    expect((await store.findByPreparationId('prep-1'))!.submittedAt, isNotNull);
  });

  test('inTransaction rolls back its writes when the body throws', () async {
    create();
    await store.insert(newPreparation('prep-1'));

    await expectLater(
      store.inTransaction((tx) async {
        await store.claim('prep-1', transaction: tx);
        await store.insert(newPreparation('prep-2'), transaction: tx);
        throw StateError('boom');
      }),
      throwsStateError,
    );

    expect((await store.findByPreparationId('prep-1'))!.submittedAt, isNull);
    expect(await store.findByPreparationId('prep-2'), isNull);
  });
}
