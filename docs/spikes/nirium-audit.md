# Spike: Nirium receipts for a settled escrow job (#246)

## Verdict: go, as an asynchronous step after `complete`

A puls3 receipt for a settled escrow job was anchored on Nirium's testnet
Audit Trail and verified from IPFS **without calling Nirium**. The receipt
says which puls3 agent was paid, for which job, and how much. puls3 signs it.
The verifier recomputes the CID from the bytes the gateway serves, and checks
the record against the `complete` transaction and against the escrow job,
which binds the agent id to the wallet it pays. Twenty more anchors stayed
inside Nirium's published limit, with no rejection.

This is what Stellar alone does not give us. The transaction proves that
money moved from the escrow to an address. The receipt adds, under puls3's
signature, that the address is agent #7 and that the payment settled job 3.
The chain check means a signed receipt cannot lie about the payee, the agent
or the amount.

Go here means a follow-up issue for the hire flow, not code in `main`. What
that issue needs is in [What a real integration needs](#what-a-real-integration-needs).
The spending policy, Reporting and the auditor agent were not tried.

The code is in [`spikes/nirium-audit-dart/`](../../spikes/nirium-audit-dart/).
It is a standalone package and does not touch `puls3_server`, the contracts or
the app.

## What was anchored

The settled job is job 3 on the testnet escrow, from
[`docs/submission/serverpod.md`](../submission/serverpod.md):

| Field | Value |
|---|---|
| `complete` transaction | [`ee6dfb52…8e50c4`](https://stellar.expert/explorer/testnet/tx/ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4), ledger 5023908 |
| Escrow | `CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2` |
| Paid | 0.5 USDC to `GAFUYV5G…MIFKY`, the wallet of agent #7 (`agt-001`, Ledger Scout) |

The record is built from Horizon's answer for that transaction, not typed by
hand. It holds only data that is already public on the ledger: network,
escrow, job id, transaction, ledger, close time, asset, the escrow's transfers,
and the agent's registry id and wallet. It holds no prompt, result, secret or
data about the person who hired. A test pins the field list.

```json
{"agent":{"registry_id":"7","wallet":"GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY"},
 "asset":"USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5",
 "closed_at":"2026-10-04T19:45:27Z",
 "escrow_contract":"CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2",
 "job_id":"3","ledger":"5023908","network":"stellar:testnet",
 "schema":"puls3.escrow.settlement.v1",
 "settle_tx":"ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4",
 "transfers":[{"amount":"0.5000000","to":"GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY"}]}
```

The attesting key for the spike is
`GCOHAMUMAKDNXGVGIK2P7MUDBC4BHVINPJ7QXE2Z436BBMBV2RMIGWS4`. It is a throwaway
key generated for this run. Its secret was never committed.

## Evidence (Stellar Testnet, Nirium testnet node, 2026-11-07)

| Mode | CID | Anchor | Verified from IPFS |
|---|---|---|---|
| Full record | [`QmSSRjPw…a8TuB`](https://nirium.myfilebase.com/ipfs/QmSSRjPwEzpmr9xbEhgAc6xR1Y4rtjJyjckTELR1ra8TuB) | 1.9 s | yes |
| Hash only | [`QmUrMP68…JGkNWf`](https://nirium.myfilebase.com/ipfs/QmUrMP68deCRbwyt4EVgkjL2ENWMSgvRQzVFkjSTJGkNWf) | 3.3 s | yes, with the local record ([`evidence/job3-hash-anchor.json`](../../spikes/nirium-audit-dart/evidence/job3-hash-anchor.json)) |

Nirium computed the same `content_sha256` as puls3,
`16db1a9a…b9a7eaa`, and stored the record in the key order we sent. It echoed
the attesting key as `attestedBy`.

The verifier refused the same receipt when given another key as puls3's, and
refused the hash-only receipt when the record was missing.

### Twenty anchors inside the limit

Twenty hash-only anchors, one every 3.5 s, which is about 17 a minute against
Nirium's 20 a minute per IP. All the CIDs are in
[`evidence/measure-hash-20.json`](../../spikes/nirium-audit-dart/evidence/measure-hash-20.json).

| | p50 | p95 | max |
|---|---|---|---|
| Anchor (`POST /api/audit/log`) | 1.6 s | 1.8 s | 1.8 s |
| Verify (IPFS, signature, Horizon), 5 to 15 minutes after anchoring | 0.4 s | 0.8 s | 1.6 s |
| Verify again with the CID and the escrow job (Soroban RPC), 2026-11-08 | 2.5 s | 3.5 s | 4.0 s |

- **20 of 20 anchored**, with no 429 and no other error.
- **20 of 20 verified again** after findings 4 and 5 were closed, with the
  CID recomputed and the escrow job read. The two job 3 receipts also
  verified again. The extra time is the Soroban RPC read.
- **0 of 20 could be read from IPFS right after anchoring.** Nirium's Filebase
  gateway timed out after 20 s for each one. **5 to 15 minutes later, 20 of 20
  verified.** A CID is usable for verification only after it propagates. A real
  integration verifies later, never inside the hire request.
- `ipfs.io` and `dweb.link` failed with a TLS handshake error from the test
  machine. `curl` failed in the same way, so the cause is this Windows machine,
  not the gateways. Only Filebase was measured.

### What the limit means for puls3

One anchor per settled hire, from one server IP, allows 20 settled hires a
minute, about 28,800 a day. That is far above testnet traffic. A burst above
the limit should queue and retry on 429, which means anchoring runs outside
the `complete` request. Verification never calls Nirium, so it does not use
the limit.

## What the spike found

1. **Dart works without the npm SDK.** `POST /api/audit/log` is plain JSON.
   An ed25519 signature from `stellar_dart` verifies against Nirium's own
   fixtures, and Nirium accepts ours.
2. **Nirium's verifier accepts an unsigned document.** Its
   `verifyAuditDocument` returns `ok` when `agent` is missing (signature
   status `absent`). A puls3 receipt must be verified with the attestation
   required and the key pinned to puls3's. This verifier does both, and a test
   covers the unsigned case.
3. **A valid signature is not enough on its own.** Whoever holds the attesting
   key can sign a false record. The verifier therefore also compares the
   record with the `complete` transaction: escrow, job, ledger, close time,
   asset and transfers. It also refuses a receipt whose agent wallet was not
   paid (tested).
4. **The CID can be recomputed, so the gateway need not be trusted.**
   Nirium's verifier does not recompute it. Nirium adds each document as one
   dag-pb UnixFS block with a CIDv0 (`Qm…`), and the CID of the bytes the
   gateway serves is the sha-256 of that block. The verifier recomputes it
   and skips a gateway whose bytes do not match. Both live CIDs recompute
   exactly, and tests use the served bytes. This covers documents of one
   block (up to 256 KiB, a receipt is about 1 KiB). A `bafy…` CID or a larger
   document is refused, not trusted.
5. **The agent is checked against the escrow job, not the current registry.**
   `create_job` accepts a job only when its `provider` is the identity
   registry's wallet for its `agent_id` (`verify_provider`), and the job
   keeps both. The verifier reads the job with Soroban RPC
   (`getLedgerEntries`, no transaction, no signer) and requires the same
   agent id, the same wallet, and the `Completed` state. Reading the
   registry's `get_agent_wallet` today would be wrong for old receipts: a
   wallet rebound later (#209) would fail every earlier receipt of that
   agent. This is item 2 of the letter of intent, answered with data the
   chain already keeps. Limit: a job entry archived after its TTL cannot be
   read until it is restored, so verification of an old receipt can fail
   for that reason.
6. **Full record or hash only.** Every field of this record is already public
   on the chain, so anchoring the full record costs no privacy and lets anyone
   verify with only the CID. Hash only keeps the record off IPFS, but then
   puls3 must serve the record for anyone to verify it. Recommendation: full
   record, as long as the record holds public chain data only.
7. **Testnet resets.** After a testnet reset Horizon forgets the transaction,
   so a testnet receipt can no longer be matched to the chain. Mainnet does
   not have this problem.

## What a real integration needs

These items are for a follow-up issue, not this spike.

- An attesting key for puls3, kept like the other server secrets
  (`docs/infra/secrets.md`), with its public key published somewhere a
  verifier can find it, for example in an ADR.
- After `complete` is confirmed: build the record from the confirmed
  transaction, and anchor it from a queue that retries on 429 and never blocks
  the hire.
- Store the CID with the hire, and show it on hire detail once it verifies.
- Read the escrow job with the receipt, and decide how long job entries stay
  live (finding 5).
- Fees: free during the beta. After the beta, a per-request fee over x402 is
  to be agreed with Nirium beforehand (letter of intent).

## Not tried

- The spending policy: experimental in `nirium` 0.16.0, with an open gap where
  code next to the signer can sign around the hook.
- Reporting, the auditor agent, mainnet, and any payment to Nirium.
- Any key or custody given to Nirium. Nirium read only public data.

## Run it

See [`spikes/nirium-audit-dart/README.md`](../../spikes/nirium-audit-dart/README.md).
