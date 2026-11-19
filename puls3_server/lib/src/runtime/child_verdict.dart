import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../chain/submission_values.dart';

/// The most characters (runes) of a child's output the parent agent accepts.
/// A child run already keeps its own manifest's `outputMaxChars`; this bounds
/// what one tool result adds to the parent's transcript. T6.4 may tune it.
const defaultChildOutputMaxChars = 16000;

/// The reason codes of a child verdict and of a failed child (ADR-0011 D3).
/// The verdict's 32-byte `reason` is [childReasonHash] of its code, so
/// anyone can check a `JobCompleted` or `JobRejected` against this list.
abstract final class ChildVerdictCode {
  /// The parent completes the child: B is paid.
  static const complete = 'child_complete';

  /// B's run failed, so it has no output; rejected from `Funded`.
  static const runFailed = 'child_run_failed';

  /// B's output is empty or blank; rejected from `Submitted`.
  static const outputEmpty = 'child_output_empty';

  /// B's output is over the parent's limit; rejected from `Submitted`.
  static const outputTooLong = 'child_output_too_long';

  /// B's run succeeded but its `submit` can never land (a terminal
  /// simulation rejection or the attempts used up); rejected from `Funded`.
  static const notSubmitted = 'child_not_submitted';

  /// No verdict: the child's `create_child_job` never landed. Only reported
  /// to the parent's loop.
  static const notOpened = 'child_not_opened';

  /// No verdict: the child was refunded by `claim_refund` after its expiry.
  /// Only reported to the parent's loop.
  static const expired = 'child_expired';
}

/// SHA-256 of the UTF-8 [code]: the escrow `reason` of a child verdict.
Uint8List childReasonHash(String code) =>
    Uint8List.fromList(sha256.convert(utf8.encode(code)).bytes);

/// The parent agent's verdict on one child job: `complete` or `reject`
/// with a [code] from [ChildVerdictCode].
final class ChildVerdict {
  const ChildVerdict._(this.complete, this.code);

  /// Completes the child with [ChildVerdictCode.complete].
  const ChildVerdict.complete() : this._(true, ChildVerdictCode.complete);

  /// Rejects the child with [code].
  const ChildVerdict.reject(String code) : this._(false, code);

  final bool complete;
  final String code;

  /// The escrow `reason` argument.
  Uint8List get reasonHash => childReasonHash(code);

  /// The submission purpose that carries this verdict.
  SubmissionPurpose get purpose => complete
      ? SubmissionPurpose.childComplete
      : SubmissionPurpose.childReject;
}

/// The server rule of ADR-0011 D3 for a child's stored [output]: reject a
/// missing output (the run failed), an empty or blank one, or one over
/// [maxOutputChars] runes; complete anything else.
ChildVerdict judgeChildOutput(String? output, {required int maxOutputChars}) {
  if (output == null) {
    return const ChildVerdict.reject(ChildVerdictCode.runFailed);
  }
  if (output.trim().isEmpty) {
    return const ChildVerdict.reject(ChildVerdictCode.outputEmpty);
  }
  if (output.runes.length > maxOutputChars) {
    return const ChildVerdict.reject(ChildVerdictCode.outputTooLong);
  }
  return const ChildVerdict.complete();
}
