# SOW evidence

One section per week of the Statement of Work. You don't need any software to
check it. Every item is either a page you can open or a transaction on
[stellar.expert](https://stellar.expert/explorer/testnet), a public block
explorer for the Stellar test network.

**How to read a transaction on stellar.expert.** Open the link. The page should
say **Successful**. Under the operations you will see the contract that was
called and the function name (for example `register_full` or `fund`), plus the
account that signed it. Each row below says what you should see.

All transactions were checked as successful on Horizon (Stellar's public API)
on 2026-11-21.

| Week | State |
|---|---|
| 1. Agent Studio: creation and on-chain identity | ✅ evidence below |
| 2. Collaboration, publishing, deployment and payments | ✅ evidence below |
| 3. SDK on npm | 🚧 not delivered yet: the npm package is in progress (#302, #314) |
| 4. CLI, documentation and final delivery | 🚧 the CLI and its docs are delivered; the demo video and the npm-based check are pending |

## The contracts, once

| Contract | What it does | Link |
|---|---|---|
| Identity registry | gives every agent an on-chain id and stores its metadata and wallet | [CD5QZOKG…FIJJ](https://stellar.expert/explorer/testnet/contract/CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ) |
| Escrow | holds the client's USDC for a hire and pays the agent when the work is approved | [CBRD7A7M…TPE2](https://stellar.expert/explorer/testnet/contract/CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2) |
| Reputation registry | stores ratings from paying clients | [CBJZYEJ5…P5Q4](https://stellar.expert/explorer/testnet/contract/CBJZYEJ5DS7TDLA2ECRAW3ICQIYAOMTCQ5QSY7PYJ5PJ2W5EAHPBP5Q4) |

Payments use Circle's testnet USDC, the only token the escrow accepts.

## Week 1: create an agent with its own wallet and on-chain identity

> A builder can create an agent from the web app. The agent has its own wallet
> and a verifiable on-chain identity on Stellar Testnet, and it can run locally.

| Evidence | Where | What you should see |
|---|---|---|
| The web app | [puls3.org](https://puls3.org/) | the marketplace and the Studio. Creating an agent needs a Stellar wallet (Freighter) on testnet |
| How to create an agent | [Agent Studio builder guide](studio/builder-guide.md) | the steps from a draft to a deployed agent |
| The identity of agent #30, "Soroban Pre-Audit", created in the Studio | [`3ddf5b2f…53b1`](https://stellar.expert/explorer/testnet/tx/3ddf5b2ff6b45c18089e53336124c23bc25ec8aedd82c1944d2ea273dad053b1) | Successful, 2026-11-17. A call to `register_full` on the identity registry, which creates agent #30 with its metadata |
| Its own wallet | [`GDQHKMYJ…NFBB`](https://stellar.expert/explorer/testnet/account/GDQHKMYJLDOMS5YDOS3MQ2XRTCSKK3VBUYHJAIHR4H7FSPETQCOTNFBB) | an account created for this agent only |
| The wallet bound to the identity | [`2bcb512d…32a3`](https://stellar.expert/explorer/testnet/tx/2bcb512daff96774e7041e799eef89d19da823e221865b9cf29e7fafb34a32a3) | Successful. A call to `set_agent_wallet` signed by the agent's own wallet |
| Run an agent locally | [Run an agent locally](cli/run-locally.md) | `puls3 run --manifest …` runs an agent on your machine, with no server and no transaction |

## Week 2: publish, deploy, pay autonomously, collaborate

> A builder can publish an agent to the marketplace, deploy it to the cloud,
> and have it make an autonomous payment on testnet. Each payment is verifiable
> through its transaction hash. Independent agents can collaborate.

**Published and deployed.** Agent #30 is listed and hireable at
[puls3.org](https://puls3.org/). It runs on the puls3 server, which is deployed
to the cloud.

**A live hire by a client (hire 20, escrow job 34, 0.50 USDC), 2026-11-18.**

| Step | Transaction | Signed by | What you should see |
|---|---|---|---|
| The client opens a job | [`464d357e…b0`](https://stellar.expert/explorer/testnet/tx/464d357e9177c276eaaf8d5ec552266032adea7e8ba22c3a64941dceeadae6b0) | the client `GBGBQI7O…CKIF` | `create_job` on the escrow |
| The client pays 0.50 USDC into escrow | [`8f212474…85c`](https://stellar.expert/explorer/testnet/tx/8f2124741a2e73aff1b1e335dda1ffcf406873fbc60904671b4f11a7387a385c) | the client | `fund`, and a USDC transfer into the escrow |
| **The agent delivers, on its own** | [`3ac1449e…7d3`](https://stellar.expert/explorer/testnet/tx/3ac1449e72fc5c6e8e4852cfec99e661c78e70d66ad685c00828ee6c739fb7d3) | **the agent's wallet** `GDQHKMYJ…NFBB` | `submit`: no person signed it |
| The client approves, and the agent is paid | [`f1d64630…550`](https://stellar.expert/explorer/testnet/tx/f1d64630bb71ad5bca278d462b8edcca0d5785b973790b46f5d1d2a73322b550) | the client | `complete`, and a USDC transfer to the agent's wallet |
| The client rates the agent | [`61648311…65d`](https://stellar.expert/explorer/testnet/tx/616483115bf2124552f88cd504464c71fc0428d0ff91aaec2285b651b8ea165d) | the client | `give_feedback` on the reputation registry |

**Agents collaborate: agent #28 hires and pays agent #29 (job 30, 0.10 USDC),
2026-11-17.** No person signs any of these transactions: each agent signs with
its own wallet.

| Step | Transaction | Signed by | What you should see |
|---|---|---|---|
| Agent #28 opens a job for agent #29 | [`3aba5bae…d3`](https://stellar.expert/explorer/testnet/tx/3aba5baeeaeb4a9427ad848e3465114c707eb06681370fa588ea8f94fedeb7d3) | agent #28 `GDUMY7PB…AIMW` | `create_job` |
| Agent #28 pays into escrow | [`a6dac2d0…e0`](https://stellar.expert/explorer/testnet/tx/a6dac2d00c742f932bda3a9e0aa5399e7833d165e636687d48efadcb058db2e0) | agent #28 | `fund` |
| Agent #29 delivers | [`d6abe4be…e5`](https://stellar.expert/explorer/testnet/tx/d6abe4be0410016fa9406f80be26dbe7323c3eb6e8b979a5b276bf4c825561e5) | agent #29 `GBJ2UDCQ…GNMT` | `submit` |
| Agent #28 approves, and agent #29 is paid | [`6903874f…8b`](https://stellar.expert/explorer/testnet/tx/6903874f8155515b23d0ac6f49a42aee68a585c98b08f77f27ef4811660db18b) | agent #28 | `complete` |

## Week 3: SDK on npm (not delivered yet)

> A developer can install the SDK from npm and create an agent with its own
> identity and wallet from code, run it locally and make autonomous payments
> on testnet.

**Not available yet:** there is no npm package to install.

- The TypeScript SDK is tracked in
  [#302](https://github.com/Zer0-Knowledge-Hack/puls3/issues/302).
- Its design, in which the developer signs with their own key, is in review in
  [#314](https://github.com/Zer0-Knowledge-Hack/puls3/issues/314).

**What already exists**, for Dart developers rather than npm:

- the Dart SDK [`puls3_sdk/`](../puls3_sdk/), with its
  [quickstart](sdk/quickstart.md) and [sessions](sdk/sessions.md) guides;
- the MCP server for AI editors, with its [setup guide](mcp/setup.md).

This section will get the npm URL when the package is published.

## Week 4: CLI, documentation and final delivery

> A builder can run the full workflow (create, run, deploy) from the terminal.
> Complete setup docs in the public repo, a demo video of the CLI end to end,
> and an end-to-end check of Studio, SDK and CLI on testnet.

| Evidence | Where | State |
|---|---|---|
| The `puls3` command line | [`puls3_cli/`](../puls3_cli/), [CLI reference](cli/reference.md) | ✅ catalog, hires, Studio test runs, agent-to-agent hires and local runs. It never signs a transaction |
| Setup docs | [README](../README.md#build-and-run), [CONTRIBUTING](../CONTRIBUTING.md), [secrets and testnet setup](infra/secrets.md) | ✅ |
| CLI checked against testnet | [#224](https://github.com/Zer0-Knowledge-Hack/puls3/issues/224) | ✅ `catalog list` lists the live agents; hire commands refuse to run without a wallet session |
| Demo video of the CLI | not recorded yet | 🚧 |
| End-to-end check of Studio, SDK and CLI on testnet | the Studio and the CLI are covered above; the npm SDK is pending (week 3) | 🚧 |

## Where these values come from

- **Contract addresses:** [`contracts/deployments/testnet.json`](../contracts/deployments/testnet.json).
- **The two hires:** [#313](https://github.com/Zer0-Knowledge-Hack/puls3/issues/313) (hire 20) and [#317](https://github.com/Zer0-Knowledge-Hack/puls3/pull/317) (agents #28 and #29).
- **Agent #30's registration:** found from the identity registry's `registered` event.
- **More technical checks:** [on-chain verification](verification/onchain.md) has the step-by-step version.
