# Tasks: Agent Escrow Payment Contract (#55)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,300-1,600 authored (excl. snapshots) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 -> PR 2 -> PR 3 -> PR 4 -> PR 5 (~300-400 each) |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

Note: chain strategy is not chosen; slice boundaries below are strategy-neutral. Orchestrator must record the choice (stacked-to-main or feature-branch-chain) before PR 1 is opened. Spec is authority where design differs (constructor shape, fee snapshot at `fund`, error/event/view names); see Risks.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Scaffold, config, allow-list, `create_job` | PR 1 | `cargo test -p escrow` | N/A: native Soroban env tests | Remove crate dir |
| 2 | `fund`, `reject`, `claim_refund`, views | PR 2 | `cargo test -p escrow` | N/A: SAC token in test env | Revert PR 2 |
| 3 | `submit`, `complete`, `release`, fee math | PR 3 | `cargo test -p escrow` | N/A: SAC token in test env | Revert PR 3 |
| 4 | Admin setters, auth, TTL, non-goals | PR 4 | `cargo test -p escrow` | N/A: native env | Revert PR 4 |
| 5 | ADR-0003 amendment note | PR 5 | `rg ADR-0005 docs/adr/0003-*.md` | N/A: docs only | Revert PR 5 |

Every PR gate: `cargo test`, `cargo clippy --all-targets -- -D warnings`, `cargo fmt --check` (run in `contracts/`). Paths below are in `contracts/contracts/escrow/`. Each feature task = RED (failing test in `src/test.rs`) -> GREEN (`src/lib.rs`) -> REFACTOR.

## PR 1: Scaffold and create_job

- [x] 1.1 Create `Cargo.toml` (workspace deps, dev-dep `identity-registry` path), `src/lib.rs` stub, `src/test.rs` harness; update `contracts/Cargo.lock`.
- [x] 1.2 VERIFY (RED): test linking `identity-registry` as dev-dependency and registering it natively; fallback: mock registry or `contractimport!`. Record outcome.
  - Outcome: linking works. `identity-registry` is a path dev-dependency, registered natively with `env.register(IdentityRegistryContract, ...)`; no mock or `contractimport!` fallback needed.
- [x] 1.3 VERIFY (RED): `TokenClient::transfer` with `&Address` vs `MuxedAddress` in a mint+transfer test; adapt call style.
  - Outcome: `TokenClient::transfer(&from, &to, &amount)` accepts `&Address` for `to` (MuxedAddress conversion). A freshly created `e.current_contract_address()` value is passed by value as `to` (clippy `needless_borrows_for_generic_args`).
- [x] 1.4 VERIFY: compare event names (`JobCreated`...) to EIP-8183 text/ADR-0005; adjust names in spec/design notes.
  - Outcome: ADR-0005 is not on this branch, so the comparison used ERC-8183's event set as recalled (`JobCreated`, `JobFunded`, `JobSubmitted`, `JobCompleted`, `JobRejected`, `JobExpired`). Spec names kept unchanged; `ProviderSet`/`BudgetSet`/`PaymentReleased`/`Refunded` are intentionally absent (spec R10, one event per transition). Re-check against ADR-0005 when it merges.
- [x] 1.5 RED/GREEN A1: constructor tests (valid, `InvalidFeeBps`, `TreasuryNotSet`, `InvalidDuration` x3); params `max_expiry`/`approval_window` NOT hardcoded.
- [x] 1.6 RED/GREEN: `EscrowError` catalogue, `JobState`, `Job`, `DataKey`, getters, `version`, TTL helpers (A7, R12).
- [x] 1.7 RED/GREEN A2: `set_token_allowed`, `is_token_allowed`, `TokenAllowedSet`; `NotAdmin`.
- [x] 1.8 RED/GREEN R1: `create_job` valid, sequential ids, hook, token, budget, expiry bounds, description 257 bytes, `ProviderMismatch`, `AgentWalletNotSet`, `AgentNotFound`, `ClientIsProvider`, unauth, `JobCreated`.
- [x] 1.9 RED/GREEN: payee frozen after registry wallet change.
- [x] 1.10 REFACTOR; run clippy/fmt gates.

## PR 2: Funding, refunds, views

- [x] 2.1 RED/GREEN R2: `fund` moves tokens; `NotClient`, `BudgetMismatch`, `JobExpired`, `InvalidState`, insufficient balance, `TokenNotAllowed`, `JobNotFound`, fee snapshot at `fund`.
- [x] 2.2 RED/GREEN R6 (Open/Funded): `reject` from `Open` (no funds), from `Funded` (full refund), `NotClient`/`NotEvaluator`, final state.
- [x] 2.3 RED/GREEN R7: `claim_refund` at/before expiry, `Submitted`/`Open` refused, no double refund, refund to client not caller.
- [x] 2.4 RED/GREEN R8: `get_job`, `job_count`, `is_expired`, unknown id.
- [x] 2.5 RED: conservation test (refund <= funded, contract balance back to prior); one event per transition, none on failure.
- [x] 2.6 REFACTOR; run gates.

