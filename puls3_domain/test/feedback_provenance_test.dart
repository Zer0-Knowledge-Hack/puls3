import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);

void main() {
  group('PaidJobReference', () {
    test('writes the version 1 text', () {
      expect(
        PaidJobReference(escrow: _escrow, jobId: 3).text,
        'puls3:job:v1:CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2:3',
      );
    });

    test('parses what it writes', () {
      final reference = PaidJobReference(escrow: _escrow, jobId: 42);

      final parsed = PaidJobReference.tryParse(reference.text);

      expect(parsed, reference);
      expect(parsed!.escrow, _escrow);
      expect(parsed.jobId, 42);
    });

    test('the largest job id it accepts round-trips exactly', () {
      final reference = PaidJobReference(escrow: _escrow, jobId: 999999999999999);

      expect(PaidJobReference.tryParse(reference.text), reference);
    });

    test('refuses an account as the escrow', () {
      expect(
        () => PaidJobReference(escrow: _alice, jobId: 1),
        throwsArgumentError,
      );
    });

    test('refuses a job id that is not positive', () {
      expect(
        () => PaidJobReference(escrow: _escrow, jobId: 0),
        throwsRangeError,
      );
      expect(
        () => PaidJobReference(escrow: _escrow, jobId: -1),
        throwsRangeError,
      );
    });

    test('parses nothing that is not exactly a reference', () {
      for (final text in [
        '',
        'puls3:job:v1:',
        'PULS3:JOB:V1:${_escrow.value}:1',
        ' puls3:job:v1:${_escrow.value}:1',
        'puls3:job:v1:${_escrow.value}:1 ',
        'puls3:job:v1:${_escrow.value}:+1',
        'puls3:job:v1:${_escrow.value}:1e3',
        'puls3:job:v1:${_escrow.value}:1000000000000000',
        'puls3:job:v1:${_alice.value}:1',
      ]) {
        expect(PaidJobReference.tryParse(text), isNull, reason: text);
      }
    });
  });

  group('feedbackCommitment', () {
    test('is the reference, agent, client and score, one per line', () {
      expect(
        feedbackCommitment(
          job: PaidJobReference(escrow: _escrow, jobId: 3),
          agent: AgentId(7),
          client: _alice,
          score: 5,
        ),
        'puls3:feedback:v1\n'
        'puls3:job:v1:CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2:3\n'
        'agent:7\n'
        'client:GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H\n'
        'score:5',
      );
    });

    test('changes with every field it binds', () {
      String commitment({int job = 3, int agent = 7, int score = 5}) =>
          feedbackCommitment(
            job: PaidJobReference(escrow: _escrow, jobId: job),
            agent: AgentId(agent),
            client: _alice,
            score: score,
          );

      final base = commitment();
      expect(commitment(job: 4), isNot(base));
      expect(commitment(agent: 8), isNot(base));
      expect(commitment(score: 4), isNot(base));
    });
  });
}
