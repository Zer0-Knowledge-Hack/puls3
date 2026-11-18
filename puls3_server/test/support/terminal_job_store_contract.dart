import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/terminal_job_store.dart';
import 'package:test/test.dart';

final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _bob = StellarAddress.parse(
  'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN',
);
final _escrowA = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
final _escrowB = StellarAddress.parse(
  'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
);

ReferencedJob _job(StellarAddress client, {JobState? state, int agent = 7}) =>
    ReferencedJob(
      client: client,
      agentId: AgentId(agent),
      state: state ?? JobState.completed,
    );

/// What every [TerminalJobStore] must do. [open] returns a store over the
/// same state each time (a second call is a restart); [reset] empties it.
void terminalJobStoreContract(
  TerminalJobStore Function() open,
  Future<void> Function() reset,
) {
  setUp(reset);

  test('a job never saved is not found', () async {
    expect(await open().find(_escrowA, 1), isNull);
  });

  test('a saved fact comes back whole, also from a new store', () async {
    await open().save(_escrowA, 1, _job(_alice, agent: 9));

    final found = await open().find(_escrowA, 1);

    expect(found?.client, _alice);
    expect(found?.agentId, AgentId(9));
    expect(found?.state, JobState.completed);
  });

  test('the same job id on another escrow is another fact', () async {
    await open().save(_escrowA, 1, _job(_alice));

    expect(await open().find(_escrowB, 1), isNull);
  });

  test('a fact is final: saving again keeps the first one', () async {
    final store = open();
    await store.save(_escrowA, 1, _job(_alice));
    await store.save(_escrowA, 1, _job(_bob, state: JobState.rejected));

    final found = await open().find(_escrowA, 1);
    expect(found?.client, _alice);
    expect(found?.state, JobState.completed);
  });
}
