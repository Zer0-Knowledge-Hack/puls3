# Proposal: Agent Escrow Payment Contract (#55)

## Intent

Hires today settle by a direct SAC transfer (ADR-0003), so a client has no recourse after paying. A Soroban escrow contract that locks funds per hire, releases them optimistically, and refunds on reject or expiry is the payment rail for every hire (ADR-0005, ERC-8183 style, Stellar 8004).

## Scope

### In Scope
- New crate `contracts/contracts/escrow/` that mirrors the identity-registry conventions.
- Job lifecycle keyed by hire id (u64): `fund` (client lock) -> `submit` (provider) -> `complete` (client) or permissionless `release` after the approval window; `reject` (client, final, full refund); permissionless `claim_refund` after `expired_at`.
- Per-hire `expired_at` bounded by an admin global maximum.
- Fee in basis points to a treasury on completion (default 0).
- Admin-managed token allow-list (USDC SAC, XLM SAC).
- Cross-contract call to identity-registry (`get_agent_wallet` / `owner_of`) to resolve and verify the payee.
- An ADR note that marks ADR-0003 as partly superseded.

### Out of Scope
- Arbiter, disputes, partial splits.
- puls3_domain refund transition, server verification of escrow events, client/app wiring (follow-up changes).
- Timeout default values (ADR-0005 D3, deferred to spec/design).
- Mainnet deployment.

## Capabilities

### New Capabilities
- `agent-escrow-lifecycle`: fund, submit, complete, auto-release, reject, claim_refund, state transitions, events.
- `agent-escrow-administration`: admin, token allow-list, fee bps and treasury, global max expiry, registry binding.

### Modified Capabilities
- None (no existing specs in `openspec/specs/`).

## Approach

Standalone contract. Persistent `DataKey::Job(u64)` record holds client, provider, token, amount, fee snapshot, `expired_at`, and the approval deadline. Custody uses `token::Client::transfer`, and auth uses `require_auth`. The payee is resolved from the registry when the job is funded and stored, so later wallet changes do not affect in-flight jobs. Typed `#[contracterror]`, `#[contractevent]`, and TTL bumps. Function and state names follow ERC-8183 and must be checked against ADR-0005 during spec. Strict TDD with `cargo test`. Delivery is an auto-chain of PRs (400-line budget each):
1. Scaffold, storage, `fund` with lock.
2. `submit`, `complete`, `release`, `reject`, `claim_refund`.
3. Fee, allow-list, global max expiry, registry integration.
4. ADR note.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `contracts/contracts/escrow/` | New | Escrow contract and tests |
| `contracts/Cargo.toml` | Modified | Workspace member |
| `docs/adr/` | New/Modified | ADR-0003 supersession note |
| domain / server / client / app | None now | Follow-up: refund transition, escrow verification |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Names diverge from ADR-0005 (not on this branch) | Med | Spec checks against `origin/docs/agentic-commerce-standards` |
| Timeout defaults undecided | High | Open item for spec/design |
| Custody bug locks funds | Med | TDD for every transition, testnet only |
| Registry outage/upgrade blocks `fund` | Low | Store the address at fund time |
| TTL expiry on long jobs | Med | Bump on every touch |

## Rollback Plan

The crate is additive. Revert the chained PRs or drop the workspace member. The direct SAC rail stays in the server until the follow-up switches it, so production payments are unaffected.

## Dependencies

- Deployed identity-registry contract ID.
- ADR-0005 merged or available for reference.

## Success Criteria

- [ ] `cargo test`, `cargo clippy -D warnings`, and `cargo fmt --check` pass.
- [ ] Every transition and refusal is covered by tests.
- [ ] Fund/release/refund amounts reconcile, with the fee taken only on completion.
- [ ] The ADR note is recorded.
