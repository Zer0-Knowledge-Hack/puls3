# ADR-0005: Align agent commerce with ERC-8183 and ERC-8004 on Soroban

- **Status:** Accepted (2026-10-02). D3 (timeout values) is deferred; see [D3](#d3-timeout-values-deferred)
- **Date:** 2026-09-30 (proposed) · 2026-10-02 (accepted; decisions D1–D10 taken by the product owner on 2026-09-30, D1/D4/D6/D8 refined on 2026-10-02)
- **Issue:** #55 (escrow contract); no dedicated issue yet
- **Research:** [Spike: agent commerce standards](../spikes/agent-commerce-standards.md)
- **Amends:** [ADR-0002](0002-agent-registry-on-soroban.md) · [ADR-0003](0003-payment-rail-and-custody.md) (see [What this supersedes or amends](#what-this-supersedes-or-amends))
- **Related:** [ADR-0001](0001-system-architecture.md) · [hire lifecycle](../domain/hire-lifecycle.md) · #8 API contract (provisional)

## Context

On 2026-09-30 the product owner set a constraint: *"puls3 must not diverge from the standards; otherwise people who build on us will find it hard to migrate or adapt."*

The spike compared puls3 with the equivalent platforms on other chains: BNB Agent Studio (APEX), Virtuals ACP v2 on Base, the Circle Agent Stack on Arc, and the Solana Agent Registry. Every one that runs **jobs** implements or follows **ERC-8183 Agentic Commerce** (Draft): per-job USDC escrow, a client, provider and evaluator, states `Open → Funded → Submitted → Completed | Rejected | Expired`, one caller-set `expiredAt` per job, a permissionless non-hookable `claimRefund` after expiry, and fees only on completion. Identity and reputation use **ERC-8004**. Direct payment is used only for x402 pay-per-call ([spike §1–§5](../spikes/agent-commerce-standards.md#1-equivalents-of-puls3-per-ecosystem)).

puls3 diverges ([spike §6](../spikes/agent-commerce-standards.md#6-puls3-gap-analysis)):

- **G1** it pays the agent wallet directly, with no escrow (ADR-0003 decision 1);
- **G2** unsettled or failed payments are resolved by manual operator review (#8 open question P1; hire lifecycle open question 3);
- **G3** the Hire lifecycle has no job expiry; timeouts are spread over #8 P2, #20 and future disputes;
- **G4** there is no evaluator: `delivered → rated` mixes acceptance with reputation;
- **G5** puls3 runs its own ERC-8004-aligned registries that are not drop-in with **Stellar 8004**, which is live on mainnet;
- **G6** payment-backed feedback relies on a trusted server authorizer (ADR-0002).

On Stellar, no ERC-8183 implementation was found (2026-09-30); Stellar 8004 covers ERC-8004; Trustless Work offers a Soroban USDC escrow with its own role model.

## Options

### A. Keep direct payment and manual review (status quo)

ADR-0003 and #8 unchanged: SAC transfer to `M…(agent wallet, hire id)`, server-side six-check verification, manual review of unsettled funds, no refunds.

- **For:** already designed and partly proven (#68 live testnet payment); no new contract before the Serverpod deadline (2026-10-14).
- **Against:** diverges from every job platform on G1–G4. Builders from APEX or ACP must rewrite their job integration; consumers bear the risk of paid jobs that fail; refunds depend on operators. Directly contradicts the product owner's constraint.

### B. Own ERC-8183 escrow contract on Soroban (chosen)

A puls3-written Soroban contract that implements ERC-8183 with the same function names (in snake_case), argument order, roles, states and rules; USDC SAC only; typed errors; one event per transition. Evaluator: the client by default (as ERC-8183, ACP and the Arc tutorial), with an APEX-style optimistic approval window as the next version (D4). The server relay (#8, Decision A) prepares every call; the consumer signs authorization entries; the server tracker submits and calls `claim_refund` on expiry.

- **For:** matches the standard every peer uses (patterns 1–8); refunds become automatic and cannot be blocked; one `expired_at` replaces scattered timeouts; the escrow is a team-written Soroban contract, which the Stellar evaluations reward (ADR-0002 alternative 1 rationale); likely the **first ERC-8183 reference on Stellar** (inference: none found); gives reputation an on-chain job record to verify (G6).
- **Against:** a new contract that holds user funds: needs tests, a threat model, and an audit before mainnet; more transactions per hire (create, fund, submit, complete); changes the domain, #8 and ADR-0003; ERC-8183 is still a Draft and may change.

### C. Build on an existing Soroban escrow (Trustless Work)

Use the Trustless Work contracts (V1 mainnet, V2 beta on testnet) behind a puls3 adapter.

- **For:** existing, deployed escrow with dispute roles; less contract code of our own.
- **Against:** its interface is its own role model, not ERC-8183 (inference from no ERC-8183 implementation found), so builders still meet a non-standard job interface and puls3 still diverges; dependency on a third party's admin and upgrade policy (the same concern ADR-0002 raised for Stellar 8004); V2 is beta. Could be revisited if Trustless Work ships ERC-8183.

**Rejected outright:** Circle Refund Protocol (unaudited; its repository warns of an arbiter-drain issue).

## Decision

**Option B.** puls3 adopts ERC-8183 for hires and ERC-8004 for identity and reputation, on Soroban. The product owner took decisions D1–D10 on 2026-09-30, one at a time, and refined D1, D4, D6 and D8 on 2026-10-02; D3 is deferred.

| # | Decision | Status |
|---|---|---|
| [D1](#d1-own-erc-8183-escrow-on-soroban) | Own ERC-8183 escrow contract on Soroban (#55) | Decided |
| [D2](#d2-sequencing) | Contract by Stellar Elite, escrow in the Serverpod demo, the rest by HackMeridian | Decided |
| [D3](#d3-timeout-values-deferred) | Timeout values | **Deferred** |
| [D4](#d4-evaluator-the-client-with-an-optimistic-approval-window) | Evaluator = the client, with an optimistic approval window | Decided |
| [D5](#d5-own-registries-drop-in-compatible-with-stellar-8004) | Own registries, drop-in compatible with Stellar 8004 | Decided |
| [D6](#d6-hire-lifecycle-aligned-with-erc-8183) | Hire lifecycle mirrors ERC-8183 1:1 (`open`, `funded`, `submitted`, `completed`, `rejected`, `expired`) | Decided (state names 2026-10-02) |
| [D7](#d7-platform-fee-in-basis-points-set-to-zero) | Platform fee in basis points, set to 0 for the MVP | Decided |
| [D8](#d8-no-disputes-in-the-mvp) | No disputes in the MVP; the client's `reject` is final; only rejects from `submitted` count against the client | Decided (scaling path open) |
| [D9](#d9-no-retry-with-another-agent-in-the-mvp) | No retry with another agent in the MVP | Decided |
| [D10](#d10-no-hooks-in-the-mvp) | No hooks in the MVP; `hook` parameter reserved | Decided |

### D1. Own ERC-8183 escrow on Soroban

A hire is an ERC-8183 job in a puls3 escrow contract (#55). The consumer is the client, the agent wallet is the provider, and the escrow holds the USDC until `complete`, `reject`, or `claim_refund`.

- **Conformance rule.** Where ERC-8183 defines a function, state, event field or rule, puls3 uses it unchanged except for Soroban conventions (snake_case, explicit `caller: Address` with `require_auth`, typed errors). puls3 additions are additive and named as such, as in ADR-0002.
- **Expiry structure.** One `expired_at` per job, set by the server when it prepares `create_job`. `fund` fails after it; `claim_refund` is permissionless, non-pausable and non-hookable. The values are D3.
- **Refunds.** Automatic: the server tracker calls `claim_refund` after expiry. Manual review remains only for funds sent outside the escrow.
- **Interface.** Fixed in #55 (or a follow-up ADR) before implementation, as ADR-0002 did for the registries.
- **Rationale:** option B is the only option that matches the standard every peer uses; Trustless Work keeps a non-standard interface and a third-party admin.
- **Consequences:** a contract of ours holds user funds; mainnet needs tests, a threat model, an audit and an upgrade policy first.

- **Runtime-failure refund.** With the client as evaluator (D4), the server cannot call `reject`; only the evaluator can (ERC-8183). When the agent runtime fails after `fund`:
  1. **Primary — client `reject`:** the server detects the failure and the app offers a one-step "reject and refund" to the client, who signs `reject` as evaluator. Immediate, but needs the client present.
  2. **Fallback — expiry + `claim_refund`:** if the client never acts, the server tracker calls the permissionless `claim_refund` once `expired_at` passes. Needs no special permissions; takes as long as the job expiry (D3).
- **Refund bound.** A refund only ever returns the amount the client funded into that job; no path pays out more than was deposited.

### D2. Sequencing

- The escrow contract is on **testnet for Stellar Elite (2026-10-10)**.
- The escrow is on the **main hire path in the Serverpod demo (2026-10-14)**. ADR-0003's direct rail is not kept as a demo exception.
- The **remaining pieces land by HackMeridian (2026-10-25)**, including the optimistic approval window (D4) and the drop-in Reputation Registry (#14, D5).
- **Consequences:** the contract is built and audited for scope against a 10-day window; D7, D8 and D10 keep its surface small for that reason.

### D3. Timeout values (deferred)

**Not decided.** The structure is decided (one `expired_at` per job, D1); the values are not. What remains to decide:

- the job `expired_at` (delivery SLA);
- the unpaid-hire window (#8 P2);
- the agent runtime timeout (#20), which must end before `expired_at`;
- the length of the optimistic approval window (D4).

Whatever the values, they must satisfy D4's invariant: runtime timeout + approval window < `expired_at`.

Peers publish examples only (1 h, 65 min, SLA-bound), not defaults ([spike §3](../spikes/agent-commerce-standards.md#3-how-the-peers-parameterize-erc-8183)).

### D4. Evaluator: the client, with an optimistic approval window

- The evaluator is the **client (consumer) by default**; the client can `complete` or `reject`.
- **Silence past an approval window is implicit approval** (BNB APEX optimistic model), so funds do not stay locked when a consumer never returns.
- **Client-only evaluation ships for Stellar Elite; the auto-approval window lands by HackMeridian.** The window length is part of D3.
- No puls3-operated evaluator: the escrow stays trustless. Third-party evaluators remain possible through the `evaluator` address.
- **Invariant: auto-approval precedes expiry.** ERC-8183 allows `claim_refund` from `Submitted` once `expired_at` passes. If the approval window could end after `expired_at`, a client could stay silent on a `submitted` job, let it expire and reclaim the funds while keeping the output, with no on-chain `reject` recorded. The escrow (#55) must therefore guarantee that a submitted job is auto-approved (`complete`) before it can expire: silence on a `submitted` job pays the provider. With this invariant, `claim_refund` only refunds jobs the provider never submitted. The D3 values must satisfy it (runtime timeout + approval window < `expired_at`).
- **Known risk: reject after delivery.** A client can still `reject` a `submitted` job and keep the output. D8 mitigates it: every `reject` is on-chain with its reason hash, and rejects from `submitted` feed client-side reputation, so agents can decline clients with high reject rates. Withholding the full deliverable until `complete` (preview or hash first) is a stronger mitigation, out of MVP scope.
- **Rationale:** matches the ERC-8183, ACP and Arc default evaluator and APEX's optimistic policy.
- **Consequences:** the app needs an approve/reject step and, later, an approval countdown. Until the auto-approval window ships (HackMeridian), the Stellar Elite contract must still enforce the invariant, for example by rejecting `claim_refund` on `Submitted` jobs or by setting `expired_at` far enough out.

### D5. Own registries, drop-in compatible with Stellar 8004

- puls3 keeps **its own Identity and Reputation registry deployments**, with an interface **identical (drop-in) to [Stellar 8004](https://github.com/trionlabs/stellar-8004)**.
- The **"only paid hires can rate" rule leaves the Reputation Registry.** It is proven by a completed ERC-8183 escrow job (the standard ERC-8183 ↔ ERC-8004 link): readers filter feedback by clients with completed jobs.
- **Rationale:** the product owner first chose Trion Labs' deployments on the premise that Stellar 8004 was official. Verification showed it is a Trion Labs community project (MIT), not listed in developers.stellar.org, with admin and upgrades controlled by Trion and no audit mentioned. Drop-in compatibility gives ERC-8004 tools a standard interface while puls3 keeps control. Upstream contributions remain possible (public repository with `CONTRIBUTING.md`).
- **Consequences:** #14 is redesigned before implementation; #13 (closed) is reviewed for drop-in gaps: typed `Result` errors versus Stellar 8004's panics, the `UriAlreadyRegistered`/`agent_id_by_uri` additions, and the `give_feedback`/`NewFeedback` changes.

### D6. Hire lifecycle aligned with ERC-8183

**Guiding principle: the Hire lifecycle mirrors the ERC-8183 escrow job 1:1.** Every hire state is an escrow state with the same name. Off-chain facts (runtime progress, feedback, the state a hire was rejected from) are separate data on the hire, not lifecycle states.

The Hire state machine (#10, merged) changes as follows (state names decided by the product owner on 2026-10-02):

| Hire state | ERC-8183 | Replaces (#10) | Notes |
|---|---|---|---|
| `open` | `Open` | `requested` | Job created; not funded yet |
| `funded` | `Funded` | `paid`, `inProgress` | Funds held by the escrow. The hire stays `funded` while the agent works |
| `submitted` | `Submitted` | `delivered` | Awaiting evaluation (D4) |
| `completed` (terminal) | `Completed` | — (new) | Evaluator accepted, or the approval window passed; escrow pays the agent |
| `rejected` (terminal) | `Rejected` | `cancelled`, `failed` (in part) | Refunded. Reached from `open` (client cancels before paying), `funded` or `submitted` |
| `expired` (terminal) | `Expired` | `failed` (in part) | Refunded through `claim_refund` |

- **Removed states:**
  - `inProgress` leaves the lifecycle; the hire stays `funded` while the agent works. **Runtime progress** (`queued`, `running`, `failed`) is separate runtime data, used by F6 polling and the server tracker.
  - `failed` is removed; a failed run ends in `rejected` or `expired` (D1, runtime-failure refund).
  - `cancelled` is removed: a pre-payment cancel is ERC-8183 `Open → Rejected` by the client, so the state is `rejected`. The hire records the **state it was rejected from**, and the UI labels a reject from `open` as **"Cancelled"**.
  - `rated` leaves the lifecycle: a rating is separate ERC-8004 feedback, and the hire keeps it as data (for example, a feedback reference).
- **Rationale:** the domain, the #8 contract and the escrow share one vocabulary; every hire state has an on-chain equivalent, so the server can derive a hire's state from the job.
- **Edges of the `open` window** (2026-10-02):
  - **No job, no state.** A hire has a status only once `create_job` is confirmed; before that it is a pending preparation, and cancelling it means abandoning the preparation (no on-chain `reject`).
  - **Unfunded expiry is derived.** An `open` job past `expired_at` is reported as `expired` with no transaction: `fund` reverts after expiry and `claim_refund` applies only to `Funded`/`Submitted`, so the job stays `Open` on chain with no funds held. This is the one derived exception to the 1:1 mirror; the escrow (#55) exposes an `is_expired(job_id)` view so indexers reach the same result.
- **Consequences:** the #10 follow-up renames `requested`, `paid` and `delivered`, removes `inProgress`, `cancelled`, `failed` and `rated`, and adds the rejected-from state, runtime progress and feedback reference as hire data. The MVP flows ([flows](../blueprints/flows.md), #22/#61) need UI copy updates (status labels, "Cancelled" for a reject from `open`, rating after `completed`).

### D7. Platform fee in basis points, set to zero

- The escrow (#55) includes a **platform fee in basis points** (1 bps = 0.01%; fee = amount × bps ÷ 10,000, rounded down, on 7-decimal USDC units) and a **platform fee recipient**.
- The fee is charged **only on `complete`**, never on `reject` or expiry refunds.
- **MVP and testnet value: 0 bps.** Enabling a fee later is a configuration change, not a new contract.
- **Rationale:** keeps the business model open without a redeploy or migration (APEX pattern). Peer fee percentages were not found in the sources and are not cited.

### D8. No disputes in the MVP

- There is **no dispute mechanism** in the MVP. The client-evaluator's **`reject` is final**.
- Every `reject` is recorded on-chain with its ERC-8183 `reason` hash and should feed **client-side reputation**, not only agent reputation.
- **Client-side reputation counts only rejects from `submitted`** (work delivered). It is derived from the job's on-chain history (the state the job was in when `reject` was called); the contract needs no extra field. Rejects from `open` (a cancel before paying) and from `funded` (for example, after a runtime failure) do not count against the client.
- **Accepted risk:** a bad-faith client can reject good work until disputes exist.
- **Rationale:** matches the ACP and Arc defaults and the vision's "disputes out of the MVP".
- **Open (future decision):** the scaling path, either the operator as arbiter of last resort or an APEX-style voter quorum.

### D9. No retry with another agent in the MVP

- No automatic or suggested retry. A rejected or expired job refunds the client through the escrow, and the client picks another agent manually.
- **Rationale:** simplest, and the client keeps control of whom they pay; Butler-style automatic retry needs consent, price caps and selection rules.
- **Consequences:** none for the contract or the frontend flows (#28). A suggested retry can come later without contract changes, because it is a new job.

### D10. No hooks in the MVP

- The escrow keeps the **`hook` parameter in `create_job`** for ERC-8183 interface compatibility but **only accepts an empty hook** in the MVP.
- Side effects (for example, writing ERC-8004 validation on `complete`) run in the puls3 server.
- When hooks are added later, **`claim_refund` stays non-hookable** by design.
- **Rationale:** limits the audit surface of the 10-day Stellar Elite contract while staying drop-in with ERC-8183.

## What this supersedes or amends

ADR-0002 and ADR-0003 are not edited in place; this ADR amends them as follows, and each gets a follow-up amendment.

| Document | Part | Effect |
|---|---|---|
| [ADR-0003](0003-payment-rail-and-custody.md) | Decision 1 (direct SAC transfer, "no escrow in the MVP") | **Superseded:** the consumer funds an escrow job (D1, D2) |
| ADR-0003 | Decision 2 (hire id as muxed id) | **Amended:** the job id identifies the hire in contract calls and events; a muxed id may still tag the escrow's payout to the agent wallet (spike B6, unverified) |
| ADR-0003 | Decision 3 (six verification checks) | **Superseded:** the server reads job state and events; asset and amount are enforced by the contract |
| ADR-0003 | Decision 6 (signer table) | **Amended:** consumer signs `create_job`/`fund` and, as evaluator, `complete`/`reject`; the server (agent's custodied key) signs `submit`; anyone can submit `claim_refund` |
| ADR-0003 | Consequences, #55 row; alternative 3 | **Superseded:** escrow is in scope |
| ADR-0003 | Decisions 4 and 5 (custody, server chain access) | Unchanged |
| [ADR-0002](0002-agent-registry-on-soroban.md) | Own registries vs Stellar 8004 | **Amended (D5):** own deployments stay, with an interface identical to Stellar 8004 |
| ADR-0002 | Reputation `authorize_feedback` by a trusted authorizer; payment-backed `give_feedback` | **Superseded (D5):** the paid-hire rule leaves the registry; it is proven by a completed escrow job and applied by readers |
| [ADR-0001](0001-system-architecture.md) | Alternative 3 (escrow on-chain rejected for the MVP) | **Revisited:** escrow moves on-chain |
| [Vision](../vision.md) §6 Out, item 5 | "Refunds, disputes, and escrow" | **Amended:** escrow and automatic refunds move in; disputes stay out (D8) |
| [Hire lifecycle](../domain/hire-lifecycle.md) | States, `rated`, open questions 1–3 | **Amended (D6):** states renamed to mirror ERC-8183 (`open`, `funded`, `submitted`, `completed`, `rejected`, `expired`); `inProgress`, `cancelled`, `failed` and `rated` removed from the lifecycle |
| #8 API contract | Decision A (relay) and B (polling) | Unchanged; the relay also carries escrow calls |
| #8 API contract | Hire payment states, payment verification mapping, P1 (manual review), P2 (abandonment window) | **Amended:** payment is `fund`; verification reads the job; P1 shrinks to funds outside the escrow; P2 becomes the job's `expired_at` (value deferred, D3) |

## Consequences

### Follow-up work

| Work | Issue | Decision |
|---|---|---|
| Change the Hire domain lifecycle: rename states, remove `inProgress`, `cancelled`, `failed`, `rated`; add rejected-from state, runtime progress and feedback reference as data; update tests | Follow-up to #10 | D6, D8 |
| Update MVP flows UI copy to the new states (status labels, "Cancelled" for a reject from `open`) | Follow-up to #22/#61 | D6 |
| Redesign the Reputation Registry as a Stellar 8004 drop-in, without the paid-hire gate | #14 | D5 |
| Review the Identity Registry for drop-in gaps | #13 (closed) | D5 |
| Fix the escrow contract in ERC-8183 shape (interface, fee in bps, empty hook only) | #55 | D1, D4, D7, D8, D10 |
| Amend ADR-0002 (registries) and ADR-0003 (rail, verification, signers) | New | D1, D5 |
| Adjust the #8 API contract to the escrow flow | #8 | D1, D4, D6 |

### Impact by issue

| Issue | Impact |
|---|---|
| **#55** Escrow contract | Becomes the ERC-8183 contract; interface fixed before implementation; on testnet by 2026-10-10 |
| **#10** Hire lifecycle (merged) | Follow-up renames `requested`/`paid`/`delivered` to `open`/`funded`/`submitted`, adds `completed` and `expired`, makes `rejected` cover pre-payment cancels, and removes `inProgress`, `cancelled`, `failed` and `rated` (D6) |
| **#8** API contract | Hire states follow D6; runtime progress (`queued`/`running`/`failed`) is a separate field for F6 polling; payment, verification, refund states, evaluator actions and outcome codes change; relay and polling decisions stay |
| **#22/#61** MVP flows | UI copy follows D6: status labels from the new states, "Cancelled" for a reject from `open`, rating offered after `completed`, runtime progress shown while `funded` |
| **#19** Hire and pay endpoint | Prepares `create_job` and `fund`; verifies by job state; drives refunds |
| **#20** Agent runtime | Calls `submit` on delivery; runtime timeout must end before `expired_at` (value deferred, D3); auto-approval window by HackMeridian (D4) |
| **#14, #21, #11** Reputation | Drop-in with Stellar 8004; readers filter feedback by clients with completed escrow jobs; rejects from `submitted`, with their reason hashes, feed client-side reputation (D8) |
| **#13, #15, #17** Identity, deploy, catalog | Drop-in review against Stellar 8004 (D5); escrow contract deployed and indexed |
| **#25, #28, #69** Wallet and hire UI | Auth-entry signing for escrow calls; evaluator approve/reject step, later an approval countdown; refund status; no retry flow (D9) |
| **#30** Configuration | Escrow contract id, fee bps and fee recipient per network; timeout values (D3) |

- Builders who know ERC-8183 and ERC-8004 find the same roles, states and rules on puls3.
- A contract of ours holds user funds; mainnet requires a security review and an upgrade policy first.
- Each hire needs more chain transactions (about four instead of one); the relay can pay their fees (spike B3, unverified until #69).
- A bad-faith client can reject good work while disputes are out (D8).
- The timeline against Stellar Elite (2026-10-10) and the Serverpod demo (2026-10-14) is tight; D7, D8 and D10 reduce the contract's scope to fit it.

## Open decisions

- **D3 timeout values (deferred):** job `expired_at`, unpaid-hire window, runtime timeout, optimistic approval window.
- **D8 scaling path (future):** operator as arbiter of last resort or APEX-style voter quorum.
The original option analysis for each decision is kept in [spike §9](../spikes/agent-commerce-standards.md#9-open-decisions-for-the-product-owner).
