import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:test/test.dart';

void main() {
  group('SubmissionPurpose', () {
    test('wire names are the api.md camelCase purposes', () {
      expect(SubmissionPurpose.values.map((p) => p.wireName), [
        'createJob',
        'fund',
        'complete',
        'reject',
        'registerFull',
        'setAgentWallet',
        'giveFeedback',
        'submit',
        'release',
        'claimRefund',
      ]);
    });

    test('every purpose round-trips through its wire name', () {
      for (final purpose in SubmissionPurpose.values) {
        expect(SubmissionPurpose.parse(purpose.wireName), purpose);
        expect(SubmissionPurpose.tryParse(purpose.wireName), purpose);
      }
    });

    test('an unknown or differently cased name is rejected', () {
      for (final wire in ['', 'CreateJob', 'create_job', 'claim_refund']) {
        expect(SubmissionPurpose.tryParse(wire), isNull, reason: wire);
        expect(
          () => SubmissionPurpose.parse(wire),
          throwsFormatException,
          reason: wire,
        );
      }
    });

    test('only submit, release and claimRefund are server-signed', () {
      expect(
        SubmissionPurpose.values.where((p) => p.isServerSigned),
        [
          SubmissionPurpose.submit,
          SubmissionPurpose.release,
          SubmissionPurpose.claimRefund,
        ],
      );
    });
  });

  group('SubmissionState', () {
    test('wire names are lowercase', () {
      expect(SubmissionState.values.map((s) => s.wireName), [
        'submitted',
        'confirmed',
        'failed',
      ]);
    });

    test('every state round-trips through its wire name', () {
      for (final state in SubmissionState.values) {
        expect(SubmissionState.parse(state.wireName), state);
        expect(SubmissionState.tryParse(state.wireName), state);
      }
    });

    test('an unknown or differently cased name is rejected', () {
      for (final wire in ['', 'Submitted', 'SUBMITTED', 'pending']) {
        expect(SubmissionState.tryParse(wire), isNull, reason: wire);
        expect(
          () => SubmissionState.parse(wire),
          throwsFormatException,
          reason: wire,
        );
      }
    });

    test('only submitted is not final', () {
      expect(SubmissionState.submitted.isFinal, isFalse);
      expect(SubmissionState.confirmed.isFinal, isTrue);
      expect(SubmissionState.failed.isFinal, isTrue);
    });
  });

  group('SubmissionOutcomeCode', () {
    test('codes are the api.md PascalCase catalog values', () {
      expect(SubmissionOutcomeCode.transactionFailed, 'TransactionFailed');
      expect(SubmissionOutcomeCode.submissionRejected, 'SubmissionRejected');
      expect(SubmissionOutcomeCode.preparationExpired, 'PreparationExpired');
      expect(SubmissionOutcomeCode.jobMismatch, 'JobMismatch');
      expect(
        SubmissionOutcomeCode.jobEvidenceUnavailable,
        'JobEvidenceUnavailable',
      );
      expect(SubmissionOutcomeCode.escrowCallFailed, 'EscrowCallFailed');
    });

    test('all lists every code once', () {
      expect(SubmissionOutcomeCode.all, {
        'TransactionFailed',
        'SubmissionRejected',
        'PreparationExpired',
        'JobMismatch',
        'JobEvidenceUnavailable',
        'EscrowCallFailed',
      });
    });

    test('isKnown accepts only catalog codes', () {
      expect(SubmissionOutcomeCode.isKnown('JobMismatch'), isTrue);
      expect(SubmissionOutcomeCode.isKnown('jobMismatch'), isFalse);
      expect(SubmissionOutcomeCode.isKnown('ChainUnavailable'), isFalse);
    });
  });
}
