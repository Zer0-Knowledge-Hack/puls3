import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/hire_settlement.dart';
import 'package:test/test.dart';

void main() {
  test('no confirmed settlement leaves the hire funded', () {
    expect(fundedHireSettlement(const []), isNull);
    expect(fundedHireSettlement([SubmissionPurpose.fund]), isNull);
  });

  test('a confirmed submit is submitted', () {
    expect(
      fundedHireSettlement([SubmissionPurpose.submit]),
      HireStatus.submitted,
    );
  });

  test('complete and release complete the hire', () {
    expect(
      fundedHireSettlement([SubmissionPurpose.complete]),
      HireStatus.completed,
    );
    expect(
      fundedHireSettlement([SubmissionPurpose.release]),
      HireStatus.completed,
    );
    expect(
      fundedHireSettlement([
        SubmissionPurpose.submit,
        SubmissionPurpose.complete,
      ]),
      HireStatus.completed,
    );
  });

  test('a confirmed reject rejects, from funded or submitted', () {
    expect(
      fundedHireSettlement([SubmissionPurpose.reject]),
      HireStatus.rejected,
    );
    expect(
      fundedHireSettlement([
        SubmissionPurpose.submit,
        SubmissionPurpose.reject,
      ]),
      HireStatus.rejected,
    );
  });

  test('a confirmed claim_refund expires the hire', () {
    expect(
      fundedHireSettlement([SubmissionPurpose.claimRefund]),
      HireStatus.expired,
    );
  });

  test('complete and release win over reject and refund', () {
    expect(
      fundedHireSettlement([
        SubmissionPurpose.reject,
        SubmissionPurpose.release,
      ]),
      HireStatus.completed,
    );
    expect(
      fundedHireSettlement([
        SubmissionPurpose.claimRefund,
        SubmissionPurpose.complete,
      ]),
      HireStatus.completed,
    );
  });
}
