import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:test/test.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _bob = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

NewHire _newHire({
  String consumer = _alice,
  String? requestId = 'request-1',
  String input = 'summarise this',
}) => NewHire(
  consumer: consumer,
  agentId: 7,
  price: 5000000,
  manifestVersion: 1,
  expiredAt: 1800000000,
  requestId: requestId,
  input: input,
);

/// The behavior every [HireLifecycleStore] shares. Run it from a `group`
/// (unit) or inside `withServerpod` (integration).
void hireLifecycleStoreContract(HireLifecycleStore Function() build) {
  late HireLifecycleStore store;

  setUp(() => store = build());

  test('insertHire stores a hire without a job and with no status', () async {
    final hire = await store.insertHire(_newHire());

    expect(hire.id, isPositive);
    expect(hire.consumer, _alice);
    expect(hire.agentId, 7);
    expect(hire.price, 5000000);
    expect(hire.manifestVersion, 1);
    expect(hire.expiredAt, 1800000000);
    expect(hire.requestId, 'request-1');
    expect(hire.input, 'summarise this');
    expect(hire.jobId, isNull);
    expect(hire.paymentTransaction, isNull);
    expect(hire.status, isNull);
    expect(await store.findHire(hire.id), isNotNull);
  });

  test('findHire is null for an unknown hire', () async {
    await store.insertHire(_newHire());

    expect(await store.findHire(999999), isNull);
  });

  test('findHireByRequest is scoped to the consumer', () async {
    final alice = await store.insertHire(_newHire());
    final bob = await store.insertHire(_newHire(consumer: _bob));

    expect((await store.findHireByRequest(_alice, 'request-1'))!.id, alice.id);
    expect((await store.findHireByRequest(_bob, 'request-1'))!.id, bob.id);
    expect(await store.findHireByRequest(_alice, 'other'), isNull);
  });

  test('a second hire with the same consumer and request conflicts', () async {
    await store.insertHire(_newHire());

    await expectLater(
      store.insertHire(_newHire(input: 'different')),
      throwsA(isA<HireRequestConflict>()),
    );
    expect(
      (await store.findHireByRequest(_alice, 'request-1'))!.input,
      'summarise this',
    );
  });

  test('bindJob sets the job id and expired_at and opens the hire', () async {
    final hire = await store.insertHire(_newHire());

    final result = await store.bindJob(hire.id, 3, expiredAt: 1800000500);

    expect(result, JobBinding.bound);
    final bound = (await store.findHire(hire.id))!;
    expect(bound.jobId, 3);
    expect(bound.expiredAt, 1800000500);
    expect(bound.status, HireStatus.open);
  });

  test('bindJob with the same job id again is a no-op', () async {
    final hire = await store.insertHire(_newHire());
    await store.bindJob(hire.id, 3, expiredAt: 1800000500);

    final result = await store.bindJob(hire.id, 3, expiredAt: 1800009999);

    expect(result, JobBinding.alreadyBound);
    expect((await store.findHire(hire.id))!.expiredAt, 1800000500);
  });

  test('bindJob refuses a job id that another hire holds', () async {
    final first = await store.insertHire(_newHire());
    final second = await store.insertHire(_newHire(requestId: 'request-2'));
    await store.bindJob(first.id, 3, expiredAt: 1800000500);

    final result = await store.bindJob(second.id, 3, expiredAt: 1800000600);

    expect(result, JobBinding.taken);
    final unchanged = (await store.findHire(second.id))!;
    expect(unchanged.jobId, isNull);
    expect(unchanged.status, isNull);
  });

  test('bindJob refuses a different job id on a bound hire', () async {
    final hire = await store.insertHire(_newHire());
    await store.bindJob(hire.id, 3, expiredAt: 1800000500);

    final result = await store.bindJob(hire.id, 4, expiredAt: 1800000600);

    expect(result, JobBinding.taken);
    expect((await store.findHire(hire.id))!.jobId, 3);
  });

  test('bindJob on an unknown hire is an invariant violation', () async {
    await expectLater(
      store.bindJob(999999, 3, expiredAt: 1800000500),
      throwsStateError,
    );
  });
}
