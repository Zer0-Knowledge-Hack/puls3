# Feature: an agent subcontracts another agent from a consumer-funded budget (#334)

- **Branch:** `feat/334-agent-subcontracting` (from `origin/main` `64a6793`)
- **Locator:** `odd/tasks/agent-subcontracting.md` · Engram `odd/agent-subcontracting/tasks`
- **Delivery strategy:** `ask-on-risk`. Chain strategy: **`stacked-to-main`** (user, 2026-11-18,
  for traceability). Each PR targets `main` and lands in order. A later slice branches from the
  previous slice until that one merges, then rebases on `main`.
- **Slices (one PR each):**
  1. T1 ADR-0011 (`feat/334-agent-subcontracting`)
  2. T2 escrow contract
  3. T3 server domain and ledger bindings
  4. T4 marketplace search
  5. T5 runtime tool loop
  6. T6 subcontract executor
  7. T7 web
  8. T8 evidence

  If a slice cannot fit ~400 lines after one honest split, it goes with a `size:exception`
  rationale.

## Objective

A consumer hires agent A with a task. When part of the task is beyond A, A's model searches the
marketplace (skill, reputation, price), picks the best agent B and subcontracts it, without any
further consumer signature. B is paid **from a subcontract reserve the consumer funded at hire
time, held by the escrow**, never from A's wallet. A delivers the combined result. Unspent reserve
returns to the consumer, and the contract emits an itemized, on-chain receipt.

## Decisions (user, 2026-11-18)

- **Path 1, the budget-bearing escrow.** Change the escrow contract instead of having A front money
  from a float. Reason: one consumer signature, no float or credit risk for A, and a subcontract tree
  that can be checked on-chain. No public ERC-8183, AP2 or x402 design covers parent→child budget
  propagation (research 2026-11-18), so this is puls3's contribution.
- **Payment of a completed child is final** (Policy 1). If the consumer later rejects the parent, B
  keeps its pay, because B delivered. The consumer agrees to this at hire time.
- **Related-party subcontracts are allowed, not banned.** A builder's agent suite may hire its own
  agents. Instead of a ban:
  - the related-party link is disclosed in the receipt and the consumer's view;
  - the server ranks the candidates objectively, and the pick is justified against that ranking or a
    price no higher than an independent alternative;
  - the consumer can opt out at hire time (default: allowed, with notice);
  - A's rating of a related-party B does not count toward reputation.

  Cycles and depth beyond the limit are refused. Reason: an owner ban hurts honest builders and is
  trivially evaded with a second wallet.

## Constraints

