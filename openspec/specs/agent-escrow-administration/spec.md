# Capability Spec: agent-escrow-administration

## Purpose

Provides administrative controls, parameter configuration, token allow-listing, and registry binding for the puls3 agent escrow contract.

## Definitions

- **admin**: single address set in the constructor. All admin calls take `caller: Address`, MUST `require_auth`, and MUST equal the stored admin, else `NotAdmin`.
- **Config** (instance storage): admin, identity registry address, treasury (optional), `fee_bps`, `max_expiry` (seconds), `approval_window` (seconds), allow-list of tokens (persistent `DataKey::AllowedToken(Address)`).

## Requirements

### Requirement: A1. constructor
`__constructor(admin, identity_registry, treasury: Option<Address>, fee_bps: u32, max_expiry: u64, approval_window: u64)` MUST store the configuration and validate it:
- `fee_bps <= MAX_FEE_BPS` (1,000 bps), else `InvalidFeeBps`.
- `fee_bps > 0` requires `treasury` to be `Some`, else `TreasuryNotSet`.
- `max_expiry > 0` and `approval_window > 0`, else `InvalidDuration`.
- `approval_window < max_expiry`, else `InvalidDuration` (otherwise no job could ever be submitted).
- `max_expiry <= MAX_EXPIRY_CEILING` (2 592 000 s, 30 days), else `InvalidDuration` (audit E-5, #206). The ceiling is `TTL_THRESHOLD` ledgers at `LEDGER_SECONDS` (5 s): a job is never left below `TTL_THRESHOLD` after a write and lives at most `max_expiry` after creation, so an open, funded or submitted job cannot archive before its own deadline, and `TTL_BUMP` leaves it twice that room. The same check applies to `set_max_expiry`.
- Default for the MVP is `fee_bps = 0`. The concrete values of `max_expiry` and `approval_window` are deployment parameters (ADR-0005 D3 deferred; see Open items). The contract MUST NOT hard-code defaults.

#### Scenario: valid construction
- **WHEN** deployed with `fee_bps = 0`, no treasury, `max_expiry = 86400`, `approval_window = 3600`
- **THEN** getters return those values and the allow-list is empty

#### Scenario: fee at MAX_FEE_BPS accepted
- **WHEN** deployed with `fee_bps = MAX_FEE_BPS` (1,000) and a valid treasury
- **THEN** deployment succeeds and `fee_bps()` returns 1,000

#### Scenario: fee above MAX_FEE_BPS rejected
- **WHEN** deployed with `fee_bps = MAX_FEE_BPS + 1` (1,001)
- **THEN** deployment fails with `InvalidFeeBps`

#### Scenario: fee without treasury
- **WHEN** `fee_bps = 100` and `treasury = None`
- **THEN** deployment fails with `TreasuryNotSet`

#### Scenario: invalid durations
- **WHEN** `max_expiry = 0`, or `approval_window = 0`, or `approval_window >= max_expiry`, or `max_expiry > MAX_EXPIRY_CEILING`
- **THEN** deployment fails with `InvalidDuration`

### Requirement: A2. token allow-list
The contract MUST expose `set_token_allowed(caller, token, allowed: bool)` and the view `is_token_allowed(token) -> bool`. The intended initial members are the USDC SAC and the XLM SAC, configured by the deployer after deployment (the contract hard-codes no token address). Emits `TokenAllowedSet(token, allowed)`.

- Removal MUST only block new `create_job` and `fund` calls. It MUST NOT block settlement (`complete`, `release`, `reject`, `claim_refund`) of already funded jobs, nor `withdraw` of a claimable balance (funds must always be able to leave).

#### Scenario: admin allows a token
- **WHEN** the admin calls `set_token_allowed(USDC, true)`
- **THEN** `is_token_allowed(USDC)` is true and `TokenAllowedSet` is emitted

#### Scenario: admin removes a token
- **WHEN** the admin calls `set_token_allowed(USDC, false)`
- **THEN** `is_token_allowed(USDC)` is false

#### Scenario: non-admin cannot change the list
- **WHEN** a non-admin calls `set_token_allowed`
- **THEN** it fails with `NotAdmin` (or an auth error) and the list is unchanged

#### Scenario: funded jobs survive removal
- **GIVEN** a `Funded` job whose token is then removed from the allow-list
- **THEN** `reject`, `claim_refund` (after expiry) and, for `Submitted`, `complete`/`release` still succeed and move the funds

#### Scenario: unknown token is not allowed
- **THEN** `is_token_allowed(X)` is false for a never-added token

### Requirement: A3. fee configuration
`set_fee_bps(caller, fee_bps)` and `set_treasury(caller, treasury: Address)` (admin only). Getters `fee_bps()` and `treasury() -> Option<Address>`.
- `fee_bps > MAX_FEE_BPS` (1,000 bps) MUST fail with `InvalidFeeBps`.
- Setting `fee_bps > 0` while no treasury is set MUST fail with `TreasuryNotSet`.
- A change applies only to jobs funded after the change: the job snapshots `fee_bps` on `fund`, and a job with a fee also snapshots the `treasury` on `fund` and is paid there at settlement (#205, audit E-3). Emits `FeeConfigUpdated(fee_bps, treasury)`.
- Setting `fee_bps = 0` MUST be allowed at any time.

#### Scenario: enable a fee later
- **WHEN** treasury is set and admin calls `set_fee_bps(250)`
- **THEN** jobs funded afterwards snapshot 250 bps; jobs funded earlier keep 0 bps

#### Scenario: fee at MAX_FEE_BPS accepted
- **WHEN** treasury is set and admin calls `set_fee_bps(MAX_FEE_BPS)` (1,000)
- **THEN** `fee_bps()` returns 1,000

#### Scenario: fee above MAX_FEE_BPS rejected
- **WHEN** admin calls `set_fee_bps(MAX_FEE_BPS + 1)` (1,001)
- **THEN** it fails with `InvalidFeeBps`

#### Scenario: fee without treasury
- **WHEN** no treasury is set and admin calls `set_fee_bps(100)`
- **THEN** it fails with `TreasuryNotSet`

#### Scenario: non-admin
- **WHEN** a non-admin calls `set_fee_bps` or `set_treasury`
- **THEN** it fails with `NotAdmin` and nothing changes

### Requirement: A4. expiry and approval-window limits
`set_max_expiry(caller, seconds)` and `set_approval_window(caller, seconds)` (admin only), with getters `max_expiry()` and `approval_window()`.
- Both MUST be greater than 0 and `approval_window < max_expiry`, else `InvalidDuration`.
- `max_expiry` bounds `expired_at - now` at `create_job` (see lifecycle R1).
- `approval_window` is read at `submit`; `approval_deadline` is stored in the job, so a later change MUST NOT alter the deadline of an already submitted job.
- Emits `LimitsUpdated(max_expiry, approval_window)`.

#### Scenario: lower the maximum
- **WHEN** the admin sets `max_expiry` lower
- **THEN** new `create_job` calls beyond it fail with `InvalidExpiry`; existing jobs keep their `expired_at`

#### Scenario: window change does not move existing deadlines
- **GIVEN** a `Submitted` job with stored `approval_deadline D`
- **WHEN** the admin changes `approval_window`
- **THEN** the job's `approval_deadline` is still `D`

#### Scenario: invalid durations
- **WHEN** `set_approval_window(0)` or `set_max_expiry` not greater than `approval_window`
- **THEN** it fails with `InvalidDuration`

#### Scenario: non-admin
- **THEN** `NotAdmin`

### Requirement: A5. identity registry binding
The registry MUST be set at construction, and is read with `identity_registry()`. `create_job` uses the bound registry for `get_agent_wallet` / `agent_exists` lookups (lifecycle R1). The address is never stored per job; only the verified `provider` and `agent_id` are.

The registry names the wallet of every new job's provider, so it changes in two timelocked steps (audit E-2, #206), all admin only:
- `propose_identity_registry(caller, registry)` records the proposal and emits `RegistryChangeProposed(registry, proposed_at, executable_at, expires_at)`. A live proposal must be cancelled first (`RegistryChangePending`); an expired one can be replaced.
- `execute_identity_registry(caller)` applies it once `REGISTRY_TIMELOCK_LEDGERS` (51 840 ledgers, about 3 days) have passed (`RegistryTimelockNotExpired` before) and within `REGISTRY_EXECUTION_WINDOW` (120 960 ledgers, about 7 days) after that (`RegistryChangeExpired` later), and emits `RegistryUpdated(registry)`.
- `cancel_identity_registry(caller)` drops the proposal and emits `RegistryChangeCancelled(registry)`.
- `pending_identity_registry()` returns the proposal (`registry`, `proposed_at`), if any. With nothing proposed, cancel and execute fail with `NoRegistryChange`.

A compromised admin key therefore cannot redirect new jobs at once: the change is public on chain for days, and can be watched for (`RegistryChangeProposed`) before it applies.

#### Scenario: a registry change waits for its timelock
- **WHEN** the admin proposes registry B
- **THEN** `identity_registry()` is still A, and `execute_identity_registry` fails with `RegistryTimelockNotExpired` until `REGISTRY_TIMELOCK_LEDGERS` have passed
- **AND THEN** it applies B and emits `RegistryUpdated(B)`

#### Scenario: registry swap does not affect in-flight jobs
- **GIVEN** a `Funded` job
- **WHEN** the admin rebinds the registry
- **THEN** `submit`, `complete`, `release`, `reject`, `claim_refund` for that job work without any registry call

#### Scenario: lookups use the bound registry
- **WHEN** the admin rebinds to registry B
- **THEN** subsequent `create_job` calls resolve the wallet from B

#### Scenario: registry unreachable
- **WHEN** the bound registry call traps
- **THEN** `create_job` fails and no job is stored; no other function is affected

#### Scenario: non-admin
- **THEN** `NotAdmin`

### Requirement: A6. admin handover
The handover takes two steps (#205, audit E-3). `set_admin(caller, new_admin)` (admin only) records `new_admin` as pending and emits `AdminProposed(current, pending)`; the admin does not change yet. `accept_admin(caller)` by the pending admin completes it and emits `AdminChanged(old, new)`; anyone else gets `NotPendingAdmin`, and with nothing pending `NoPendingAdmin`. A new `set_admin` replaces the pending admin, and `set_admin(caller, caller)` cancels it. `pending_admin() -> Option<Address>` reads it. The admin has NO power over job funds: it cannot move, freeze, redirect, or cancel any job, and it cannot pause `claim_refund`. The admin MUST NOT be able to change a job's client, provider, evaluator, budget or expiry.

#### Scenario: handover
- **WHEN** the admin calls `set_admin(new)` and `new` calls `accept_admin(new)`
- **THEN** the old admin's next admin call fails with `NotAdmin` and the new admin's succeeds

#### Scenario: a mistyped admin changes nothing
- **WHEN** the admin calls `set_admin(typo)`
- **THEN** the admin is unchanged and keeps every admin call until an address it controls accepts

#### Scenario: admin cannot touch funds
- **THEN** the contract exposes no admin function that transfers job tokens (no sweep, rescue, pause or force-settle)

### Requirement: A7. getters and version
The contract MUST expose `admin()`, `pending_admin()`, `identity_registry()`, `treasury()`, `fee_bps()`, `max_expiry()`, `approval_window()`, `is_token_allowed(token)` and `version() -> String`.

#### Scenario: getters reflect state
- **AFTER** each admin update
- **THEN** the matching getter returns the new value

### Requirement: A8. admin events and errors
Each successful admin change emits one event (`TokenAllowedSet`, `FeeConfigUpdated`, `LimitsUpdated`, `RegistryChangeProposed`, `RegistryChangeCancelled`, `RegistryUpdated`, `AdminProposed`, `AdminChanged`); failed calls emit none. Additional error variants: `NotAdmin`, `InvalidFeeBps`, `TreasuryNotSet`, `InvalidDuration`, `RegistryNotSet`, `RegistryChangePending`, `NoRegistryChange`, `RegistryTimelockNotExpired`, `RegistryChangeExpired`.

## Open items (not decided; do not hard-code)

1. Values of `max_expiry` and `approval_window` (ADR-0005 D3 deferred). The only constraint: `runtime timeout + approval_window < expired_at`, enforced on-chain as `now + approval_window < expired_at` at `submit`.
2. Admin key model (single address vs multisig) and upgrade policy before mainnet (ADR-0005 consequence).
3. Contract IDs of USDC and XLM SAC per network (deployment config).
