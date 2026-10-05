# Archive Report: fix-server-soroban-rpc-adapter

**Archive Date**: 2026-10-04  
**Archived to**: `openspec/changes/archive/2026-10-04-fix-server-soroban-rpc-adapter/`  
**Artifact Store Mode**: hybrid (OpenSpec + Engram)

## Executive Summary

The Soroban RPC Ledger Adapter change has been fully implemented, verified and archived. All 19 implementation tasks are complete. The two delta specs (soroban-rpc-ledger-adapter and soroban-contract-reads) have been synced into the main spec tree at `openspec/specs/`. The adapter is read-only, provides an implementation of `LedgerPort` for the server, and is not wired into `server.dart` (per scope).

## Final State Authority

### Rank 1: Persisted Tasks Artifact

**Status**: ✅ All 19 tasks checked complete

- Unit 0 (Fixture Recording): 3/3 tasks checked ✓
- Unit 1 (Config): 3/3 tasks checked ✓
- Unit 2 (Encoder & Transport): 6/6 tasks checked ✓
- Unit 3 (Registry Reads): 2/2 tasks checked ✓
- Unit 4 (Payments & Escrow): 4/4 tasks checked ✓
- Unit 5 (Docs & Gates): 2/2 tasks checked ✓

### Rank 2: Explicit Final-State Facts (from launch prompt)

The orchestrator confirmed the following state at archive time, which outranks any intermediate snapshots:

- ✅ All 19 tasks done
- ✅ Verification: PASS WITH WARNINGS (0 CRITICAL, 5 warnings total)
- ✅ Test suite: 98/98 unit tests pass
- ✅ Build: `dart analyze --fatal-infos` clean
- ✅ Adapter: read-only implementation of `LedgerPort` (no signing, no submission)
- ✅ Integration: not wired into `server.dart` (per scope)
- ✅ Root `pubspec.lock`: untouched by implementation
- ✅ Live fixtures: recorded read-only against soroban-testnet

### Rank 3: Intermediate Snapshots

Verification was completed with a PASS WITH WARNINGS verdict (see verify-report.md in this archive). The 5 warnings are:

1. **Apply-progress lacks TDD cycle table**: The strict-tdd-verify module expects a "TDD Cycle Evidence" table documenting RED/GREEN history. Apply-progress (stored in Engram, not in openspec) provides a summary without this table. Downgraded from CRITICAL because runtime test evidence is complete (98/98 pass) and RED history cannot be reconstructed after the fact. The parent may add the table in a later review.