- ADR-0005 D6: `HireStatus` mirrors the escrow job 1:1, so "waiting for a subcontract" is run data,
  not a hire state. The ADR must amend ADR-0005 D9 (consent for re-hiring) and D10 (no hooks), and
  ADR-0006 D6 (agent spend is the builder's).
- The escrow is audited (2026-10-25). Contract changes need tests, an audit note and a testnet
  redeploy. Today the escrow: has a fixed `budget`, has no top-up, rejects hooks, and caps
  `max_expiry` (#333).
- The runtime does one text-only model call today: no tools, no structured output, no
  pause/resume, 120 s timeout, sequential runner.
- Testnet only. Secrets never printed.

## Tasks

- [x] **T1** (done 2026-11-18: delegated writer; `docs/adr/0011-budget-bearing-escrow-and-agent-subcontracting.md`,
  D1–D11, status Proposed; structural readback by parent. Notable choices: new `fund_with_reserve`
  keeps the ERC-8183 signatures, the parent cannot `submit` while a child is open, depth 2, a new
  escrow deploy because the escrow has no upgrade entrypoint, and rating readers must accept the old
  escrow id) ADR-0011, budget-bearing escrow and agent-initiated subcontracting. The 0010 number is
  taken by PR #346. Contents: consumer reserve, `create_child_job` from the reserve, child lifecycle
  and refund to the reserve, parent close releasing unspent reserve, receipt events, depth limit and
  cycles, related-party rules, the runtime tool loop and run phases, and the amendments to ADR-0005
  D9/D10 and ADR-0006 D6. Route: delegated writer (ADR needs preparation reads of 0004/0005/0006).
- [x] **T2** (done 2026-11-18. Route: delegated writer, trigger 2+ non-trivial files plus preparation
  reads. RED: 86 compile errors. GREEN: `cargo test -p escrow` 179/179 (149 existing, 30 new);
  clippy, fmt and the WASM build (rustup 1.98.1, 37,168 B) are clean. Version bumped to 0.2.0.
  Commits `ac63a7b` (source and tests, ~1,430 authored lines) and `6365e02` (generated snapshots).
  Native review: risk high, granted. The first attempt with snapshots hit
  `lens_context_budget_exceeded`, so the commit was split. The re-run had 4 lenses, came back
  approved and was acknowledged (lineage `review-efe2486d9d0ef315`).
  Known local flake: Windows `Os 1224` while writing snapshots, which is environmental. CI on Linux
  is the authority.) Escrow contract: reserve at `fund`, `create_child_job`, child settle/reject/expire
  accounting against the parent reserve, parent completion refunding unspent reserve, events.
  Rust tests including the invariant (sum of children ≤ reserve, child expiry ≤ parent). Route:
  delegated writer.
- [x] **T3** Server domain and persistence: hire subcontract cap and related-party opt-out,
  `parentHireId`, receipt line items, migrations, ledger bindings for the new entrypoints. Route:
  delegated writer (trigger: 2+ non-trivial files across domain, server, ledger and migrations,
  mapped first by a read-only explorer). Done 2026-11-18, split by the user's choice into two
  stacked slices with the same final tree as the unsplit work (`backup/334-t3-unsplit`):
  - Slice A `feat/334-ledger-subcontract`: `2386ef4` ledger bindings (events, v0.2.0 job decoder,
    errors 124-127, `contractFunction`, `draftCreateChildJob`), +748/-20.
  - Slice B `feat/334-server-subcontract`: `ec44b71` domain, persistence and hire creation with a
    reserve (+673/-12), `7cbe47a` regenerated protocol and migration
    `20261118221650421-hire-subcontract`.
  Checks at A: server `dart analyze --fatal-infos` clean, `dart test test/unit test/hire` 1063
  passed, domain 301 passed. Checks at B: domain 309 passed, server analyze clean,
  `dart test test/unit test/hire` 1077 passed, `dart test test/integration` 185 passed, client
  analyze clean; a second `serverpod generate` changed no content. Native review of the unsplit
  source: medium risk, granted, one reliability lens, approved and acknowledged (lineage
  `review-f955cb3b83a47254`). Each split slice was reviewed again as its own target: A `2386ef4`
  (medium, granted, reliability lens, approved and acknowledged, lineage
  `review-bc7e85bf85502f8d`) and B source `ec44b71` on base `2386ef4` (medium, granted, reliability
  lens, approved and acknowledged, lineage `review-cb09b5b886640baf`). Notes:
  `fund_with_reserve` stays under purpose `fund` (the tracker only funds on `fund`), and the wire
  function name now comes from `SubmissionPurpose.contractFunction`. `createChildJob` is untracked
  by `chain_submission_tracker.dart` until T6. `allowRelatedParty` defaults to true (D10) and is
  stored only. The reserve ceiling comes from `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS`. The
  `fund_with_reserve` encoding lives in slice B because it reads `HireRow.subcontractReserve`.
- [ ] **T4** Server-side marketplace search for agents: skill, rating, paid hires, price, `hireable`,
  related-party flag, excluding self and cycles, ranked objectively. Route: delegated writer.
- [ ] **T5** Runtime tool loop (Workers AI and Anthropic tool calling, bounded turns) with
  `search_agents` and `subcontract` tools, plus run phases (run → waiting for a child → resume).
  Route: delegated writer.
- [ ] **T6** Subcontract executor: runtime → child job from the reserve, A evaluates B, A's run
  resumes with B's result, receipt stored. Route: delegated writer.
- [ ] **T7** Web: hire with a subcontract cap and a related-party toggle, and a receipt/subcontract
  tree on hire detail. Route: delegated writer.
- [ ] **T8** Testnet evidence from the web: a consumer hires A, A subcontracts B from the reserve, A
  delivers, the unspent reserve is refunded, and every hash is checked. Record it in
  `docs/verification/334-agent-subcontracting.md`.

## Acceptance

Issue #334 acceptance, restated for path 1. On testnet, a consumer hires A with one signature that
funds A's price plus a subcontract cap. A's model subcontracts B through the reserve with no further
signature. B delivers, A delivers the combined result, and the consumer approves. The unspent reserve
returns to the consumer. The itemized receipt can be checked on-chain, and every tx hash on
StellarExpert.

## Checks

- Contracts: `cargo test` for the escrow, plus the existing cargo-audit workflow.
- Server: `dart analyze`, plus unit and integration tests for the changed services.
- Flutter: `flutter analyze` and `flutter test` for the changed screens.
- T8: RPC `getTransaction` SUCCESS for every hash, and Horizon balances.

## Progress

- 2026-11-18: research done (code map, agentic-payments landscape) and decisions recorded. Next: T1.
- 2026-11-18: T1 (PR #357), T2 (PR #358) and T3 (slices A and B, not yet PRs) done. Next: review
  each slice, open PR A stacked on #358 and PR B stacked on A, then T4.
