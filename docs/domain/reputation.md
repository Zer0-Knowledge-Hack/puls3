# Reputation

- **Issue:** #11 · **Package:** [`puls3_domain/`](../../puls3_domain/) (pure Dart)

Reputation is how consumers choose between agents in the catalog. It is computed
from the **feedback** left on paid hires. A naive average is easy to game — one
5-star review would outrank an agent with 100 reviews averaging 4.8, and an owner
could rate their own agent — so puls3 uses the rules below.

This document is the source of truth for the formula and its parameters.
`puls3_domain/lib/src/reputation.dart` is the executable form, and
`puls3_domain/test/reputation_test.dart` reproduces the worked examples exactly.

## Rules

1. **Only the consumer of a `completed` hire leaves feedback.** The consumer is
   the one who hired, funded and evaluates the job (ADR-0005 D5, D6; invariant
   `I20`). The hire must be `completed`.
2. **One feedback per hire.** A hire is rated at most once (`HireAlreadyRated`).
3. **An owner cannot rate its own agent.** A feedback whose client is the agent's
   owner is rejected (`FeedbackFromAgentOwner`).
4. **A score is an integer from 1 to 5** and the comment is at most 500
   characters (`I16`, `I17`).
5. **The catalog ranks agents by a Bayesian average**, not by the raw mean.

## Formula

An agent's reputation `R` is the Bayesian average of its `n` scores, drawn
toward a prior mean `m` by a prior weight `C`:

```
        C · m + Σ sᵢ
R  =  ────────────────         rounded to two decimals
           C + n
```

| Parameter | Value | Meaning |
|---|---|---|
| `m` (`reputationPriorMean`) | `4.0` | The score a new agent starts at. |
| `C` (`reputationPriorWeight`) | `5` | How many ratings the prior is worth. |

### Why these parameters

- **`m = 4.0` — optimistic but unproven.** A brand-new agent starts "good, not
  perfect". It sits below an established agent and above a poorly rated one, so
  it is discoverable without being ranked first.
- **`C = 5` — a small, bounded prior.** Five ratings is enough that one or two
  reviews cannot jump an agent to the top, yet small enough that a genuine track
  record overtakes the prior quickly. With `n = 0` the agent shows `4.00`; each
  new rating moves it toward its observed mean.

The prior only affects *ranking with few reviews*. As `n` grows, `R` approaches
the plain mean, so the formula never hides a long, consistent record.

## Worked examples

`m = 4.0`, `C = 5`.

| Case | Scores | `n` | `Σ sᵢ` | `R` (raw) | `R` (2 dp) |
|---|---|---|---|---|---|
| **New agent**, no reviews | — | 0 | 0 | 4.0000 | **4.00** |
| **Few reviews**, one 5-star | `[5]` | 1 | 5 | 4.1666… | **4.17** |
| **Many reviews**, 100 reviews averaging 4.80 | 80×`5` + 20×`4` | 100 | 480 | 4.7619… | **4.76** |

**Anti-gaming check.** A plain mean would rank the one 5-star agent (`5.00`)
above the established agent (`4.80`). The Bayesian average ranks the new agent
at **4.17**, well below the established **4.76** — a single review cannot buy the
top spot, while the established agent is barely moved from its real mean.

## On-chain vs. off-chain

