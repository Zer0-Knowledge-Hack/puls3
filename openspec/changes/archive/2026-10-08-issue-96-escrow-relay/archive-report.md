# Archive Report: Escrow Relay Prepare and Submit Endpoints (#96)

**Change**: issue-96-escrow-relay
**Archive date**: 2026-10-08
**Status**: Closed and archived
**Artifact store mode**: Hybrid (openspec + engram)

## Final State Summary

All 23 implementation tasks are complete. Verification verdict was PASS WITH WARNINGS (0 critical blockers). Archive is unblocked. The change has been fully planned, implemented, verified, and archived.

### Completion Status

| Category | Status |
|----------|--------|
| All 23 tasks checked complete | ✓ DONE |
| Verify verdict | PASS WITH WARNINGS (0 critical) |
| Build (dart analyze --fatal-infos) | ✓ CLEAN |
| Unit tests (test/unit, test/protocol, test/spike, test/ledger, test/hire) | ✓ 538 passed |
| Integration tests (real Postgres/Redis) | ✓ 68 passed |
| Testnet end-to-end (acceptance criterion 1) | ✓ SUCCESSFUL |

### Test Evidence (Final Counts)

- **Unit and component tests**: 538 passed, 0 failed
- **Integration tests**: 68 passed, 0 failed (Postgres + Redis containers)
- **Build analysis**: No issues found (dart analyze --fatal-infos)
- **Last successful runs**: 
  - Commit aa11c8d (fix server verify warnings) — all suites green
  - Commit ca89a27 (testnet E2E) — hire 231, jobs 4; create_job tx 3a4bd3a8c904e135c871fde471e3699797656397785e1dac9871ae7fbbde67b3, fund tx 2bdd4b77d53bd1cb165e7ba6aef7b00d950d9c14d4acfddb38aa3d11f619cd59; both confirmed on Horizon testnet

## Specs Merged

### Spec 1: Hire Payment (openspec/specs/hire-payment/spec.md)

**Action**: Updated with 5 new and 1 modified requirement

- **Modified**: "Create an open hire" — updated to reflect endpoint structure, session wallet, null initial status, CreateHireResult return type, requestId idempotency, WalletMismatch check
- **Added**: "create_job confirmation records the job id and opens the hire" (onJobCreated effect)
- **Added**: "Every hire method requires the session wallet" (SessionWallet seam enforced)
- **Added**: "Settlement by complete and reject awaits #97" (liabilities documented)

**Merge method**: `gentle-ai sdd-archive-compose` (native composition, preserves unrelated requirements)

### Spec 2: Escrow Relay (openspec/specs/escrow-relay/spec.md)

**Action**: Created as new capability specification

- **10 ADDED requirements** covering:
  - Spike gate for cryptographic implementation
  - Prepare returns unsigned server-built envelope
  - Preparation validity window required configuration
  - Ownership and session enforcement
  - Preparation expiry and supersession
  - Signed envelope verification
  - Persist-then-send with never-throwing chain outcomes
  - At most one submission per preparation
  - One escrow submission in flight per hire
  - Idempotent, retry-safe submission behavior

**Merge method**: Mechanical copy (file did not exist; copy verified with empty diff)

## Verification Warnings: Resolution Status

**Per launch prompt final-state facts**, all major warnings resolved in later commits:

| Finding | Resolved in | Details |
|---------|-----------|---------|
| W1: No composition test of real codec | Commit aa11c8d | `test/hire/escrow_relay_real_codec_test.dart` — verified create_job and fund signing/relay with real StellarEnvelopeCodec |
| W3: ChainDataUnavailable after persist | Commit aa11c8d | `submitEscrowCall` reads agent catalog before claim (outage fails safely, retry relays once). Note: ChainDataUnavailable not in api.md submitEscrowCall row; proposal to add it documented. |
| W5: AgentUnavailable unmapped in prepare | Commit aa11c8d | `HireEndpoint._prepare` maps AgentUnavailable to AgentNotFound |
| S1: InvalidHireTransition.details.status inconsistency | Commit aa11c8d | Omit status field when hire has none (JSON null held in Map<String,String>) |

**Still open** (accepted follow-ups, per verify-report):

