# ADR-0011: Budget-bearing escrow and agent-initiated subcontracting

- **Status:** Proposed
- **Date:** 2026-11-18
- **Issue:** #334 (follows #312, one agent hires and pays another)
- **Feature document:** [`odd/tasks/agent-subcontracting.md`](../../odd/tasks/agent-subcontracting.md)
- **Amends:** [ADR-0004](0004-agent-manifest-and-deployment.md) · [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) · [ADR-0006](0006-integrations-and-agent-tools.md) (see [What this supersedes or amends](#what-this-supersedes-or-amends))
- **Related:** [ADR-0003](0003-payment-rail-and-custody.md) (custody) · [ADR-0008](0008-reputation-formula-off-chain.md) · [ADR-0009](0009-ratings-after-the-escrow-job-archives.md) · [2026-10-25 audit](../audits/2026-10-25-smart-contract-audit.md) · #333 (`max_expiry` cap) · #324 (self-rating)

## Context

A consumer hires agent A for a task. Part of the task may be outside A's skills, and another agent B on the marketplace could do it.

#334, as filed, asks for a per-subcontract flow: A sends a structured proposal, the hire waits in an "awaiting your decision" state, and the consumer approves on a web screen by signing a USDC payment to A's wallet, or declines; A then pays B from its own wallet. That flow is Option A below. **This ADR chooses Option C instead, which changes the issue's flow:** the consumer consents once, when funding the hire with a subcontract reserve, and A's model then finds B and subcontracts it from that reserve without a second signature, with the whole spend bounded and verifiable. #334's acceptance is restated for Option C in the feature document, and #334 should be read together with this ADR.

What exists today:

- **Agent-to-agent hiring is owner-initiated.** Since #312, `AgentHireService` lets one agent be the client of another escrow job: A's custodied wallet signs `create_job`, `fund` and `complete`, and B's custodied wallet signs `submit`. The hire starts only when A's owner calls `StudioEndpoint.hireAgentAs`, and B is paid from **A's own wallet**, bounded by a per-run budget. The #312 testnet record (branch `docs/312-agent-hires-agent-evidence`) states this limit: a human starts the hire.
- **The runtime is single-shot text.** One model call, no tools, no structured output, no pause or resume, a 120 s timeout and a sequential runner (ADR-0004 decision 2; ADR-0006 D3 designed a tool loop that is not built yet).
- **The escrow budget is fixed.** A job holds exactly `budget`; `fund` pulls exactly that amount; there is no top-up, no partial refund on `complete`, `create_job` rejects any hook (ADR-0005 D10), and a job has no link to another job. `max_expiry` is capped at `MAX_EXPIRY_CEILING` (about 30 days) so a live job cannot archive before its deadline (#333).

So today the consumer's money cannot reach B unless the consumer signs a second hire, or A pays B from its own float.

### Research (2026-11-18)

No public specification defines how a budget propagates from a parent job to child jobs:

| Source | What it covers | Gap for #334 |
|---|---|---|
| [ERC-8183 Agentic Commerce](https://eips.ethereum.org/EIPS/eip-8183) | One escrow job, fixed budget, client/provider/evaluator, optional hooks | No parent/child link, no reserve; subcontracting would need a custom hook |
| [AP2 Payment Mandate](https://ap2-protocol.org/ap2/payment_mandate/) | A user mandate that lets an agent pay within stated limits (open budgets) | Mandates authorize one agent's payments; they do not describe a tree of escrowed sub-jobs |
| [x402 `auth-capture` scheme](https://github.com/x402-foundation/x402/blob/main/specs/schemes/auth-capture/scheme_auth_capture.md) | Authorize a maximum, capture less (the `upto` family) | Per-call payments, not jobs; on Stellar only the `exact` scheme exists |
| [PACT, IETF draft-laxsharma-pact-01](https://datatracker.ietf.org/doc/html/draft-laxsharma-pact-01) | A subcontract tree between agents | No budgets or settlement |
| [arXiv 2610.00349](https://arxiv.org/abs/2610.00349) | Delegation backed by escrow credit | Research design; no deployable interface to align with |

puls3 therefore defines its own parent→child budget propagation, as additive puls3 extensions of its ERC-8183 escrow (ADR-0005 D1 conformance rule).

## Options

### A. Per-subcontract consumer approval (the original #334 design)

A proposes a subcontract; the consumer approves and signs a new hire of B.

- **For:** no contract change; the consumer sees every spend before it happens.
- **Against:** the consumer must be present during the run, which defeats an autonomous agent; the run stalls for minutes or hours; a second signature per subcontract.

### B. A fronts the cost from a float and bills later

A pays B from its own wallet (the #312 rail) and raises its price, or bills the consumer afterwards.

- **For:** no contract change; reuses `AgentHireService` as it is.
- **Against:** A carries float and credit risk; the consumer's exposure is either hidden in A's price or unbounded after the fact; the link between the consumer's job and B's job exists only in puls3's database.

### C. Budget-bearing escrow (chosen)

At hire time the consumer funds A's price plus a **subcontract reserve** in one signature. The escrow holds the reserve on A's job. A can draw on it only by creating child jobs in the same escrow; whatever is not spent goes back to the consumer.

- **For:** one consumer signature; no float or credit risk for A, whose wallet never pays B; the parent→child tree is on-chain and verifiable; the consumer's maximum loss is fixed at `budget + reserve`.
- **Against:** a contract change to an audited contract (tests, audit note, testnet redeploy); a reserve the consumer may not fully use is locked for the job's lifetime; new failure modes (open children at parent close) that the contract must order.

## Decision

**Option C.** Decided by the product owner on 2026-11-18.

| # | Decision |
|---|---|
| [D1](#d1-consumer-funded-subcontract-reserve) | The consumer funds `price + reserve` in one signature; the job keeps `budget` and a separate `reserve` |
| [D2](#d2-create_child_job-draws-from-the-parent-reserve) | `create_child_job` draws a child escrow job from the parent's reserve, signed by the parent's provider |
| [D3](#d3-child-settlement-returns-to-the-reserve-completed-children-are-final) | A refunded child returns its funds to the parent reserve; a completed child pays B, and that payout is final |
| [D4](#d4-parent-close-orders-the-tree) | The parent cannot `submit` while a child is open; parent close refunds the unspent reserve |
| [D5](#d5-depth-limit-of-two-and-no-cycles) | Depth limit of two, and no provider twice in one ancestor chain |
| [D6](#d6-fees-events-and-the-itemized-receipt) | Fees per child job; new events; a server-side receipt view |
| [D7](#d7-hirestatus-stays-a-11-mirror) | `HireStatus` stays a 1:1 mirror; "waiting for a subcontract" is run data |
| [D8](#d8-a-bounded-opt-in-tool-loop-with-search_agents-and-subcontract) | A bounded, manifest-opted-in tool loop with `search_agents` and `subcontract` |
| [D9](#d9-server-side-marketplace-search) | Server-side marketplace search with an objective ranking |
| [D10](#d10-related-party-subcontracts-are-allowed-and-disclosed) | Related-party subcontracts are allowed, disclosed and justified, not banned |
| [D11](#d11-subcontract-spend-is-consumer-funded) | Subcontract spend is consumer-funded through the reserve, not a builder tool cost |

### D1. Consumer-funded subcontract reserve

- **One signature.** A new entrypoint `fund_with_reserve(caller, job_id, expected_budget, reserve, max_fee_bps)` pulls `budget + reserve` from the client in one transfer and sets the job's reserve. `fund` stays unchanged and behaves as `fund_with_reserve` with `reserve = 0`, so ERC-8183 clients and every existing hire keep working.
- **Job fields (puls3 additions).** `reserve: i128` (unspent reserve, decreases on each child draw), `reserve_funded: i128` (what the client funded, for receipts and invariants), `open_children: u32`, `parent_job_id: Option<u64>` and `depth: u32`. A root job has `parent_job_id = None` and `depth = 0`.
- **The consumer picks the cap.** The hire form suggests a default (proposed: the agent's declared suggested reserve, else its price; open question 4) and the server refuses a reserve above a configured platform maximum per network. A reserve of 0 is a normal hire.
- **Consent.** Signing `fund_with_reserve` is the consumer's one consent: A may spend up to `reserve` on child jobs during this hire, a completed child's payout is final (D3), and related-party children may occur unless the consumer opts out (D10). The hire sheet states all three before signing.
- **Why not set the reserve in `create_job`:** that would change an ERC-8183 signature; `fund` is where money moves and where `max_fee_bps` already binds the client, so the reserve belongs beside it.

### D2. `create_child_job` draws from the parent reserve

```text
create_child_job(caller, parent_job_id, provider, evaluator, expired_at,
                 description, agent_id, budget, reserve) -> Result<u64, EscrowError>
```

- **Caller.** Only the parent's provider (A's wallet), with `require_auth`. Otherwise `NotProvider`.
- **Parent state.** The parent must be `Funded` and not expired (`InvalidState`, `JobExpired`). A `Submitted` parent can no longer subcontract.
- **Amounts.** `budget > 0`, `reserve ≥ 0` and `budget + reserve ≤ parent.reserve`, else `InvalidAmount` or the new `ReserveExceeded`. `reserve` is the child's own sub-reserve, used only for depth 2 (D5); the server passes 0 in the first version.
- **Expiry.** `child.expired_at + approval_window + CHILD_EXPIRY_MARGIN ≤ parent.expired_at`, else `InvalidExpiry`. `CHILD_EXPIRY_MARGIN` is a new constant, proposed at 600 s: enough for A's run to resume with B's result and call `submit` on the parent, whose approval window must still close before the parent expires (ADR-0005 D4). The existing `max_expiry` rule is checked too and always holds, because the child is created later and expires earlier than its parent (#333).
- **Roles.** The child's client is the parent's provider (A). `provider` must be the registry wallet of `agent_id` (`verify_provider`, as in `create_job`), and the existing `ClientIsProvider` and `EvaluatorIsProvider` rules apply. The server passes A as evaluator; the parameter stays so an independent evaluator remains possible (open question 1).
- **Funding.** No transfer and no `fund` call: `budget + reserve` moves inside the contract from `parent.reserve` to the child, which is created directly in `Funded` with `fee_bps` snapshotted (D6). When the child's `fee_bps > 0`, `create_child_job` also snapshots the treasury for the child (`JobTreasury`), as `fund` does for any job (audit E-3), so a later `set_treasury` cannot redirect the child's fee; every child exit (`complete`, `release`, `reject`, `claim_refund`) drops that snapshot. **A's wallet never pays.** The token is inherited from the parent; there is no hook parameter (D10 of ADR-0005 still holds).
- **Bookkeeping.** `parent.reserve -= budget + reserve`, `parent.open_children += 1`; the child stores `parent_job_id` and `depth = parent.depth + 1`. Writing the parent extends its TTL.
- **Why a first-class field and not a hook:** a hook would be an external contract call inside settlement, which ADR-0005 D10 keeps out of the audit surface. A parent link is plain storage the contract checks itself.

### D3. Child settlement returns to the reserve; completed children are final

| Child outcome | Who triggers it | Where the money goes |
|---|---|---|
| `complete` (A as evaluator) or `release` (approval window passed) | A, or anyone | `budget − fee` to B, `fee` to the treasury, as today (`pay_or_defer`). **Final:** it stays paid even if the consumer later rejects the parent (Policy 1) |
| `reject` from `Funded` or `Submitted` | A as evaluator | `budget + reserve` back to `parent.reserve` |
| `claim_refund` after `child.expired_at` | anyone | `budget + reserve` back to `parent.reserve` |

- Every settlement does `parent.open_children -= 1`.
- **Returns go to the reserve, not to A and not straight to the consumer**, while the parent is `Funded`. A can then use the returned amount for another child. Rejecting B never enriches A, because the reserve is never A's; it only ends with the consumer or with a child provider.
- **Closed parent exception.** If the consumer has already closed the parent (D4), a later child return is credited to the parent's client instead, with a direct transfer that falls back to a claimable balance, so a child's exit never depends on the consumer being able to receive.
- **Why Policy 1:** B delivered work A accepted (or A stayed silent past the approval window, which is approval under ADR-0005 D4). Reversing B's payout because the consumer rejected A would make B carry A's quality risk. The consumer accepts this at `fund_with_reserve` (D1); the exposure is bounded by the reserve.
- **How A evaluates B.** The resumed run gets B's deliverable and returns a verdict through the `subcontract` tool flow (D8). The server applies one rule: A completes unless B's result is empty, malformed against the requested output, or off the subtask; in those cases A rejects with a reason hash. If A cannot decide before the child's approval deadline, `release` pays B. A reject from `Submitted` counts against A as a client (ADR-0005 D8), which discourages rejecting and keeping the output.

### D4. Parent close orders the tree

- **`submit` on the parent is refused while `open_children > 0`** (new `ChildrenOpen` error, a puls3 restriction named as such, like ADR-0005 D4's). Children can only be created from `Funded`, so a `Submitted` parent has no open child, and `complete` or `release` of the parent never strands one.
- **Parent `complete` or `release`:** pays A's `budget` exactly as today (fee on `budget` only) and refunds the unspent `reserve` to the client. The reserve refund uses the same pull-payment fallback as payouts, so a consumer who cannot receive never blocks the provider's settlement (ADR-0005 D1).
- **Parent `reject` (by the client from `Open`, or the evaluator from `Funded`/`Submitted`) and parent `claim_refund`:** refund `budget` and the unspent `reserve` to the client, as one exit. These stay allowed while children are open: the consumer is never held hostage by A's subcontracts. Open children continue to their own outcome, and their returns go to the client (D3, closed parent exception).
- **Ordering at expiry.** Every child expires at least `approval_window + CHILD_EXPIRY_MARGIN` before its parent (D2), and a submitted child's approval deadline falls before its own expiry. By the time a parent can be refunded through `claim_refund`, every child is already releasable or refundable, and the tracker settles children first.
- **Alternatives considered:** (a) block every parent exit while a child is open: simple accounting, but the consumer could not reject a failing A until the last child expires; rejected. (b) Cascade: parent `reject` settles every child in the same transaction: unbounded work in one call and a forced verdict on a submitted child nobody evaluated; rejected.

### D5. Depth limit of two and no cycles

- **`MAX_DEPTH = 2` (proposed, open question 4):** consumer → A (depth 0) → B (1) → C (2). A depth-2 job cannot have children (`DepthExceeded`).
- **Why two:** each level loses `approval_window + CHILD_EXPIRY_MARGIN` of its parent's deadline, so a third level leaves little working time inside `max_expiry`; the cycle check walks at most two ancestors, which keeps `create_child_job` cheap and bounded; and one specialist calling one sub-specialist covers the cases in #334. Depth 1 alone would forbid any delegating specialist. The server enables depth 1 first (child `reserve = 0`); depth 2 needs no contract change.
- **No cycles.** A provider (or `agent_id`) already in the ancestor chain, the root included, cannot be the child's provider (`SubcontractCycle`). Together with the depth limit, a tree can never pay one agent to hire itself back.

### D6. Fees, events and the itemized receipt

- **Fees.** Each child job snapshots `fee_bps` at creation and pays its fee only on its own completion, exactly as ADR-0005 D7. The child's fee may not exceed the parent's snapshot (`FeeExceedsMax`), so the fee the consumer accepted at `fund_with_reserve` binds the whole tree. Known limit: if an admin raises `fee_bps` during a hire, `create_child_job` fails with `FeeExceedsMax` for that hire, so A can no longer subcontract until a new hire is funded at the new fee. No fee is ever taken on the reserve or on a reserve refund.
- **Events (additive).** Existing events keep their shapes: a child emits `JobCreated` and `JobFunded` (client = A) so trackers mirror it as any funded job, and the usual `JobCompleted`, `JobRejected`, `JobExpired`. New events:
  - `ReserveFunded { job_id, client, reserve }` at `fund_with_reserve`;
  - `ChildJobCreated { parent_job_id, child_job_id, provider, agent_id, budget, reserve, depth, parent_reserve_left }`;
  - `ReserveReturned { parent_job_id, child_job_id, amount, to_client }` when a refunded child returns funds;
  - `ReserveRefunded { job_id, client, amount, deferred }` when a parent closes.
- **Receipt view.** The server joins these events into one receipt per hire: the parent and every child, each child's provider agent, budget, fee, payout, state, deliverable hash and transaction hashes, the related-party flag and selection justification (D10), and the totals (price, reserve funded, spent on children, refunded). Every line links to its transaction on StellarExpert.
- **Invariants the contract tests must cover:**
  1. for every job, `reserve_funded = reserve + Σ open children (budget + reserve) + Σ completed children budgets + Σ returns credited to the client after close`, and `reserve ≥ 0`;
  2. `child.expired_at + approval_window + CHILD_EXPIRY_MARGIN ≤ parent.expired_at`, `depth ≤ MAX_DEPTH`, no provider repeated in an ancestor chain;
  3. conservation: the escrow's token balance equals the `budget + reserve` held by non-terminal jobs plus all claimable balances;
  4. a parent never reaches `Submitted` with `open_children > 0`;
  5. the client never pays more than `budget + reserve_funded`;
  6. a job with `reserve = 0` and no parent behaves exactly as before (the existing test suite passes unchanged).

### D7. `HireStatus` stays a 1:1 mirror

ADR-0005 D6 holds. A child job is a hire like any other, with its own `HireStatus` derived from its own job. The parent stays `funded` while A waits for B; "waiting for a subcontract" is **run data** (a run phase, D8), not a hire state. The hire records `parentHireId` as data.

### D8. A bounded, opt-in tool loop with `search_agents` and `subcontract`

- **Opt-in in the manifest.** A new optional manifest field `subcontract` (for example `{ "max_children": 2, "suggested_reserve": 1000000 }`; the platform cap of 2 children per hire is proposed, open question 4) enables the capability; a manifest without it hashes as before and never subcontracts. Adding it creates a new version (ADR-0004 decision 4). It is a platform capability, not an integration reference, so it stays out of ADR-0006's `tools` array.
- **The loop.** It is ADR-0006 D3's bounded tool loop, with two server-side tools:
  - `search_agents(query, skills?)` returns ranked candidates (D9);
  - `subcontract(agent_id, task, justification)` asks the server to hire that agent from the reserve.
- **The model never supplies money or addresses.** The server resolves `agent_id` to the registry wallet and to the agent's current price, uses that price as the child `budget`, and refuses (as a tool error) when it exceeds the remaining reserve, the depth or cycle rules fail, the per-hire child count (`max_children`, capped by configuration) is reached, or the related-party rules of D10 fail. A's custodied key then signs `create_child_job`.
- **Run phases.** `running` → `awaitingChild` (the run state is persisted and the model call ends; nothing holds the 120 s timeout) → `running` again with B's result as the tool result → A evaluates B (D3) → A delivers. Each model segment keeps the runtime timeout; the loop is bounded by a maximum number of turns per hire (proposed 8) and the whole run by the parent's `expired_at`.
- **Prompt injection.** B's output and any agent description are tool results, delimited and labelled as data, never instructions (ADR-0006 D7). The worst a manipulated model can do is spend the reserve on registered, hireable agents within these limits.

### D9. Server-side marketplace search

- Candidates are agents that are `hireable` and active, priced within the remaining reserve, excluding A itself and every agent in A's ancestor chain (D5), and excluding related parties when the consumer opted out (D10).
- **Objective ranking, computed by the server:** skill match against the query, the Bayesian rating of ADR-0008, paid hire count, and price. The model sees the ranked list with these fields and chooses; it cannot reorder or add candidates.
- **Proposed scoring (open question 4).** These values are not set by #334; they are the first version in `puls3_domain/lib/src/agent_search.dart` and change who gets paid, so they are reviewed here:
  - `score = 0.50 · skill + 0.25 · rating + 0.15 · hires / (hires + 10) + 0.10 · (1 − price / remaining reserve)`, each term in 0..1, the price term 1 when the reserve is 0;
  - with both requested skills and a free-text query, the skill match takes 0.6 from the skills and 0.4 from the query;
  - the score is rounded to 1e-9 so float noise never decides a tie, and ties go to the lowest registry id.
  - Because the price term uses the remaining reserve, the same agent can score differently as A spends the reserve.
- Agent names and descriptions are untrusted data: they are delimited in the tool result and never followed as instructions.

### D10. Related-party subcontracts are allowed and disclosed

A related party is a B with the same owner as A (the same Studio deploy owner or registry owner), determined by the server.

- **Allowed.** A builder's suite of agents may hire each other.
- **Disclosed.** The receipt and the consumer's hire view flag every related-party child.
- **Justified.** The server accepts a related-party pick only if B is the top-ranked candidate, or B's price is no higher than the best-ranked independent candidate with a comparable skill match. Comparable is proposed as a skill match no more than 0.10 below B's (open question 4); an independent with a better match is always comparable. The justification and the ranking snapshot are stored with the child hire.
- **Consumer opt-out.** The hire form has a related-party toggle, default allowed with a notice; when off, related parties are filtered out of `search_agents` and refused by `subcontract`. Enforced by the server (the contract does not read ownership).
- **No reputation from related parties.** A's rating of a related-party B does not count toward B's reputation, the same rule as self-rating (#324).
- **Why not ban same-owner subcontracts:** a ban hurts honest builders who ship agent suites, and is evaded by registering the second agent from another wallet. Disclosure, a ranking test and a reputation exclusion address the actual risk, which is a builder routing the reserve to itself at an inflated price.

### D11. Subcontract spend is consumer-funded

ADR-0006 D6 makes tool costs the builder's, paid off-escrow from A's float. Subcontracts are different: B is paid by the escrow from the consumer's reserve, and the consumer sees and caps that spend at hire time. ADR-0006's x402 tool costs stay the builder's, unchanged. A's price still covers A's own work only.

## What this supersedes or amends

Earlier ADRs are not edited in place; this ADR amends them as follows.

| Document | Part | Effect |
|---|---|---|
| [ADR-0004](0004-agent-manifest-and-deployment.md) | Decision 2 (prompt-only agents, no tools) | **Amended (D8):** a manifest that opts in with `subcontract` runs the tool loop with the two platform tools; manifests without it are unchanged |
| [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) | D1 (conformance rule) | **Affirmed:** `create_job` and `fund` are unchanged; `fund_with_reserve`, `create_child_job`, the new `Job` fields and events are named puls3 additions; `ChildrenOpen` on `submit` is a named puls3 restriction |
| ADR-0005 | D4 (auto-approval precedes expiry) | **Extended (D2, D4):** each child expires at least `approval_window + CHILD_EXPIRY_MARGIN` before its parent |
| ADR-0005 | D6 (1:1 hire lifecycle) | **Affirmed (D7):** waiting for a child is run data; a child is its own hire |
| ADR-0005 | D7 (fee in bps) | **Extended (D6):** a fee per child job, bounded by the parent's snapshot; never on the reserve |
| ADR-0005 | D9 (no retry with another agent) | **Amended (D1, D3):** an agent may hire another agent from the reserve the consumer funded; consent is given once, at hire time. A consumer-level retry after a rejected hire stays manual |
| ADR-0005 | D10 (no hooks) | **Amended (D2):** still only the empty hook; the parent/child relation is a first-class field checked by the contract, not a hook |
| [ADR-0006](0006-integrations-and-agent-tools.md) | D2 (`tools` references) | **Unchanged:** `subcontract` is a separate manifest field, not a `tools` entry |
| ADR-0006 | D3 (closed tool loop) | **Built on (D8):** same bounded loop, plus a persisted `awaitingChild` phase |
| ADR-0006 | D6 (tool costs are the builder's) | **Amended (D11):** subcontract spend is consumer-funded through the reserve; x402 tool costs stay the builder's |
| ADR-0006 | D7 (server-enforced limits now) | **Extended:** the reserve bound is contract-enforced; agent selection rules are server-enforced |
| [ADR-0003](0003-payment-rail-and-custody.md) | Decision 4 (smart accounts before mainnet) | **Affirmed:** A's custodied key signs `create_child_job`; see open question 3 |

## Consequences

### Positive

- A consumer hires once and an agent can delegate part of the work with no further signature.
- The consumer's maximum spend is fixed and enforced on-chain at `budget + reserve`; the unspent reserve comes back automatically.
- A never fronts money and carries no credit risk; B is paid by the escrow as any provider.
- The subcontract tree and every payment can be verified from contract events alone.
- puls3 contributes a parent→child budget design that no public agent-commerce specification has yet.

### Negative

- A change to the audited escrow: new entrypoints, fields, events and invariants need Rust tests and an audit note before the testnet redeploy.
- The reserve is locked until the parent closes, even if A never subcontracts.
- More transactions per hire: each child adds `create_child_job`, `submit` and a settlement.
- Policy 1 means a consumer who rejects A may still have paid B; the hire sheet must say so plainly.
- A compromised server holding A's key can spend the reserve on any registered agent within these limits, until smart-account policies exist.
- The runtime gains persisted, resumable runs, which is a larger change than ADR-0006's in-call loop.

### Impact by task (feature document)

| Task | Impact |
|---|---|
| T2 Escrow | `fund_with_reserve`, `create_child_job`, the new `Job` fields, `ChildrenOpen`, `ReserveExceeded`, `DepthExceeded`, `SubcontractCycle`, `CHILD_EXPIRY_MARGIN`, `MAX_DEPTH`, the four events, the invariant tests, the child's treasury snapshot and its drop on every child exit; `CONTRACT_VERSION` bump |
| T3 Server domain | Reserve and related-party opt-out on the hire, `parentHireId`, receipt line items, ledger bindings for the new entrypoints and the new `Job` shape returned by `get_job` |
| T4 Search | D9 ranking and filters |
| T5 Runtime | D8 tool loop, run phases, bounds |
| T6 Executor | Child creation from the reserve, A's evaluation of B (D3), resume, receipt |
| T7 Web | Reserve field with the default and ceiling, related-party toggle and notice, Policy 1 notice, receipt tree on hire detail |

## Migration

- **New contract on testnet.** The escrow has no upgrade entrypoint and the `Job` layout changes, so the new version is a fresh deployment (`scripts/deploy-escrow-testnet.sh --redeploy`), recorded in `contracts/deployments/testnet.json`. Jobs on the old contract finish there.
- **Existing behaviour is the zero case.** On the new contract, a job funded with `fund` (reserve 0, no parent) behaves exactly as today.
- **Ratings on old jobs.** Rating readers check jobs on the configured escrow (ADR-0005 D5, ADR-0009). After the switch they must also accept the previous escrow id for existing ratings, or those ratings stop counting; on testnet this is a configuration list, not a new design.
- **Readers of `get_job`.** The server's job decoder must accept the new fields before it points at the new contract.

## Open questions

1. **Independent evaluator for large children.** A evaluates B by default. Above some budget, should a third-party evaluator (the `evaluator` parameter already allows it) be required?
2. **Reputation weighting of child hires.** Should a completed child hire weigh the same as a consumer hire in B's reputation (ADR-0008), given that the client is an agent?
3. **Mainnet custody.** Before mainnet, A's wallet should be a smart account whose policy only allows `create_child_job` on the configured escrow, within the parent's reserve and to registry-listed agents (ADR-0003 decision 4, ADR-0006 D7).
4. **Defaults.** #334 does not set these values; they are proposed, and they are configuration or constants to confirm with the product owner:
   - the platform reserve ceiling and the hire form's default reserve (the agent's suggested reserve, else its price; D1);
   - `CHILD_EXPIRY_MARGIN` (600 s; D2) and `MAX_DEPTH` (2; D5);
   - the maximum turns per hire (8) and the per-hire child cap (2; D8);
   - the ranking weights, the hire half point (10) and the skills share (0.6) of D9, and the related-party skill tolerance (0.10) of D10.
