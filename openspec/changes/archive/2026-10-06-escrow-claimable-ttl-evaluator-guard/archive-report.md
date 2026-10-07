# Archive Report: Escrow Claimable TTL and Evaluator Guard (issue #95)

**Change**: escrow-claimable-ttl-evaluator-guard  
**Archived to**: `openspec/changes/archive/2026-10-06-escrow-claimable-ttl-evaluator-guard/`  
**Archive date**: 2026-10-06  
**Mode**: hybrid (openspec + engram sdd/)  

## Executive Summary

Change #95 (Escrow Claimable TTL and Evaluator Guard) has been fully implemented, verified, and archived. All 16 implementation tasks are complete. The delta spec for `agent-escrow-lifecycle` has been merged into the main spec using native composition. The change folder has been moved to the archive folder with the date prefix convention. The SDD cycle is complete.

## Verification Status

**Verdict**: PASS (final-state)

Per `verify-report.md` at verification time (evidence_revision: sha256:215d17162eed87d090a2de7e9468e22d514a854e5ce29262e6275bb5def96643):
- **Blockers**: 0
- **Critical findings**: 0
- **Warnings**: 0
- **Suggestions**: 2 (out-of-scope follow-ups for #77 and #84)
- **Requirements**: 5/5
- **Scenarios**: 27/27
- **Test exit code**: 0 (136 passed, 0 failed)
- **Build exit code**: 0 (escrow.wasm exports 30 functions, including extend_claimable_ttl)

## Final-State Facts

Per orchestrator launch prompt (final-state authority):
- **Apply phase**: committed in 3 commits (code+tests+snapshots, docs, openspec change)
- **Test count**: 136 escrow tests pass
- **Toolchain**: fmt/clippy/stellar contract build clean
- **No regressions**: CRLF-only churn in snapshots was discarded; tree is clean after discard

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| agent-escrow-lifecycle | Updated | ADDED R15 (extend_claimable_ttl); MODIFIED R1 (evaluator guard), R11 (extend_claimable_ttl mention), R12 (code 117), R13 (allow-list) |

**Composition method**: native `gentle-ai sdd-archive-compose` command (guarantees byte-perfect merge without model truncation)

**Main spec path**: `openspec/specs/agent-escrow-lifecycle/spec.md`

**Verification**: Merged spec now contains 1 instance of "### Requirement: R15" and 12 total mentions of "extend_claimable_ttl" (new requirement plus all modified requirements)

## Archive Contents

All artifacts moved to `openspec/changes/archive/2026-10-06-escrow-claimable-ttl-evaluator-guard/`:

- ✅ proposal.md (3908 bytes)
- ✅ design.md (6790 bytes)
- ✅ exploration.md (3479 bytes)
- ✅ specs/agent-escrow-lifecycle/spec.md (delta, now archived)
- ✅ tasks.md (5249 bytes, 16/16 implementation tasks complete, 0 unchecked)
- ✅ verify-report.md (4018 bytes, PASS verdict)

## Archive Move Verification

**Mechanical copy contract**: All artifacts copied using `git mv` and verified with `diff -r`  
**Diff output**: Empty (byte-identity confirmed)  
**Source removal**: Confirmed absent from active `openspec/changes/` directory  
**Active changes state**: No longer contains escrow-claimable-ttl-evaluator-guard  

## Source of Truth Updated

The main spec at `openspec/specs/agent-escrow-lifecycle/spec.md` now reflects:
- **New capability**: `extend_claimable_ttl(recipient, token)` for permissionless TTL bumping of deferred payouts
- **New guard**: `create_job` rejects evaluator == provider with error code 117 (`EvaluatorIsProvider`)
- **Error catalogue**: Added `EvaluatorIsProvider = 117` with stable code
- **Non-goals**: Confirmed no dispute, pause, or hook-execution surface added
- **Compliance**: All requirements (R1, R11, R12, R13, R15) and 27 scenarios verified at runtime

## Rollback Path

To revert this change: rollback the 3 implementation commits plus the delta spec merge. The main spec atomic merge can be reverted by re-running `git revert` on the merge commit or by manually removing R15 and the R1/R11/R12/R13 modifications. No storage migration or state changes were introduced; deployed instances remain unaffected until redeploy (#84).

## Out-of-Scope Follow-ups

Per verify-report suggestions (unblocking, advisory only):
- **#77**: Serverpod/Flutter client-side mapping of error code 117 (external to puls3)
- **#84**: Testnet redeploy to activate the new function and error on the live instance

## Task Completion Gate

✅ All 16 implementation tasks checked in `tasks.md`  
✅ No CRITICAL or WARNING issues in verify-report  
✅ All requirements and scenarios compliant at runtime  
✅ Archive folder verified to contain all artifacts with byte-identity  

## SDD Cycle Closure

**Proposal**: ✅ Issue #95 scope and approach confirmed  
**Spec**: ✅ Delta spec merged into main spec  
**Design**: ✅ Technical approach documented and implemented  
**Tasks**: ✅ All implementation tasks completed  
**Apply**: ✅ 3 commits (code+tests, docs, openspec delta)  
**Verify**: ✅ PASS verdict (0 critical, 0 warnings)  
**Archive**: ✅ Change folder archived with date prefix; specs synced; archive report persisted  

**Status**: COMPLETE — Ready for the next change.