2. **No apply-progress.md in openspec**: Hybrid mode stores apply-progress only in Engram (#413), not in the openspec folder. This is by design for hybrid mode.

3. **restorePreamble fixture is mutated**: The fixture for testing `restorePreamble` error handling is a mutated copy of a recorded response, not a live recording (cannot be live-recorded in test).

4. **Testnet tx retention**: The `get_transaction_success.json` fixture will leave public RPC retention (~7 days); offline tests are unaffected, but live re-recording will not be possible after expiry. This is expected and documented.

5. **Root pubspec.lock rewrites**: Local `dart` rewrites root `pubspec.lock` on each run; it was reverted with `git checkout pubspec.lock` and is clean (per launch prompt). This is a known Dart behavior.

**Per Final-State Authority (Rank 2 > Rank 3)**: The explicit final-state facts confirm root `pubspec.lock` remains untouched, so the warning is superseded by the launch prompt's record of the committed state.

## Spec Sync Results

### Soroban RPC Ledger Adapter

**Status**: ✅ NEW spec created (no merge required)

- **Source**: `openspec/changes/fix-server-soroban-rpc-adapter/specs/soroban-rpc-ledger-adapter/spec.md`
- **Target**: `openspec/specs/soroban-rpc-ledger-adapter/spec.md`
- **Action**: Mechanical copy (new spec, no existing main spec)
- **Diff verification**: CLEAN (source and target byte-identical)
- **Requirements**: 10 ADDED requirements
- **Scenarios**: 16 ADDED scenarios

### Soroban Contract Reads

**Status**: ✅ NEW spec created (no merge required)

- **Source**: `openspec/changes/fix-server-soroban-rpc-adapter/specs/soroban-contract-reads/spec.md`
- **Target**: `openspec/specs/soroban-contract-reads/spec.md`
- **Action**: Mechanical copy (new spec, no existing main spec)
- **Diff verification**: CLEAN (source and target byte-identical)
- **Requirements**: 3 ADDED requirements
- **Scenarios**: 5 ADDED scenarios

## Archive Contents

✅ All required SDD artifacts are present in `openspec/changes/archive/2026-10-04-fix-server-soroban-rpc-adapter/`:

- proposal.md (4.2 KB) — intent, scope, capabilities, approach, risks
- design.md (8.1 KB) — technical decisions, data flow, interfaces, testing strategy
- exploration.md (2.2 KB) — prior exploration work
- tasks.md (4.6 KB) — all 19 tasks with completion checkmarks
- verify-report.md (8.5 KB) — verification verdict and spec compliance matrix
- specs/soroban-rpc-ledger-adapter/spec.md — 10 requirements, 16 scenarios
- specs/soroban-contract-reads/spec.md — 3 requirements, 5 scenarios

## Verification Verdict

**Source**: verify-report.md (in archive, recorded by sdd-verify phase)

```yaml
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 12/12 (soroban-rpc-ledger-adapter) + 3/3 (soroban-contract-reads)
scenarios: 31/31
test_command: "cd puls3_server && dart test test/unit"
test_exit_code: 0
build_command: "cd puls3_server && dart analyze --fatal-infos"
build_exit_code: 0
```

**Spec Compliance**: All 15 requirements and 31 scenarios are COMPLIANT.

**Assertion Quality**: Passed triangulation and safety-net checks; no tautologies or ghost loops found.

## Delivery Readiness

Per the spec and design documents:

- **In Scope / Delivered**:
  - ✅ `http: ^1.6.0` as direct server dependency (in pubspec.yaml, locked)
  - ✅ `StellarConfig` from `PULS3_STELLAR_*` environment variables
  - ✅ JSON-RPC client (`simulateTransaction`, `getTransaction` with `xdrFormat: json`)
  - ✅ In-repo XDR encoder for unsigned invoke envelopes (golden-tested)
  - ✅ `SorobanLedger implements LedgerPort` (`agentWallet`, `findPayment`, `agentExists`, `agentUri`, `escrowJob`)
  - ✅ Adapter-level `LedgerUnavailable` on HTTP/RPC failure
  - ✅ Offline unit tests (98/98 pass, no network/DB/Redis required)

- **Out of Scope / Not Delivered** (intentionally):
  - ⊘ Signing or submitting transactions (deferred to stellar_dart)
  - ⊘ Wiring into `server.dart`, endpoints, Serverpod protocol (not wired)
  - ⊘ Flutter, contracts, domain port changes (unchanged)
  - ⊘ Checking for reused transaction hashes (hire use-case concern)

## Key Implementation Facts

### Code Structure

- 9 source files in `puls3_server/lib/src/ledger/`:
  - `stellar_config.dart` — environment config with testnet defaults
  - `ledger_errors.dart` — sealed exception types
  - `strkey.dart` — local Stellar address decoding (no domain change)
  - `xdr_invoke_encoder.dart` — XDR envelope builder
  - `sc_val_json.dart` — JSON-RPC value decoders
  - `soroban_rpc_client.dart` — HTTP-based RPC client
  - `transfer_event_parser.dart` — SAC transfer event extraction
  - `escrow_job.dart` — escrow job record decoder
  - `soroban_ledger.dart` — main adapter implementing `LedgerPort`

- 7 test files in `puls3_server/test/unit/ledger/`
- 11 recorded fixtures in `puls3_server/test/unit/ledger/fixtures/`

### Safety and Read-Only Audit

- No signing, keypair, secret key or `sendTransaction` code in puls3_server/lib
- Envelope has zero signatures and zero auth entries
- All contract reads use `simulateTransaction` only (no broadcast capability)
- No secrets found in the diff; fixtures contain public on-chain data only
- Live recordings against soroban-testnet were read-only (no broadcast)

### Offline Testing

- All 98 unit tests pass offline using `MockClient` and recorded fixtures
- No PostgreSQL, Redis, or network access required for ledger tests
- Testnet drift test validates `StellarConfig.testnet` against `contracts/deployments/testnet.json`

### Review Workload

- Estimated ~650 changed lines across 16 new files
- Delivered as 1 PR with `size:exception` label (per user acceptance)
- Reviewed in 6 commit-organized units (fixtures, config, encoder, registry, payments, docs)

## Archive Operation Details

### Spec Sync (Step 2)

- Task Completion Gate: PASSED (19/19 tasks checked)
- Delta specs: 2 new specs (soroban-rpc-ledger-adapter, soroban-contract-reads)
- Main specs status: No existing main specs for these domains (new additions)
- Copy method: Mechanical shell copy with temp file and atomic move
- Verification: Diff -r confirms byte-identity of source and destination

### Archive Move (Step 3)

- Source: `openspec/changes/fix-server-soroban-rpc-adapter`
- Destination: `openspec/changes/archive/2026-10-04-fix-server-soroban-rpc-adapter`
- Method: `git mv` (tracked files)
- Pre-move snapshot: Created with `cp -R` for verification
- Verification: Post-move `diff -r` against snapshot confirms integrity

### Verification (Step 4)

- ✅ Main specs updated correctly (2 new specs in openspec/specs/)
- ✅ Change folder moved to archive
- ✅ Archive contains all artifacts (proposal, specs, design, tasks, verify-report)
- ✅ Archived `tasks.md` has all implementation tasks checked (19/19)
- ✅ Active changes directory no longer has this change
- ✅ Verbatim diff -r readback: CLEAN (empty output)

## SDD Cycle Closure

The Soroban RPC Adapter for LedgerPort change has completed all SDD phases:

1. ✅ **sdd-explore** — scope and risk assessment
2. ✅ **sdd-propose** — user acceptance and scope confirmation
3. ✅ **sdd-spec** — 2 detailed specifications with 15 requirements and 31 scenarios
4. ✅ **sdd-design** — technical architecture and interfaces
5. ✅ **sdd-tasks** — 19 implementation tasks across 6 units
6. ✅ **sdd-apply** — complete implementation with all tasks checked
7. ✅ **sdd-verify** — verification of all requirements and scenarios (PASS WITH WARNINGS)
8. ✅ **sdd-archive** — change closed and archived

Ready for the next change. The adapter is in place and awaiting wiring into the server (a separate scope item).

---

## Engram Observation IDs (for traceability)

This archive report is stored in Engram at topic key: `sdd/fix-server-soroban-rpc-adapter/archive-report`

No Engram-sourced artifacts were read during this phase (all artifacts were retrieved from OpenSpec filesystem paths per hybrid mode). The archive report itself is being saved to Engram as the terminal audit record.
