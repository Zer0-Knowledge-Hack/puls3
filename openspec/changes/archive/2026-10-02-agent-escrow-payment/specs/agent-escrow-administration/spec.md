# Delta Spec: agent-escrow-administration

Change: `agent-escrow-payment` (#55). New capability; all requirements ADDED. Complements `agent-escrow-lifecycle`. Admin entry points are **(puls3 additions)**; ADR-0005 D1/D4/D7 require the configuration but do not name the functions.

## Definitions

- **admin**: single address set in the constructor. All admin calls take `caller: Address`, MUST `require_auth`, and MUST equal the stored admin, else `NotAdmin`.
- **Config** (instance storage): admin, identity registry address, treasury (optional), `fee_bps`, `max_expiry` (seconds), `approval_window` (seconds), allow-list of tokens (persistent `DataKey::AllowedToken(Address)`).

## Requirements

### A1. constructor
`__constructor(admin, identity_registry, treasury: Option<Address>, fee_bps: u32, max_expiry: u64, approval_window: u64)` MUST store the configuration and validate it:
- `fee_bps <= 10_000`, else `InvalidFeeBps`.
- `fee_bps > 0` requires `treasury` to be `Some`, else `TreasuryNotSet`.
- `max_expiry > 0` and `approval_window > 0`, else `InvalidDuration`.
- `approval_window < max_expiry`, else `InvalidDuration` (otherwise no job could ever be submitted).
- Default for the MVP is `fee_bps = 0`. The concrete values of `max_expiry` and `approval_window` are deployment parameters (ADR-0005 D3 deferred; see Open items). The contract MUST NOT hard-code defaults.

#### Scenario: valid construction
- WHEN deployed with `fee_bps = 0`, no treasury, `max_expiry = 86400`, `approval_window = 3600`
- THEN getters return those values and the allow-list is empty

#### Scenario: invalid bps
- WHEN `fee_bps = 10_001`
- THEN deployment fails with `InvalidFeeBps`

#### Scenario: fee without treasury
- WHEN `fee_bps = 100` and `treasury = None`
- THEN deployment fails with `TreasuryNotSet`

#### Scenario: invalid durations
- WHEN `max_expiry = 0`, or `approval_window = 0`, or `approval_window >= max_expiry`
- THEN deployment fails with `InvalidDuration`

### A2. token allow-list
The contract MUST expose `set_token_allowed(caller, token, allowed: bool)` and the view `is_token_allowed(token) -> bool`. The intended initial members are the USDC SAC and the XLM SAC, configured by the deployer after deployment (the contract hard-codes no token address). Emits `TokenAllowedSet(token, allowed)`.

- Removal MUST only block new `create_job` and `fund` calls. It MUST NOT block settlement (`complete`, `release`, `reject`, `claim_refund`) of already funded jobs, nor `withdraw` of a claimable balance (funds must always be able to leave).

#### Scenario: admin allows a token
- WHEN the admin calls `set_token_allowed(USDC, true)`
- THEN `is_token_allowed(USDC)` is true and `TokenAllowedSet` is emitted

#### Scenario: admin removes a token
- WHEN the admin calls `set_token_allowed(USDC, false)`
- THEN `is_token_allowed(USDC)` is false

#### Scenario: non-admin cannot change the list
- WHEN a non-admin calls `set_token_allowed`
- THEN it fails with `NotAdmin` (or an auth error) and the list is unchanged

#### Scenario: funded jobs survive removal
- GIVEN a `Funded` job whose token is then removed from the allow-list
- THEN `reject`, `claim_refund` (after expiry) and, for `Submitted`, `complete`/`release` still succeed and move the funds

#### Scenario: unknown token is not allowed
- THEN `is_token_allowed(X)` is false for a never-added token

### A3. fee configuration
`set_fee_bps(caller, fee_bps)` and `set_treasury(caller, treasury: Address)` (admin only). Getters `fee_bps()` and `treasury() -> Option<Address>`.
- `fee_bps > 10_000` MUST fail with `InvalidFeeBps`.
- Setting `fee_bps > 0` while no treasury is set MUST fail with `TreasuryNotSet`.
- A change applies only to jobs funded after the change (the job snapshots `fee_bps` on `fund`); the `treasury` is read at settlement. Emits `FeeConfigUpdated(fee_bps, treasury)`.
- Setting `fee_bps = 0` MUST be allowed at any time.

#### Scenario: enable a fee later
- GIVEN `fee_bps = 0` and a treasury set
- WHEN the admin calls `set_fee_bps(250)`
- THEN jobs funded afterwards snapshot 250 bps; jobs funded earlier keep 0 bps

#### Scenario: bad bps
- WHEN `set_fee_bps(10_001)`
- THEN it fails with `InvalidFeeBps`

#### Scenario: fee without treasury
- GIVEN no treasury
- WHEN `set_fee_bps(100)`
- THEN it fails with `TreasuryNotSet`

#### Scenario: non-admin
- WHEN a non-admin calls `set_fee_bps` or `set_treasury`
- THEN it fails with `NotAdmin` and nothing changes

### A4. expiry and approval-window limits
`set_max_expiry(caller, seconds)` and `set_approval_window(caller, seconds)` (admin only), with getters `max_expiry()` and `approval_window()`.
- Both MUST be greater than 0 and `approval_window < max_expiry`, else `InvalidDuration`.
- `max_expiry` bounds `expired_at - now` at `create_job` (see lifecycle R1).
- `approval_window` is read at `submit`; `approval_deadline` is stored in the job, so a later change MUST NOT alter the deadline of an already submitted job.
- Emits `LimitsUpdated(max_expiry, approval_window)`.

#### Scenario: lower the maximum
- WHEN the admin sets `max_expiry` lower
- THEN new `create_job` calls beyond it fail with `InvalidExpiry`; existing jobs keep their `expired_at`

#### Scenario: window change does not move existing deadlines
- GIVEN a `Submitted` job with stored `approval_deadline D`
- WHEN the admin changes `approval_window`
- THEN the job's `approval_deadline` is still `D`

#### Scenario: invalid durations
- WHEN `set_approval_window(0)` or `set_max_expiry` not greater than `approval_window`
- THEN it fails with `InvalidDuration`

#### Scenario: non-admin
- THEN `NotAdmin`

### A5. identity registry binding
`set_identity_registry(caller, registry: Address)` (admin only) and getter `identity_registry()`. The registry MUST be set at construction. `create_job` uses the bound registry for `get_agent_wallet` / `agent_exists` lookups (lifecycle R1). The address is never stored per job; only the verified `provider` and `agent_id` are. Emits `RegistryUpdated(registry)`.

#### Scenario: registry swap does not affect in-flight jobs
- GIVEN a `Funded` job
- WHEN the admin rebinds the registry
- THEN `submit`, `complete`, `release`, `reject`, `claim_refund` for that job work without any registry call

#### Scenario: lookups use the bound registry
- WHEN the admin rebinds to registry B
- THEN subsequent `create_job` calls resolve the wallet from B

#### Scenario: registry unreachable
- WHEN the bound registry call traps
- THEN `create_job` fails and no job is stored; no other function is affected

#### Scenario: non-admin
- THEN `NotAdmin`

### A6. admin handover
`set_admin(caller, new_admin)` (admin only) replaces the admin. Emits `AdminChanged(old, new)`. The admin has NO power over job funds: it cannot move, freeze, redirect, or cancel any job, and it cannot pause `claim_refund`. The admin MUST NOT be able to change a job's client, provider, evaluator, budget or expiry.

#### Scenario: handover
- WHEN the admin calls `set_admin(new)`
- THEN the old admin's next admin call fails with `NotAdmin` and the new admin's succeeds

#### Scenario: admin cannot touch funds
- THEN the contract exposes no admin function that transfers job tokens (no sweep, rescue, pause or force-settle)

### A7. getters and version
The contract MUST expose `admin()`, `identity_registry()`, `treasury()`, `fee_bps()`, `max_expiry()`, `approval_window()`, `is_token_allowed(token)` and `version() -> String`.

#### Scenario: getters reflect state
- AFTER each admin update
- THEN the matching getter returns the new value

### A8. admin events and errors
Each successful admin change emits one event (`TokenAllowedSet`, `FeeConfigUpdated`, `LimitsUpdated`, `RegistryUpdated`, `AdminChanged`); failed calls emit none. Additional error variants: `NotAdmin`, `InvalidFeeBps`, `TreasuryNotSet`, `InvalidDuration`, `RegistryNotSet`.

## Open items (not decided; do not hard-code)

1. Values of `max_expiry` and `approval_window` (ADR-0005 D3 deferred). The only constraint: `runtime timeout + approval_window < expired_at`, enforced on-chain as `now + approval_window < expired_at` at `submit`.
2. Upper cap on `fee_bps` below 10_000 (this spec allows up to 10_000).
3. Admin key model (single address vs multisig) and upgrade policy before mainnet (ADR-0005 consequence).
4. Contract IDs of USDC and XLM SAC per network (deployment config).
