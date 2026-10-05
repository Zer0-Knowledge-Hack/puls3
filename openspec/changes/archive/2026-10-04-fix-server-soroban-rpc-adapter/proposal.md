# Proposal: Soroban RPC Adapter for LedgerPort

## Intent

`puls3_domain` defines `LedgerPort`, but nothing implements it, so the server cannot read agents, jobs or payments from chain. This change adds a read-only Soroban RPC adapter in `puls3_server` (ADR-0001) to unblock the agent catalog endpoint (`fix-server-agent-catalog-endpoint`).

## Scope

### In Scope
- `http: ^1.6.0` as a direct server dependency
- `StellarConfig` from `PULS3_STELLAR_*` env vars, plus a `StellarConfig.testnet` constant mirroring `contracts/deployments/testnet.json` (with a drift test)
- JSON-RPC client (`simulateTransaction`, `getTransaction` with `xdrFormat: "json"`) over an injected `http.Client`
- In-repo XDR encoder for unsigned invoke envelopes (golden-tested against `stellar contract invoke --build-only`)
- `SorobanLedger implements LedgerPort` (`agentWallet`, `findPayment`), plus `agentExists`, `agentUri`, `escrowJob` (a server-local record)
- Adapter-level `LedgerUnavailable` on HTTP/RPC failure
- Offline unit tests in `test/unit/ledger/` (MockClient and recorded live fixtures)

### Out of Scope
- Signing or submitting transactions (`stellar_dart` deferred)
- Wiring into `server.dart`, endpoints, Serverpod protocol
- Flutter, contracts, domain port changes
- Checking for reused transaction hashes (a hire use-case concern)

## Capabilities

### New Capabilities
- `soroban-rpc-ledger-adapter`: `LedgerPort` implementation (`agentWallet`, `findPayment` with SAC transfer validation, first match wins), config, error mapping
- `soroban-contract-reads`: registry `agentExists`/`agentUri` and escrow `escrowJob` reads through simulation

### Modified Capabilities
None

## Approach

Raw JSON-RPC over `package:http` with a hand-written XDR invoke encoder; responses decoded from the JSON format with tolerant parsing. Payment rule: status SUCCESS, a `transfer` event from the configured USDC SAC, `to` equals the agent wallet, exact amount, and `to_muxed_id` equals the hire id. Otherwise the result is `null`.

## Affected Areas

| Component | Impact | Description |
|-----------|--------|-------------|
| `puls3_server/pubspec.yaml`, root `pubspec.lock` | Modified | Direct `http` dependency |
| `puls3_server/lib/src/ledger/` | New | Config, RPC client, encoder, decoders, adapter |
| `puls3_server/test/unit/ledger/` | New | Unit, golden and fixture tests |
| domain, client, app, contracts | None | — |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Unconfirmed `getTransaction` JSON field names | Med | Record live fixtures first, parse tolerantly |
| Encoder bugs | Med | Golden test against stellar-cli output |
| Simulation source account requirements | Low | Configurable funded source, verified live once |
| ~7-day RPC retention makes old hashes look unpaid | Med | Document it; the hire flow stores the verified `Payment` |
| Testnet reset invalidates ids/fixtures | Low | Drift test, env override |
| Lock change triggers all CI jobs | Low | Accepted |

## Rollback Plan

The code is additive and not wired in. Revert the PR commit(s), which removes `lib/src/ledger/`, the tests, and the `http` direct dependency (lock restored). No data or protocol migration.

## Dependencies

- Live testnet deployment (`contracts/deployments/testnet.json`) for fixtures
- stellar-cli 28.0.0 for golden envelopes

## Review Workload

Estimate ~650 changed lines (~350 config/client/encoder/registry, ~300 payment/escrow/tests), over the 400-line budget. Delivered as ONE PR labeled `size:exception`: the adapter is one cohesive read-only unit with no runtime consumer, so splitting it would ship an unusable partial port. Review it commit by commit (config, encoder, registry reads, payments).

## Success Criteria

- [ ] `SorobanLedger` satisfies `LedgerPort`; `dart analyze --fatal-infos` is clean
- [ ] Encoder golden test matches stellar-cli base64
- [ ] Fixture tests cover SUCCESS, FAILED/NOT_FOUND, wrong SAC, non-muxed, bad amount or hire id, void wallet, and 5xx/timeout (`LedgerUnavailable`)
- [ ] Drift test confirms `StellarConfig.testnet` matches `testnet.json`
- [ ] `cd puls3_server && dart test` passes without Postgres/Redis for the ledger tests
