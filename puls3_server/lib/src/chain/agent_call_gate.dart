import 'package:puls3_domain/puls3_domain.dart';

import '../ledger/envelope_codec.dart';
import 'chain_submission_store.dart';
import 'submission_values.dart';

/// Whether [signer] has an agent-signed call ([agentSignedPurposes]) still
/// `submitted`, so a new envelope for it would reuse its account sequence
/// and be `txBadSeq`.
///
/// Calls are serialized per signing wallet, not globally: one stuck call of
/// agent A must not stall every other agent's `submit` or child verdict
/// (#334, T6.4.2). Each of the three agent-signed senders, `AgentSubmitSender`,
/// `EscrowChildResultSource` and `EscrowSubcontractPort`, asks this before it
/// reads a sequence.
///
/// Why the signer is read from the stored envelope instead of a column
/// (decided 2026-11-23, recorded in `odd/tasks/agent-subcontracting.md`):
/// `chain_submission` does not record who signed, and adding a `source`
/// column would need a migration of a persisted format, plus a rule for the
/// existing rows that have no value. Every agent-signed envelope already
/// carries its source account, and the set this reads (submitted rows of
/// four purposes) is small by design, because each wallet keeps at most one
/// in flight. Decoding a few envelopes per pass is cheaper than the
/// migration and needs no backfill. Revisit with a column if that set grows
/// or the pass gets hot.
///
/// Fails closed: a record without an envelope, or one [codec] cannot read,
/// counts as in flight for every signer, which is the old global gate. The
/// tracker settles it when it confirms, fails or expires.
///
/// This is a check, not a lock: two passes that check at the same instant
/// can both build. The store's unique transaction hash and the sequence
/// check on the chain stay the backstop, as before.
Future<bool> agentCallInFlight({
  required ChainSubmissionStore submissions,
  required EnvelopeCodec codec,
  required StellarAddress signer,
}) async {
  for (final envelope in await submissions.submittedEnvelopes(
    agentSignedPurposes,
  )) {
    final source = envelope == null ? null : codec.sourceOf(envelope);
    if (source == null || source == signer) return true;
  }
  return false;
}
