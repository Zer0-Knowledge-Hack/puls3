# Capability Spec: agent-escrow-lifecycle

## Purpose

Defines the escrow job lifecycle of the puls3 agent escrow contract (#55). Source of truth for names, states and events: ADR-0005 (ERC-8183 in snake_case, explicit `caller: Address` with `require_auth`, typed errors). puls3 additions are marked **(puls3 addition)**.

## Definitions

- **Job**: one ERC-8183 job; one hire maps to one job. Identified by a contract-assigned sequential `u64` job id returned by `create_job`.
- **State** (`JobState`): `Open`, `Funded`, `Submitted`, `Completed`, `Rejected`, `Expired`. `Completed`, `Rejected`, `Expired` are terminal.
- **Roles**: `client` (pays), `provider` (agent wallet, receives), `evaluator` (accepts or rejects; the client by default, passed as the `evaluator` argument).
- **now**: `env.ledger().timestamp()` in seconds. A job is *expired* when `now >= expired_at`.
- **approval window**: global duration in seconds (`approval_window`, see administration spec). `approval_deadline = submitted_at + approval_window`, stored on `submit`.
- **Job record** (persistent, `DataKey::Job(u64)`): client, provider, evaluator, agent_id, token, budget, fee_bps (snapshot, set on `fund`), expired_at, description, state, submitted_at, approval_deadline, deliverable.
- `reason` and `deliverable` are `BytesN<32>` hashes. `description` is a `String` of at most 256 bytes.

## State machine

```
create_job -> Open
Open      --fund (client)------------------> Funded
Open      --reject (client)----------------> Rejected   (no funds held)
Funded    --submit (provider)--------------> Submitted
Funded    --reject (evaluator)-------------> Rejected   (full refund)
Funded    --claim_refund (anyone, expired)-> Expired    (full refund)
Submitted --complete (evaluator)-----------> Completed  (payout minus fee)
Submitted --release (anyone, after approval_deadline)--> Completed  (puls3 addition)
Submitted --reject (evaluator, before approval_deadline)--> Rejected (full refund)
```

`claim_refund` is NOT valid from `Submitted` (ADR-0005 D4 invariant: a submitted job is auto-approved before it can expire). This stays true even when a payout fails: a failed payout never reopens a refund path, it becomes a claimable balance (R14).

## Requirements

### R1. create_job
The contract MUST expose `create_job(caller, provider, evaluator, expired_at, description, hook, agent_id, token, budget) -> Result<u64, EscrowError>`. The first six parameters follow ERC-8183 order; `agent_id: u32`, `token: Address`, `budget: i128` are **(puls3 addition)** because puls3 prices are fixed by the manifest and the payee is verified against the identity registry.

- `caller` MUST authorize (`require_auth`) and becomes the `client`.
- `hook` is `Option<Address>` and MUST be `None` (ADR-0005 D10); otherwise the call MUST fail with `HookNotSupported`.
- `budget` MUST be greater than 0, else `InvalidAmount`.
- `token` MUST be on the admin allow-list, else `TokenNotAllowed`.
- `expired_at` MUST be greater than `now` and at most `now + max_expiry`, else `InvalidExpiry`.
- `description` longer than 256 bytes MUST fail with `DescriptionTooLong`.
- The contract MUST call the bound identity registry `get_agent_wallet(agent_id)` and require `Some(wallet)` equal to `provider`. `None` MUST fail with `AgentWalletNotSet`; a different address MUST fail with `ProviderMismatch`. An unknown agent MUST fail with `AgentNotFound` (the registry's `get_agent_wallet` returns `None`, so the contract MUST disambiguate through `agent_exists`). The verified provider is stored in the job; later registry changes MUST NOT affect the job.
- `client` MUST differ from `provider`, else `ClientIsProvider` (an agent cannot hire itself; ERC-8004 no-self-feedback spirit).
- On success: state `Open`, a new sequential id (starting at 1), the job record is persisted, its TTL extended, and event `JobCreated` emitted. No tokens move.

#### Scenario: create a valid job
- GIVEN an allow-listed token, an agent whose registry wallet is `P`, and valid `expired_at`
- WHEN the client calls `create_job` with `provider = P`, `evaluator = client`, `hook = None`
- THEN it returns job id 1, `get_job(1).state == Open`, and `JobCreated` is emitted
- AND no token balance changes

#### Scenario: ids are sequential
- WHEN two jobs are created in a row
- THEN ids are 1 and 2

#### Scenario: non-empty hook rejected
- WHEN `create_job` is called with `hook = Some(addr)`
- THEN it fails with `HookNotSupported` and no job is stored

#### Scenario: token not allow-listed
- WHEN `create_job` is called with a token not on the allow-list
- THEN it fails with `TokenNotAllowed`

#### Scenario: invalid budget
- WHEN `budget` is 0 or negative
- THEN it fails with `InvalidAmount`

#### Scenario: expiry bounds
- WHEN `expired_at <= now`, or `expired_at > now + max_expiry`
- THEN it fails with `InvalidExpiry`
- AND `expired_at == now + max_expiry` succeeds

#### Scenario: provider does not match registry wallet
- GIVEN the registry wallet for `agent_id` is `P`
- WHEN `create_job` is called with `provider = Q != P`
- THEN it fails with `ProviderMismatch`

#### Scenario: agent has no wallet
- GIVEN the agent exists but has no wallet set
- WHEN `create_job` is called
- THEN it fails with `AgentWalletNotSet`

#### Scenario: unknown agent
- WHEN `agent_id` does not exist in the registry
- THEN it fails with `AgentNotFound`

#### Scenario: client equals provider
- WHEN the caller is the registry wallet of `agent_id` and `provider` is the same address
- THEN it fails with `ClientIsProvider`

#### Scenario: payee frozen at creation
- GIVEN a job was created with provider `P`
- WHEN the agent's registry wallet is later changed to `P2`
- THEN `submit` is still authorized for `P` only, and `complete` still pays `P`

#### Scenario: unauthorized create
- WHEN `create_job` is invoked without the client's authorization
- THEN it fails with an auth error and no job is stored

#### Scenario: description too long
- WHEN `description` is 257 bytes
- THEN it fails with `DescriptionTooLong`

### R2. fund
The contract MUST expose `fund(caller, job_id, expected_budget, max_fee_bps) -> Result<(), EscrowError>`.

- `caller` MUST authorize and MUST equal the job `client`, else `NotClient`.
- State MUST be `Open`, else `InvalidState`.
- `now < expired_at`, else `JobExpired` (a job cannot be funded after expiry).
- `expected_budget` MUST equal `budget`, else `BudgetMismatch` (front-run protection).
- The current `fee_bps` (the value about to be snapshotted) MUST be `<= max_fee_bps`, else `FeeExceedsMax`. This protects the client from a fee raised between `create_job` and `fund`; the admin cannot divert the budget of a job the client did not accept the fee for.
- The token MUST still be allow-listed, else `TokenNotAllowed`.
- The contract MUST pull exactly `budget` of `token` from the client to the contract via `token::Client::transfer` and snapshot the current `fee_bps` into the job.
- State becomes `Funded`, TTL extended, event `JobFunded` emitted.

#### Scenario: fund moves tokens
- GIVEN an `Open` job with budget 1_000_0000 and client balance 5_000_0000
- WHEN the client calls `fund(job_id, 1_000_0000, max_fee_bps)` with `max_fee_bps >= fee_bps`
- THEN client balance is 4_000_0000, contract balance increases by 1_000_0000, state is `Funded`, `JobFunded` emitted

#### Scenario: wrong caller
- WHEN a non-client calls `fund`
- THEN it fails with `NotClient` (or an auth error if unauthorized) and no tokens move

#### Scenario: budget mismatch
- WHEN `expected_budget != budget`
- THEN it fails with `BudgetMismatch` and state stays `Open`

#### Scenario: fund after expiry
- GIVEN `now >= expired_at`
- WHEN the client calls `fund`
- THEN it fails with `JobExpired`, no tokens move, state stays `Open`

#### Scenario: fund twice
- GIVEN a `Funded` job
- WHEN `fund` is called again
- THEN it fails with `InvalidState`

#### Scenario: insufficient client balance
- WHEN the client balance is below `budget`
- THEN the call fails (token error), state stays `Open`, and no event is emitted

#### Scenario: token removed from allow-list after create
- GIVEN the admin removed the token after `create_job`
- WHEN `fund` is called
- THEN it fails with `TokenNotAllowed`

#### Scenario: unknown job
- WHEN `fund` is called with a non-existent job id
- THEN it fails with `JobNotFound`

#### Scenario: fee snapshot
- GIVEN `fee_bps = 0` at create and `250` when the client funds
- THEN the job stores `fee_bps = 250` (value at `fund` time)
- AND a later `set_fee_bps` does not change this job's fee

#### Scenario: fee within the client maximum
- GIVEN `fee_bps = 250`
- WHEN the client calls `fund` with `max_fee_bps` 250, 251 or 10_000
- THEN `fund` succeeds and the job stores `fee_bps = 250`

#### Scenario: fee above the client maximum
- GIVEN `fee_bps = 250`
- WHEN the client calls `fund` with `max_fee_bps` 249 (or 0)
- THEN it fails with `FeeExceedsMax`, no tokens move and the job stays `Open`

#### Scenario: fee raised before fund
- GIVEN an `Open` job and the admin then sets `fee_bps = 10_000`
- WHEN the client calls `fund` with `max_fee_bps = 0`
- THEN it fails with `FeeExceedsMax` and the treasury receives nothing

#### Scenario: zero maximum with zero fee
- GIVEN `fee_bps = 0`
- WHEN the client calls `fund` with `max_fee_bps = 0`
- THEN `fund` succeeds

### R3. submit
The contract MUST expose `submit(caller, job_id, deliverable) -> Result<(), EscrowError>`.

- `caller` MUST authorize and MUST equal the stored `provider`, else `NotProvider`.
- State MUST be `Funded`, else `InvalidState`.
- `now < expired_at`, else `JobExpired`.
- `now + approval_window` MUST be strictly less than `expired_at`, else `SubmitTooLate` (D4 invariant: auto-approval precedes expiry).
- On success: state `Submitted`, `deliverable`, `submitted_at = now`, `approval_deadline = now + approval_window` stored, TTL extended, event `JobSubmitted` emitted. No tokens move.

#### Scenario: provider submits
- GIVEN a `Funded` job
- WHEN the stored provider calls `submit(job_id, hash)`
- THEN state is `Submitted`, `approval_deadline == now + approval_window`, `JobSubmitted` emitted, balances unchanged

#### Scenario: non-provider submits
- WHEN the client or a third party calls `submit`
- THEN it fails with `NotProvider`

#### Scenario: submit from wrong state
- WHEN the job is `Open`, `Submitted`, or terminal
- THEN `submit` fails with `InvalidState`

#### Scenario: submit after expiry
- GIVEN `now >= expired_at`
- THEN `submit` fails with `JobExpired`

#### Scenario: submit too late for the approval window
- GIVEN `now + approval_window >= expired_at` but `now < expired_at`
- WHEN the provider calls `submit`
- THEN it fails with `SubmitTooLate` and the job stays `Funded` (refundable after expiry)

### R4. complete
The contract MUST expose `complete(caller, job_id, reason) -> Result<(), EscrowError>`.

- `caller` MUST authorize and MUST equal the `evaluator`, else `NotEvaluator`.
- State MUST be `Submitted`, else `InvalidState`.
- It MAY be called at any time while `Submitted` (including after `approval_deadline`, if `release` has not run yet).
- Settlement (see R9) pays `budget - fee` to the provider and `fee` to the treasury; a payout whose transfer fails is credited as a claimable balance instead (R14) and does not revert.
- State becomes `Completed`, event `JobCompleted` (with `reason`, `payout`, `fee`, `auto_released = false`) emitted.

#### Scenario: complete with zero fee
- GIVEN a `Submitted` job, budget 1_000_0000, snapshot fee 0 bps
- WHEN the evaluator calls `complete(job_id, reason)`
- THEN the provider receives 1_000_0000, the contract balance returns to its prior value, treasury receives nothing, state `Completed`

#### Scenario: complete with fee
- GIVEN snapshot fee 250 bps, budget 1_000_0000
- THEN fee = 25_0000, provider receives 975_0000, treasury receives 25_0000

#### Scenario: non-evaluator completes
- WHEN any other address calls `complete`
- THEN it fails with `NotEvaluator`

#### Scenario: complete from wrong state
- WHEN the job is `Open`, `Funded`, or terminal
- THEN it fails with `InvalidState`

#### Scenario: third-party evaluator
- GIVEN a job created with `evaluator = E != client`
- THEN only `E` can `complete`; the client calling `complete` fails with `NotEvaluator`

### R5. release (puls3 addition)
The contract MUST expose `release(job_id) -> Result<(), EscrowError>`, callable by anyone and requiring no authorization.

- State MUST be `Submitted`, else `InvalidState`.
- `now >= approval_deadline`, else `ApprovalWindowOpen`.
- Settlement identical to `complete` (R9, R14); `reason` is the all-zero hash; event `JobCompleted` with `auto_released = true`.
- Funds only ever go to the stored provider and treasury, never to the caller.

#### Scenario: silence pays the provider
- GIVEN a `Submitted` job and `now >= approval_deadline`
- WHEN any address calls `release(job_id)`
- THEN the provider is paid `budget - fee`, state `Completed`, `JobCompleted.auto_released == true`

#### Scenario: release too early
- GIVEN `now < approval_deadline`
- THEN `release` fails with `ApprovalWindowOpen` and state stays `Submitted`

#### Scenario: release at the exact deadline
- GIVEN `now == approval_deadline`
- THEN `release` succeeds

#### Scenario: release from wrong state
- WHEN the job is not `Submitted`
- THEN `release` fails with `InvalidState`

#### Scenario: release is permissionless
- WHEN an unrelated address (not client, provider, evaluator) calls `release`
- THEN it succeeds and the caller's balance is unchanged

### R6. reject
The contract MUST expose `reject(caller, job_id, reason) -> Result<(), EscrowError>`. Reject is final (ADR-0005 D8).

- `caller` MUST authorize.
- From `Open`: `caller` MUST equal `client`, else `NotClient`. No funds move.
- From `Funded`: `caller` MUST equal `evaluator`, else `NotEvaluator`. The full `budget` is refunded to the client.
- From `Submitted`: `caller` MUST equal `evaluator`, else `NotEvaluator`, and `now < approval_deadline`, else `ApprovalWindowClosed` (silence past the window is implicit approval). The full `budget` is refunded to the client; no fee is charged.
- From terminal states: `InvalidState`.
- State becomes `Rejected`; event `JobRejected` carries `rejector`, `reason`, `from_state` (the state the job was in when `reject` was called, so indexers can count rejects from `Submitted` against the client), and `refunded` (amount, 0 from `Open`).

#### Scenario: client cancels an open job
- GIVEN an `Open` job
- WHEN the client calls `reject`
- THEN state `Rejected`, `JobRejected.from_state == Open`, `refunded == 0`, no balance change

#### Scenario: non-client rejects an open job
- WHEN anyone but the client calls `reject` on an `Open` job
- THEN it fails with `NotClient`

#### Scenario: evaluator rejects a funded job
- GIVEN a `Funded` job, client balance after funding 4_000_0000
- WHEN the evaluator (client) calls `reject`
- THEN the client balance returns to 5_000_0000, contract balance returns to prior value, `from_state == Funded`

#### Scenario: evaluator rejects a submitted job in the window
- GIVEN a `Submitted` job and `now < approval_deadline`
- WHEN the evaluator calls `reject`
- THEN full refund to the client, no fee to the treasury even if `fee_bps > 0`, `from_state == Submitted`

#### Scenario: reject after the approval window
- GIVEN `now >= approval_deadline`
- THEN `reject` fails with `ApprovalWindowClosed` and the job stays `Submitted`

#### Scenario: provider tries to reject
- WHEN the provider calls `reject` on a `Funded` or `Submitted` job
- THEN it fails with `NotEvaluator`

#### Scenario: reject is final
- GIVEN a `Rejected` job
- THEN `fund`, `submit`, `complete`, `release`, `reject`, `claim_refund` all fail with `InvalidState`

### R7. claim_refund
The contract MUST expose `claim_refund(job_id) -> Result<(), EscrowError>`, callable by anyone, requiring no authorization, never pausable and never hookable.

- State MUST be `Funded`, else `InvalidState` (a `Submitted` job MUST fail with `InvalidState`; it settles through `complete`, `release` or `reject`; ADR-0005 D4 invariant). An `Open` job is not refundable (no funds held). `claim_refund` MUST NOT be extended to `Submitted` to rescue a failed payout: the contract cannot tell a failed payout from a client that never called `release`, so that would let a silent client wait for `expired_at`, reclaim the funds and keep the deliverable. Failed payouts are handled by the pull-payment balance (R14).
- `now >= expired_at`, else `NotExpired`.
- The full `budget` is returned to the stored `client` (never to the caller). No fee.
- State becomes `Expired`; events `JobExpired` emitted with the refunded amount.

#### Scenario: expiry refund
- GIVEN a `Funded` job and `now >= expired_at`
- WHEN any address calls `claim_refund`
- THEN the client receives `budget`, the contract balance returns to its prior value, state `Expired`, `JobExpired` emitted

#### Scenario: refund exactly at expiry
- GIVEN `now == expired_at`
- THEN `claim_refund` succeeds

#### Scenario: refund before expiry
- GIVEN `now < expired_at`
- THEN it fails with `NotExpired`

#### Scenario: refund of a submitted job is refused
- GIVEN a `Submitted` job and `now >= expired_at`
- THEN `claim_refund` fails with `InvalidState`
- AND `release` succeeds because `approval_deadline < expired_at`

#### Scenario: refund of an open job
- GIVEN an `Open` job past `expired_at`
- THEN `claim_refund` fails with `InvalidState` and `is_expired(job_id)` is true

#### Scenario: no double refund
- GIVEN an `Expired` job
- THEN a second `claim_refund` fails with `InvalidState`

#### Scenario: refund goes to the client, not the caller
- WHEN a third party calls `claim_refund`
- THEN the third party's balance is unchanged

#### Scenario: refund never charges the fee
- GIVEN a `Funded` job with `fee_bps > 0` and `now >= expired_at`
- WHEN any address calls `claim_refund`
- THEN the client receives the full `budget`, the treasury balance is unchanged and the contract balance for the job is 0

#### Scenario: deferred payout does not open a refund
- GIVEN a job settled by `release` whose provider payout was deferred to a claimable balance
- WHEN `now >= expired_at` and any address calls `claim_refund`
- THEN it fails with `InvalidState` and the client balance is unchanged

### R8. views
The contract MUST expose read-only views: `get_job(job_id) -> Result<Job, EscrowError>`, `job_count() -> u64`, and `is_expired(job_id) -> Result<bool, EscrowError>`.

- `is_expired` MUST return true when the state is `Expired`, or when the state is `Open` or `Funded` and `now >= expired_at`; otherwise false. It lets indexers derive the unfunded-expiry result without a transaction (ADR-0005 D6).
- Unknown id MUST fail with `JobNotFound`.

#### Scenario: unfunded expiry is derived
- GIVEN an `Open` job and `now >= expired_at`
- THEN `is_expired` is true and `get_job.state` is still `Open`

#### Scenario: live job not expired
- GIVEN a `Funded` job and `now < expired_at`
- THEN `is_expired` is false

#### Scenario: submitted job never reported expired
- GIVEN a `Submitted` job past `expired_at`
- THEN `is_expired` is false

#### Scenario: unknown job
- WHEN any view is called with an unknown id
- THEN it fails with `JobNotFound`

### R9. settlement and fee math
All payouts MUST use `token::Client::transfer` from the contract.

- `fee = floor(budget * fee_bps / 10_000)`, computed overflow-free as `(budget / 10_000) * fee_bps + (budget % 10_000) * fee_bps / 10_000`. This is exact for `fee_bps <= 10_000` and can never overflow, so a job cannot get stuck in `Submitted` because of the fee math. `fee_bps` is the snapshot taken at `fund`.
- `payout = budget - fee`. `payout + fee == budget` MUST always hold.
- The fee transfer MUST be skipped when `fee == 0`. The fee goes to the `treasury` configured at settlement time.
- Fee is charged ONLY on completion (`complete`, `release`); never on `reject` or `claim_refund`.
- No path MUST pay out more than `budget` for a job, and each job settles at most once.
- The provider payout and the treasury fee are paid with the `try_` variant of `transfer`, each independently. A failed payout (host error or contract error from the token) credits a claimable balance and emits `PayoutDeferred` (R14); the job still becomes `Completed`.
- `ArithmeticOverflow` remains only for the claimable balance `checked_add`.

#### Scenario: fee rounds down
- GIVEN budget 999 units and 250 bps
- THEN fee = 24, payout = 975

#### Scenario: tiny amount yields zero fee
- GIVEN budget 39 units and 250 bps
- THEN fee = 0 and payout = 39

#### Scenario: maximum bps
- GIVEN `fee_bps = 10_000`
- THEN fee == budget, payout == 0 and the provider transfer of 0 is skipped (or succeeds with 0) without error

#### Scenario: largest budget settles
- GIVEN `budget = i128::MAX` and `fee_bps` of 1, 250, 5_000 or 10_000
- THEN settlement succeeds, the job is `Completed` and `fee == floor(budget * fee_bps / 10_000)` exactly (for example 17014118346046923173168730371588410 at 1 bps and `i128::MAX` at 10_000 bps)

#### Scenario: fee equals the floor of the exact product
- FOR a range of budgets and every `fee_bps` in `0..=10_000`
- THEN `fee == budget * fee_bps / 10_000` computed without truncation errors, and `fee <= budget`

#### Scenario: conservation
- FOR every terminal path, the sum of transfers out equals the budget funded into that job, and the contract token balance attributable to the job is 0

### R10. events
Every state transition MUST emit exactly one event via `#[contractevent]`; failures MUST emit none.

| Event | Emitted by | Fields |
|---|---|---|
| `JobCreated` | `create_job` | job_id, client, provider, evaluator, agent_id, token, budget, expired_at |
| `JobFunded` | `fund` | job_id, client, amount, fee_bps |
| `JobSubmitted` | `submit` | job_id, provider, deliverable, approval_deadline |
| `JobCompleted` | `complete`, `release` | job_id, evaluator, reason, payout, fee, auto_released |
| `JobRejected` | `reject` | job_id, rejector, reason, from_state, refunded |
| `JobExpired` | `claim_refund` | job_id, client, refunded |
| `PayoutDeferred` | `complete`, `release` (only when a payout falls back to claimable) | job_id (topic), recipient, token, amount |
| `PayoutWithdrawn` | `withdraw` | recipient (topic), token, amount |

Job id MUST be a topic on every job event except `PayoutWithdrawn`, which is job-independent (the recipient is its topic). Events carry no secrets. `PayoutDeferred` is additional to, never a replacement for, the `JobCompleted` of the same call; when no payout falls back to claimable, a transition emits exactly one event.

#### Scenario: one event per transition
- WHEN each transition in the state machine executes successfully and every payout transfer succeeds
- THEN exactly one matching event with the listed fields is emitted

#### Scenario: no event on failure
- WHEN a call fails with any guard error
- THEN no escrow event is emitted

### R11. storage and TTL
Jobs live in persistent storage under `DataKey::Job(u64)`. Every write or read-modify touch of a job MUST extend its TTL. Contract-instance TTL MUST be extended on every call that touches instance data. A job record MUST remain readable after reaching a terminal state (until TTL expiry).

The persistent TTL bump (`TTL_BUMP`, about 60 days at 5-second ledgers) is unrelated to `max_expiry`; no cap ties them. A job whose lifetime exceeds the TTL is archived unless kept alive with the permissionless `extend_ttl(job_id)` or restored from archival afterwards. A claimable balance entry is bumped when it is written.

#### Scenario: TTL bumped
- WHEN a job transitions
- THEN its persistent TTL is at least the configured threshold afterwards

#### Scenario: extend_ttl keeps a long job alive
- GIVEN a `Funded` job whose TTL has dropped below the threshold
- WHEN anyone calls `extend_ttl(job_id)`
- THEN the job TTL is back at `TTL_BUMP` and the job is still readable

### R12. error catalogue
Failures MUST be typed `#[contracterror]` values (no panics for domain failures) with stable distinct codes: `JobNotFound`, `InvalidState`, `NotClient`, `NotProvider`, `NotEvaluator`, `InvalidAmount`, `InvalidExpiry`, `JobExpired`, `NotExpired`, `BudgetMismatch`, `TokenNotAllowed`, `HookNotSupported`, `DescriptionTooLong`, `ProviderMismatch`, `AgentWalletNotSet`, `AgentNotFound`, `ClientIsProvider`, `SubmitTooLate`, `ApprovalWindowOpen`, `ApprovalWindowClosed`, `ArithmeticOverflow`, `FeeExceedsMax` (115), `NothingToWithdraw` (116), `RegistryNotSet` (see administration spec). Authorization failures raised by `require_auth` are host auth errors.

### R14. pull payment (failed payouts)
The contract MUST NOT let a failing payout transfer (for example a recipient without a trustline, or a frozen holder) trap funds. The contract is not upgradeable, so settlement must always be able to finish.

- In `complete` and `release`, the provider payout and the treasury fee MUST each be sent with `try_transfer`, handling both the host-error and the contract-error layer of the result. On failure the job STILL becomes `Completed`, the amount is added (`checked_add`, `ArithmeticOverflow` on overflow) to the persistent `DataKey::Claimable(recipient, token)` balance with its TTL bumped, the funds stay in the contract, and `PayoutDeferred` is emitted. The two payouts are independent: one failing does not affect the other.
- `withdraw(caller, token) -> Result<i128, EscrowError>`: `caller` MUST authorize and only touches their own balance. A zero or missing balance fails with `NothingToWithdraw`. The balance MUST be cleared before the transfer (checks-effects-interactions). If the transfer fails the whole call reverts and the balance stays claimable. Success emits `PayoutWithdrawn` and returns the amount. `withdraw` MUST NOT check the token allow-list.
- `claimable(recipient, token) -> i128` is a view returning 0 when there is no balance.
- `claim_refund` MUST remain `Funded`-only (R7).

#### Scenario: provider without trustline, complete
- GIVEN a `Submitted` job and a provider whose token transfer fails
- WHEN the evaluator calls `complete`
- THEN the call succeeds, the job is `Completed`, the provider balance is 0, the contract still holds the amount, `claimable(provider, token) == payout` and `PayoutDeferred` precedes `JobCompleted`

#### Scenario: provider without trustline, release
- GIVEN the same setup and `now >= approval_deadline`
- WHEN anyone calls `release`
- THEN the outcome is identical to `complete` with `auto_released == true`

#### Scenario: both failure layers
- GIVEN a token whose `transfer` fails with a host panic, or with a typed contract error
- THEN both fall back to the claimable balance

#### Scenario: withdraw after recovery
- GIVEN a deferred payout and a provider that can now receive the token
- WHEN the provider calls `withdraw(token)`
- THEN the provider receives the amount, `claimable` is 0, the contract balance for the job is 0 and `PayoutWithdrawn` is emitted

#### Scenario: withdraw twice
- WHEN the balance was already withdrawn, or never existed
- THEN `withdraw` fails with `NothingToWithdraw`

#### Scenario: withdraw still failing
- GIVEN the recipient still cannot receive the token
- WHEN `withdraw` is called
- THEN the whole call reverts and `claimable` is unchanged

#### Scenario: withdraw needs the caller signature
- WHEN `withdraw` is called without the `caller` authorization
- THEN it fails and the balance is unchanged

#### Scenario: withdraw after allow-list removal
- GIVEN the admin removed the token from the allow-list after the payout was deferred
- THEN `withdraw` still succeeds

#### Scenario: treasury transfer fails
- GIVEN a treasury whose transfer fails and `fee > 0`
- WHEN the job is settled
- THEN the provider is paid in full, `claimable(treasury, token) == fee`, and the treasury can `withdraw` later

#### Scenario: independent payouts and conservation
- GIVEN both transfers fail
- THEN both amounts become claimable, and provider balance + treasury balance + contract balance for the job always equals the budget

### R13. non-goals (testable absences)
The contract MUST NOT expose any arbiter, dispute, partial-split, pause, `set_provider`, `set_budget`, or hook-execution entry point in this change.

#### Scenario: no dispute surface
- THEN the contract spec exposes no function named `dispute`, `resolve`, `vote_reject`, `pause`, or `split`

The public function list is pinned by an allow-list test. `withdraw` and `claimable` (R14) were added to it deliberately; both only move or read funds already owed to the caller.
