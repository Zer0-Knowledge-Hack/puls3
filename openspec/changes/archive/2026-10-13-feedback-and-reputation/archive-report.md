# Archive Report: feedback-and-reputation (issue #21)

**Project**: puls3
**Branch**: feat/21-feedback-and-reputation
**Archived**: 2026-10-13
**Archive path**: `openspec/changes/archive/2026-10-13-feedback-and-reputation/`
**Store mode**: hybrid (engram + openspec)

## Final State at Close

Final-state facts, ranked per the Final-State Authority hierarchy:

1. **Tasks artifact (highest rank)**: `openspec/changes/feedback-and-reputation/tasks.md` has 20 checked items (`[x]`) and 0 unchecked (`[ ]`). Engram tasks observation #521 reports all 18 implementation tasks done plus the 2 gate items (20 total incl. gates). The Task Completion Gate passed with no reconciliation.
2. **Launch-prompt final-state facts**:
   - apply: 18/18 implementation tasks done (20 total incl. gates).
   - delivery: single-pr with `size:exception`.
   - After verify, a walkthrough script `puls3_server/tool/feedback_walkthrough.dart` was written and run; all results were MATCH/REJECTED as expected. This file is untracked and is NOT part of the change set; it is not archived.
   - Testnet e2e criterion: deferred to #14 (PR #165) and to completed-status persistence. Not complete.
3. **verify-report (snapshot, lowest rank)**: per `verify-report` observation #523, at verification time: PASS WITH WARNINGS, 0 CRITICAL, 5 WARNING, 3 SUGGESTION; 20/20 tasks; 15/15 scenarios COMPLIANT across 6 requirements. Test counts at verify time: domain 266 pass, server targeted 830 pass, Flutter 341 pass, analyzers clean. Server full `dart test` at verify time: 836 pass plus 21 setUpAll errors in 17 integration files, all Postgres connection refused; identical on a clean origin/main worktree (environmental, not caused by this change, not diagnosed further here).

### Known Follow-ups (carried forward, not resolved by this archive)

- `getHire` does not expose `feedbackReference` after reload (verify warning; still listed as a follow-up in the launch prompt).
- Shared `ReputationRegistry` contract suite not built.
- Flutter studio/deploy previews still rating 0.0 (`AgentSummary.rating` default 4.0 is a documented drift; see verify warnings).
- Production reputation registry is unwired until #14: `UnwiredReputationCalls` throws `HireConfigurationMissing`; `UnwiredReputationRegistry` returns empty inputs.
- Testnet e2e: deferred to #14 and completed-status persistence.

### Documented drifts recorded at verify (snapshot, per `verify-report` #523)

- `FeedbackFromAgentOwner` reused.
- Literal `4.0` default for rating.
- `paidHireCount` uses a proxy.

## Traceability: Engram Observation IDs Read

| Artifact | Topic key | Observation ID |
|----------|-----------|----------------|
| exploration | `sdd/feedback-and-reputation/exploration` | 517 (referenced, not re-read) |
| proposal | `sdd/feedback-and-reputation/proposal` | 518 |
| spec | `sdd/feedback-and-reputation/spec` | 519 |
| design | `sdd/feedback-and-reputation/design` | 520 |
| tasks | `sdd/feedback-and-reputation/tasks` | 521 |
| apply-progress | `sdd/feedback-and-reputation/apply-progress` | 522 (referenced via launch prompt, not re-read) |
| verify-report | `sdd/feedback-and-reputation/verify-report` | 523 |

Observations 518, 519, 520, 521, and 523 were read in full with `mem_get_observation`. Observation 522 and 517 were not re-read in this phase; their facts are taken from the launch prompt and the other artifacts.

## Main Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| `agent-catalog-endpoint` | Updated (delta merged) | MODIFIED "AgentSummary model" replaced in place (matched by name); ADDED "Catalog reputation fields" appended. Requirement count 9 to 10. Merged via `gentle-ai sdd-archive-compose` (exit 0). |
| `hire-feedback` | Created | New full spec copied mechanically from `specs/hire-feedback/spec.md`. |

Composition command used:

```bash
gentle-ai sdd-archive-compose \
  --canonical "openspec/specs/agent-catalog-endpoint/spec.md" \
  --delta "openspec/changes/feedback-and-reputation/specs/agent-catalog-endpoint/spec.md" \
  --output "openspec/specs/agent-catalog-endpoint/spec.md.compose-tmp" \
&& mv "openspec/specs/agent-catalog-endpoint/spec.md.compose-tmp" "openspec/specs/agent-catalog-endpoint/spec.md"
```

Exit status 0. The delta's `(Previously: no rating or reputation field was allowed.)` note is preserved verbatim in the merged MODIFIED requirement, as delivered by the delta.

## Archive Contents

- proposal.md
- design.md
- tasks.md (20/20 checked)
- exploration.md
- verify-report.md
- specs/hire-feedback/spec.md
- specs/agent-catalog-endpoint/spec.md (delta, retained as history)
- archive-report.md (this file, additive)

## Mechanical Readback Evidence

- Folder move: `git mv` refused an untracked source (`fatal: source directory is empty`, status 128). The snapshot check then confirmed the source unchanged and a plain `mv` was used, per the skill's fallback.
- Post-move `diff -r <pre-move snapshot> openspec/changes/archive/2026-10-13-feedback-and-reputation` output (verbatim): empty, exit 0.
- Hire-feedback copy `diff -r` (verbatim): empty, exit 0.
- Source `openspec/changes/feedback-and-reputation/` confirmed absent after move. Active changes directory no longer contains this change.

## Risks and Notes

- The `agent-catalog-endpoint` canonical spec is a composed result, not a byte copy; its evidence is the zero exit of `gentle-ai sdd-archive-compose` plus the requirement header listing above, not a `diff -r`.
- No CRITICAL issues in the verify report; archive proceeded without override.
- Untracked, out-of-scope file `puls3_server/tool/feedback_walkthrough.dart` and `puls3_server/config/passwords.yaml.bak-before-sep10` remain untouched and are not part of this archive.
- Nothing was staged, committed, or pushed.
