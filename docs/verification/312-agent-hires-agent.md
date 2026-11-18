# #312 verification: one agent hires and pays another on testnet

This record shows that the acceptance criteria of #312 hold on Stellar Testnet. It covers two runs of
`puls3_server/tool/a2a_hire_testnet.dart`, made on 2026-11-18 from `main` at `64a6793`.

| Criterion (#312) | Evidence |
| --- | --- |
| One agent hires and pays another on testnet with no human signing in the loop. | [Run 1](#run-1-a-hires-and-pays-b): A's custodied key signs `create_job`, `fund` and `complete`, and B's custodied key signs `submit`. Nobody signs from a wallet app or the CLI. |
| The payment and the result are linked to the calling hire and visible on stellar.expert. | Run 1: the four escrow transactions belong to hire 6 / escrow job 36. Each one links to stellar.expert below. |
| Spending is bounded (per-run budget) so an agent cannot drain its wallet. | [Run 2](#run-2-the-per-run-budget-refuses-an-over-budget-hire): when the price is above the budget, the hire is refused before anything is signed. A's USDC balance stays the same. |

## How the runs were made

- **Network:** Stellar Testnet (`https://soroban-testnet.stellar.org`). The tool refuses any network other than testnet.
- **Contracts:**
  - escrow `CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`
  - token (Circle testnet USDC SAC) `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA`
- **Server:** the real `HireService`, `EscrowRelayService` and chain tracker. They run in-process in Serverpod `--mode test`, against the local test database (`docker compose up -d postgres_test redis_test` in `puls3_server/`).
- **Custody:** both agents are custodied `agent_wallet` rows. Each run uses a throwaway custody key (`PULS3_AGENT_WALLET_SECRET_KEY` unset), and no secret is printed.
- **Agent B's work:** a deterministic summary computed in the tool, not a model call. The run proves the payment path, not a model provider.

To reproduce, run from `puls3_server/`:

```sh
docker compose up -d postgres_test redis_test
dart run tool/a2a_hire_testnet.dart --mode test                                   # run 1
dart run tool/a2a_hire_testnet.dart --mode test --price 1000000 --budget 500000   # run 2
```

Amounts are in USDC stroops (1 USDC = 10,000,000 stroops).

## Run 1: A hires and pays B

| | |
| --- | --- |
| Hiring agent A | registry agent 33, [`GA4EZFX7C3YW75AA35LY4OEXQTP4EER2DXWENQNWCTCSWVDB5LP4NC76`](https://stellar.expert/explorer/testnet/account/GA4EZFX7C3YW75AA35LY4OEXQTP4EER2DXWENQNWCTCSWVDB5LP4NC76) |
| Hired agent B | registry agent 34, [`GCFSLCDNQD5NKGV4TS7OSILL7WBG6MLKSQAZVRIYDOW4I74PYKLUGNIC`](https://stellar.expert/explorer/testnet/account/GCFSLCDNQD5NKGV4TS7OSILL7WBG6MLKSQAZVRIYDOW4I74PYKLUGNIC) |
| Hire / escrow job | hire 6 / job 36 |
| Price / budget | 1,000,000 / 2,000,000 (0.1 / 0.2 USDC) |
| B's output | `Summary by agent B: "Agent A delegates this paragraph to agent B." (22 words).` |

Escrow transactions. Each one returned `SUCCESS` from `getTransaction` on the testnet RPC, in consecutive ledgers:

| Step | Signed by | Ledger | Transaction |
| --- | --- | --- | --- |
| `create_job` | A | 5799908 | [`eb79b21d…0803009`](https://stellar.expert/explorer/testnet/tx/eb79b21d0a0ad212d86bce440af303d28ecba0bcb514a0276dd682a990803009) |
| `fund` | A | 5799909 | [`facc6f3e…dd1acc6`](https://stellar.expert/explorer/testnet/tx/facc6f3e9583276d39aa10bad952f0ce73c4ffdd53c91fba6aff7cf2fdd1acc6) |
| `submit` | B | 5799910 | [`121f11e7…0be8d6c`](https://stellar.expert/explorer/testnet/tx/121f11e7d9bb12b4ee157fba9bb9c146f7fbad44b17fb4fe7acda61520be8d6c) |
| `complete` | A | 5799911 | [`bbd87203…2035b77`](https://stellar.expert/explorer/testnet/tx/bbd87203174801c485a87e2f1aad47ff4b84c9b84956e7e6ec2ba66072035b77) |

Setup transactions. These are not part of the hire. They make A and B real testnet accounts with USDC and registry ids:

| Step | Transaction |
| --- | --- |
| `change_trust` USDC (A) | [`45931a60…08188ef`](https://stellar.expert/explorer/testnet/tx/45931a602b69599a8fb14ca85eb411c0c29ddcd5a840ba661446f45a708188ef) |
| `change_trust` USDC (B) | [`db80f5ee…ee115e`](https://stellar.expert/explorer/testnet/tx/db80f5ee9bca20d28f0b6d6efb0579905bf0aba0bcee7d3688713d1f64ee115e) |
| `path_payment` XLM→USDC (A) | [`f64a2044…29b8e47`](https://stellar.expert/explorer/testnet/tx/f64a2044c2d239944d9dd0bb82791588673746e5f38d41dfa25b8fb0f29b8e47) |
| `register_full` (A) | [`ad7b4855…cf9fd92`](https://stellar.expert/explorer/testnet/tx/ad7b48557c6d4267079ccbac436eab72c4cec4df8402697966116b70ecf9fd92) |
| `register_full` (B) | [`1ba14486…3ec91e6`](https://stellar.expert/explorer/testnet/tx/1ba144863c3117277e05015ea7770ab96fa4b3f3fde7e2c3fa147264a3ec91e6) |

## Run 2: the per-run budget refuses an over-budget hire

This run uses the same setup with fresh agents: A is registry agent 35, [`GDX2MHQEJ3RAMADZNEN3K3KFZF3KRQZNUJCD6X6MTZHNYULWPOUHHTDB`](https://stellar.expert/explorer/testnet/account/GDX2MHQEJ3RAMADZNEN3K3KFZF3KRQZNUJCD6X6MTZHNYULWPOUHHTDB), and B is registry agent 36. The price is 1,000,000 and the budget is 500,000.

The hire stops in `AgentHireService._withinBudget` (`puls3_server/lib/src/hire/agent_hire_service.dart`) with this error:

```text
AgentHireOverBudget: price 1000000 > budget 500000 USDC stroops
```

- No `create_job`, `fund` or other escrow transaction was signed. A's account history has only its setup transactions (account creation, `change_trust`, `path_payment`, `register_full`).
- A's USDC balance stayed at 0.1100000 USDC (1,100,000 stroops), the same amount it held right after the swap.

The budget is checked twice. The first check uses the catalog price, before the hire is created. The second uses the stored hire price, before anything is signed. Unit tests in `puls3_server/test/unit/hire/agent_hire_service_test.dart` cover both checks. `StudioEndpoint.hireAgentAs` maps the refusal to `BudgetExceeded`, which `puls3_server/test/studio/studio_endpoint_test.dart` covers. The CLI (`studio hire-as`, #329), the web Studio (#332) and the hire sheet (#342) all go through that endpoint.

## Not covered here

- **A model-backed agent B.** B's work in these runs is deterministic. A hire whose provider runs a model goes through the same escrow path, and the hire runtime covers it.
- **A daily or cumulative cap.** The budget bounds each run. Nothing on the server caps the budget an owner passes, or how many runs happen per day. #312 asks only for a per-run budget.
