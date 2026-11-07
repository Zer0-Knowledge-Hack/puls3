# Issue #201 · R-2a: tie each on-chain rating to a paid hire (feedback provenance)

- **Issue:** [#201](https://github.com/Zer0-Knowledge-Hack/puls3/issues/201)
- **Source:** security audit of 2026-10-25, finding R-2a (Medium), P2,
  `area: domain`, `area: contracts`, labelled `after hackmeridian`
- **Status:** investigated (documents 01–10), then implemented on branch
  `feat/201-feedback-provenance` (document 11). No contract or ABI change.
  Not deployed and not merged
- **Decision (2026-11-07):** ratings without a verifiable paid job no longer
  count, including the ones written before this change
- **Code inspected:** `main` at `dd2a83d`

## The question in one paragraph

The rule "only the consumer of a completed, paid hire can rate it, once" lives
only in the server (`FeedbackService`). The Reputation Registry accepts
`give_feedback` from any address, about any registered agent, at any time, and
the app's own call sends an empty `feedback_uri` and a zero `feedback_hash`, so
nothing on chain links a score to a hire. The escrow contract, on the other
hand, already holds a public, on-chain proof of a paid and completed job
(`get_job(job_id)` → `client`, `agent_id`, `state == Completed`). The fix is to
make every app rating carry the escrow job reference, and to let any reader
check that reference against the escrow instead of trusting the server.

## Documents

| Document | Contents |
|---|---|
| [01-issue-analysis.md](01-issue-analysis.md) | What #201 asks, its acceptance criteria and its links to ADR-0005, #200, #202, #211 |
| [02-current-architecture.md](02-current-architecture.md) | Contracts, server, domain and app pieces involved, and the source of truth for "paid and completed" |
| [03-feedback-flow.md](03-feedback-flow.md) | Hire → fund → submit → complete → rate, step by step, and where the hire reference is lost |
| [04-contract-analysis.md](04-contract-analysis.md) | Reputation Registry and escrow: what is stored, emitted, checked |
| [05-domain-and-backend-analysis.md](05-domain-and-backend-analysis.md) | Domain rules, `FeedbackService`, call builder and the reputation reader |
| [06-security-analysis.md](06-security-analysis.md) | Abuse scenarios, each marked demonstrated or hypothetical, with evidence |
| [07-stellar-8004-compatibility.md](07-stellar-8004-compatibility.md) | ABI, the fields that can carry the reference, and what ADR-0002 must record |
| [08-test-coverage.md](08-test-coverage.md) | Existing tests, commands run, missing tests |
| [09-technical-proposal.md](09-technical-proposal.md) | Alternatives and the recommended design (not implemented) |
| [10-final-report.md](10-final-report.md) | Requirement matrix, answers to the 11 questions, next steps |
| [11-implementation.md](11-implementation.md) | What was implemented, tests, verification status, expected behavior change |

## Main findings

1. **Confirmed in code** (not executed on testnet): a rating written straight
   to the registry counts in the rating puls3 serves. The reader has no paid-hire filter
   (`puls3_domain/lib/src/feedback_record.dart:70`, ADR-0005 D5 implementation
   note) and the registry has no hire field.
2. **Confirmed in code:** the app's own `give_feedback` carries no hire reference
   (`puls3_server/lib/src/feedback/reputation_calls.dart:79-89`: empty URI,
   zero hash).
3. **Structural:** `feedback_uri` and `feedback_hash` are **only emitted** in
   the `NewFeedback` event, never stored. Public RPC keeps about 7 days of
   events, so a reference that lives only there is not durably readable through
   the same reads the rating uses (`read_feedback`).
4. **The proof of payment already exists on chain:** an escrow job in
   `Completed` has been funded with the full budget and paid out
   (`contracts/contracts/escrow/src/lib.rs:849` `settle`). A rating can be
   verified by any reader against `get_job` without trusting the server.
5. **Recommended:** keep the ABI. Put a canonical job reference in a stored
   field (`tag2`) and in `feedback_uri`, commit it in `feedback_hash`, and add a
   public domain rule that counts a record only if the escrow says the job is
   `Completed` for that client and agent, at most once per job.
