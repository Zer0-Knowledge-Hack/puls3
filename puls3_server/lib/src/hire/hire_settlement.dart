import 'package:puls3_domain/puls3_domain.dart' show HireStatus;

import '../chain/submission_values.dart';

/// How a funded hire settled, from its confirmed escrow submissions.
///
/// Terminal purposes win, in this order: `complete` or `release` →
/// [HireStatus.completed], `reject` → [HireStatus.rejected], `claim_refund`
/// → [HireStatus.expired]. A confirmed `submit` with none of those is
/// [HireStatus.submitted]. Otherwise null: the hire stays `funded`.
///
/// The status is derived on read, so it needs no column. A confirmed record
/// never changes, so concurrent trackers and repeated reads agree. The
/// contract makes overlapping terminals impossible; `complete`/`release`
/// still win if both exist, as they did for `release` vs `claim_refund`.
HireStatus? fundedHireSettlement(Iterable<SubmissionPurpose> confirmed) {
  final purposes = confirmed.toSet();
  if (purposes.contains(SubmissionPurpose.complete) ||
      purposes.contains(SubmissionPurpose.release)) {
    return HireStatus.completed;
  }
  if (purposes.contains(SubmissionPurpose.reject)) {
    return HireStatus.rejected;
  }
  if (purposes.contains(SubmissionPurpose.claimRefund)) {
    return HireStatus.expired;
  }
  if (purposes.contains(SubmissionPurpose.submit)) {
    return HireStatus.submitted;
  }
  return null;
}

/// Purposes that move a funded hire off `funded` once confirmed.
const settlementPurposes = {
  SubmissionPurpose.submit,
  SubmissionPurpose.complete,
  SubmissionPurpose.reject,
  SubmissionPurpose.release,
  SubmissionPurpose.claimRefund,
};
