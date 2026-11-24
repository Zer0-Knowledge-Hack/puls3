# ADR-0009: A rating keeps counting after its escrow job archives

- **Status:** Proposed
- **Date:** 2026-11-17
- **Issue:** #273 (follow-up of #201 and #239)
- **Related:** [ADR-0008](0008-reputation-formula-off-chain.md) · [ADR-0002](0002-agent-registry-on-soroban.md) (Reputation Registry, #201 amendment) · [ADR-0005 D5](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md)

## Context

Since #239 a rating counts only when the configured escrow's `get_job` says its job is `Completed` for the same client and agent. A `Job` is a persistent entry that archives after `TTL_BUMP` (about 60 days) unless someone calls `extend_ttl(job_id)`. Once it archives, `get_job` through a simulation answers `restorePreamble`, the reader marks the rating `jobUnreadable`, and the agent's score decays back to the prior. #239 keeps final job states in memory, so a completed job keeps counting while the process runs and stops counting after a restart.

Facts checked for this decision:

- Archived is not deleted. Since Protocol 23 an archived entry in a transaction's restore list is restored by the same signed `InvokeHostFunction` transaction ([state archival](https://developers.stellar.org/docs/learn/fundamentals/contract-development/storage/state-archival#contract-data-automatic-restoration)). A simulation never restores anything, and puls3's server never signs.
- `extend_ttl(job_id)` already exists on the escrow and is permissionless (`contracts/contracts/escrow/src/lib.rs`). Keeping a job alive does not need a contract change, so it does not need a new audit; it needs someone to call it before the TTL runs out, for as long as ratings should count.
- On the testnet escrow there is no archived job yet (29 jobs, all readable on 2026-11-17), so the cost of a restore is not measured. This ADR does not assume one.

## Decision

**Option (a), as a fallback that is subordinate to the chain.** The server keeps the facts of every job it reads in a final state (`Completed`, `Rejected`, `Expired`) in `terminal_job_fact`: escrow, job id, client, agent id, final state and when it was read.

1. `get_job` is always read first. A readable job is the chain's answer, and a stored fact never overrules it.
2. A stored fact is used only when `get_job` reports the entry archived. A job with no stored fact stays `jobUnreadable`, as before: archived entries still drop only their own record, never an agent's whole reputation.
3. A final state never changes, so the first fact stored for a job is kept (unique on escrow and job id).
4. If the store cannot be read for an archived job, the whole read fails. It is never reported as "no rating". If it cannot be written, the job that the chain just answered still counts, and the write is tried again on the next read.
5. No contract change, no signing server, no restore.

## What this costs, honestly

ADR-0008 says a rating is trustworthy because anyone can recompute it from the chain. For an archived job, a third party who does not restore the entry sees `jobUnreadable`, while puls3 serves the rating from its own table. The two can differ until the job is restored. The table holds only facts the server itself read from the escrow, so an auditor can check each row against the chain by restoring the entry, but a table that is lost or edited changes the served score without a trace on chain.

## Not decided here

- **Restoring archived jobs from the server** (a funded server account paying a restore) and **a keeper that calls `extend_ttl`** would keep the whole rating on chain. Both need a decision on who signs and pays, and a measured cost. They are tracked apart from #273.
- Archived escrow instance or code, and escrow rotation, are the other items of #273 and have their own changes.

## Escrow rotation (#273, item 3)

A rating names its job as `puls3:job:v1:<escrow>:<job id>`, so a job is its escrow and its id: the same id on two escrows is two jobs.

1. **The reader trusts a list.** `PULS3_STELLAR_ESCROW` is the escrow new hires use. `PULS3_STELLAR_PREVIOUS_ESCROWS` (comma-separated) lists the ones it replaced. A reference to any escrow outside the two is still `otherEscrow`, and each job is read from the escrow its reference names. `FeedbackProvenance` holds `escrows` and keys its jobs by reference; the verification script reads the same list as the server.
2. **The hire stores its escrow.** `hire.escrow` is set when the `create_job` is confirmed, to the escrow the tracker reads the event from, and `give_feedback` names that escrow in the reference and the commitment. The column is nullable and added without a backfill.
3. **A hire without an escrow means the configured one.** That covers hires created before the column and hires without a job.
4. **Before the first rotation, old hires get their escrow from the chain (#307).** In each environment that has hires, an operator runs `puls3_server/tool/backfill_hire_escrow.dart --escrow <the escrow they were funded on>`, first as a dry run and then with `--apply`. For every hire with a job and no escrow, it reads `get_job` on that escrow and writes the address only when the job is there for the same client and agent. Anything else stays empty and is reported:
   - no such job;
   - a job for another client or agent;
   - an archived job whose hire has no confirmed `create_job` on that escrow.

   **An archived job is not a hole** (#384 review). `get_job` cannot read it, so the tool reads the hire's confirmed `create_job` submission, whose signed envelope the server already stores (`chain_submission`). When that envelope invoked `create_job` on the escrow passed in, the job was created there, and the address is written (`matchedFromEnvelope`). That covers the oldest hires, which are the ones most likely to archive first. It does not depend on how #336 keeps rated jobs alive.

   **Why not a migration.** A migration runs on every database, local and test ones included, whose hires may come from another escrow, and a wrong backfill is hard to undo. This tool writes only what the chain confirms, never overwrites a hire's own escrow, and can be rerun. It is the reason an escrow rotation's checklist starts with this run.

Not covered: hires that are still in flight when the escrow is rotated (prepared, funded or settled through the new escrow). The relay and the deadline runner use the configured escrow for every call, so this change keeps their ratings checkable, not their settlement.