## PR 3: Submit, completion, settlement

- [x] 3.1 RED/GREEN R3: `submit` happy path, `NotProvider`, `InvalidState`, `JobExpired`, `SubmitTooLate`; stores `approval_deadline`.
- [x] 3.2 RED/GREEN R9: fee math (rounds down 999/250, 39/250, 10_000 bps, `i128::MAX` overflow), `payout + fee == budget`.
- [x] 3.3 RED/GREEN R4: `complete` zero fee, 250 bps, `NotEvaluator`, wrong state, third-party evaluator.
- [x] 3.4 RED/GREEN R5: `release` after deadline, exact deadline, early `ApprovalWindowOpen`, permissionless, `auto_released = true`.
- [x] 3.5 RED/GREEN R6 (Submitted): `reject` in window (no fee), `ApprovalWindowClosed`; reject-final across all functions.
- [x] 3.6 RED: funded jobs settle after allow-list removal; settlement works with no registry call.
- [x] 3.7 REFACTOR; run gates.

## PR 4: Admin, auth, TTL

- [x] 4.1 RED/GREEN A3: `set_fee_bps`, `set_treasury`, `FeeConfigUpdated`; later change keeps earlier snapshots.
- [x] 4.2 RED/GREEN A4: `set_max_expiry`, `set_approval_window`; stored deadline unchanged; `LimitsUpdated`.
- [x] 4.3 RED/GREEN A5/A6: `set_identity_registry` (rebind, in-flight jobs unaffected), `set_admin` handover, events.
- [x] 4.4 RED: explicit-auth tests with `MockAuthInvoke` + transfer `sub_invokes` for `fund`; `NotAdmin` for every setter.
- [x] 4.5 RED/GREEN R11: TTL bumps on job and instance; `extend_ttl`; terminal job readable.
- [x] 4.6 RED: R13 absence test (no dispute/pause/split/`set_budget`/`set_provider`; no admin fund-moving function).
- [x] 4.7 REFACTOR; final `cargo test`, clippy, fmt.

## Review fixes (PR #78)

- [x] R.1 RED/GREEN blocker: `settle` pays provider and treasury with `try_transfer` (both error layers); failure credits `DataKey::Claimable`, emits `PayoutDeferred`; job still `Completed`; test-only mock token.
- [x] R.2 RED/GREEN `withdraw(caller, token)` (auth, `NothingToWithdraw`, clear-before-transfer, revert on failed transfer, `PayoutWithdrawn`, no allow-list check) and `claimable` view; new errors 115/116.
- [x] R.3 RED tests: complete/release without trustline, withdraw after unblock/twice/auth/allow-list removal, treasury failure, independent payouts, conservation, `claim_refund` still refused for `Submitted`/deferred jobs.
- [x] R.4 RED/GREEN `fund(..., max_fee_bps)` with `FeeExceedsMax` (ok at/below, rejected above, 0 with fee 0); existing tests updated.
- [x] R.5 RED/GREEN overflow-free `compute_fee`; replaced the overflow tests with `i128::MAX` settlement and floor-equality property loop.
- [x] R.6 Document TTL vs `max_expiry` (rustdoc, spec R11, design); test `extend_ttl` keeps a long funded job alive.
- [x] R.7 RED D7 tests: `claim_refund` after expiry, `reject` from `Open`/`Funded`/`Submitted` with `fee_bps > 0` refund in full, treasury and contract balance checked.
- [x] R.8 R13 allow-list updated for `withdraw` and `claimable`; stale snapshots removed; gates (fmt, clippy, test, `stellar contract build`) green.

## PR 5: Docs

- [ ] 5.1 Add amendment note to `docs/adr/0003-*.md` linking ADR-0005 (blocked until ADR-0005 merged).

## Open (user confirmation pending)

- Defaults `approval_window` 86400 s, `max_expiry` 2592000 s are deploy parameters only; tests use explicit values.
- Whether to omit `set_budget`/`set_provider`/`optParams`.

## Risks

- Spec/design drift: constructor shape, `fee_bps` snapshot time (spec: `fund`; design: `create_job`), names (`job_count` vs `total_jobs`, `FeeConfigUpdated` vs `FeeUpdated`, `ProviderMismatch` vs `ProviderNotAgentWallet`), `agent_exists` use. Follow spec; confirm before 1.6.
- Spec says `token::Client`; design says `TokenClient` (non-deprecated).
