# Archive Report: fix-readme-onchain-evidence

**Change**: fix-readme-onchain-evidence  
**Artifact Store**: hybrid  
**Archive Date**: 2026-10-04  
**Status**: ARCHIVED

---

## Executive Summary

The `fix-readme-onchain-evidence` change has been successfully completed, verified, and archived. All 19 implementation tasks are complete. Two delta specs (`testnet-escrow-deployment` and `onchain-evidence-docs`) have been merged into the main spec repository. The change is ready for delivery.

---

## Final State

### Task Completion

**Status**: ALL COMPLETE

All 19 tasks across 4 phases are marked complete in `tasks.md`:

| Phase | Tasks | Count | Evidence |
|-------|-------|-------|----------|
| Phase 1: Prerequisites | 1.1–1.3 | 3 | All [x] checked; registry preflight confirmed, expiry and provider chosen, wallet binding confirmed |
| Phase 2: PR 1 Scripts | 2.1–2.10 | 10 | All [x] checked; test scripts created and passing, deploy and seed scripts complete, REFACTOR passed |
| Phase 3: Manual Live Run | 3.1–3.2 | 2 | All [x] checked; live testnet execution completed 2026-10-04 by operator; `testnet.json` updated |
| Phase 4: PR 2 Docs | 4.1–4.4 | 4 | All [x] checked; evidence table, verification guide, and contracts docs all written |

**Closure Evidence**:
- Persisted `tasks.md` has zero unchecked implementation tasks (all 19 are [x]).
- Apply-progress and verify-report (from earlier phases) confirm all work complete as of those snapshots; no later work remains pending.

### Verification Result

**Status**: PASS WITH WARNINGS

From `verify-report.md` (created during sdd-verify phase):

| Metric | Result |
|--------|--------|
| Blockers | 0 |
| Critical findings | 0 |
| Verdict | pass_with_warnings |
| Test exit codes | 0 (both suites) |

**Test Results**:
- `bash scripts/tests/escrow-deploy.test.sh`: 143 passed, 0 failed, exit 0
- `bash scripts/tests/seed-preflight.test.sh`: 52 passed, 0 failed, exit 0

**Spec Compliance**:
- testnet-escrow-deployment: all 6 requirements (D1–D6) COMPLIANT
- onchain-evidence-docs: all 7 requirements (E1–E7) COMPLIANT

### Warnings and Observations

**Warnings** (non-blocking):
1. README.md line 54 contains the word "feedback" (mermaid `result + feedback`). This is a pre-existing usage outside the openspec change scope, present in earlier commits.
2. Spec headings use the format `### D1.` and `### E1.` rather than `### Requirement:`, so the native status envelope counts 0 requirements by title. The full content matches the stated 13 requirements and 28 scenarios; the title format is a style difference only.
3. Apply-progress lacks the strict per-task TDD Cycle Evidence table (it reports batch summaries instead). RED test files exist and are green; triangulation is adequate.

**Suggestions** (noted for future improvement):
1. Agent registration and orphan agent hashes in README are not persisted in `testnet.json` (they come from script output), though all were confirmed on Horizon. Recording them in `testnet.json` would improve traceability.
2. `contracts/AGENTS.md` mentions `contracts/escrow/` while the crate lives at `contracts/contracts/escrow/` (workspace-relative path, matching existing convention). Clarification in the doc would help readers.
3. README states the registry "owner and original deployer" is one account while agents were registered by another. A single clarifying sentence about the ownership split would improve transparency.

### Live Execution Results

**Date**: 2026-10-04  
**Actor**: Operator (funded testnet key holder)  
**Outcome**: SUCCESS

| Component | Result |
|-----------|--------|
| Escrow Contract ID | CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2 |
| Test Job State | Completed (Job ID 3) |
| Direct Payment Hire ID | 8 |
| All 4 Test Job Tx Hashes | Recorded and confirmed on Horizon |
| Script Bug Fix | Found during live run (numeric JobState read-back); test case added; all tests passing |

**Verification**: All evidence values confirmed on stellar.expert (testnet) and Horizon; every claim in README is independently verifiable.

### Artifacts Merged

**Specs Synced to Main Repository**:

