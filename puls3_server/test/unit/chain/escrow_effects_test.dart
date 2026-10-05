import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 10, 5, 12);
final _address = StellarConfig.testnet.simulationSource;

StoredSubmission _submission(SubmissionPurpose purpose) => StoredSubmission(
  id: 1,
  preparationId: 'prep-1',
  purpose: purpose,
  transactionHash: 'a' * 64,
  state: SubmissionState.submitted,
  errorCode: null,
  explorerUrl: null,
  hireId: 7,
  signedEnvelopeXdr: 'AAAA',
  validUntil: _at,
  lastSentAt: null,
  sendAttempts: 0,
  createdAt: _at,
  updatedAt: _at,
);

void main() {
  group('EffectResult', () {
    test('ok', () {
      expect(const EffectResult.ok(), isA<EffectOk>());
    });

    test('failed keeps a job outcome code and an optional field', () {
      final result = EffectResult.failed(
        SubmissionOutcomeCode.jobMismatch,
        field: 'budget',
      );

      expect(
        result,
        isA<EffectFailed>()
            .having((r) => r.code, 'code', SubmissionOutcomeCode.jobMismatch)
            .having((r) => r.field, 'field', 'budget'),
      );
      expect(
        EffectResult.failed(SubmissionOutcomeCode.jobEvidenceUnavailable),
        isA<EffectFailed>().having((r) => r.field, 'field', isNull),
      );
    });

    test('failed rejects any other code', () {
      expect(
        () => EffectResult.failed(SubmissionOutcomeCode.transactionFailed),
        throwsArgumentError,
      );
    });
  });

  group('NoopEscrowEffects', () {
    test('accepts every effect and logs it', () async {
      final logged = <String>[];
      final effects = NoopEscrowEffects(
        log: (level, message) => logged.add('${level.name} $message'),
      );

      final created = await effects.onJobCreated(
        _submission(SubmissionPurpose.createJob),
        JobCreatedEvent(
          jobId: 3,
          client: _address,
          provider: _address,
          evaluator: _address,
          agentId: AgentId(7),
          token: _address,
          budget: BigInt.one,
          expiredAt: 1,
        ),
      );
      final funded = await effects.onFunded(
        _submission(SubmissionPurpose.fund),
        JobFundedEvent(
          jobId: 3,
          client: _address,
          amount: BigInt.one,
          feeBps: 0,
        ),
      );

      expect(created, isA<EffectOk>());
      expect(funded, isA<EffectOk>());
      expect(logged, [
        allOf(startsWith('info'), contains('job 3'), contains('submission 1')),
        allOf(startsWith('info'), contains('job 3'), contains('submission 1')),
      ]);
    });
  });
}
