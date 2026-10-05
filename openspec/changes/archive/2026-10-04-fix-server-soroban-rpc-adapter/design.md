# Design: Soroban RPC Adapter for LedgerPort

## Technical Approach

A read-only adapter in `puls3_server/lib/src/ledger/`. Contract reads go through `simulateTransaction` with an unsigned invoke envelope built by an in-repo XDR encoder. Payments go through `getTransaction`. Both calls send `xdrFormat: "json"` over an injected `http.Client`. The adapter is not wired into `server.dart`.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|---|---|---|---|
| Payment equality checks | Adapter checks status, SAC, `transfer`, muxed id and value ranges. `Payment.settles` checks wallet, amount and hire id | Pass the hire into the adapter | `findPayment(hash)` has no hire input, and the domain already owns the `settles` checks |
| Errors | `LedgerUnavailable` (transport, RPC, malformed or archived) and `LedgerContractError(code)` (unexpected contract error) | Return `null` for everything | `null` means "not on chain". An outage must not look like "unpaid" |
| Strkey bytes | Local `strkey.dart` (decode only) | Export the domain helper | The proposal rules out domain changes |
| Config | Environment variables, with each one falling back to `StellarConfig.testnet` | Values in `passwords.yaml` | Ids are public. ADR-0001 §5 says per-network values are environment config |
| Timeout | Required constructor argument | A default value | No documented value exists. The composition root (#19) chooses it |
| ADR-0005 | `findPayment` stays (the port defines it); `escrowJob` is the escrow-path read | Drop `findPayment` | ADR-0005 supersedes ADR-0003 decision 3, but the domain port is unchanged |

## Data Flow

    SorobanLedger ──encodeInvoke──→ SorobanRpcClient ──POST──→ RPC
         │  ←── ScValJson readers ←── results[0].returnValueJson / error
         └─ findPayment ──getTransaction──→ firstUsdcPayment(tx) → Payment?

## File Changes

| File | Action | Description |
|---|---|---|
| `puls3_server/pubspec.yaml`, root `pubspec.lock` | Modify | Add `http: ^1.6.0` |
| `lib/src/ledger/stellar_config.dart` | Create | `StellarConfig` |
| `lib/src/ledger/ledger_errors.dart` | Create | Sealed `LedgerException` |
| `lib/src/ledger/strkey.dart` | Create | `Uint8List rawKey(StellarAddress)` |
| `lib/src/ledger/xdr_invoke_encoder.dart` | Create | `ScArg`, `encodeInvokeEnvelope` |
| `lib/src/ledger/sc_val_json.dart` | Create | Typed ScVal JSON readers |
| `lib/src/ledger/soroban_rpc_client.dart` | Create | JSON-RPC transport |
| `lib/src/ledger/transfer_event_parser.dart` | Create | Tolerant SAC event extraction |
| `lib/src/ledger/escrow_job.dart` | Create | `EscrowJob`, `EscrowJobState`, decoder |
| `lib/src/ledger/soroban_ledger.dart` | Create | `SorobanLedger implements LedgerPort` |
| `test/unit/ledger/*_test.dart`, `fixtures/` | Create | One test file per source file |

## Interfaces / Contracts

```dart
final class StellarConfig { // fromEnvironment(Map<String,String> env)
  final Uri rpcUrl; final String networkPassphrase;
  final StellarAddress usdcSac, identityRegistry, escrow, simulationSource;
  static final testnet = ...; // values from testnet.json and ADR-0001
}
// PULS3_STELLAR_RPC_URL, _NETWORK_PASSPHRASE, _USDC_SAC,
// _IDENTITY_REGISTRY, _ESCROW, _SIMULATION_SOURCE
sealed class ScArg { const factory ScArg.u32(int v); const factory ScArg.u64(int v); }
String encodeInvokeEnvelope({required StellarAddress source, required int fee,
  required int sequence, required StellarAddress contract,
  required String function, required List<ScArg> args});
class SorobanLedger implements LedgerPort {
  SorobanLedger(SorobanRpcClient rpc, StellarConfig config);
  Future<bool> agentExists(AgentId id);      // agent_exists
  Future<String?> agentUri(AgentId id);      // agent_uri, #2 -> null
  Future<EscrowJob?> escrowJob(int jobId);   // get_job, #1 -> null
}
```

`simulationSource` in `testnet` is the escrow admin `GAFUYV5G…` (an existing account). The invoke uses fee `100` and sequence `0`, pending the live check.

**Envelope byte layout** (XDR, big-endian, strings padded to 4 bytes):

```
u32 2 (ENVELOPE_TYPE_TX) | u32 0 KEY_TYPE_ED25519 + 32B source | u32 fee | i64 seq
u32 0 PRECOND_NONE | u32 0 MEMO_NONE | u32 1 op count | u32 0 no op source
u32 24 INVOKE_HOST_FUNCTION | u32 0 INVOKE_CONTRACT | u32 1 SC_ADDRESS_CONTRACT + 32B
u32 len + fn bytes + pad | u32 argc | args | u32 0 auth | u32 0 tx ext | u32 0 signatures
ScArg.u32: u32 3 + u32 v   ScArg.u64: u32 5 + u64 v
```

**ScVal JSON readers:** the value `"void"` reads as `null`. Integers are accepted as a number or a numeric string: `u32` decodes to `int`, `u64` to `int` (range-checked) and `i128` to `BigInt`. The other readers are `bool`, `string`, `symbol`, `address` (parsed as `StellarAddress`), `bytes` (hex) and `map`, which returns a `Map<String, Object?>` keyed by symbol. `Job` decodes from its map with symbol keys. `state` is read as `u32` and mapped by index to `EscrowJobState`, and `deliverable` is `"void"` or `bytes`. A shape mismatch throws `LedgerUnavailable`.

**Simulate:** a non-empty `error` is matched against `Error\(Contract, #(\d+)\)`. An expected code returns `null`, any other code throws `LedgerContractError`, and an unparseable error throws `LedgerUnavailable`. A `restorePreamble` also throws `LedgerUnavailable`.

**Event parser:** returns `null` unless `status == SUCCESS`. It reads events from `events.contractEventsJson` (flattened) and falls back to a tree walk for maps with `type: "contract"` and `contract_id`. The first event that passes every check wins:
- `contract_id == usdcSac`
- topics `[symbol transfer, address from, address to, string]`
- data is a map with `amount` (i128) and `to_muxed_id` (u64)
- amount is in `1..2^53-1`
- `HireId` is valid

The `contract_id`, `{"symbol":"amount"}` and `{"symbol":"to_muxed_id"}` shapes are confirmed by `spikes/payments-poc/pay.sh`.

## Testing Strategy (strict TDD: RED first per unit)

| Unit | RED tests |
|---|---|
| config | env override, invalid address throws, drift: `testnet` equals `../contracts/deployments/testnet.json` |
| strkey | raw bytes of a known G and C address |
| encoder | hand-computed bytes for `agent_exists(7)`; golden equals CLI base64 |
| ScVal | each type, `void`, mismatch |
| rpc client | `MockClient`: 200, 5xx, timeout, JSON-RPC `error`, non-JSON → `LedgerUnavailable` |
| event parser | recorded SUCCESS; mutated copies: FAILED, NOT_FOUND, wrong SAC, non-muxed, amount 0 or > 2^53-1, hire id 0 |
| adapter | fixtures for exists, uri, missing uri, wallet, void wallet, job 3, missing job, payment tx |

Negative cases mutate recorded fixtures in-test. No whole response is fabricated.

**Recording (read-only, no broadcast):**
1. `stellar contract invoke --id <registry> --source-account <simulationSource identity> --network testnet --send=no --build-only -- agent_exists --agent_id 7` produces the golden base64. Store it in `fixtures/envelope_agent_exists_7.json` with the command, plus the fee and sequence taken from `stellar tx decode`.
2. `curl -s -X POST https://soroban-testnet.stellar.org -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"simulateTransaction","params":{"transaction":"<b64>","xdrFormat":"json"}}'` records each simulate fixture. The first call also verifies the source and sequence requirement.
3. Run `getTransaction` with `{"hash":"652a575b…","xdrFormat":"json"}`, plus an unknown hash for NOT_FOUND.

## Threat Matrix

N/A: no routing, shell, subprocess, VCS/PR automation, executable classification or process integration. The only outbound call is an HTTP POST to the configured RPC.

## Migration / Rollout

No migration required.

## Open Questions

- [ ] Simulation source and sequence (fee 100, seq 0) must be verified live in the first recording step. This design phase had no shell, so the check has not run.
- [ ] Exact `getTransaction` event field names: confirm them from the recorded fixture.
- [ ] `StellarConfig.testnet` is a code default, which conflicts with ADR-0001 §5 ("never code"). The proposal accepted it with a drift test.