Consistent with ADR-0002 (#6) and ADR-0005 D5. [ADR-0008](../adr/0008-reputation-formula-off-chain.md)
(#203) records why the formula is not computed on chain:

- **On-chain — the Reputation Registry (#14, ERC-8004 drop-in).** Stores the
  individual, verifiable **feedback records**: the agent id, the client, the
  score and comment, and the reference to the hire/job it is about. The
  "only paid hires can rate" rule is **not** a registry field; it is proven by a
  `completed` ERC-8183 escrow job (the ERC-8183 ↔ ERC-8004 link).
- **Off-chain — the backend / catalog (#21).** Reads the on-chain feedback and
  computes `R` with this formula to rank agents. The aggregate is a **read
  model**: cached for the catalog, recomputable at any time, and never
  authoritative for the raw reviews.

## Implementation

- `reputationOf(Iterable<Feedback>)` — the Bayesian average above, rounded to
  two decimals; empty input returns `reputationPriorMean`.
- `reputationPriorMean`, `reputationPriorWeight` — the parameters `m` and `C`.
- `isSelfRating(Feedback, {required StellarAddress owner})` and
  `rejectSelfRating(...)` — rule 3.

## Verifying Agent Reputation

Anyone can recompute the rating puls3 shows for an agent from the chain and
compare it with what the server serves (#202, audit finding R-2b).

### How the rating is computed

The server reads every feedback record of the agent from the Reputation
Registry (#14) with simulated contract calls, keeps the records that count
(below) and serves `reputationOf()` over them: the Bayesian average of the
[Formula](#formula), `m = 4.0`, `C = 5`, rounded to two decimals. The served
`paidHireCount` is the number of records that count. The server keeps a rating
for 60 s (`reputationCacheTtl`) before reading the registry again.

### Why the formula stays off chain

The registry stores raw feedback; ranking is a product decision (ADR-0005 D5,
[On-chain vs. off-chain](#on-chain-vs-off-chain)). Keeping the formula in
`puls3_domain` lets it change without a contract migration, and the same Dart
code runs on the server and in the verification script, so a verifier never
re-implements it.

### How every on-chain feedback is taken into account

The registry accepts feedback from any address and in any scale. A record does
not count only for one of these reasons, and no other rule exists
(`exclusionOf` and `exclusionsOf` in `puls3_domain/lib/src/feedback_record.dart`):

| Reason (`FeedbackExclusion`) | When |
|---|---|
| `unreadable` | The registry lists the record but `read_feedback` cannot load it |
| `revoked` | Its submitter revoked it (`is_revoked`) |
| `notWholeScore` | `value_decimals` is not 0 |
| `outOfScale` | The value is outside 1 to 5 |
| `fromAgentOwner` | The record's client is the agent's owner on the identity registry (`owner_of`). An agent the registry does not have has no owner; an owner that cannot be read (archived entry included) fails the whole read, never opens the rule |
| `noJobReference` | `tag2` is not a paid-job reference `puls3:job:v1:<escrow>:<job id>` (#201) |
| `otherEscrow` | The reference names an escrow other than the configured one |
| `jobUnreadable` | The escrow's `get_job` has no such job, or its entry is archived. It excludes only that record; a node failure fails the whole read |
| `jobMismatch` | The job's `client` is not the record's client, or its `agent_id` is not the rated agent |
| `jobNotCompleted` | The job is not `Completed` (not paid and settled, or refunded) |
| `jobAlreadyRated` | An earlier record already counts for the same job |

`fromAgentOwner` applies on chain the rule the server already enforces when it builds `give_feedback`. It does not see a second wallet of the owner: that case is Sybil resistance (#200). The last six tie each rating to a paid hire (#201). `Completed` is reachable
only through `Funded` and `Submitted` and is terminal, so it proves that the
client paid the full budget and the provider was paid. The escrow address
comes from the reader's configuration, never from the record. A rating written
straight to the contract, without such a job, is valid ERC-8004 data but does
not count in puls3's rating; this includes every rating written before #201.

- `SorobanReputationRegistry.recordsOf()` reads **every** record: all pages of
  `get_clients_paginated` until the empty page, then `get_last_index` and
  `read_feedback` for every index of every client.
- It then reads the escrow's `get_job` once for each job those records name
  (only for records that pass the score rules).
- `feedbacksOf()` is exactly `countedFeedback(records, provenance)`; the server
  adds no filter of its own. Equal scores from one client for two paid jobs are
  separate records (`(client, index)` is the registry key) and both count; two
  records for the same job count once, the first one.
- A read that fails at any point throws: the server never computes a rating
  from part of the records. It serves the last complete value it read, or
  reports the catalog as unavailable when it never read one.

`puls3_domain/test/feedback_record_test.dart` and
`puls3_server/test/unit/ledger/soroban_reputation_registry_test.dart` check each
of these: no record dropped without a public reason, every page read, no
duplicate removed, an empty agent, a failure in the middle of a read, and each
paid-job rule (#201).

### Run the script

From the repository root (a pub workspace, so the script needs no pubspec of its
own). It reads the registry with simulations (no key, no signature) and calls
the public catalog `agent.list`:

```bash
dart run scripts/verify_reputation.dart 7                                  # deployed server
dart run scripts/verify_reputation.dart 7 --api http://localhost:8080      # local server
```

`7` is the agent's `registryId` (its id in the Identity Registry, shown in the
catalog). Exit code: `0` match, `1` mismatch, `2` a read failed or bad arguments.

### Read the result

```
registry : CBJZYEJ5DS7TDLA2ECRAW3ICQIYAOMTCQ5QSY7PYJ5PJ2W5EAHPBP5Q4
agent    : 7
pages    : 2 page(s) of get_clients_paginated (50 clients per page)
records  : 1 listed, 1 counted
  GABK…HF5H #1  value=5 decimals=0 revoked=false  counts

recomputed: rating 4.17, 1 counted feedback
served    : rating 4.17, paidHireCount 1 (https://puls3-hub-on-stellar.api.serverpod.space)
MATCH: the served rating is the formula over every counted on-chain record.
```

- **pages**: how many client pages were read, the empty page that ends the
  list included.
- **records**: every record with `counts` or `excluded: <reason>`. Since #201
  each line also shows `job=<id>(<state>)`, or `job=-` when `tag2` holds no
  reference. The sample above was taken before #201; that record has no
  reference, so the script now reports it as `excluded: noJobReference`.
- **recomputed vs served**: the rating and count from the chain next to the
  server's. `MATCH` means the served rating is `reputationOf()` over every
  counted record. `MISMATCH` means they differ.

### Limitations

- **Current state only.** The script reads the registry as it is now; Soroban
  has no read at a past ledger, so a past rating cannot be recomputed. A
  revoked feedback simply stops counting.
- **The 60 s cache.** Right after a new or revoked feedback, the served value
  can be up to a minute old: run the script again after a minute before reading
  a `MISMATCH` as a fault.
- **Archived state.** If registry entries expire (TTL), reads need a restore;
  the script and the server then fail rather than show a partial rating.
- **Same reader code.** The script reuses the server's Soroban reader and the
  domain rule; to verify without puls3 code, call the same three registry
  functions and the escrow's `get_job` with `stellar contract invoke
  --send=no` and apply the rules above and the [Formula](#formula) by hand.

Step-by-step evidence: [`docs/verification/reputation.md`](../verification/reputation.md).

## Out of scope

- The Reputation Registry contract (#14).
- The feedback endpoint (#21) and catalog.
- UI for ratings.
