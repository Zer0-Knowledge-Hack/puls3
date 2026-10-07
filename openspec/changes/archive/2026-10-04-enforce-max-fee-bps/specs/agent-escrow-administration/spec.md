# Delta Spec: agent-escrow-administration

Change: `enforce-max-fee-bps` (#79). Modifies requirements A1 and A3 to enforce a hard `MAX_FEE_BPS` ceiling below 10,000 bps. Resolves open item #2.

## MODIFIED Requirements

### Requirement: A1. constructor
`__constructor(admin, identity_registry, treasury: Option<Address>, fee_bps: u32, max_expiry: u64, approval_window: u64)` MUST store the configuration and validate it:
- `fee_bps <= MAX_FEE_BPS` (1,000 bps), else `InvalidFeeBps`.
- `fee_bps > 0` requires `treasury` to be `Some`, else `TreasuryNotSet`.
- `max_expiry > 0` and `approval_window > 0`, else `InvalidDuration`.
- `approval_window < max_expiry`, else `InvalidDuration` (otherwise no job could ever be submitted).
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
- **WHEN** `max_expiry = 0`, or `approval_window = 0`, or `approval_window >= max_expiry`
- **THEN** deployment fails with `InvalidDuration`

### Requirement: A3. fee configuration
`set_fee_bps(caller, fee_bps)` and `set_treasury(caller, treasury: Address)` (admin only). Getters `fee_bps()` and `treasury() -> Option<Address>`.
- `fee_bps > MAX_FEE_BPS` (1,000 bps) MUST fail with `InvalidFeeBps`.
- Setting `fee_bps > 0` while no treasury is set MUST fail with `TreasuryNotSet`.
- A change applies only to jobs funded after the change (the job snapshots `fee_bps` on `fund`); the `treasury` is read at settlement. Emits `FeeConfigUpdated(fee_bps, treasury)`.
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
