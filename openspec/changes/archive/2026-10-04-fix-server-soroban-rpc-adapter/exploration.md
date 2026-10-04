# Exploration: fix-server-soroban-rpc-adapter

Full analysis: engram `sdd/fix-server-soroban-rpc-adapter/explore` (obs 408).

## Current state

- `puls3_domain` defines `LedgerPort { findPayment(TransactionHash) -> Payment?, agentWallet(AgentId) -> StellarAddress? }`. Nothing implements it.
- `puls3_server` has no chain code, no ledger folder and no custom config reader. `http 1.6.0` is already resolved transitively; `package:http/testing.dart` ships `MockClient`.
- Deployed testnet values live in `contracts/deployments/testnet.json` (registry, escrow, USDC SAC; RPC `https://soroban-testnet.stellar.org`).
- Reads use `simulateTransaction` with a hand-built unsigned invoke envelope (about 100 lines of XDR encoding). Payments are checked with `getTransaction` using `xdrFormat: "json"`: status SUCCESS, a SAC `transfer` event from the configured USDC contract, matching amount and `to_muxed_id`.
- The "tx hash not reused" rule belongs to the hire use case, not the adapter.

## Approaches

| Approach | Verdict |
|---|---|
| Raw JSON-RPC over `package:http` + tiny XDR encoder | Recommended: no new dependency, offline-testable, read-only |
| `stellar_dart` | Unverified API, large lock diff, couples a read PR to a signing bet |
| `stellar_flutter_sdk` | Needs Flutter, not viable on the server |

## Defaults chosen

1. Several matching transfer events in one transaction: take the first match.
2. Configuration through environment variables plus a testnet constant (public ids are not secrets).
3. The adapter throws `LedgerUnavailable` on HTTP/RPC errors; the domain port stays unchanged.

## Risks

- Real `getTransaction` JSON field names are unconfirmed: record live fixtures first and parse tolerantly.
- Encoder correctness must be guarded by a golden test against `stellar contract invoke --build-only`.
- RPC retention (about 7 days) makes old hashes look unpaid: persist the verified `Payment` at hire time.
- A testnet reset invalidates ids and fixtures.

## Suggested split (400-line budget)

- PR 1: `http` dependency, `StellarConfig`, RPC client, encoder, decoders, registry reads.
- PR 2: `findPayment`, `get_job`, `LedgerUnavailable` handling, docs.
