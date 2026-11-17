# Keep paid-job ratings after the escrow job archives, survive escrow rotation (#273)

Objective: implement the four items of #273 (follow-up of #201). Branch `fix/273-rating-archive-escrow-rotation` (worktree `puls3-worktrees/fix-273-ratings`). Delivery: `ask-on-risk`, max 4 chained PRs. Runner: `dart test` (server, domain), `dart analyze --fatal-infos`, `serverpod generate`.

## Specs
- **S1** (item 1) "a rating still counts after its job archives, including across a restart." Decision (user-confirmed): option (a), "The server stores the terminal job facts it read (job id, client, agent, final state) and reads them before `get_job`" is changed by the user's decision to: the stored fact is a read **fallback subordinate to the chain**, used only when `get_job` reports the job archived, and never overriding a readable job. Restore (c) and a keeper (b') are out of scope (separate issue). Recorded in a new ADR.
- **S2** (item 2) "an archived escrow instance or code is reported as unavailable, never as "no ratings", without letting one archived job reference fail an agent's whole reputation."
- **S3** (item 3) "the escrow is stored per hire, and the reader accepts the configured list."
- **S4** (item 4) "linked to #200, with the minimum amount decided there." (comment only, no code)

## Tasks
- [x] **T1** (S1) Terminal job fact store + registry fallback + ADR-0009. Route: inline. Risk: item 1 (new persisted table, additive migration only). Checks: unit suite 833 pass, analyze clean; Postgres integration test written but NOT run (Docker daemon down).
- [x] **T2** (S2) Distinguish archived escrow instance/code from an archived job (job_count probe in ContractEscrowJobReader). Route: inline. Risk: none (only the registry reads `archived`). Checks: 1164 unit tests pass, analyze clean.
- [x] **T3** (S3) Escrow column on hire (migration) + trusted escrow list in domain/reader. Route: inline. Risk: items 1, 3. Decision (user, 2026-11-17): pre-existing hires use the configured escrow (null = configured); backfill option tracked in #307. Done on branch fix/273-escrow-per-hire: domain escrows list + reference-keyed jobs, StellarConfig.previousEscrows, hire.escrow column, give_feedback names the hire escrow, verify script. Postgres integration tests NOT run (Docker down).
- [ ] **T4** (S4) Comment on #200. Route: inline.

## Log
- L1 (2026-11-16, user): "Implementa la #273 en un nuevo git worktree."
- L2 (2026-11-17, user): confirmed "(a) subordinada a la cadena", restore/keeper left for a separate issue. Evidence: no archived job on testnet escrow (29 jobs, all live); restore cost unmeasured; Protocol 23 restores inside a signed InvokeHostFunction, a simulation cannot restore.
