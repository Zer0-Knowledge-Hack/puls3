# puls3 — Product vision and MVP scope

Status: draft for team approval · Last updated: 2026-09-23 · Issue: #2

This is the single source of truth for **what we build, for whom, and why on Stellar**. The architecture (#5), the blueprints (#22, #23), and the pitch (#3, #4) derive from it. If they disagree with this document, this document wins until it is changed in a PR.

## 1. Problem

AI agents are starting to do paid work: they summarize, translate, audit code, and call other agents. Three things are still hard:

- **Creating an agent that can earn.** A builder can write an agent in an afternoon, but giving it an identity, a wallet, and a price takes custom infrastructure.
- **Finding an agent you can trust.** There is no common place to search agents by skill, compare prices, or check a track record.
- **Paying an agent per task.** Cards and subscriptions were not built for machine-to-machine payments of a few cents, and they settle in days, not seconds.

## 2. Users

| Persona | Goal | Pain today |
|---|---|---|
| **Agent builder** (developer or prompt engineer) | Publish an agent once and get paid every time someone uses it | Has to build auth, billing, and a wallet before earning the first cent |
| **Agent consumer** (a person, a team, or another agent) | Find an agent that does a task well and pay only for that task | No catalog, no reputation, and no way to pay small amounts per request |

## 3. Solution

puls3 is an agent hub on Stellar. In the **Agent Studio**, a builder defines an agent (what it does, which model it uses, and its price), tests it, and deploys it. Every deployed agent gets **its own on-chain identity in a Soroban registry and its own Stellar wallet**. In the **Marketplace**, anyone can search agents by skill, check their reputation, hire one, and pay per task in USDC. The server verifies the payment on-chain before the agent runs, and the consumer's feedback builds the agent's reputation.

**One-line pitch:** *Create AI agents, find AI agents, and pay them in seconds, on Stellar.*

## 4. Why Stellar

| Reason | What it means for puls3 | Official source |
|---|---|---|
| **Per-request payments for agents are documented first-class use cases** | Stellar documents x402 and the Machine Payments Protocol (MPP) as ways to make "programmatic, per-request payments over HTTP — designed for AI agents". The x402 facilitators listed include a Coinbase facilitator (testnet) and an OpenZeppelin Relayer plugin (testnet and mainnet). | [Agentic payments](https://developers.stellar.org/docs/build/agentic-payments) · [x402 on Stellar](https://developers.stellar.org/docs/build/agentic-payments/x402) |
| **Tiny, predictable fees** | The network minimum base fee is 100 stroops (0.00001 XLM), so a payment of a few cents is not eaten by fees. | [Fees and resource limits](https://developers.stellar.org/docs/learn/fundamentals/fees-resource-limits-metering) |
| **Real digital dollars that settle in seconds** | USDC and EURC by Circle are available on Stellar, which "settle transactions in a matter of seconds with finality". Agents are priced and paid in USDC. | [USDC and EURC on Stellar](https://stellar.org/products-and-tools/circle-usdc-eurc) |
| **Assets usable from smart contracts** | The Stellar Asset Contract lets Soroban contracts use native Stellar assets such as USDC directly, with the SEP-41 token interface. | [Stellar Asset Contract](https://developers.stellar.org/docs/tokens/stellar-asset-contract) |
| **Smart wallets with spending rules** | Contract accounts can use passkeys, session keys, or policy signers, and enforce "spending limits, allow lists, time-based rules". This is how an agent's wallet can have guardrails. | [Contract accounts](https://developers.stellar.org/docs/build/guides/contract-accounts) |

## 5. Differentiator

On EVM chains, [ERC-8004 "Trustless Agents"](https://eips.ethereum.org/EIPS/eip-8004) defines on-chain registries for agent identity, reputation, and validation, and our earlier project *pulse* used it on BNB Chain.

**We did not find an equivalent agent registry on Soroban** in the sources we checked: the Stellar developer docs, the LumenLoop directory, and the Scout repository search (checked 2026-09-21). puls3 adds:

- An **Agent Identity Registry** on Soroban: owner, payment address, and metadata for every agent (#6, #13)
- A **Reputation Registry** on Soroban, fed by paid hires only (#14)
- A Studio and a Marketplace on top, so builders and consumers never touch the contracts directly

This is a claim about what we found, not proof that nothing exists. #6 records the prior art we evaluated.

## 6. MVP scope

The MVP is what we show at the Serverpod hackathon (Oct 14, 2026), on **testnet**.

### In

1. **Create an agent:** the builder defines name, skills, model, prompt, and price in the Studio, test-runs it, and deploys it. Deploying registers the agent on-chain and creates its wallet.
2. **Discover agents:** the consumer browses the catalog, filters by skill, and opens an agent's detail page (price, on-chain identity, reputation).
3. **Hire and pay an agent:** the consumer connects a Stellar wallet, pays the agent's price in USDC, and the server verifies the payment on-chain before running the task.
4. **Get the result and rate it:** the consumer sees the result and leaves feedback, which counts toward the agent's reputation.

### Out

1. Mainnet and real money
2. Agent-to-agent hiring (the rail chosen in #7 should allow it later, but no UI or orchestration in the MVP)
3. The ERC-8004 Validation Registry (TEE attestation, re-execution, validator staking)
4. Fiat on/off-ramps and anchors
5. Refunds, disputes, and escrow for long-running tasks
6. Native mobile apps (the MVP is Flutter web)
7. Upgradeable contracts and governance

## 7. Demo success criteria

In the Serverpod video (under 2 minutes, #4), a judge must see, **with no mock data**:

1. A builder deploys an agent from the Studio, and its identity appears on a testnet explorer.
2. The new agent shows up in the Marketplace catalog, served by the Serverpod backend.
3. A consumer pays the agent in USDC from a Stellar wallet, and the transaction opens on a testnet explorer.
4. The agent runs only after the payment is verified, and returns a result.
5. The consumer rates the agent, and the rating shows up on the agent's detail page.

If one of these steps is faked, we say so in the video.
