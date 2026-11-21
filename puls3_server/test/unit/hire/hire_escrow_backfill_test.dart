import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/hire/hire_escrow_backfill.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:test/test.dart';

const _escrow = 'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';
const _other = 'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ';
const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _bob = 'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R';
const _usdc = 'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA';

EscrowJob _job({required String client, int agentId = 7}) => EscrowJob(
  client: StellarAddress.parse(client),
  provider: StellarAddress.parse(_bob),
  evaluator: StellarAddress.parse(client),
  agentId: AgentId(agentId),
  token: StellarAddress.parse(_usdc),
  budget: BigInt.from(5000000),
  feeBps: 0,
  expiredAt: 1795000000,
  description: 'job',
  state: EscrowJobState.completed,
  submittedAt: 0,
  approvalDeadline: 0,
  deliverable: null,
);

HireWithoutEscrow _hire(int id, int jobId) =>
    (hireId: id, jobId: jobId, consumer: _alice, agentId: 7);

/// Hire rows in memory. A hire with an escrow is not listed.
final class _Rows implements HireEscrowRows {
  _Rows(List<HireWithoutEscrow> hires) : all = [...hires];

  final List<HireWithoutEscrow> all;
  final Map<int, String> escrows = {};

  @override
  Future<List<HireWithoutEscrow>> withoutEscrow() async => [
    for (final hire in all)
      if (!escrows.containsKey(hire.hireId)) hire,
  ];

  @override
  Future<bool> setEscrowIfEmpty(int hireId, String escrow) async {
    if (escrows.containsKey(hireId)) return false;
    escrows[hireId] = escrow;
    return true;
  }
}

/// The escrow being checked: its jobs by id, and the ids that are archived.
final class _Jobs implements EscrowJobReader {
  _Jobs(this.jobs, {this.archived = const {}});

  final Map<int, EscrowJob> jobs;
  final Set<int> archived;
  LedgerException? failure;
  final reads = <int>[];

  @override
  Future<EscrowJob?> escrowJob(int jobId) async {
    reads.add(jobId);
    if (failure != null) throw failure!;
    if (archived.contains(jobId)) {
      throw const LedgerUnavailable('archived', archived: true);
    }
    return jobs[jobId];
  }
}

HireEscrowBackfill _backfill(_Rows rows, _Jobs jobs) => HireEscrowBackfill(
  rows: rows,
  jobs: jobs,
  escrow: StellarAddress.parse(_escrow),
);

void main() {
  group('HireEscrowBackfill (#307)', () {
    test('writes the escrow of a hire whose job is on it', () async {
      final rows = _Rows([_hire(1, 34)]);
      final jobs = _Jobs({34: _job(client: _alice)});

      final lines = await _backfill(rows, jobs).run(apply: true);

      expect(lines.single.outcome, BackfillOutcome.matched);
      expect(lines.single.written, isTrue);
      expect(rows.escrows, {1: _escrow});
    });

    test('writes nothing without apply', () async {
      final rows = _Rows([_hire(1, 34)]);
      final jobs = _Jobs({34: _job(client: _alice)});

      final lines = await _backfill(rows, jobs).run(apply: false);

      expect(lines.single.outcome, BackfillOutcome.matched);
      expect(lines.single.written, isFalse);
      expect(rows.escrows, isEmpty);
    });

    test('a hire funded on another escrow keeps an empty escrow', () async {
      // The same job id on this escrow belongs to another client, or to
      // another agent: the hire was not funded here.
      final rows = _Rows([_hire(1, 34), _hire(2, 35)]);
      final jobs = _Jobs({
        34: _job(client: _bob),
        35: _job(client: _alice, agentId: 8),
      });

      final lines = await _backfill(rows, jobs).run(apply: true);

      expect(lines.map((l) => l.outcome), [
        BackfillOutcome.otherJob,
        BackfillOutcome.otherJob,
      ]);
      expect(lines.any((l) => l.written), isFalse);
      expect(rows.escrows, isEmpty);
    });

    test('a wrong escrow address writes nothing', () async {
      final rows = _Rows([_hire(1, 34), _hire(2, 35)]);

      final lines = await _backfill(rows, _Jobs({})).run(apply: true);

      expect(
        lines.map((l) => l.outcome),
        everyElement(BackfillOutcome.noSuchJob),
      );
      expect(rows.escrows, isEmpty);
    });

    test('an archived job is reported and left empty', () async {
      final rows = _Rows([_hire(1, 34), _hire(2, 35)]);
      final jobs = _Jobs({35: _job(client: _alice)}, archived: {34});

      final lines = await _backfill(rows, jobs).run(apply: true);

      expect(lines.map((l) => l.outcome), [
        BackfillOutcome.archived,
        BackfillOutcome.matched,
      ]);
      expect(rows.escrows, {2: _escrow});
    });

    test('a hire with its own escrow is never read or changed', () async {
      final rows = _Rows([_hire(1, 34), _hire(2, 35)])..escrows[1] = _other;
      final jobs = _Jobs({
        34: _job(client: _alice),
        35: _job(client: _alice),
      });

      await _backfill(rows, jobs).run(apply: true);

      expect(jobs.reads, [35]);
      expect(rows.escrows, {1: _other, 2: _escrow});
    });

    test('a chain that cannot be read stops the run', () async {
      final rows = _Rows([_hire(1, 34)]);
      final jobs = _Jobs({34: _job(client: _alice)})
        ..failure = const LedgerUnavailable('RPC down');

      await expectLater(
        _backfill(rows, jobs).run(apply: true),
        throwsA(isA<LedgerUnavailable>()),
      );
      expect(rows.escrows, isEmpty);
    });

    test('a rerun after a full run has nothing left to do', () async {
      final rows = _Rows([_hire(1, 34)]);
      final jobs = _Jobs({34: _job(client: _alice)});
      await _backfill(rows, jobs).run(apply: true);

      final again = await _backfill(rows, jobs).run(apply: true);

      expect(again, isEmpty);
    });
  });
}
