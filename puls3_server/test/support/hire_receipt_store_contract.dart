import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:test/test.dart';

const _wallet = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

/// A receipt store and two hire ids it may reference; [parentHireId] and
/// [childHireId] are fresh for every fixture.
final class HireReceiptStoreFixture {
  const HireReceiptStoreFixture({
    required this.store,
    required this.parentHireId,
    required this.childHireId,
  });

  final HireReceiptStore store;
  final int parentHireId;
  final int childHireId;
}

NewReceiptLine _line(
  HireReceiptStoreFixture f, {
  int? childHireId,
  int budget = 500000,
}) => NewReceiptLine(
  parentHireId: f.parentHireId,
  childHireId: childHireId ?? f.childHireId,
  providerAgentId: 9,
  providerWallet: _wallet,
  budget: budget,
  relatedParty: true,
  justification: 'cheapest research agent',
  createTransaction: 'ab' * 32,
);

/// The rules every [HireReceiptStore] keeps, for the in-memory and the
/// Serverpod implementation.
void hireReceiptStoreContract(Future<HireReceiptStoreFixture> Function() make) {
  late HireReceiptStoreFixture f;

  setUp(() async => f = await make());

  test('insert stores a pending line the child hire finds', () async {
    final stored = await f.store.insert(_line(f));

    final found = await f.store.findByChildHire(f.childHireId);
    expect(found?.id, stored.id);
    expect(found?.parentHireId, f.parentHireId);
    expect(found?.providerAgentId, 9);
    expect(found?.providerWallet, _wallet);
    expect(found?.budget, 500000);
    expect(found?.state, ReceiptLineState.pending);
    expect(found?.relatedParty, isTrue);
    expect(found?.justification, 'cheapest research agent');
    expect(found?.createTransaction, 'ab' * 32);
    expect(found?.childJobId, isNull);
  });

  test('findByChildHire is null for an unknown child', () async {
    expect(await f.store.findByChildHire(f.childHireId), isNull);
  });

  test('listByParent returns the parent lines oldest first', () async {
    final first = await f.store.insert(_line(f));
    final second = await f.store.insert(
      _line(f, childHireId: f.childHireId + 1000000, budget: 7),
    );

    final lines = await f.store.listByParent(f.parentHireId);
    expect([for (final l in lines) l.id], [first.id, second.id]);
  });

  test('markNotOpened moves a pending line once', () async {
    await f.store.insert(_line(f));

    expect(await f.store.markNotOpened(f.childHireId), isTrue);
    expect(await f.store.markNotOpened(f.childHireId), isFalse);
    expect(
      (await f.store.findByChildHire(f.childHireId))?.state,
      ReceiptLineState.notOpened,
    );
  });

  test('markUnverified moves a pending line once', () async {
    await f.store.insert(_line(f));

    expect(await f.store.markUnverified(f.childHireId), isTrue);
    expect(await f.store.markUnverified(f.childHireId), isFalse);
    expect(await f.store.markNotOpened(f.childHireId), isFalse);
    expect(
      (await f.store.findByChildHire(f.childHireId))?.state,
      ReceiptLineState.unverified,
    );
  });

  test('markOpened records the child job on a pending line once', () async {
    await f.store.insert(_line(f));

    final opened = await f.store.inTransaction(
      (transaction) => f.store.markOpened(
        f.childHireId,
        childJobId: 44,
        createTransaction: 'cd' * 32,
        state: 'funded',
        transaction: transaction,
      ),
    );

    expect(opened, isTrue);
    final line = await f.store.findByChildHire(f.childHireId);
    expect(line?.childJobId, 44);
    expect(line?.createTransaction, 'cd' * 32);
    expect(line?.state, 'funded');
    expect(
      await f.store.markOpened(
        f.childHireId,
        childJobId: 45,
        createTransaction: 'ef' * 32,
        state: 'funded',
      ),
      isFalse,
    );
    expect(await f.store.markNotOpened(f.childHireId), isFalse);
    expect((await f.store.findByChildHire(f.childHireId))?.childJobId, 44);
  });

  test('markSettled records the settlement of an opened line once', () async {
    await f.store.insert(_line(f));
    expect(
      await f.store.markSettled(
        f.childHireId,
        state: 'completed',
        fee: 1,
        payout: 2,
        settleTransaction: 'ef' * 32,
      ),
      isFalse,
      reason: 'a pending line is not settled',
    );
    await f.store.markOpened(
      f.childHireId,
      childJobId: 44,
      createTransaction: 'cd' * 32,
      state: 'funded',
    );

    expect(
      await f.store.markSettled(
        f.childHireId,
        state: 'completed',
        fee: 10000,
        payout: 490000,
        settleTransaction: 'ef' * 32,
      ),
      isTrue,
    );
    expect(
      await f.store.markSettled(
        f.childHireId,
        state: 'rejected',
        fee: 0,
        payout: 0,
        settleTransaction: '12' * 32,
      ),
      isFalse,
    );

    final line = await f.store.findByChildHire(f.childHireId);
    expect(line?.state, 'completed');
    expect(line?.fee, 10000);
    expect(line?.payout, 490000);
    expect(line?.settleTransaction, 'ef' * 32);
    expect(line?.childJobId, 44);
  });

  test('recordDeliverable sets the deliverable hash once', () async {
    await f.store.insert(_line(f));

    final first = await f.store.inTransaction(
      (transaction) => f.store.recordDeliverable(
        f.childHireId,
        '34' * 32,
        transaction: transaction,
      ),
    );

    expect(first, isTrue);
    expect(await f.store.recordDeliverable(f.childHireId, '56' * 32), isFalse);
    final line = await f.store.findByChildHire(f.childHireId);
    expect(line?.deliverableHash, '34' * 32);
    expect(line?.state, ReceiptLineState.pending);
  });

  test('inTransaction rolls the insert back when the body throws', () async {
    await expectLater(
      f.store.inTransaction((transaction) async {
        await f.store.insert(_line(f), transaction: transaction);
        throw StateError('abort');
      }),
      throwsStateError,
    );

    expect(await f.store.findByChildHire(f.childHireId), isNull);
  });
}
