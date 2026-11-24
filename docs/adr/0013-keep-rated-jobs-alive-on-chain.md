# ADR-0013: Keep rated jobs alive on chain with a TTL keeper

- **Status:** Proposed
- **Date:** 2026-11-21
- **Issue:** #336 (follow-up of #273 and ADR-0009)
- **Related:** [ADR-0009](0009-ratings-after-the-escrow-job-archives.md) (the server table fallback) · [ADR-0008](0008-reputation-formula-off-chain.md) (anyone can recompute a rating)

## Context

A rating counts only while `get_job` can read its escrow job. A job is a persistent entry that archives when its TTL runs out. ADR-0009 added a server table of the final job facts as a fallback. That table is something a third party cannot check without restoring the entry. #336 asks what keeping the job readable on chain would really cost, with measurements.

## Measurements

All of them were taken on **testnet, 2026-11-21, ledger 5 850 554**, read-only. Nothing was signed or submitted.

- **Method:**
  - `getLedgerEntries` for the network's `STATE_ARCHIVAL` config, and for the escrow's `Job(id)` entries, its instance and its code;
  - `simulateTransaction` of escrow `extend_ttl(job_id)`, unsigned, built with the server's `encodeInvokeEnvelope`.
- **Escrow:** `CBRD7A7M…TPE2`, WASM `15f98ea5…` (the deployed 0.1.0).

### The network

| Setting | Value | In time (5 s ledgers) |
|---|---|---|
| `min_persistent_ttl` | 120 960 ledgers | about 7 days |
| `max_entry_ttl` | 3 110 400 ledgers | about 180 days |
| `persistent_rent_rate_denominator` | 1215 | |

**Does a restore last? No.** Since Protocol 23, a restored entry comes back with the network's minimum persistent TTL, here about 7 days, and then archives again unless it is extended. So restoring is not a one-off: it has to be followed by an `extend_ttl`, and a job that is extended in time never needs a restore.

### The jobs

| Job | TTL left | `extend_ttl` minimum resource fee | What the call does |
|---|---|---|---|
| 2 (completed, 2026-10-04) | 209 996 ledgers, **about 12 days** | 629 336 stroops (**0.063 XLM**) | extends to `TTL_BUMP` (1 036 800 ledgers, about 60 days): about 48 more days |
| 3 (completed, the README's evidence job) | about 12 days | 629 336 stroops | same |
| 30, 35 (completed, 2026-11-17/18) | about 56 days | 6 564 stroops | nothing to extend yet (above `TTL_THRESHOLD`): the cost of the read |

- **The escrow instance and code** are live for about 52 more days. Each `extend_ttl` also extends the instance.
- **Rent:** 629 336 stroops for 826 649 ledgers is about 0.76 stroops per ledger for one `Job` entry.
- **A keeper's cost:** about **0.04 XLM per job per 30 days**. That is 1.46 XLM a month for all 37 jobs on the testnet escrow, plus a 100-stroop inclusion fee per call.

**Not measured:** the cost of a restore. No escrow job is archived yet. The first two, jobs 2 and 3, archive around **2026-12-03**. A restore is not needed on the path decided below, so it was not forced on the local sandbox.

## Decision

1. **Keep rated jobs alive with a keeper, before they archive.**
   - Every final job that backs a counted rating gets an `extend_ttl(job_id)` when its TTL falls below `TTL_THRESHOLD`, about 30 days.
   - `extend_ttl` is permissionless and needs no contract change, so it needs no new audit.
   - Each call buys at least 30 more days, so a keeper that runs weekly never lets a rated job archive.
2. **The keeper signs with its own funded account.** It is not the escrow admin, not the reputation owner and not an agent's custodied wallet (D-1, #206). Its secret is a server secret like the others, and it holds only XLM for fees: losing it can cost that balance and nothing else. puls3 pays for it as a platform cost, at the rate above.
3. **No restore from the server.** A restored entry lasts about 7 days, so restoring is the expensive way to do the same thing. It remains a manual operation, by anyone, for a job that the keeper missed.
4. **The server table of ADR-0009 stays, as the fallback.** It answers only for an archived job, a case that should no longer happen once the keeper runs. The audit limit it accepts is unchanged: a third party who does not restore the entry cannot check such a rating.

## Until the keeper exists

- **Jobs 2 and 3 archive around 2026-12-03.** Job 3 is the escrow evidence of record in the README.
- A maintainer can call `extend_ttl(3)` (and `extend_ttl(2)`) before then, from any funded testnet identity:

  ```bash
  stellar contract invoke --id CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2 --network testnet --source-account <identity> -- extend_ttl --job_id 3
  ```

  It costs about 0.063 XLM and keeps the job readable for about 60 more days.

## Implementation (not in this ADR)

The keeper is a server loop, like the chain tracker:

- it lists the final jobs whose ratings count;
- it reads each one's TTL (`getLedgerEntries`);
- it signs and submits `extend_ttl` for those below the threshold.

It needs a new secret (`PULS3_TTL_KEEPER_SECRET_KEY`) documented in `docs/infra/secrets.md`. It also needs a test that a rated job is extended before it archives, and that its rating still counts without the server table. It starts once this ADR is accepted.
