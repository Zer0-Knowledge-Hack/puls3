# 06 · Security analysis

"Confirmed in code" means the path is visible in the code and needs no
assumption; it was **not** executed on testnet for this analysis. "Hypothetical"
means it depends on a condition that the code does not show today.

Severity is relative to the reputation feature (the audit rates R-2a Medium).

## Scenarios today

| # | Scenario | Possible today? | Component that allows it | Evidence | Impact | Severity | Validation needed |
|---|---|---|---|---|---|---|---|
| S1 | Feedback with no hire at all | **Yes, confirmed in code** | Reputation Registry accepts any caller; the reader counts any 1..5 whole value | `reputation-registry/src/lib.rs:199-266` (no hire check); `feedback_record.dart:70-80` (four exclusions only) | Any funded account moves an agent's served rating | Medium (the R-2a finding) | Reader rule: count only records whose job is `Completed` on the canonical escrow for this client and agent |
| S2 | Feedback without payment | **Yes** (same path as S1) | Same | Same | Same | Medium | Same rule: `Completed` implies funded and settled |
| S3 | Feedback before completion | **Yes** via direct call; **No** via the app (`HireNotCompleted`) | Contract has no state check | `feedback_service.dart:147-149` vs contract | Rating for an undelivered or later refunded job | Medium | Same rule, evaluated against the job state |
| S4 | Many ratings for one hire | **Yes** via direct call (each call gets a new index); **No** via the app (`HireAlreadyRated`) | Contract has no uniqueness | `:238-239` index increment; `_isRated` only sees server submissions | One paid job weighs N times | Medium | At most one counted record per job id (reader) |
| S5 | Hire reference forged in `feedback_uri` | Not applicable today (the field is empty); **would be possible** with any URI-only design | A string is not a proof | `reputation_calls.dart:87` | A URL can point at anything | — today; High if a URI were trusted | Never trust the URI; resolve the job id against `get_job` and check client, agent, state |
| S6 | `feedback_hash` that does not match the data | Not applicable today (zero hash) | The contract never checks the hash | `:208-209` passed through to the event only | A hash alone proves nothing about payment | — | Hash = commitment to a canonical document that includes the job reference; verifiers recompute it. Payment is proven by the escrow, not by the hash |
| S7 | Reference to another client's job | Would be possible if only the job id were checked | — | — | Rater borrows a real paid job | High if unchecked | Check `job.client == record.client` (the record's key is the authenticated caller) |
| S8 | Reference to a job of another agent | Same | — | — | Borrow a paid job of agent B to rate agent A | High if unchecked | Check `job.agent_id == record.agent_id` |
| S9 | Reference to a fake escrow contract | Would be possible if the escrow address came from the record | — | — | Attacker deploys a contract whose `get_job` returns `Completed` | High if unchecked | Pin the canonical escrow id(s) in the verifier configuration; never read it from the record |
| S10 | Reuse of the same job (payment evidence) across records | Possible via direct call (same client, same job, several indexes) | — | S4 | Same as S4 | Medium | One counted record per `(escrow, job_id)`: the first live one by index |
| S11 | Agent owner rates through a second wallet that paid a real job | **Yes**, even after the fix | Escrow forbids only `client == provider`; registry forbids only owner / operators | `escrow/src/lib.rs:429`, `reputation-registry/src/lib.rs:230` | Owner pays the budget to its own agent wallet (fee 0, ADR-0005 D7) and rates 5. Cost: network fees only | Medium, residual | Out of scope of provenance (provenance proves a paid job, not an independent buyer). Related: #200 (rating through the payout wallet). Mitigations: non-zero fee, minimum budget, reader weighting |
| S12 | Rating of a cancelled or refunded job | Possible via direct call | — | — | — | Medium | `Rejected` / `Expired` are not `Completed`; the rule excludes them. `Completed` is terminal, so no later refund is possible (`settle`, `:849`) |
| S13 | Impersonation of the client | **No** | `caller.require_auth()` in `give_feedback` and `create_job` | `:211`, `escrow :413` | — | — | Keep it. The record's client is the authenticated caller |
| S14 | Backend changes the data it relays | Limited | The consumer signs the exact call; the server cannot sign | `feedback_service.dart:23` ("the server never signs") | A server could prepare a call with a wrong job id; the consumer would sign it unless the wallet shows the arguments | Low | The reader rule rejects a mismatching job (client/agent/state checks), so a wrong reference only makes the rating not count |
| S15 | Server state differs from chain state | Yes, liveness only | `release` by a third party is not seen by the server | `hire_settlement.dart:16-30` | A completed job looks `submitted`; the consumer cannot rate in the app | Low | Out of scope; reconciling with `get_job` would fix it |
| S16 | Reader cannot load the job (archived after ~60 days TTL) | Hypothetical, likely over time | Persistent entry TTL | `escrow/src/lib.rs:16-24` | A valid rating cannot be verified until restored | Low | Treat "job unreadable" as its own exclusion (like `unreadable`), keep `extend_ttl(job_id)` on completed jobs, or restore when verifying |
| S17 | Reference only in an event that the RPC no longer serves | Structural, if the design uses only `feedback_uri`/`feedback_hash` | Events are not stored in contract state; RPC keeps ~7 days | [04](04-contract-analysis.md) | The rating becomes unverifiable with `read_feedback` reads | Medium for the design | Put the job reference in a stored field (`tag2`), or run an event indexer and accept that verification depends on it |
| S18 | Legacy ratings without a reference | Yes | All current records | `reputation_calls.dart:79-89` | If the new rule excludes them, served ratings change (agent 7's one rating would stop counting) | Product decision | Decide: exclude (strict), or count as "unverified" for a transition period and show it |

## Conclusions

- R-2a is real and confirmed in code: S1–S4 work today through a direct
  contract call, and the served rating counts the result.
- A reference in `feedback_uri` is not proof. Proof is the escrow job state,
  checked with the record's own authenticated client and agent, on a pinned
  escrow contract (S5, S7, S8, S9).
- `feedback_hash` adds integrity of an off-chain document, not proof of
  payment (S6).
- Uniqueness can be enforced by readers without contract changes (S4, S10).
- S11 (self-dealing through a paid job) stays possible after any provenance
  fix, because the job is real. It should be tracked with #200, not hidden.
