# Exploration: Agent Escrow and Payment contract (#55)

Engram topic: `sdd/agent-escrow-payment/explore` (observation 352). Full report lives there; this file is the hybrid-mode summary.

## Summary

Issue #55 is best served by a new standalone `escrow` Soroban crate (`contracts/contracts/escrow/`) with per-hire records, `token::Client` custody, ledger-timestamp deadlines and an admin-set arbiter, with no cross-contract call to identity-registry in v1. ADR-0003, ADR-0001 and `docs/vision.md` defer escrow, refunds and disputes, so a new ADR (or amendment) is required.

## Recommended approach

- A1: escrow pulls funds via `token::Client::transfer(consumer, contract, amount)`; token allow-list (USDC SAC, XLM SAC).
- B1: `DataKey::Escrow(u64 hire_id) -> EscrowRecord`; persistent storage with TTL bumps; duplicate hire ids rejected.
- C1: state machine `Funded`, `Delivered`, `Released`, `Refunded`, `Disputed`; permissionless timeout pokes; arbiter `resolve`.
- D1: no registry cross-call in v1; payee stored at lock time.
- Mirror identity-registry conventions (errors 1..8 reserved style, `#[contractevent]`, `DataKey`, TTL helpers).

## Open product decisions

1. Scope vs ADR-0003 (opt-in rail vs replacement).
2. Who validates completion.
3. Arbiter model (none / admin / multisig; partial splits or not).
4. Fee (none / bps to treasury).
5. Timeouts (per-hire vs global, defaults, maximums).
6. Token allow-list and who can change it.
7. Failure semantics (agent self-cancel, server `fail`, automatic refund after SLA).
8. Payee trust (caller-supplied vs registry check).
9. Strict TDD flag (`openspec/config.yaml` says false).

## Risks

Scope conflict with ADRs; custody/arbiter trust; non-allow-listed tokens; i128 vs domain int amounts; TTL on long SLAs; Dart domain has no refund transition; 400-line review budget requires splitting; payee changes must not affect in-flight escrow.
