# Tasks: Soroban RPC Adapter for LedgerPort

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~650 |
| 400-line budget risk | High |
| Chained PRs recommended | No (single PR accepted) |
| Suggested split | One PR, reviewed commit by commit (units 0-5) |
| Delivery strategy | ask-on-risk |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

`size:exception` already accepted by the user for this single PR.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 0 | Record live fixtures (read-only) | PR 1 | N/A | curl + stellar-cli, no broadcast | `test/unit/ledger/fixtures/` |
| 1 | Config, errors, dependency | PR 1 | `dart test test/unit/ledger/stellar_config_test.dart` | N/A, pure | config + pubspec commit |
| 2 | Strkey, encoder, ScVal, RPC client | PR 1 | `dart test test/unit/ledger` | MockClient | encoder/client commit |
| 3 | Registry reads | PR 1 | `dart test test/unit/ledger/soroban_ledger_test.dart` | MockClient + fixtures | adapter reads commit |
| 4 | Payments + escrow | PR 1 | `dart test test/unit/ledger` | MockClient + fixtures | parser/escrow commit |
| 5 | Docs, final gates | PR 1 | `dart analyze --fatal-infos` | N/A | docs commit |

## Unit 0: Live fixture recording (read-only, before any parser code)

- [x] 0.1 Run `stellar contract invoke ... --send=no --build-only -- agent_exists --agent_id 7`; save base64, command, fee, seq to `puls3_server/test/unit/ledger/fixtures/envelope_agent_exists_7.json`.
- [x] 0.2 curl `simulateTransaction` (`xdrFormat: json`) against https://soroban-testnet.stellar.org; confirm source `GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY`, fee 100, seq 0 work. Record `simulate_*.json` fixtures (exists, uri, missing uri, wallet, void wallet, job 3, missing job) in `puls3_server/test/unit/ledger/fixtures/`.
- [x] 0.3 curl `getTransaction` for hash `652a575b...` and an unknown hash; record SUCCESS and NOT_FOUND fixtures; confirm event field names. Never broadcast.

## Unit 1: Config

- [x] 1.1 Add `http: ^1.6.0` to `puls3_server/pubspec.yaml`; refresh root `pubspec.lock`.
- [x] 1.2 RED: `puls3_server/test/unit/ledger/stellar_config_test.dart`: env override, empty env equals testnet, invalid address throws, drift test of contract ids only against `contracts/deployments/testnet.json` (read-only). RPC URL and passphrase come from ADR-0001 §5.
- [x] 1.3 GREEN: `puls3_server/lib/src/ledger/stellar_config.dart` and `ledger_errors.dart` (sealed `LedgerUnavailable`, `LedgerContractError(code)`).

## Unit 2: Encoder and transport

- [x] 2.1 RED+GREEN: `strkey.dart` raw bytes of known G and C addresses.
- [x] 2.2 RED: encoder test with hand-computed `agent_exists(7)` bytes and golden equal to fixture 0.1.
- [x] 2.3 GREEN: `puls3_server/lib/src/ledger/xdr_invoke_encoder.dart`.
- [x] 2.4 RED: `sc_val_json_test.dart` per type, `void` to null, mismatch throws `LedgerUnavailable`; GREEN: `sc_val_json.dart`.
- [x] 2.5 RED: client test: 200, 5xx, timeout, JSON-RPC error, non-JSON map to `LedgerUnavailable`; no `sendTransaction`.
- [x] 2.6 GREEN: `soroban_rpc_client.dart`; timeout is a required constructor arg (no default).

## Unit 3: Registry reads

- [x] 3.1 RED: `soroban_ledger_test.dart`: exists true/false, uri present/absent, wallet registered/void, restorePreamble, contract error.
- [x] 3.2 GREEN: `soroban_ledger.dart` (`agentExists`, `agentUri`, `agentWallet`); REFACTOR.

## Unit 4: Payments and escrow

- [x] 4.1 RED: `transfer_event_parser_test.dart`: recorded SUCCESS plus mutated FAILED, NOT_FOUND, wrong SAC, non-muxed, amount 0 or above 2^53-1, hire id 0, first match wins.
- [x] 4.2 GREEN: `transfer_event_parser.dart`; the adapter validates status, SAC, topic, `to_muxed_id` and amount only. Wallet, amount and hire comparisons stay in the domain (`Payment.settles`).
- [x] 4.3 RED+GREEN: `findPayment` in `soroban_ledger.dart` returns `Payment?` from the recorded tx fixture.
- [x] 4.4 RED: `escrow_job_test.dart`: job 3 decode, missing job null, shape mismatch; GREEN: `escrow_job.dart` and `escrowJob`.

## Unit 5: Docs and gates

- [x] 5.1 Document RPC retention (~7 days) and env vars in the `puls3_server/lib/src/ledger/` library doc comments.
- [x] 5.2 Run `dart test test/unit` and `dart analyze --fatal-infos` in `puls3_server`; confirm ledger tests pass offline.
