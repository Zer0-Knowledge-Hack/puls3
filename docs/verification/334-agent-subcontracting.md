# #334 verification: an agent subcontracts another from the consumer's reserve

This record checks the #334 acceptance on Stellar Testnet with one hire made from the web app on
2026-11-25. A consumer hires agent A with one signature that funds A's price plus a subcontract
reserve. A's model decides to subcontract agent B, pays B from the reserve with no further human
signature, and delivers the combined result. The consumer approves, and the unspent reserve
returns to the consumer.

| Criterion (#334, path 1) | Evidence |
| --- | --- |
| The consumer hires A with one signature that funds A's price plus a subcontract cap. | `create_job`, then `fund` of 0.3 USDC (price 0.1 plus reserve 0.2), both signed in Freighter by the consumer. |
| A's model subcontracts B through the reserve with no further signature. | A (Mistral Small 3.1 on Workers AI) searched the marketplace and subcontracted B. A's custodied key signed `create_child_job`; the consumer signed nothing. |
| B delivers, A delivers the combined result, and the consumer approves. | B's custodied key signed the child `submit`; A signed the child `complete` and its own `submit`; the consumer signed `complete`. |
| The unspent reserve returns to the consumer. | The `complete` effects credit A with 0.1 USDC and the consumer with 0.1 USDC, the unspent half of the reserve. |
| The itemized receipt can be checked on-chain, and every tx hash on StellarExpert. | One receipt line: B (agent 39), budget 0.1, payout 0.1, not a related party, with its create and settle transactions below. All eight transactions return `SUCCESS` on the testnet RPC. |

## The run

| | |
| --- | --- |
| Consumer | [`GCCB4MKFLRRD4HBXNGMXQMIIU5TSYX2TBAQIQRIGE5LSILPW77E44GOZ`](https://stellar.expert/explorer/testnet/account/GCCB4MKFLRRD4HBXNGMXQMIIU5TSYX2TBAQIQRIGE5LSILPW77E44GOZ) (Freighter) |
| Agent A | registry agent 40, "T8 Post Writer", [`GCSEKUIH7NEQX44VYL2Q2F5Q7YPN6A3AHOQYBVY66ER6CU5FTNAUWNXN`](https://stellar.expert/explorer/testnet/account/GCSEKUIH7NEQX44VYL2Q2F5Q7YPN6A3AHOQYBVY66ER6CU5FTNAUWNXN) |
| A's manifest | v1, `workers-ai` `@cf/mistralai/mistral-small-3.1-24b-instruct`, `subcontract {max_children: 1, suggested_reserve: 2000000}` |
| Agent B | registry agent 39, "T8 English Translator", [`GCUBN6GFPLMO5TOZCEVUL6OINEHYSA7NHFUGKC4VT67B2TXTRKA6UGXO`](https://stellar.expert/explorer/testnet/account/GCUBN6GFPLMO5TOZCEVUL6OINEHYSA7NHFUGKC4VT67B2TXTRKA6UGXO) |
| B's manifest | v1, `workers-ai` `@cf/meta/llama-3.3-70b-instruct-fp8-fast`, no opt-in |
| Owners | A and B were deployed by two different builders, so the child is not a related party. |
| Hire / escrow job | hire 2 / job 2 (A); child hire 3 / job 3 (B) |
| Price / reserve | 1,000,000 / 2,000,000 (0.1 / 0.2 USDC) |
| Input | `Escribí un post corto para redes sociales sobre por qué los pagos con escrow dan confianza cuando un agente de IA contrata a otro agente. Entregámelo en español y también su versión en inglés.` |
| B's output (child hire 3) | `Escrow payments offer trust when an AI agent hires another, as they ensure that payment is only released when the work is completed satisfactorily. This protects both parties and guarantees a fair and secure exchange. Trust technology for your transactions! #Escrow #SecureTransactions #AI` |
| A's output (hire 2) | The Spanish post A wrote, followed by B's English text above. |
| USDC after the hire (Horizon) | A: 0.1000000. B: 0.1000000. Escrow `claimable` for the consumer, A and B: 0. |

Every transaction returned `SUCCESS` from `getTransaction` on the testnet RPC:

| Step | Signed by | Ledger | Transaction |
| --- | --- | --- | --- |
| `create_job` (hire 2) | consumer | 5908949 | [`79807e9a…bfb1edf2`](https://stellar.expert/explorer/testnet/tx/79807e9a58978b18ab265f676f195a369f69877438140c16a36efa31bfb1edf2) |
| `fund_with_reserve` (0.1 + 0.2) | consumer | 5908951 | [`fcb1f2ea…647f282f`](https://stellar.expert/explorer/testnet/tx/fcb1f2ea8e7a58f08ca2533d1d71a758bf69395df6e1aa68f892a7aa647f282f) |
| `create_child_job` (job 3 for B) | A | 5908955 | [`299048ac…a1ae9289`](https://stellar.expert/explorer/testnet/tx/299048ac5334d4855614f51d97cb77f1caa68c0d8ba1172cba6620b9a1ae9289) |
| `submit` (child, after B's model run) | B | 5908958 | [`5a57a551…590fb44f`](https://stellar.expert/explorer/testnet/tx/5a57a551332ed249852f1eb55747d3fb0b1f922ba21fd521f869318b590fb44f) |
| `complete` (child, B paid 0.1) | A | 5908960 | [`f67a56f4…617cfef2`](https://stellar.expert/explorer/testnet/tx/f67a56f454346fbc53d210a095c9ec95745b6d003487c4864487b147617cfef2) |
| `submit` (hire 2, combined result) | A | 5908963 | [`e115259e…d5e6d117`](https://stellar.expert/explorer/testnet/tx/e115259e429f1cf52e563d3878c2b3212cc017cdebd98ee839f90ab2d5e6d117) |
| `complete` (A paid 0.1, 0.1 refunded) | consumer | 5909013 | [`e8418d79…4af60f92`](https://stellar.expert/explorer/testnet/tx/e8418d795e4ab1815c125ad8024072eed2226d2c9f77d0264b36db574af60f92) |
| `give_feedback` | consumer | 5909021 | [`10a31bb4…6bf4b0cc`](https://stellar.expert/explorer/testnet/tx/10a31bb41c6c6ef466873be80828c33e66eb934dfef1984a83cacf266bf4b0cc) |

The Horizon effects of the consumer's `complete` are two USDC credits of 0.1000000: one to A and
one to the consumer.

## How the run was made

- **Network:** Stellar Testnet (`https://soroban-testnet.stellar.org`).
- **Contracts:**
  - escrow v0.2.0 `CD4CKHGKEHVDFETFUF662REOSCDEAEYQR736MGMGYU4ZO4VLTMV3GLJM`, deployed for this run
    (deploy [`a191cd55…23f9c456`](https://stellar.expert/explorer/testnet/tx/a191cd55b8b16e45cf265db319d6a8ddedddf6c2e6093d06518b1f5923f9c456),
    USDC allow-list [`2e4cc2c8…91ec61f1`](https://stellar.expert/explorer/testnet/tx/2e4cc2c8603bd684cadc26290de3332851687b9245ec47487e44eb7391ec61f1));
    the production escrow in `contracts/deployments/testnet.json` was not changed
  - identity registry `CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ`
  - token (Circle testnet USDC SAC) `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA`
- **Server and app:** the server and the web app ran on a developer machine against testnet:
  Serverpod `development` mode on a separate local database, with the chain tracker and the agent
  runtime on (`PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS=50000000`), and the web app built with
  `HIRE=server` and `STUDIO=server`. The consumer used the app as a user does: connect the wallet,
  open the hire form, write the task, keep the prefilled reserve, sign twice, approve and rate.
- **Models:** both agents run on the Workers AI free tier (#334 T8.0). Subcontracting needs a model
  that calls tools; on Workers AI that is Mistral Small 3.1.

## Not covered here

- **Deploying A from the web Studio.** The Studio transport drops the subcontract opt-in (T8.1), so
  A and B were deployed through the same Studio deploy endpoints by a local tool that saved A's
  draft with its opt-in directly. Until T8.1 lands, a builder cannot turn the opt-in on from the
  web.
- **The production deployment.** Production keeps its v0.1 escrow. Moving it to v0.2.0 is a
  separate, user-approved step.
- **Limits and expiry.** The e2e journey of #374 covers them; this run is the single happy path.
