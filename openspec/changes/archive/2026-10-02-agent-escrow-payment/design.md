# Design: Agent Escrow Payment Contract (#55)

## Technical Approach

A new Soroban crate `contracts/contracts/escrow/` implements an ERC-8183 job escrow (ADR-0005 D1) in the identity-registry style: one `src/lib.rs` (types, errors, events, contract, helpers) and one `src/test.rs`. Names, states and events follow the specs `agent-escrow-lifecycle` and `agent-escrow-administration` (the authority). The workspace glob `members = ["contracts/*"]` already includes the crate.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|---|---|---|---|
| Job identity | Sequential `u64` from `create_job`, starting at 1 | Caller-supplied hire id | ERC-8183 returns the id; caller ids can be squatted (ADR-0005 amends ADR-0003 D2). |
| Budget and token | Set in `create_job` (puls3 additions); `fund(expected_budget)` guard | ERC `set_budget`/`set_provider` | Manifest-fixed prices; smaller audit surface (spec R13). |
| Payee check | `create_job` resolves `agent_exists` then `get_agent_wallet`; provider snapshotted | Lookup at payout | Wallet changes cannot redirect funds; registry outages only block new jobs (A5). |
| Registry client | Local `#[contractclient]` trait with `agent_exists(u32) -> bool` and `get_agent_wallet(u32) -> Option<Address>` | Normal dependency; `contractimport!` | Both functions exist with these signatures in `identity-registry/src/lib.rs`. Linking merges exports into the WASM; `contractimport!` needs a prebuilt WASM. |
| Fee snapshot | `fee_bps` copied into `Job` at `fund`; `treasury` read at settlement | Snapshot at `create_job` | Spec R2/A3. Fee is computed only at settlement, overflow-free (`(budget / 10_000) * bps + (budget % 10_000) * bps / 10_000`), so settlement cannot get stuck. `fund` takes `max_fee_bps` so a fee raised before `fund` cannot be imposed on the client. |
| Failed payouts | Pull payment: `try_transfer` in `settle`; on failure credit `Claimable(recipient, token)`, emit `PayoutDeferred`; `withdraw(caller, token)` pulls it | Let `settle` revert; let `claim_refund` accept `Submitted` | A recipient without a trustline would lock funds in a non-upgradeable contract. Accepting `Submitted` in `claim_refund` would let a silent client wait out `expired_at` and keep the output (ADR-0005 D4), so it stays `Funded`-only. `withdraw` skips the allow-list so funds can always leave. |
| Approval deadline | `approval_window` read at `submit`; `approval_deadline` stored | Snapshot window at create | Spec A4. |
| Optimistic window | `submit` requires `now + approval_window < expired_at`; permissionless `release` at `now >= approval_deadline`; `claim_refund` only from `Funded` | Clamp deadline | Enforces the D4 invariant. |
| Token API | `token::TokenClient` | `token::Client` | `Client` is deprecated in SDK 28 (`clippy -D warnings`). Same `transfer` call the spec names, no behavior change. |
| Allow-list | Checked in `create_job` and `fund` only | Every call | Removal never blocks settlement (A2). |
| No pause/upgrade/sweep | None | Admin pause | `claim_refund` is non-pausable; admin has no power over funds (A6). |

## State Machine

```
Open --fund(client)--> Funded --submit(provider)--> Submitted --complete(evaluator) | release(anyone, now>=deadline)--> Completed
Open --reject(client)--> Rejected      Funded --reject(evaluator)--> Rejected (refund)
Funded --claim_refund(anyone, now>=expired_at)--> Expired (refund)
Submitted --reject(evaluator, now<deadline)--> Rejected (refund)
```

`fund` and `submit` require `now < expired_at`. An `Open` job past expiry stays `Open`; `is_expired` derives it (D6).

## Interfaces / Contracts

