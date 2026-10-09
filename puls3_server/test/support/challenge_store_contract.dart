import 'package:puls3_server/src/auth/challenge_store.dart';
import 'package:test/test.dart';

/// Builds a store whose clock is [now]. Called inside each test body.
typedef ChallengeStoreFactory =
    ChallengeStore Function(DateTime Function() now);

const _wallet = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

/// The behavior every [ChallengeStore] shares (W26). Run it from a `group`
/// (unit) or inside `withServerpod` (integration).
void challengeStoreContract(ChallengeStoreFactory build) {
  late DateTime clock;
  late ChallengeStore store;

  setUp(() {
    clock = DateTime.utc(2026, 10, 9, 12);
  });

  ChallengeStore create() => store = build(() => clock);

  NewChallenge fresh(String id) => NewChallenge(
    challengeId: id,
    wallet: _wallet,
    challengeXdr: 'AAAA',
    transactionHash: id.padLeft(64, 'b'),
    expiresAt: clock.add(const Duration(minutes: 15)),
  );

  test('insert then find returns the stored challenge', () async {
    create();
    final challenge = fresh('c1');

    await store.insert(challenge);
    final found = await store.find('c1');

    expect(found, isNotNull);
    expect(found!.challengeId, challenge.challengeId);
    expect(found.wallet, challenge.wallet);
    expect(found.challengeXdr, challenge.challengeXdr);
    expect(found.transactionHash, challenge.transactionHash);
    expect(found.expiresAt, challenge.expiresAt);
    expect(found.createdAt, clock);
    expect(found.consumedAt, isNull);
  });

  test('an unknown id is not found', () async {
    create();

    expect(await store.find('missing'), isNull);
    expect(await store.consume('missing'), ConsumeOutcome.notFound);
  });

  test('consume succeeds once and then reports already consumed', () async {
    create();
    await store.insert(fresh('c1'));

    expect(await store.consume('c1'), ConsumeOutcome.consumed);
    expect((await store.find('c1'))!.consumedAt, clock);
    expect(await store.consume('c1'), ConsumeOutcome.alreadyConsumed);
  });

  test('a challenge at or past its expiry is not consumed', () async {
    create();
    final challenge = fresh('c1');
    await store.insert(challenge);
    clock = challenge.expiresAt;

    expect(await store.consume('c1'), ConsumeOutcome.expired);
    expect((await store.find('c1'))!.consumedAt, isNull);
  });

  test('a consume inside a transaction that throws leaves the row '
      'unconsumed', () async {
    create();
    await store.insert(fresh('c1'));

    await expectLater(
      store.inTransaction((tx) async {
        expect(
          await store.consume('c1', transaction: tx),
          ConsumeOutcome.consumed,
        );
        throw StateError('boom');
      }),
      throwsStateError,
    );

    expect((await store.find('c1'))!.consumedAt, isNull);
    expect(await store.consume('c1'), ConsumeOutcome.consumed);
  });
}
