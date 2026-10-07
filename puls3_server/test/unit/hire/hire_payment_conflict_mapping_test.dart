import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:test/test.dart';

void main() {
  group('hirePaymentIndexOf', () {
    test('maps a unique violation of each hire_payment index', () {
      expect(
        hirePaymentIndexOf(code: '23505', constraintName: 'hire_id'),
        HirePaymentIndex.hireId,
      );
      expect(
        hirePaymentIndexOf(code: '23505', constraintName: 'transaction_hash'),
        HirePaymentIndex.transactionHash,
      );
      expect(
        hirePaymentIndexOf(code: '23505', constraintName: 'job_id'),
        HirePaymentIndex.jobId,
      );
    });

    test('does not map a unique violation of an unknown constraint', () {
      expect(
        hirePaymentIndexOf(code: '23505', constraintName: 'hire_payment_pkey'),
        isNull,
      );
      expect(hirePaymentIndexOf(code: '23505', constraintName: null), isNull);
    });

    test('does not map another SQLSTATE even on a known constraint name', () {
      expect(
        hirePaymentIndexOf(code: '23503', constraintName: 'hire_id'),
        isNull,
      );
      expect(hirePaymentIndexOf(code: null, constraintName: 'job_id'), isNull);
    });
  });
}
