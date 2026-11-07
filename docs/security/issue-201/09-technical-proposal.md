# 09 · Technical proposal (not implemented)

## 1. Current architecture

The escrow proves paid and completed jobs on chain. The Reputation Registry
stores ratings with no hire link. The server applies the hire rules on the app
path, and the reader counts every well-formed record (see [02](02-current-architecture.md)).

## 2. Problem

The link rating → hire exists only in the server database, and the reader has
no rule that uses it, so a rating written straight to the contract counts
(S1–S4 in [06](06-security-analysis.md)).

## 3. Current flow

See [03](03-feedback-flow.md): the hire's `jobId` is known when the server
prepares `give_feedback`, but the call sends empty strings and a zero hash.

## 4. Alternatives

| | Write side | Read side | ABI | Durable verification | Backend trust | Effort |
|---|---|---|---|---|---|---|
| **A. URI + hash only** | `feedback_uri` = job reference, `feedback_hash` = commitment | Reader must index `NewFeedback` events | Unchanged | **No** with public RPC (~7 days); needs an event indexer or archive access | Low, but the indexer becomes a dependency | Medium |
| **B. Stored reference + reader rule (recommended)** | `tag2` = canonical job reference; `feedback_uri` = same reference (or a document containing it); `feedback_hash` = SHA-256 of the canonical document | Domain rule in `exclusionOf`/`countedFeedback`: resolve the job on the pinned escrow, check client, agent, `Completed`, first per job | Unchanged; convention only | **Yes**: `read_feedback` + `get_job` are permanent state reads (restorable when archived) | None: anyone can rerun it with `verify_reputation.dart` | Medium |
| C. Contract gate | `give_feedback` checks the escrow job and stores "rated" per job | Unchanged | Breaks drop-in (new arg) or deviates (parsing) | Yes, on write | None | High, plus an upgrade and a migration; reverses ADR-0005 D5 |
| D. Separate attestation contract | The escrow (on settle) or the client writes an attestation `job → rating` in a puls3 contract | Reader joins registry + attestation | Registry unchanged; a new contract | Yes | None | High |
| E. Server-signed attestation | The server signs `(job, rating)` | Readers trust the server key | Unchanged | Yes | **Full trust in the backend**: does not meet #201 | Low |

## 5. Recommended design: alternative B

### Data written on chain (by the consumer's signed `give_feedback`)

| Argument | Value |
|---|---|
| `value`, `value_decimals` | score 1..5, `0` (unchanged) |
| `tag1` | `""` (unchanged; kept free for a category) |
| `tag2` | canonical reference, e.g. `puls3:job:v1:<escrow C…>:<job_id>` (exact grammar fixed in the implementation; versioned so it can evolve) |
| `endpoint` | `""` (unchanged) |
| `feedback_uri` | the same reference, or a URI of a feedback document that contains it. A document host does not exist today ("puls3 has no off-chain host for the comment", `reputation_calls.dart:53-55`), so the reference itself is the simplest value |
| `feedback_hash` | SHA-256 over a canonical encoding of `{version, network passphrase, escrow, job_id, agent_id, client, value}` (and the comment when a document host exists) |

What stays off chain: the comment (until a host exists), the server's hire id
and database rows. They are not needed for verification.

### Payment verification mechanism

`get_job(job_id)` on the **pinned** escrow contract (configuration, never from
the record) must return:

- `state == Completed` (implies funded with the full budget and settled);
- `client == record.client` (the record's key is the authenticated caller);
- `agent_id == record.agent_id`.

That is the chain `Calificación → Contratación → Trabajo finalizado → Pago
confirmado`, evaluated with public reads only.

### Domain validations (`puls3_domain`)

- Parse the reference strictly (prefix, version, escrow id, `u64` job id);
  malformed → excluded.
- New public exclusion reasons, e.g. `noJobReference`, `jobNotCompleted`,
  `jobMismatch` (client/agent/escrow), `jobUnreadable`, `jobAlreadyRated`.
- One counted record per `(escrow, job_id)`: the lowest live index of that
  client. Decide whether a revoked record frees the job (recommended: yes,
  so a client can correct a rating by revoke + rate, still one counted).
- Keep the app-path rules (`checkHireRateable`, `checkFeedbackAllowed`)
  unchanged, so A2 holds.
- `FeedbackRecord` gains the stored `tag2`; the domain needs a port to read a
  job (`EscrowJobReader`) so the rule stays pure and testable.

### Contract validations

None required for B. Optional, compatible hardening (separate decision):
a maximum length for `tag2`/`feedback_uri` to bound storage cost (a behavioral
deviation, to record in ADR-0002 if done).

### Backend changes

- `ReputationCalls.giveFeedback` takes the job reference (or the hire with
  its `jobId`) and fills `tag2`, `feedback_uri`, `feedback_hash`.
- `FeedbackService.prepare` refuses a hire without `jobId` (it cannot be
  `completed` anyway).
- `SorobanReputationRegistry` decodes `tag2` and reads jobs from the escrow
  (batched simulations, with a cache keyed by job id, since `Completed` is
  terminal).
- `scripts/verify_reputation.dart` gains the escrow id and reports the new
  exclusions.

### Frontend changes

None for the write side: the server builds the call. #211 (rating screen)
inherits the reference. The app may show "verified paid hire" on a rating
later; not required by #201.

## 6. Stellar 8004 compatibility

No ABI change. The deviation is a puls3 reading convention, to be recorded in
ADR-0002 (see [07](07-stellar-8004-compatibility.md)).

## 7. Tests needed

See [08](08-test-coverage.md), "Missing tests" 1–16.

## 8. Implementation risks

| Risk | Mitigation |
|---|---|
| Existing ratings have no reference and would stop counting (agent 7 today) | Product decision before merging: strict exclusion, or a dated transition where unreferenced records count as "unverified" and are shown as such. Or re-rate testnet hires |
| Read cost: one `get_job` per counted record | Cache by job id (terminal state), batch simulations; the 60 s rating cache already exists |
| Escrow upgrade or redeploy changes the escrow id | The pinned escrow set must be a list with history, versioned like the reference |
| Job entries archive after ~60 days | `jobUnreadable` exclusion plus `extend_ttl(job_id)` on completed rated jobs, or restore during verification |
| Hash canonicalization mismatches between server and verifier | One encoder in `puls3_domain`, golden test vectors |
| Self-dealing through a real paid job (S11) | Not solved by provenance. Track with #200; consider a non-zero fee or minimum budget |
| Divergence server status vs chain (`release` by a third party, S15) | Out of scope; reading `get_job` when preparing would also fix it |
| Wallet UX shows a long `tag2` string | Short, versioned format |
