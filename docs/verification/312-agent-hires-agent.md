# #312 verification: one agent hires and pays another on testnet

This record checks the acceptance criteria of #312 on Stellar Testnet with three runs made on
2026-11-18.

| Run | Tool | What A and B are |
| --- | --- | --- |
| [3](#run-3-real-studio-agents-b-answers-with-its-model) | `puls3_server/tool/a2a_studio_hire_testnet.dart` | **Deployed Studio agents.** B is a Workers AI agent whose output comes from its model through the hire runtime. |
| [1](#run-1-a-hires-and-pays-b), [2](#run-2-the-per-run-budget-refuses-an-over-budget-hire) | `puls3_server/tool/a2a_hire_testnet.dart` (from `main` `64a6793`) | Bare custodied wallets. B's work is deterministic. These runs cover only the payment rail and the budget refusal. |

Payments go through the puls3 escrow, not x402 (#275).

| Criterion (#312) | Evidence |
| --- | --- |
| One agent hires and pays another on testnet with no human signing in the loop. | **Run 3:** A and B are deployed Studio agents (registry 37 and 38). A's custodied key signs `create_job`, `fund` and `complete`. B's runtime runs its model, then B's custodied key signs `submit`. No human signs any of them. |
| The payment and the result are linked to the calling hire and visible on stellar.expert. | **Run 3:** hire 7 / escrow job 37. All four escrow transactions return `SUCCESS` on the testnet RPC and link to stellar.expert. B's model output is stored on hire 7, and B's USDC balance went from 0 to 0.1. |
| Spending is bounded (per-run budget) so an agent cannot drain its wallet. | **Run 2:** with the price above the budget, the hire is refused before anything is signed, and A's USDC balance stays the same. |

**Limit of this evidence: a human starts the hire.** A's owner calls `hireAgentAs`, the endpoint
behind CLI `studio hire-as`, the web Studio and the hire sheet. After that call, every signature
belongs to an agent. Having A's model decide to subcontract B on its own is #334, and nothing in
this record shows it.

## Run 3: real Studio agents, B answers with its model

- **Deploy:** the tool deploys both agents through the Studio endpoints the web app uses:
  `saveDraft` → `prepareDeploy` → `register_full` → `prepareWalletAuthorization` →
  `set_agent_wallet` → `active`. A throwaway builder owns both agents, and the builder's
  Workers AI credential is stored encrypted, as the Studio stores it.
- **Hire:** the tool calls `StudioEndpoint.hireAgentAs`. The server's own runtime and chain tracker run the hire.

| | |
| --- | --- |
| Builder (owner of A and B) | [`GDKAJMNZ6WOMQ3EWLJI2UOWA3FWNHZM2BR7KJQUGQ2TQV5LZ7FUWJ7EO`](https://stellar.expert/explorer/testnet/account/GDKAJMNZ6WOMQ3EWLJI2UOWA3FWNHZM2BR7KJQUGQ2TQV5LZ7FUWJ7EO) |
| Hiring agent A | registry agent 37, [`GC6PCP64EYOCXZ5KG7RWOU44KHJJ4QPLRW7X4JGZGR5GGDXR434B332U`](https://stellar.expert/explorer/testnet/account/GC6PCP64EYOCXZ5KG7RWOU44KHJJ4QPLRW7X4JGZGR5GGDXR434B332U) |
| Hired agent B | registry agent 38, [`GCXYYLLMDSHLRL72XIHF6SITZZBDZNR2TRV45JBK6LBZ5FHC356AO6OO`](https://stellar.expert/explorer/testnet/account/GCXYYLLMDSHLRL72XIHF6SITZZBDZNR2TRV45JBK6LBZ5FHC356AO6OO) |
| B's manifest | v1, provider `workers-ai`, model `@cf/meta/llama-3.3-70b-instruct-fp8-fast` |
| Hire / escrow job | hire 7 / job 37, final status `completed` |
| Price / budget | 1,000,000 / 2,000,000 (0.1 / 0.2 USDC) |
| Input | `Summarize in two sentences why escrowed payments matter for AI agents hiring each other.` |
| B's model output | `Escrowed payments matter for AI agents hiring each other because they provide a secure and trusted mechanism for exchanging value, ensuring that payment is made only when the agreed-upon service or task is completed to the satisfaction of the hiring agent. By holding payment in escrow until the terms of the agreement are fulfilled, AI agents can mitigate the risk of non-payment or non-delivery, facilitating more reliable and efficient transactions between autonomous entities.` |
| USDC after the hire (Horizon) | A: 0.0100000 (0.11 before the hire). B: 0.1000000. |

Every transaction returned `SUCCESS` from `getTransaction` on the testnet RPC:

| Step | Signed by | Ledger | Transaction |
| --- | --- | --- | --- |
| `register_full` (A) | builder | 5800286 | [`7cd19189…130c20c8`](https://stellar.expert/explorer/testnet/tx/7cd19189ac3e0af27db414b703fc186a5024712d1948ccd6d0aaa929130c20c8) |
| `set_agent_wallet` (A) | A (builder auth entry) | 5800289 | [`5afc66e1…ae63a245`](https://stellar.expert/explorer/testnet/tx/5afc66e107e3b2dfb6e6c1127fa15896d7dfea18e3f7a3f4376b7d6eae63a245) |
| `register_full` (B) | builder | 5800290 | [`1cc013aa…49081181`](https://stellar.expert/explorer/testnet/tx/1cc013aa341654f1dc71ade41b497394b3cccf98590fd459a6d22dfb49081181) |
| `set_agent_wallet` (B) | B (builder auth entry) | 5800293 | [`162d7258…cd87d7f85`](https://stellar.expert/explorer/testnet/tx/162d72582d9b5577c5193dc2d58179e911653b0d40f00ad04c3fafecd87d7f85) |
| `create_job` | A | 5800295 | [`84b79237…88a2e1dd`](https://stellar.expert/explorer/testnet/tx/84b792374c04ba7c794788a70fe970320b0c0781019d8f2e0f57459c88a2e1dd) |
| `fund` | A | 5800296 | [`b3f72ce6…341b8c27`](https://stellar.expert/explorer/testnet/tx/b3f72ce65b61ade05bbc7c2e465b806fcba37ede56771ddc44ecfced341b8c27) |
| `submit` (after B's model run) | B | 5800298 | [`2b9e2169…3c580a7a`](https://stellar.expert/explorer/testnet/tx/2b9e2169f4ba78a367e901f289134ef5fc2e0b9401a16aaa460768b39c580a7a) |
| `complete` | A | 5800299 | [`f4ab1ce0…f18d592a19`](https://stellar.expert/explorer/testnet/tx/f4ab1ce05333faec91bc253a23c8b64f643cb4d800479adf31f418f18d592a19) |

To reproduce, run from `puls3_server/`. It needs a Cloudflare Workers AI token as the
`workersAiApiToken` password in the `test` section of `config/passwords.yaml`, and the account id
exported:

```sh
docker compose up -d postgres_test redis_test
PULS3_WORKERS_AI_ACCOUNT_ID=<cloudflare account id> dart run tool/a2a_studio_hire_testnet.dart --mode test
```

The tool never prints the token, the account id or any secret seed.

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

- **An agent deciding to hire.** In the product, the owner of the hiring agent starts the hire (CLI `studio hire-as`, the web Studio or the hire sheet). No runtime tool lets a model decide to subcontract. That is #334.
- **A's model.** A is a deployed Studio agent, but its model takes no part in run 3. A only acts as the paying client and evaluator, and its custodied key signs `complete` without checking B's output.
- **A daily or cumulative cap.** The budget bounds each run. Nothing on the server caps the budget an owner passes, or how many runs happen per day. #312 asks only for a per-run budget.
