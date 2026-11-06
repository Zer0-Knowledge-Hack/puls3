# Verifying an agent's reputation

How to check that the rating puls3 shows for an agent is the reputation formula
over **every** feedback record on chain, with nothing filtered by the server.
Security audit follow-up R-2b (audit of 2026-10-25), issue #202.

## The problem it closes

The rating is computed off chain by design: the server reads the Reputation
Registry and applies `reputationOf()` (`puls3_domain`, the Bayesian average of
[`docs/domain/reputation.md`](../domain/reputation.md)). Before #202 the rule
for which records count lived only inside the server's chain reader. A server
that dropped some records would change every score, and nobody outside the
backend could tell.

## What changed (#202)

| Where | Change |
|---|---|
| `puls3_domain/lib/src/feedback_record.dart` | `FeedbackRecord` (a record as the registry stores it), `FeedbackExclusion` with the only four reasons a record does not count, `exclusionOf()` and `countedFeedback()`. Public, pure Dart, shared by the server and the tool |
| `puls3_server/lib/src/ledger/soroban_reputation_registry.dart` | `recordsOf()` returns every record the registry lists, raw. `feedbacksOf()` is now exactly `countedFeedback(recordsOf())`: the adapter has no filter of its own |
| `puls3_server/tool/verify_reputation.dart` | Recomputes a rating from the raw records and compares it with the rating the server serves |
| `puls3_domain/test/feedback_record_test.dart` | Each exclusion reason; every record without one reaches the formula, in order; nothing is dropped without a public reason |
| `puls3_server/test/unit/ledger/soroban_reputation_registry_test.dart` | `recordsOf()` returns every listed record (including revoked, unreadable and off-scale ones); `feedbacksOf()` equals `countedFeedback(recordsOf())` |
| `docs/domain/reputation.md` | "Which on-chain feedback counts" and "How to verify a rating" |

The four reasons a record does not count:

| Reason | When |
|---|---|
| `unreadable` | Listed by the registry, but `read_feedback` cannot load it |
| `revoked` | Its submitter revoked it |
| `notWholeScore` | `value_decimals` is not 0 |
| `outOfScale` | The value is outside 1 to 5 |

## Rules

- Read-only. Contract reads are simulations; the server call is the public
  catalog (`agent.list`). No secret, no signature, nothing is broadcast.
- The server keeps a rating for 60 s (`reputationCacheTtl`). Right after a new
  feedback, run the check again after a minute before reading a mismatch.

## Run it

```bash
cd puls3_server
dart run tool/verify_reputation.dart <registryId>                 # deployed server
dart run tool/verify_reputation.dart <registryId> --api http://localhost:8080
```

`<registryId>` is the agent's id in the Identity Registry (the catalog's
`registryId`, for example `7` for Ledger Scout). Exit code: `0` match, `1`
mismatch, `2` a read failed.

## Evidence (testnet, 2026-11-06)

Reputation Registry `CBJZYEJ5DS7TDLA2ECRAW3ICQIYAOMTCQ5QSY7PYJ5PJ2W5EAHPBP5Q4`,
deployed server `https://puls3-hub-on-stellar.api.serverpod.space`.

Agent 7, one feedback on chain:

```
records  : 1 listed, 1 counted
  GABK…HF5H #1  value=5 decimals=0 revoked=false  counts

recomputed: rating 4.17, 1 counted feedback
served    : rating 4.17, paidHireCount 1
MATCH: the served rating is the formula over every counted on-chain record.
```

Agent 13, no feedback (the prior, 4.00):

```
records  : 0 listed, 0 counted

recomputed: rating 4.00, 0 counted feedback
served    : rating 4.00, paidHireCount 0
MATCH: the served rating is the formula over every counted on-chain record.
```

4.17 is `(5 · 4.0 + 5) / (5 + 1)`, rounded to two decimals, as in the worked
examples of [`docs/domain/reputation.md`](../domain/reputation.md).

## Tests

```bash
cd puls3_domain && dart analyze --fatal-infos && dart test
cd puls3_server && dart test test/unit/ledger/soroban_reputation_registry_test.dart test/agent/reputation_catalog_reader_test.dart
```
