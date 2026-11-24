# Rotating the escrow: from 0.1.0 to 0.2.0

Escrow 0.2.0 (#358) adds fields to `Job`, so a job stored by 0.1.0 does not
decode under 0.2.0 (#376). This page is how the testnet deployment moves to
0.2.0 without stranding any job, and what is on the current escrow today.

## The path: a fresh contract id, and the old escrow drains in place

**The escrow has no upgrade function.** Its WASM cannot be replaced, so 0.2.0
is always a new contract with a new id. Teaching 0.2.0 to decode a 0.1.0 job
would not help either: the two contracts never share storage.

So the path is:

1. Deploy 0.2.0 as a new contract.
2. Point the server at it.
3. Leave the old escrow running its own code for its own jobs.

Nothing on the old contract changes. Each of its jobs keeps the transitions
it has today:

| State | Funds held | How it ends on the old escrow |
|---|---|---|
| `open` | none (never funded) | nothing to do. The client can still cancel it (`reject` from `open`) |
| `funded`, past `expired_at` | the budget | `claim_refund(job_id)`. Anyone can call it, and it pays only the client |
| `submitted`, past `approval_deadline` | the budget | `release(job_id)`. Anyone can call it, and it pays the provider |
| final (`completed`, `rejected`, `expired`) | none | nothing. Keep it readable for ratings (ADR-0009) |

Ratings keep counting: the server lists the old escrow in
`PULS3_STELLAR_PREVIOUS_ESCROWS`, and each rating reference names its own
escrow (ADR-0009, "Escrow rotation").

## What is on the testnet escrow (read on 2026-11-21)

`CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2` has
`job_count` 37. All of them were read with `get_job`, and every one is
readable: none is archived. **12 are not final, and all are past `expired_at`**:

| Job | State | Budget (USDC) | Agent | Ends with |
|---|---|---|---|---|
| 1 | `submitted` | 0.50 | 7 | `release` (pays the provider) |
| 4, 5, 7, 8, 9, 10, 12, 21 | `funded` | 0.10 each, 0.80 in all | 13 | `claim_refund` (pays each client) |
| 11 | `open` | 0.10, never funded | 13 | nothing |
| 13 | `open` | 1.25, never funded | 8 | nothing |
| 24 | `open` | 4.50, never funded | 9 | nothing |

**Held by the old escrow: 1.30 testnet USDC** (0.50 + 0.80). The other 25 jobs
are final.

To read it again, for each id from 1 to `job_count` (with
`$ESCROW` and `$SRC` from [on-chain verification](../verification/onchain.md)):

```bash
stellar contract invoke --id $ESCROW --network testnet --source-account $SRC --send=no -- job_count
stellar contract invoke --id $ESCROW --network testnet --source-account $SRC --send=no -- get_job --job_id <id>
```

## The rotation, step by step

Run it on testnet first. Each step is done by a maintainer: the deploy and
the drain calls need a funded Stellar identity to pay fees. No step needs the
escrow admin to touch a job.

1. **Store the escrow on old hires** (#307, tool added in #384). With the server's database and the
   old escrow still configured, run from `puls3_server/`:

   ```bash
   dart run tool/backfill_hire_escrow.dart --escrow <old escrow>          # dry run
   dart run tool/backfill_hire_escrow.dart --escrow <old escrow> --apply
   ```

   Every hire then names the escrow it was funded on, so it does not point to
   the new one after step 4.
2. **Deploy 0.2.0.** Run `scripts/deploy-escrow-testnet.sh --redeploy` from the
   identity that will be the admin. It builds, deploys, allow-lists USDC and
   records the new contract in `contracts/deployments/testnet.json`. Then
   check:
   - `version()` returns the new version. **On `main` it still returns
     `0.1.0`** (`CONTRACT_VERSION` in `contracts/contracts/escrow/src/lib.rs`),
     although #358 changed the `Job` format. Bump it before this deploy, so the
     two contracts can be told apart on chain;
   - `identity_registry()` returns the registry in `testnet.json`.
3. **Hand over the admin** if the deploy identity is not the long-term admin:
   `set_admin`, then `accept_admin` (the D-1 hand-over in #382).
4. **Point the server at it.** Set `PULS3_STELLAR_ESCROW=<new escrow>` and
   `PULS3_STELLAR_PREVIOUS_ESCROWS=<old escrow>`, then deploy the server. New
   hires use the new escrow, and ratings of old jobs still count.
5. **Drain the old escrow.** Do this before or after step 4, in any order:
   - `claim_refund(job_id)` for each `funded` job past `expired_at`;
   - `release(job_id)` for each `submitted` job past `approval_deadline`.

   Each call is permissionless and pays only the job's client (refund) or
   provider (release). Read the list again just before, because a client may
   have done it already.
6. **Keep rated jobs readable.** A `completed` job on the old escrow that backs
   a rating needs `extend_ttl(job_id)` before it archives, or it falls back to
   the server's stored fact (ADR-0009).
7. **Update the evidence.** Update the README's on-chain evidence, and the
   SOW evidence page once it lands (#383), to name both escrows: the old one
   for the recorded hires, the new one for hires after the rotation.

## Not covered

- **Hires in flight during the switch.** The server's relay and deadline
  runner call only the configured escrow (ADR-0009, "Not covered"). So switch
  when no hire is between `create_job` and its settlement on the old escrow.
  A job left funded there still ends through step 5, outside the app.
- **Mainnet**, which has no deployment yet.
