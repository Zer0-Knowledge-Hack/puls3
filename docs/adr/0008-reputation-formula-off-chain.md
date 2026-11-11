# ADR-0008: The reputation formula stays off chain

- **Status:** Proposed
- **Date:** 2026-11-10
- **Issue:** #203 (security audit of 2026-10-25, follow-up; related findings R-2a, R-2b, R-4)
- **Related:** [reputation formula](../domain/reputation.md) · [verifying a rating](../verification/reputation.md) · [ADR-0005 D5](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md#d5-own-registries-drop-in-compatible-with-stellar-8004) · [ADR-0002](0002-agent-registry-on-soroban.md)

## Context

The audit asked whether the reputation score itself should be computed on chain, instead of by the server.

What is on chain today, and what is not:

- **The raw ratings are on chain.** Each feedback is a record in the Reputation Registry (#14): agent id, client, value, decimals and revocation.
- **The score is off chain.** The server reads every record of an agent, keeps the ones that count, and serves `reputationOf()` from `puls3_domain`. That is a Bayesian average with prior mean `m = 4.0` and prior weight `C = 5` ([formula](../domain/reputation.md#formula)). The catalog keeps each value for 60 s.
- **The contract has a different aggregate.** `get_summary` returns the plain average of the non-revoked records of the clients the caller passes. Since the R-4 fix (#205, merged in #241) it reads at most `MAX_SUMMARY_CLIENTS` (5) clients and `MAX_SUMMARY_RECORDS` (50) records, and does not count records past the cap. The app and the server do not call it.
- **The score can already be checked.** R-2b (#202, closed) added `scripts/verify_reputation.dart`. It recomputes an agent's score from the raw records with the same domain code and compares it with what the server serves ([evidence](../verification/reputation.md#evidence-testnet-2026-11-06)).
- **Which ratings come from a paid hire is still open.** R-2a (#201) ties each rating to its paid hire; its PR (#239) is a draft.

## Decision

**The formula stays off chain, in `puls3_domain`. What makes it trustworthy is that anyone can recompute it from the chain, not that a contract computes it.**

1. The registry keeps storing the raw feedback, with the Stellar 8004 interface (ADR-0005 D5). No contract change.
2. `reputationOf()` in `puls3_domain` stays the only implementation of the formula. The server and the verification script both call it, so they cannot drift apart.
3. Every rule that decides whether a record counts is public code (`exclusionOf` in `puls3_domain`). The server adds no filter of its own, as R-2b established.
4. `get_summary` stays as the Stellar 8004 compatibility read. puls3 does not show it as "the" score, and the docs do not present it as one.
5. Paid-hire provenance (R-2a, #201) is added the same way, as a public rule that a verifier can apply, not as an on-chain aggregate.

## Why not on chain

| Concern | On chain | Off chain (this decision) |
|---|---|---|
| **Compute limits** | An aggregate over every record of an agent grows with the number of ratings. R-4 had to cap `get_summary` at 5 clients and 50 records, so an on-chain score over a real track record would be partial by construction. | The server pages through every record with simulated reads, which cost no fee. |
| **Stellar 8004 drop-in** | A new aggregate function, or a different `get_summary`, breaks the identical interface that ADR-0005 D5 keeps for the ecosystem's tools. | The registry interface does not change. |
| **Changing the formula** | `m` and `C` are product choices. On chain, each change is a contract upgrade: `propose_upgrade`, then a `TIMELOCK_LEDGERS` (51,840 ledgers, about 3 days) wait, then `execute_upgrade`. | A change is a code change in `puls3_domain`, reviewed like any other, and the same commit updates the verification script. |
| **Who can check the score** | Anyone, by reading the contract. | Anyone, with `scripts/verify_reputation.dart` or by hand with `stellar contract invoke --send=no` and the documented formula. |
| **Trust in the server** | The server cannot change the score. | The server could serve a wrong score. The script would show it as `MISMATCH`, but nothing stops the server from serving it. |

The last row is the cost of this decision. It is accepted for the testnet product because the raw records are on chain and the check is public and cheap.

## Consequences

- Changing `m` or `C` needs a PR that updates `docs/domain/reputation.md` and the worked examples in `puls3_domain/test/reputation_test.dart`. No contract work is involved.
- Anyone who reads `get_summary` directly gets a plain average over a capped set of records. That number can differ from the puls3 score, and that is expected.
- Verification reads the registry as it is now. Soroban has no read at a past ledger, so a past score cannot be recomputed ([limitations](../domain/reputation.md#limitations)).
- Reading every record of every agent grows with the number of ratings. The 60 s cache covers testnet. A larger catalog needs an indexer or incremental reads, and that is a scaling task, not a reason to move the formula on chain.

## Revisit when

- **Before mainnet**, together with the other audit follow-ups in #206. If puls3 needs a score that the server cannot misreport, the next step is an indexer or a signed attestation that anyone can check against the chain. A full on-chain aggregate is not the next step, because of the compute limits above.
- **If R-2a lands with on-chain provenance** that a contract could check cheaply. The decision would then be revisited with a budget and limits analysis, as #203 asks for an "on-chain" outcome.
