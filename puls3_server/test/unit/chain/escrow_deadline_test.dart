import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:test/test.dart';

final _client = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _provider = StellarAddress.parse(
  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
);
final _usdc = StellarAddress.parse(
  'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H',
);

const _deadline = 1_700_000_100;
const _expiredAt = 1_700_000_500;

EscrowJob _job(EscrowJobState state) => EscrowJob(
  client: _client,
  provider: _provider,
  evaluator: _client,
  agentId: AgentId(7),
  token: _usdc,
  budget: BigInt.from(5000000),
  feeBps: 0,
  expiredAt: _expiredAt,
  description: 'triage',
  state: state,
  submittedAt: state == EscrowJobState.submitted ? _deadline - 60 : 0,
  approvalDeadline: state == EscrowJobState.submitted ? _deadline : 0,
  deliverable: null,
);

void main() {
  group('dueEscrowServerCall', () {
    test(
      'release fires at the approval deadline and not one second before',
      () {
        final job = _job(EscrowJobState.submitted);

        expect(
          dueEscrowServerCall(
            job: job,
            isExpired: false,
            ledgerTime: _deadline - 1,
          ),
          isNull,
        );
        expect(
          dueEscrowServerCall(
            job: job,
            isExpired: false,
            ledgerTime: _deadline,
          ),
          EscrowServerCall.release,
        );
      },
    );

    test('claim_refund fires only when the escrow says the funded job '
        'is expired', () {
      final job = _job(EscrowJobState.funded);

      expect(
        dueEscrowServerCall(
          job: job,
          isExpired: false,
          ledgerTime: _expiredAt,
        ),
        isNull,
      );
      expect(
        dueEscrowServerCall(
          job: job,
          isExpired: true,
          ledgerTime: _expiredAt,
        ),
        EscrowServerCall.claimRefund,
      );
    });

    test('a submitted job is released, never refunded', () {
      expect(
        dueEscrowServerCall(
          job: _job(EscrowJobState.submitted),
          isExpired: true,
          ledgerTime: _deadline,
        ),
        EscrowServerCall.release,
      );
    });

    test('an open job past expiry is not refunded', () {
      expect(
        dueEscrowServerCall(
          job: _job(EscrowJobState.open),
          isExpired: true,
          ledgerTime: _expiredAt,
        ),
        isNull,
      );
    });
  });

  group('EscrowDeadlineSweep', () {
    test('asks the sender only after the escrow deadline', () async {
      final jobs = _Jobs({3: _job(EscrowJobState.submitted)});
      final expiry = _Expiry({3: false});
      final sender = _Sender();
      EscrowDeadlineSweep sweepAt(int ledgerTime) => EscrowDeadlineSweep(
        jobs: jobs,
        expiry: expiry,
        sender: sender,
        ledgerTime: ledgerTime,
      );
      const hire = DueEscrowHire(hireId: 9, jobId: 3);

      expect(await sweepAt(_deadline - 1).pass([hire]), 0);
      expect(sender.sent, isEmpty);

      expect(await sweepAt(_deadline).pass([hire]), 1);
      expect(sender.sent.single.call, EscrowServerCall.release);
      expect(sender.sent.single.hireId, 9);
    });

    test('a missing job sends nothing', () async {
      final sender = _Sender();
      final sweep = EscrowDeadlineSweep(
        jobs: _Jobs({}),
        expiry: _Expiry({}),
        sender: sender,
        ledgerTime: _deadline,
      );

      expect(
        await sweep.pass([const DueEscrowHire(hireId: 9, jobId: 3)]),
        0,
      );
      expect(sender.sent, isEmpty);
    });
  });
}

final class _Jobs implements EscrowJobReader {
  _Jobs(this.jobs);

  final Map<int, EscrowJob> jobs;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async => jobs[jobId];
}

final class _Expiry implements EscrowExpiryReader {
  _Expiry(this.flags);

  final Map<int, bool> flags;

  @override
  Future<bool> isExpired(int jobId) async => flags[jobId] ?? false;
}

final class _Sent {
  _Sent({required this.hireId, required this.jobId, required this.call});

  final int hireId;
  final int jobId;
  final EscrowServerCall call;
}

final class _Sender implements EscrowServerCallSender {
  final sent = <_Sent>[];

  @override
  Future<void> send({
    required int hireId,
    required int jobId,
    required EscrowServerCall call,
  }) async {
    sent.add(_Sent(hireId: hireId, jobId: jobId, call: call));
  }
}