| Domain | Source | Destination | Action | Details |
|--------|--------|-------------|--------|---------|
| testnet-escrow-deployment | `openspec/changes/fix-readme-onchain-evidence/specs/testnet-escrow-deployment/spec.md` | `openspec/specs/testnet-escrow-deployment/spec.md` | Created | 116 lines, 6 requirements, all ADDED |
| onchain-evidence-docs | `openspec/changes/fix-readme-onchain-evidence/specs/onchain-evidence-docs/spec.md` | `openspec/specs/onchain-evidence-docs/spec.md` | Created | 98 lines, 7 requirements, all ADDED |

**Verification**: Both copies verified byte-for-byte with `diff -r`; empty diff confirms identity.

### Archive Contents

**Location**: `openspec/changes/archive/2026-10-04-fix-readme-onchain-evidence/`

| Artifact | Status | Checksum |
|----------|--------|----------|
| proposal.md | ✅ Present | Original verified intact |
| design.md | ✅ Present | Original verified intact |
| tasks.md | ✅ Present | Original verified intact (all 19 [x]) |
| verify-report.md | ✅ Present | Original verified intact |
| specs/testnet-escrow-deployment/spec.md | ✅ Present | Original verified intact |
| specs/onchain-evidence-docs/spec.md | ✅ Present | Original verified intact |

**Archive Move Verification**: `git mv` succeeded; `diff -r` between pre-move snapshot and archived folder returned empty (no differences). Active change folder is gone; archive folder is in place.

---

## Source of Truth Updated

The following specifications are now authoritative and will be referenced for all future work on these capabilities:

- `openspec/specs/testnet-escrow-deployment/spec.md` — escrow deploy script, deployment record, token allow-list, seed wallet binding, test job lifecycle
- `openspec/specs/onchain-evidence-docs/spec.md` — README evidence table, verification guide, on-chain traceability

---

## SDD Cycle Closure

| Phase | Status | Evidence |
|-------|--------|----------|
| sdd-propose | ✅ Complete | Proposal artifact with intent, scope, dependencies, risks, rollback plan |
| sdd-spec | ✅ Complete | Two delta specs created; all requirements approved |
| sdd-design | ✅ Complete | Design artifact with technical approach, data flow, interfaces, testing strategy |
| sdd-tasks | ✅ Complete | Tasks artifact with 19 implementation tasks; forecast and review workload approved |
| sdd-apply | ✅ Complete | All tasks complete; scripts, tests, docs written; live execution successful |
| sdd-verify | ✅ Complete | Verification passed with warnings (0 critical); all compliance checks green |
| sdd-archive | ✅ Complete | Specs synced, change folder moved, archive report written, cycle closed |

**Next Recommended**: none — this change is fully archived and closed.

---

## Traceability

### Orchestrator-Injected Context

- **Change**: fix-readme-onchain-evidence
- **Artifact Store**: hybrid (filesystem + Engram)
- **Artifact Paths** (hybrid — read from filesystem, saved to both):
  - proposal: `openspec/changes/fix-readme-onchain-evidence/proposal.md` (archived to `openspec/changes/archive/2026-10-04-fix-readme-onchain-evidence/proposal.md`)
  - spec (delta): `openspec/changes/fix-readme-onchain-evidence/specs/{testnet-escrow-deployment,onchain-evidence-docs}/spec.md` (archived; merged to main specs)
  - design: `openspec/changes/fix-readme-onchain-evidence/design.md` (archived)
  - tasks: `openspec/changes/fix-readme-onchain-evidence/tasks.md` (archived)
  - verify-report: `openspec/changes/fix-readme-onchain-evidence/verify-report.md` (archived)

### Engram Artifact IDs

Engagement with Engram is a future operation if selected by the orchestrator. Archive report will be persisted as `sdd/fix-readme-onchain-evidence/archive-report` (topic_key).

---

## Notes

- The 3 warnings in verification do not block archive; they are noted for transparency and future improvement.
- The script bug found during live execution (numeric JobState read-back) was diagnosed, fixed, and validated with a test; no residual issues remain.
- All on-chain claims are independently verifiable via stellar.expert (testnet) and stellar CLI; the README and docs provide step-by-step instructions in `docs/verification/onchain.md`.
- Orphan agents (7 earlier seeds) remain on-chain and are documented honestly as orphans, not removed (per design, permanent history).
- The `reputation_registry` was correctly left undeployed (`null`), as specified.
- Two PRs are planned for delivery: PR 1 (scripts + offline tests + deployment record) and PR 2 (docs); both merged PRs are tracked as #84 and issue #83 is active for context.

---

**Archive Report Completed**: 2026-10-04  
**Prepared by**: sdd-archive executor (Claude Haiku 4.5)  
**Archive Ready**: YES
