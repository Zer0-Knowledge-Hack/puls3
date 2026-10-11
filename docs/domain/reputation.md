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

Consistent with ADR-0002 (#6) and ADR-0005 D5:

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

## Out of scope

- The Reputation Registry contract (#14).
- The feedback endpoint (#21) and catalog.
- UI for ratings.
