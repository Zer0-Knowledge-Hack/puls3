# Delta for agent-escrow-lifecycle

Base spec: `openspec/specs/agent-escrow-lifecycle/spec.md`. Change: escrow-claimable-ttl-evaluator-guard (issue #95).

## ADDED Requirements

### Requirement: R15. extend_claimable_ttl (puls3 addition)
The contract MUST expose `extend_claimable_ttl(recipient: Address, token: Address)`, callable by anyone, requiring no authorization, never pausable and never hookable.

- It MUST extend the contract-instance TTL on every call.
- It MUST extend the persistent TTL of `DataKey::Claimable(recipient, token)` to `TTL_BUMP` (same threshold/bump values as the other persistent entries) only when that entry exists.
- When the entry does not exist it MUST NOT revert and MUST NOT create the entry; only the instance TTL is extended.
- It MUST NOT credit, debit, move or otherwise change any claimable balance, and MUST NOT transfer tokens.
- It MUST emit no event and return no value.
- `extend_ttl(job_id)` is unchanged and MUST NOT be affected by this requirement.

#### Scenario: decayed claimable is restored and still withdrawable
- GIVEN a deferred payout credited as `claimable(recipient, token) == A`, and the ledger advanced so the entry TTL dropped below the threshold
- WHEN any address calls `extend_claimable_ttl(recipient, token)`
- THEN the Claimable entry TTL is `TTL_BUMP`
- AND `claimable(recipient, token)` is still `A`
- AND the recipient can later `withdraw(token)` and receives exactly `A`

#### Scenario: balance and tokens unchanged by the bump
- GIVEN a claimable balance `A` and known contract, recipient and caller token balances
- WHEN any address calls `extend_claimable_ttl(recipient, token)`
- THEN `claimable(recipient, token)` is unchanged, no token balance changes, and no event is emitted

#### Scenario: unknown claimable only bumps the instance
- GIVEN no Claimable entry exists for `(recipient, token)`
- WHEN any address calls `extend_claimable_ttl(recipient, token)`
- THEN the call succeeds without error
- AND the instance TTL is extended
- AND no Claimable entry exists afterwards and `claimable(recipient, token) == 0`

#### Scenario: permissionless
- WHEN an address unrelated to the recipient, the token, the treasury and any job calls `extend_claimable_ttl` without any recipient authorization
- THEN it succeeds

## MODIFIED Requirements

### Requirement: R1. create_job
The contract MUST expose `create_job(caller, provider, evaluator, expired_at, description, hook, agent_id, token, budget) -> Result<u64, EscrowError>`. The first six parameters follow ERC-8183 order; `agent_id: u32`, `token: Address`, `budget: i128` are **(puls3 addition)** because puls3 prices are fixed by the manifest and the payee is verified against the identity registry.

- `caller` MUST authorize (`require_auth`) and becomes the `client`.
- `hook` is `Option<Address>` and MUST be `None` (ADR-0005 D10); otherwise the call MUST fail with `HookNotSupported`.
- `budget` MUST be greater than 0, else `InvalidAmount`.
- `token` MUST be on the admin allow-list, else `TokenNotAllowed`.
- `expired_at` MUST be greater than `now` and at most `now + max_expiry`, else `InvalidExpiry`.
- `description` longer than 256 bytes MUST fail with `DescriptionTooLong`.
- The contract MUST call the bound identity registry `get_agent_wallet(agent_id)` and require `Some(wallet)` equal to `provider`. `None` MUST fail with `AgentWalletNotSet`; a different address MUST fail with `ProviderMismatch`. An unknown agent MUST fail with `AgentNotFound` (the registry's `get_agent_wallet` returns `None`, so the contract MUST disambiguate through `agent_exists`). The verified provider is stored in the job; later registry changes MUST NOT affect the job.
- `client` MUST differ from `provider`, else `ClientIsProvider` (an agent cannot hire itself; ERC-8004 no-self-feedback spirit).
- `evaluator` MUST differ from `provider`, else `EvaluatorIsProvider` (a provider cannot approve its own work; same anti-self-dealing class as `ClientIsProvider`, ADR-0005 D4). The check MUST run immediately after the `ClientIsProvider` check and before the identity-registry verification, so it fails before any registry call. `evaluator == client` (the default) and any third-party `evaluator` distinct from `provider` remain valid.
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

#### Scenario: evaluator equals provider
- GIVEN a client `C != P`, an agent whose registry wallet is `P`, and `job_count() == n`
- WHEN `C` calls `create_job` with `provider = P` and `evaluator = P`
- THEN it fails with `EvaluatorIsProvider`
- AND no job is stored, `job_count()` is still `n`, and no escrow event is emitted

#### Scenario: evaluator equals client is still accepted
- GIVEN a valid job input with `evaluator = client`
- WHEN `create_job` is called
- THEN it succeeds and `get_job(id).evaluator == client`

#### Scenario: third-party evaluator is still accepted
- GIVEN a valid job input with `evaluator = E` where `E` differs from both `client` and `provider`
- WHEN `create_job` is called
- THEN it succeeds and `get_job(id).evaluator == E`

#### Scenario: client and evaluator both equal provider
- WHEN `caller == provider == evaluator`
- THEN it fails with `ClientIsProvider` (the earlier check wins) and no job is stored

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

### Requirement: R11. storage and TTL
Jobs live in persistent storage under `DataKey::Job(u64)`. Every write or read-modify touch of a job MUST extend its TTL. Contract-instance TTL MUST be extended on every call that touches instance data. A job record MUST remain readable after reaching a terminal state (until TTL expiry).

The persistent TTL bump (`TTL_BUMP`, about 60 days at 5-second ledgers) is unrelated to `max_expiry`; no cap ties them. A job whose lifetime exceeds the TTL is archived unless kept alive with the permissionless `extend_ttl(job_id)` or restored from archival afterwards. A claimable balance entry (`DataKey::Claimable(recipient, token)`) is bumped when it is written and, because nothing else touches it, MUST be keepable alive by the permissionless `extend_claimable_ttl(recipient, token)` (R15) so a deferred payout is not archived while its recipient has not yet withdrawn.

#### Scenario: TTL bumped
- WHEN a job transitions
- THEN its persistent TTL is at least the configured threshold afterwards

#### Scenario: extend_ttl keeps a long job alive
- GIVEN a `Funded` job whose TTL has dropped below the threshold
- WHEN anyone calls `extend_ttl(job_id)`
- THEN the job TTL is back at `TTL_BUMP` and the job is still readable

#### Scenario: extend_claimable_ttl keeps a deferred payout alive
- GIVEN a claimable balance whose entry TTL has dropped below the threshold
- WHEN anyone calls `extend_claimable_ttl(recipient, token)`
- THEN the Claimable entry TTL is back at `TTL_BUMP` and `claimable(recipient, token)` is unchanged

### Requirement: R12. error catalogue
Failures MUST be typed `#[contracterror]` values (no panics for domain failures) with stable distinct codes: `JobNotFound`, `InvalidState`, `NotClient`, `NotProvider`, `NotEvaluator`, `InvalidAmount`, `InvalidExpiry`, `JobExpired`, `NotExpired`, `BudgetMismatch`, `TokenNotAllowed`, `HookNotSupported`, `DescriptionTooLong`, `ProviderMismatch`, `AgentWalletNotSet`, `AgentNotFound`, `ClientIsProvider`, `SubmitTooLate`, `ApprovalWindowOpen`, `ApprovalWindowClosed`, `ArithmeticOverflow`, `FeeExceedsMax` (115), `NothingToWithdraw` (116), `EvaluatorIsProvider` (117), `RegistryNotSet` (see administration spec). Authorization failures raised by `require_auth` are host auth errors.

Error codes are ABI and append-only: `EvaluatorIsProvider` MUST be 117 and MUST NOT renumber or reuse any existing code.

#### Scenario: EvaluatorIsProvider has a stable code
- WHEN `create_job` fails because `evaluator == provider`
- THEN the contract error code is exactly 117

### Requirement: R13. non-goals (testable absences)
The contract MUST NOT expose any arbiter, dispute, partial-split, pause, `set_provider`, `set_budget`, or hook-execution entry point in this change.

#### Scenario: no dispute surface
- THEN the contract spec exposes no function named `dispute`, `resolve`, `vote_reject`, `pause`, or `split`

The public function list is pinned by an allow-list test. `withdraw` and `claimable` (R14) were added to it deliberately; both only move or read funds already owed to the caller. `extend_claimable_ttl` (R15) is added to it deliberately; it only extends TTL and moves or credits nothing.

#### Scenario: allow-list includes extend_claimable_ttl
- WHEN the exported-functions allow-list test runs
- THEN `extend_claimable_ttl` is a permitted exported function and no other new function is exported
