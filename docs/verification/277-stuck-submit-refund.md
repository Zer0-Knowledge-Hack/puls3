# #277 verification: a funded hire whose submit cannot land is refunded by the consumer

This record covers the two testnet acceptance criteria of #277 that #292 left pending. The runs
were made on 2026-11-25 (UTC) with `puls3_server/tool/e2e_stuck_submit_refund_testnet.dart` on
`main` after #292.

| Criterion (#277) | Evidence |
| --- | --- |
| A funded hire whose submit cannot happen shows the reason and Reject and refund; the reject confirms on testnet and returns the USDC. | **Run 1:** the escrow refused the agent's `submit` with `SubmitTooLate` (#106). `getHire` reported `funded` with `submitErrorCode: SubmitSimulationRejected` and no result. The consumer signed `reject` from `funded`, and the price came back. |
| A `Funded` job past `expired_at` can be refunded from the app with the consumer's signature, with no server key. | **Run 2:** `escrowRelaySigningKey` was unset (the tracker logged "release and claim_refund stay off"). Before `expired_at`, `prepareClaimRefund` refused with `InvalidHireTransition`. After it, the hire was still `funded`, and the consumer signed `claim_refund`, stored as a consumer-prepared record. The price came back. |

The app side of both criteria (the reason, **Reject and refund**, **Claim refund**, "Funded ·
Recording") is covered by the widget tests of #292 (`hire_detail_screen_test.dart`). These runs
exercise the same endpoints the app calls: `getHire`, `prepareReject`, `prepareClaimRefund` and
`submitEscrowCall`.

## Setup

- **Network:** Stellar Testnet. Escrow `CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`
  (`approval_window` 86400 s), token Circle testnet USDC SAC
  `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA`.
- **Consumer:** [`GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H`](https://stellar.expert/explorer/testnet/account/GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H).
  It signs every transaction below.
- **Agent:** registry id 13, "Support Relay", price 0.1 USDC, payee
  `GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY`.
- **Server:** the real `HireEndpoint`, hire wiring and chain tracker in Serverpod `--mode test`.
  They ran against a fresh local database (`SERVERPOD_DATABASE_NAME=puls3_e2e_277`), which was
  dropped after the run. `PULS3_HIRE_JOB_DURATION_SECONDS=360`, shorter than the approval window,
  so the agent's `submit` can never land.
- **The seam:** `createHire` refuses an agent whose payee is not custodied (#276). The tool
  adds a placeholder `agent_wallet` row for the payee in the local database and removes it at
  the end. That row has no usable key, and the tool fails if the submit sender tries to sign.

## Run 1: Reject and refund

Hire 1, escrow job 40. The agent's `submit` went through the runtime's `AgentSubmitSender`,
and the simulation returned contract error #106 (`SubmitTooLate`, terminal).

| Step | Ledger | Transaction |
| --- | --- | --- |
| `create_job` | 5910729 | [`1ae40b05…17a803af`](https://stellar.expert/explorer/testnet/tx/1ae40b05b182c9caf53801be37daf6be53a1cbdcda1b7835387841c617a803af) |
| `fund` | 5910730 | [`50e75a02…e18258b8`](https://stellar.expert/explorer/testnet/tx/50e75a024e46c37aaea1c8163b8f773fd57e1dde0cc0261ec9bf1dd1e18258b8) |
| `reject` (from `funded`) | 5910731 | [`2c31cfdd…95b7b02`](https://stellar.expert/explorer/testnet/tx/2c31cfdddc0fe1713106f10a73b4422a35ed9d8fddb9f224e76f8a6db95b7b02) |

Consumer USDC (Horizon): 17.4 → 17.3 after `fund` → 17.4 after `reject`.

## Run 2: Claim refund after expiry

Hire 2, escrow job 41, `expired_at` 2026-11-25 03:34:23 UTC.

| Step | Ledger | Transaction |
| --- | --- | --- |
| `create_job` | 5910732 | [`ce4a8562…9a2f2caa`](https://stellar.expert/explorer/testnet/tx/ce4a85625bb40b320cdb6273220104156fac3966a444e1881bc413469a2f2caa) |
| `fund` | 5910733 | [`f979becf…71a93e9e`](https://stellar.expert/explorer/testnet/tx/f979becfd6ecfb4e4de44bd8bc45828fde1087b729e2da870f48872871a93e9e) |
| `claim_refund` (consumer-signed, after expiry) | 5910809 | [`09edbdbc…877f88af`](https://stellar.expert/explorer/testnet/tx/09edbdbcebbd588a367866c0d914a87bf859c253116b36106d88538b877f88af) |

Consumer USDC (Horizon): 17.4 → 17.3 after `fund` → 17.4 after `claim_refund`.

Every transaction above returns `successful: true` from Horizon, with the consumer as the source
account.

## Reproduce

See "Stuck submit refund proof on testnet (#277)" in `puls3_server/README.md`. Use a fresh
database: the shared `puls3_test` may hold hires of another escrow (the local sandbox), whose
job ids clash with the testnet ones on `hire_job_id_idx`.
