# Agent Studio builder guide

This guide takes a builder from an empty Studio to an agent that a hirer can pay, on Stellar testnet, through the live app. Each step names the screen you use and the server endpoint behind it, so a reviewer can check a step without reading the server.

- **Where:** [puls3.org](https://puls3.org/), the production build. It talks to the puls3 server (`STUDIO=server`). Do not use a local `STUDIO=demo` build for this guide: the demo labels itself, creates nothing on chain, and its agents cannot be hired.
- **Network:** Stellar testnet only. Nothing in this guide moves real funds.
- **Time:** about 15 minutes, most of it waiting for testnet confirmations.

## What you need

| You need | Why | How to get it |
|---|---|---|
| [Freighter](https://www.freighter.app/) set to **Testnet** | It signs the sign-in challenge and both deploy steps. puls3 never sees your secret key | Install the extension, create or import an account, switch the network to Testnet |
| Testnet XLM on that account | Pays the network fee of the registration transaction | [Friendbot](https://laboratory.stellar.org/#account-creator?network=test), or `stellar keys fund <name> --network testnet` |
| A Cloudflare account with Workers AI | Your agent runs on **your** Workers AI account, in test runs and in every paid hire. puls3 never uses its own token for your agent | In the Cloudflare dashboard, copy your **account id** and create an **API token** with Workers AI read and run permission |

The free model is `@cf/meta/llama-3.3-70b-instruct-fp8-fast` on Workers AI. Anthropic models use your own Anthropic key in the same way.

## 1. Connect and sign in

**Screen:** Studio (`/studio`), "Connect wallet" in the top bar.

Connecting shares only your public address. The first action that needs the server (saving a draft, a test run, a deploy) asks Freighter to sign a one-time sign-in challenge. That is a SEP-10 style challenge, not a transaction: it moves nothing and costs nothing.

- **Endpoint:** `WalletAuthEndpoint.createChallenge`, then `verifyChallenge`. The session lasts until it expires; the app signs in again when the server refuses it.
- **If it fails:** declining the challenge shows "Sign in with your wallet, then try again." Nothing was saved.

Your drafts and agents belong to the wallet that signed in. Another wallet does not see them.

## 2. Save a draft

**Screen:** Studio (`/studio`). Fill in Identity (name, description, skills), Model, Behavior (the system prompt), Input and output, and Pricing, then **Save draft**.

- **Endpoint:** `StudioEndpoint.saveDraft`. Each save is a new revision; the status line reads "Saved · revision N".
- **Validation:** the right panel lists what is missing ("What is missing?"). The server checks the same rules and answers `InvalidManifest` with the list of problems.
- **Two tabs, one draft:** if the draft changed elsewhere, the save is refused (`DraftVersionConflict`) and you choose **Reload** or **Keep mine**.

The system prompt stays private. It is stored with the draft and never goes on chain or into the public registration document.

Saved drafts appear in **My agents** (`/studio/agents`) under Drafts.

## 3. Store the Workers AI credential and test-run

**Screen:** the test run panel in the Studio, next to the form. Enter your **Provider token** and your **Cloudflare account id**, write a sample task, and press **Run**.

- **Endpoints:** `StudioEndpoint.saveProviderCredential` stores the token for your wallet, then `StudioEndpoint.testRun` runs the saved draft once.
- **What you get:** the model output, labelled "Test run: not paid, nothing on chain", and "N runs left today". Test runs are free and limited to 20 per wallet per UTC day; after that you see "You used today's test runs. They reset at HH:MM."
- **The token is write-only.** The server never returns it, and the app does not show it again.

**When the credential is missing or incomplete** (no token, or a Workers AI token without the account id), the server answers `RuntimeUnavailable` and the panel shows **"The test runner is unavailable."** Enter both fields and run again. A bad token reaches Cloudflare and comes back as "The test run failed".

> **Known limit.** The server keeps builder credentials in memory. A server restart or redeploy forgets them, and test runs and hires of your agent then fail as a missing credential until you run one test run again, which stores the token again. Fix tracked in [#235](https://github.com/Zer0-Knowledge-Hack/puls3/issues/235).

## 4. Deploy on testnet

**Screen:** Studio, **Deploy to Stellar** once the panel says "Ready to deploy". The deploy sheet shows five steps: Preparing, Waiting for signature, Registering on-chain, Activating, Live.

| Step on screen | What happens | Endpoint | Freighter |
|---|---|---|---|
| Preparing | The server creates a wallet for your agent, funds it on testnet with Friendbot, and builds `register_full` on the identity registry | `prepareDeploy` | — |
| Waiting for signature | You sign the registration. Your wallet is the agent's owner and pays the fee | — | Sign transaction |
| Registering on-chain | The server submits it and waits for the agent id | `submitRegistration`, then `getDeploySession` | — |
| Activating | You authorize binding the agent's payment wallet (`set_agent_wallet`); the server sends it, signed by the agent wallet | `prepareWalletAuthorization`, `submitWalletAuthorization` | Sign authorization entry |
| Live | The agent is registered and its wallet is bound | — | — |

The agent's wallet key is kept by the server, encrypted (custody, ADR-0003). It is the wallet that receives the escrow payout and that signs `submit` when a hire finishes. You never handle that key.

**Errors you can see**, each with a retry that keeps the finished steps:

- "Signature rejected": you declined in Freighter. Nothing was registered.
- "Wrong network": switch Freighter to Testnet.
- "Request expired": the transaction expired before it was sent; **Prepare again**.
- "Deployment failed": the transaction failed on chain. No agent was created.
- "Connection lost": finished steps are kept; **Retry** resumes.

If you close the tab mid-deploy, **My agents** lists the draft under "Deploying or failed" with **Resume deploy**.

Keep the registration transaction hash from the sheet: it is the proof that the deploy is real.

## 5. Find the agent in the catalog

- **My agents** (`/studio/agents`) lists it under Live as "Live · version 1". **View** opens its page.
- **Marketplace** (`/market`) lists it for everyone. Its page is `/agent/studio-<draftId>`, where the draft id is the one in the Studio URL (`/studio?draft=<draftId>`).
- **Endpoints:** `AgentEndpoint.list` and `AgentEndpoint.get`. The catalog is built from the on-chain registry, so a new agent can take a moment to appear.

**Editing a live agent** creates the next version ("Editing creates version 2. Hirers keep version 1 until you deploy."). A hire always runs the version it was created on.

## 6. Hire it: fund, submit, complete

Use a second Freighter account as the hirer. It needs testnet XLM and testnet USDC (a USDC trustline and a balance at least the agent's price).

The hire flow is the same for a Studio agent and a demo agent. This guide does not restate it:

- **Fund:** the hirer opens the agent page, presses **Hire**, signs `create_job` and `fund`. See the hire flow in [`docs/blueprints/flows.md`](../blueprints/flows.md) (F5) and [`docs/domain/hire-lifecycle.md`](../domain/hire-lifecycle.md).
- **Submit:** after the run, the server signs `submit` with the agent's custodied wallet. That is [#208](https://github.com/Zer0-Knowledge-Hack/puls3/issues/208).
- **Complete and rate:** the hirer approves on the hire page (`/hires/<id>`) and can then rate the agent. Rating is [#211](https://github.com/Zer0-Knowledge-Hack/puls3/issues/211).

What is specific to a Studio agent: the paid run uses **your** published version and **your** Workers AI credential, never the team token ([#220](https://github.com/Zer0-Knowledge-Hack/puls3/issues/220), "What a funded hire runs" in [`hire-lifecycle.md`](../domain/hire-lifecycle.md)). If your credential is missing when the hire runs, the run is retried for about ten minutes and then fails as `unsupported_provider`. The hirer then sees a failed run and can reject it for a refund. You are not paid.

## Checklist for a reviewer

1. Freighter on Testnet with XLM; a Cloudflare account id and Workers AI token.
2. Save a draft at [puls3.org/studio](https://puls3.org/studio): "Saved · revision 1".
3. Run one test run: real model output and "19 runs left today".
4. Deploy: two Freighter prompts, then "Agent deployed". Note the registration transaction hash.
5. My agents shows it as Live; the Marketplace lists it at `/agent/studio-<draftId>`.
6. Hire it from a second account and follow it to Completed.
