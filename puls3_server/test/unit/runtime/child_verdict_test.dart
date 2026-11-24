import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/runtime/child_verdict.dart';
import 'package:test/test.dart';

void main() {
  group('judgeChildOutput', () {
    test('completes a non-blank output', () {
      final verdict = judgeChildOutput('Findings: three.');

      expect(verdict.complete, isTrue);
      expect(verdict.code, ChildVerdictCode.complete);
      expect(verdict.purpose, SubmissionPurpose.childComplete);
    });

    test('rejects a missing output as a failed run', () {
      final verdict = judgeChildOutput(null);

      expect(verdict.complete, isFalse);
      expect(verdict.code, ChildVerdictCode.runFailed);
      expect(verdict.purpose, SubmissionPurpose.childReject);
    });

    test('rejects an empty or blank output', () {
      for (final output in ['', '  \n\t ']) {
        final verdict = judgeChildOutput(output);
        expect(verdict.code, ChildVerdictCode.outputEmpty, reason: output);
        expect(verdict.complete, isFalse);
      }
    });

    test('never rejects an output for its length', () {
      // B's own run already fails an output over its manifest's
      // `outputMaxChars`, which no manifest may set above 16000, so a stored
      // output of any length was valid work and is paid.
      for (final output in ['x' * 16000, 'x' * 40000, '\u{1F600}' * 16000]) {
        final verdict = judgeChildOutput(output);
        expect(verdict.code, ChildVerdictCode.complete);
        expect(verdict.complete, isTrue);
      }
    });
  });

  test('the reason codes are the documented wire values', () {
    expect(ChildVerdictCode.complete, 'child_complete');
    expect(ChildVerdictCode.runFailed, 'child_run_failed');
    expect(ChildVerdictCode.outputEmpty, 'child_output_empty');
    expect(ChildVerdictCode.notSubmitted, 'child_not_submitted');
    expect(ChildVerdictCode.notOpened, 'child_not_opened');
    expect(ChildVerdictCode.expired, 'child_expired');
  });

  test('the reason hash is sha256 of the reason code', () {
    for (final code in [
      ChildVerdictCode.complete,
      ChildVerdictCode.runFailed,
      ChildVerdictCode.outputEmpty,
      ChildVerdictCode.notSubmitted,
    ]) {
      expect(
        childReasonHash(code),
        sha256.convert(utf8.encode(code)).bytes,
        reason: code,
      );
    }
    expect(
      judgeChildOutput('ok').reasonHash,
      childReasonHash(ChildVerdictCode.complete),
    );
  });

  test('a reject verdict from a run that never submitted', () {
    final verdict = ChildVerdict.reject(ChildVerdictCode.notSubmitted);

    expect(verdict.complete, isFalse);
    expect(verdict.purpose, SubmissionPurpose.childReject);
    expect(verdict.reasonHash, childReasonHash('child_not_submitted'));
  });
}
