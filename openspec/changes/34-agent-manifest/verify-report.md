# Verify Report: 34-agent-manifest (#34)

Mode: openspec + Engram, Strict TDD. Tip: `feat/34-agent-manifest-03-json-docs` (chain #135 merged, #138, #139, this branch).

## Verdict: PASS WITH WARNINGS (0 CRITICAL, 1 WARNING open (W4), W1-W3 resolved, 2 SUGGESTION)

## Gate (puls3_domain)
| Command | Result |
|---|---|
| `dart analyze --fatal-infos` | No issues found (0) |
| `dart test` | 234 passed, 0 failed |
| `dart format --set-exit-if-changed .` | 15 files, 0 changed, exit 0 |

Tasks: all [x] (1.1-1.9, R.1-R.2, 2.1-2.8, 3.1-3.9, F.1-F.5, 4.1-4.4). Runtime deps: none (`pubspec.yaml` has only dev_dependencies `lints`, `test`).

## Scenario coverage (test/manifest_test.dart)
| Scenario | Covering test (line) | Status |
|---|---|---|
| S1 | I26 empty draft accepted (389) | OK |
| S2 | I26 below minimum (393) | OK |
| S3 | I26 above maximum (402) | OK |
| S4 | Draft JSON S4 wrong types (752); float/out-of-range price (778) | OK, float 1.5 rejected; see W1 |
| S5 | I32 complete -> v1 (421) | OK |
| S6 | I32 empty draft (430) | OK |
| S7 | I32 immutability (483), aliasing (677) | OK |
| S8, S9 | I27 boundaries (255) | OK |
| S10 | I27 runes (241), hardening (545-569) | OK |
| S11 | I27 whitespace/no trim (245) | OK |
| S12 | I28-31 skills count (298) | OK |
| S13 | duplicate id (311), through JSON (980) | OK |
| S14 | via JSON (835) | OK, one problem kind per distinct kind; see W3 |
| S15-S17 | model policy (183-201, 358) | OK |
| S18 | isPaid (213) | OK |
| S19 | unknown keys (814), manifest (1251) | OK |
| S20, S21, S43 | max chars boundaries (318) | OK |
| S22 | price positive (345), float (778) | PARTIAL, see W1 |
| S23 | assets unsupported (879), price (345) | OK |
| S24 | tools (800, 993, 1251) | OK |
| S25 | six at once (446) | OK, uses inputMaxChars 0, see W2 |
| S26 | stable order (446-468, 1144) | OK |
| S27, S28, S29 | I25 (55, 70, 74), toDraft (492) | OK |
| S30 | manifest round-trip (1180) | OK |
| S31 | draft round-trip (919) | OK |
| S32 | unknown keys (814, 1073) | PARTIAL, see W3 |
| S33 | wrong schema (1190) | OK |
| S34-S37 | canonical (1308-1344) | OK |
| S38-S40 | reference examples (1423-1448) | OK |
| S41 | ModelId (127-165) | OK |
| S42 | ModelPolicy workers-ai paid (220) | OK |

All 43 scenarios have at least one passing test. None untested.

## Issue #34 acceptance criteria
- Every ADR-0004/spike rule has a test: yes (groups I23-I32 plus JSON/canonical groups).
- #33 example parses and validates as deployable: yes (S38); workers-ai example too (S39); both round-trip to equal doc.
- Incomplete draft accepted as draft and rejected for deploy: yes (S1, S6).
- model.md updated: I23-I32 present (docs/domain/model.md:164-173) and match test groups.
- Zero runtime deps: yes. analyze 0 issues, tests pass: yes.
- Docs: ADR-0004 amendment (decisions 1-5, hash/salt moved to #18), api.md:277-279 wire mapping and draft without version. Consistent with implementation. CI filter for `docs/architecture/examples/*` present (ci.yml:39).

## Issues
CRITICAL: none.

WARNING
- W1 RESOLVED (spec amendment, see commit `docs(openspec): align agent manifest spec ...`): integral numbers written with a decimal point (`3000000.0`) are accepted as integers; non-integral, NaN, infinity and beyond +-(2^53-1) are rejected. Spec requirements and S4/S22/S34 amended. Follow-up code fix d6595f7 applies the range check to the `int` branch too (dart2js).
- W2 RESOLVED (spec amendment): S25 uses `inputMaxChars` 0, consistent with S3.
- W3 RESOLVED (spec amendment): S14/S32 describe one `unknownKey` per document and one problem per distinct skill problem kind, ordered by field order then problem kind.
- W4 Test file is 1,477 lines in one file and the single PR carries a `size:exception`; acceptable but noted.

SUGGESTION
- S-1 DONE: spec.md deltas amended (W1-W3).
- S-2 `Skill` still counts UTF-16 length (known, PR #120).

## Next
sdd-archive (spec text now matches shipped behavior).