- W2: No source-inspection test for "no default in code" (W2) — behavioral tests show no fallback works; source inspection not automated
- W4: TDD Cycle Evidence tables incomplete for C1-C5 (tables exist for C6-C7 only) — evidence is verifiable but tabular form incomplete
- S2: InvalidSignedEnvelope adds details.reason not listed in api.md — document it
- S3: Non-canonical envelope encoding round-trip — late failure, not security impact; close with byte-for-byte envelope comparison
- S4: Unreproduced flake in envelope_codec_test "signature over another transaction" — deterministic test (golden vector); monitor in CI
- InputTooLong not enforced (no documented limit in spec or code)
- AgentInactive indistinguishable from AgentNotFound (both map to AgentNotFound)
- PersistenceUnavailable unmapped in error handling
- getHire/listHires not implemented (out of scope for #96; HireDetail from submit carries null payment, result, explorer)
- onFunded job-id comparison not performed (depends on lifecycle store; follow-up)
- complete/reject settlement depends on #97 (tracked as "Settlement by complete and reject awaits #97")
- SessionWallet fail-closed until #25 (real sessions not yet implemented)

## Testnet End-to-End Proof (Acceptance Criterion 1)

**Status**: SUCCESSFUL (commit ca89a27)

- **Hire ID**: 231
- **Job ID**: 4
- **Create job transaction**: `3a4bd3a8c904e135c871fde471e3699797656397785e1dac9871ae7fbbde67b3` (ledger 5081683, confirmed on Horizon)
- **Fund transaction**: `2bdd4b77d53bd1cb165e7ba6aef7b00d950d9c14d4acfddb38aa3d11f619cd59` (ledger 5081684, confirmed on Horizon)
- **Consumer**: Alice (testnet Stellar identity)
- **Agent**: Registry id 13 (Support Relay, wallet available)
- **Envelope verification**: Tampered envelope rejected with EnvelopeMismatch; repeated submit returns existing record
- **Test database**: Postgres containers started, hire and chain_submission rows recorded, 1 USDC spent to escrow

## Archive Contents

Archived to: `openspec/changes/archive/2026-10-08-issue-96-escrow-relay/`

- ✓ proposal.md (Intent, scope, risks, rollback plan, success criteria)
- ✓ design.md (Port and adapter design, error handling, session wallet seam)
- ✓ exploration.md (Codebase map and spike findings)
- ✓ specs/ (delta specs for hire-payment and escrow-relay)
- ✓ tasks.md (All 23 tasks marked complete across 7 phases: C1 Spike, C2 Doc, C3 Protocol, C4 Codec, C5 Store, C6 Services, C7 Endpoint + remediation batches 8-9)
- ✓ apply-progress.md (9 batches of work, final commit ca89a27)
- ✓ verify-report.md (PASS WITH WARNINGS verdict, 0 critical, 56/56 scenarios passing, 5 warnings and 4 suggestions resolved/documented)

## Task Completion Gate

**Result**: PASS

All 23 implementation task checkboxes are marked `[x]` in `openspec/changes/archive/2026-10-08-issue-96-escrow-relay/tasks.md`. No unchecked boxes remain.

Task distribution:
- C1 (Spike): 2/2 ✓
- C2 (Doc reconciliation): 3/3 ✓
- C3 (Protocol + migration): 3/3 ✓
- C4 (Codec + RPC): 4/4 ✓
- C5 (Preparation store): 2/2 ✓
- C6 (Services): 6/6 ✓
- C7 (Endpoint, seam, wiring): 3/3 ✓

Total: 23/23 tasks complete.

## Source of Truth Updated

The following main specs now reflect the new behavior and are the authoritative source for future implementation and review:

- **openspec/specs/hire-payment/spec.md** — Updated with 5 new requirements (session enforcement, null initial status, idempotency, onJobCreated, settlement awaiting #97) and 1 modified requirement (createHire endpoint, CreateHireResult return type)
- **openspec/specs/escrow-relay/spec.md** — New specification created with 10 requirements covering preparation, verification, persistence, submission flow, and session/ownership enforcement

## Observation IDs (Engram Artifacts)

**No Engram observations found.** Artifacts store is hybrid, with all artifacts in openspec filesystem only:
- proposal.md
- design.md
- exploration.md
- specs/escrow-relay/spec.md
- specs/hire-payment/spec.md
- tasks.md
- apply-progress.md
- verify-report.md

If Engram artifacts were persisted in an earlier phase, they are not discoverable by `mem_search`. Archive report persisted only to openspec filesystem and Engram (this document).

## Verification and Readback

**Spec merge verification**:
- Hire-payment delta: `gentle-ai sdd-archive-compose` applied 1 MODIFIED and 5 ADDED requirements preserving 9 unrelated requirements intact
- Escrow-relay spec: Copied mechanically with `cp -R`; readback `diff -r` output: empty (no differences)

**Archive folder move verification**:
- Source: `openspec/changes/issue-96-escrow-relay/` -> git mv to archive location
- Destination: `openspec/changes/archive/2026-10-08-issue-96-escrow-relay/`
- Pre-move snapshot created and compared after move
- Readback `diff -r` output: empty (no differences)
- Source directory removed after move

## SDD Cycle Complete

The change has been fully:
1. **Proposed** — scope, approach, risks, success criteria defined
2. **Specified** — delta specs for hire-payment and new escrow-relay spec created
3. **Designed** — ports, adapters, session wallet seam, error mapping designed and documented
4. **Implemented** — 7 phases of TDD work with 23 tasks, 538 unit and 68 integration tests
5. **Verified** — PASS WITH WARNINGS verdict, 0 critical blockers, warnings resolved in later commits
6. **Archived** — specs merged to source of truth, change folder moved to archive, final state documented

Ready for the next change.

---

**Archive created by**: sdd-archive phase executor  
**Archive date**: 2026-10-08  
**Branch**: feat/19-hire-pay-endpoint  
**Change**: issue-96-escrow-relay