```rust
__constructor(admin, identity_registry: Address, treasury: Option<Address>, fee_bps: u32, max_expiry: u64, approval_window: u64)
create_job(caller, provider, evaluator, expired_at: u64, description: String, hook: Option<Address>,
           agent_id: u32, token: Address, budget: i128) -> Result<u64, EscrowError>
fund(caller, job_id, expected_budget: i128, max_fee_bps: u32)   submit(caller, job_id, deliverable: BytesN<32>)
complete(caller, job_id, reason: BytesN<32>)  reject(caller, job_id, reason: BytesN<32>)
claim_refund(job_id) /* no auth */            release(job_id) /* puls3, no auth */
// admin: set_token_allowed(caller, token, bool), set_fee_bps, set_treasury(caller, Address),
//   set_max_expiry, set_approval_window, set_identity_registry, set_admin
// pull payment: withdraw(caller, token) -> i128, claimable(recipient, token) -> i128
// views: get_job, job_count, is_expired, is_token_allowed, admin, identity_registry, treasury,
//   fee_bps, max_expiry, approval_window, version, extend_ttl(job_id)
```

`Job { client, provider, evaluator, agent_id: u32, token, budget: i128, fee_bps: u32 (0 until fund), expired_at, description, state: JobState, submitted_at: u64, approval_deadline: u64, deliverable: Option<BytesN<32>> }`. `JobState`: Open=0, Funded=1, Submitted=2, Completed=3, Rejected=4, Expired=5.

`create_job` check order: auth, hook, budget, description, expiry, token, client != provider, then `agent_exists` (AgentNotFound), `get_agent_wallet` None (AgentWalletNotSet), mismatch (ProviderMismatch).

**Storage**: instance `Admin`, `IdentityRegistry`, `Treasury` (optional), `FeeBps`, `MaxExpiry`, `ApprovalWindow`, `JobCount`; persistent `Job(u64)`, `AllowedToken(Address)`, `Claimable(Address, Address) -> i128`. TTL: reuse `TTL_THRESHOLD=518_400`, `TTL_BUMP=1_036_800` (~60 days at 5 s ledgers); every write bumps instance and touched keys; public `extend_ttl(job_id)` keeps long-lived and terminal jobs readable. The TTL is unrelated to `max_expiry` and no cap links them: a job longer than the TTL needs `extend_ttl` calls or a restore.

**Errors**: ERC-shaped 1 JobNotFound, 2 InvalidState, 3 NotClient, 4 NotProvider, 5 NotEvaluator, 6 InvalidAmount, 7 BudgetMismatch, 8 InvalidExpiry, 9 JobExpired, 10 NotExpired, 11 HookNotSupported. puls3 (100+): 100 NotAdmin, 101 TokenNotAllowed, 102 ProviderMismatch, 103 AgentWalletNotSet, 104 AgentNotFound, 105 ClientIsProvider, 106 SubmitTooLate, 107 ApprovalWindowOpen, 108 ApprovalWindowClosed, 109 InvalidFeeBps, 110 TreasuryNotSet, 111 InvalidDuration, 112 RegistryNotSet (defensive missing-key read), 113 DescriptionTooLong, 114 ArithmeticOverflow (claimable `checked_add` only), 115 FeeExceedsMax, 116 NothingToWithdraw.

**Events** (`#[contractevent]`, `job_id` topic, fields per spec R10): `JobCreated`, `JobFunded`, `JobSubmitted`, `JobCompleted` (`release` sets `auto_released = true`, zero reason, `evaluator` = stored evaluator), `JobRejected` (`from_state`, `refunded`), `JobExpired`. Admin: `TokenAllowedSet`, `FeeConfigUpdated` (both fee setters), `LimitsUpdated` (both limit setters), `RegistryUpdated`, `AdminChanged`. Pull payment: `PayoutDeferred` (`job_id` topic, recipient, token, amount; emitted before `JobCompleted` when a payout falls back) and `PayoutWithdrawn` (recipient topic, token, amount; job-independent).

**Settlement**: `fee = budget.checked_mul(fee_bps)? / 10_000` computed before any write; payout `budget - fee`; zero transfers skipped; no fee on refunds. State is written before transfers; the host forbids reentrancy. `fund` pulls via `TokenClient::transfer`; the client's auth must cover the sub-invocation.

## Testing Strategy (strict TDD, `cargo test -p escrow`)

| Layer | What | Approach |
|---|---|---|
| Unit | Each transition and error | `env.register(EscrowContract, (...))`, `try_*` → `Err(Ok(EscrowError::X))` |
| Integration | Registry check | dev-dep `identity-registry`; `register(&owner)` sets wallet = owner; `unset_agent_wallet` for AgentWalletNotSet |
| Integration | Custody | `register_stellar_asset_contract_v2`, `StellarAssetClient::mint`, balances after each path |
| Unit | Time, TTL, auth | `set_timestamp`, `get_ttl`, `MockAuthInvoke` with transfer `sub_invokes` |
| Integration | Failed payouts | Test-only mock token in `test.rs` whose `transfer` fails (host panic or contract error) for a configurable blocked address; the real SAC cannot simulate a missing trustline |

`TokenClient::transfer` takes `to: MuxedAddress`; passing `&Address` is unverified (task 1.3).

## PR Slicing (matches tasks.md)

1. Scaffold, constructor, getters, errors, allow-list, `create_job`. 2. `fund`, `reject` (Open/Funded), `claim_refund`, `get_job`/`job_count`/`is_expired`. 3. `submit`, `complete`, `release`, fee math, `reject` from Submitted. 4. Fee/limit/registry/admin setters, auth, TTL and `extend_ttl`, non-goals. 5. ADR-0003 amendment note.

## File Changes

| File | Action |
|---|---|
| `contracts/contracts/escrow/{Cargo.toml,src/lib.rs,src/test.rs}` | Create |
| `contracts/contracts/escrow/test_snapshots/**` | Create (generated) |
| `contracts/Cargo.lock` | Modify |
| `docs/adr/0003-*.md` | Modify (amendment note) |

## Threat Matrix

N/A: no routing, shell, subprocess, VCS/PR or process boundary. Custody invariants are tested instead: refund <= funded, `payout + fee == budget`, one settlement per job.

## Migration / Rollout

Additive, testnet only. The server keeps the direct SAC rail until the follow-up change.

## Review fixes (PR #78)

- Blocker: failed payouts are credited as pull-payment balances (R14) instead of reverting; `claim_refund` stays `Funded`-only.
- `fund(..., max_fee_bps)` with `FeeExceedsMax`; overflow-free fee math (the old overflow error path is gone from settlement).
- Fee-free refund paths covered by tests (D7); TTL vs `max_expiry` documented.
- Residual risks, not implemented: a refund to a client that lost its token trustline (or is frozen) still reverts `claim_refund` and `reject`, with no pull-payment fallback; `withdraw` is per recipient and token, so a recipient that can never receive the token keeps the funds locked by their own condition; a claimable entry that outlives its TTL needs a restore.

## Reconciliation (spec wins)

- Constructor: `identity_registry`, `treasury: Option<Address>`, order `max_expiry, approval_window`; no tokens vector (use `set_token_allowed`).
- `fee_bps` snapshot moved from `create_job` to `fund`; fee computed only at settlement; `approval_window` no longer snapshotted at create.
- Registry client adds `agent_exists` for AgentNotFound vs AgentWalletNotSet.
- Errors renamed/added: InvalidStatus→InvalidState, ProviderNotAgentWallet→ProviderMismatch, ApprovalWindowNotElapsed→ApprovalWindowOpen, ApprovalWindowElapsed→ApprovalWindowClosed, InvalidConfig→InvalidDuration, ExpiryTooFar/ExpiryTooSoon→InvalidExpiry; added AgentWalletNotSet, AgentNotFound, ClientIsProvider, TreasuryNotSet, RegistryNotSet.
- Events: removed `PaymentReleased`/`Refunded` (one event per transition); `JobCompleted` gains `auto_released`; `JobRejected` gains `from_state`/`refunded`; admin events renamed.
- Admin/views: `set_fee` split into `set_fee_bps`/`set_treasury`; `set_timeouts` into `set_max_expiry`/`set_approval_window`; `set_registry`→`set_identity_registry`; added `set_admin`; `total_jobs`→`job_count`; `JobStatus`→`JobState`.
- Removed the on-chain 30-day `max_expiry` cap (spec forbids hard-coded limits) and the resolved `client == provider` question.

## Open Questions (pending user confirmation; D3)

- [ ] Deploy defaults: `approval_window` 86_400 s (24 h), `max_expiry` 2_592_000 s (30 days). Not hard-coded.
- [x] `max_expiry` beyond the persistent TTL bump (~60 days): resolved as documentation only. No numeric cap; rustdoc on the constants, constructor and `set_max_expiry`, plus spec R11 and this design, state that a longer job needs `extend_ttl` or a restore.
- [ ] Omitting `set_budget`/`set_provider`/`optParams` (ERC deviation).
