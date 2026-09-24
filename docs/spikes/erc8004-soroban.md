# Spike: ERC-8004 agent registries on Soroban

- **Issue:** #6 · **Time-box:** 2 days · **Date:** 2026-09-23
- **Decision record:** [ADR-0002](../adr/0002-agent-registry-on-soroban.md)

## Question

What do we build on-chain for the MVP so that every puls3 agent has a verifiable identity and reputation on Stellar, and what interface do #13 and #14 implement?

## Summary

- ERC-8004 defines three registries: Identity, Reputation, and Validation.
- **An ERC-8004 implementation already runs on Soroban:** [Stellar 8004](https://github.com/trionlabs/stellar-8004) (MIT), on testnet and mainnet. The issue assumed nothing like it existed; that is no longer true.
- **Decision:** puls3 deploys **its own** Identity and Reputation registries, aligned with the Stellar 8004 subset used by the MVP. Shared reads and event fields follow that interface, but omitted NFT/upgrade methods and puls3's payment-backed feedback authorization mean compatibility is not drop-in. Validation stays out of the MVP. Details and the exact interface are in [ADR-0002](../adr/0002-agent-registry-on-soroban.md).

## 1. ERC-8004 in brief

[ERC-8004: Trustless Agents](https://eips.ethereum.org/EIPS/eip-8004) (Draft, created August 2025) lets agents be discovered and trusted across organizations through three per-chain singleton registries.

| Registry | What it stores | Who writes |
|---|---|---|
| **Identity** | An ERC-721 token per agent (`agentId`) whose `agentURI` resolves to a registration file (name, description, services and endpoints, x402 support, supported trust models). Optional key/value metadata, including the reserved `agentWallet` (the payment address). | The agent's owner or an approved operator. Changing `agentWallet` needs a signature from the new wallet. |
| **Reputation** | Feedback per `(agentId, client, index)`: a signed fixed-point `value` with `valueDecimals`, two tags, and a revoked flag. `endpoint`, `feedbackURI` and `feedbackHash` are emitted in events but not stored. Anyone can append a response to a feedback. | Any address **except** the agent's owner or operators. `getSummary` aggregates feedback **only from a list of clients the caller chooses**, which is how a consumer filters out Sybil reviews. |
| **Validation** | Requests to a named validator and its 0–100 responses, keyed by `requestHash` (re-execution, zkML, TEE attestation). | The agent's owner requests; only the named validator responds. |

Off-chain data (registration files, feedback details, validation evidence) lives on IPFS or HTTPS, optionally pinned by a hash.

## 2. Prior art on Stellar

Checked 2026-09-23. Starting points: the [awesome-stellar-ai](https://github.com/trionlabs/awesome-stellar-ai) list, web search, and the links in #6.

| Project | What it is | Verdict |
|---|---|---|
| [**trionlabs/stellar-8004**](https://github.com/trionlabs/stellar-8004) | All three ERC-8004 registries on Soroban, deployed on [testnet](https://stellar.expert/explorer/testnet/contract/CDE3K4COIAGWNNJQQLL26SYI3KBJF5FUDHXG5FA6GYDJCG7T5V7FIWZH) and mainnet. Identity is an NFT built on OpenZeppelin `stellar-tokens`; timelocked upgrades; reproducible builds; explorer at stellar8004.com; TypeScript SDK; Supabase indexer. MIT. Inspected at commit `d92c2f4`. | **Align with its MVP subset.** Reusing shared names and event fields reduces adapter work, but puls3-specific omissions and payment-backed feedback require an adapter. We do not fork its code: see "Why not reuse the code" below. |
| [**berkingurcan/stellar-agent-search**](https://github.com/berkingurcan/stellar-agent-search) | Read-only MCP server and CLI that discovers, ranks, and vets Stellar 8004 agents. | **Inspiration, and a warning.** It reads through the stellar8004.com Explorer API, which indexes the Stellar 8004 contracts only. Interface compatibility alone does **not** make puls3 agents show up in these tools. Its ranking (quality, volume, breadth) is a useful reference for #11. |
| [**eunomia-finance/eunomia**](https://github.com/eunomia-finance/eunomia) | Non-custodial agent treasury on Soroban: per-payment and rolling 24h caps, payee allow lists or reputation thresholds, expiring session keys ("Leashes"), MCP integration. MIT / Apache-2.0. | **Take inspiration for #7**, not for #6. It is about bounding what an agent can spend, not about identity. Its reputation-gated payees show how a registry can be consumed by other contracts. |
| [**Stellar AI Agent Kit** (SCF)](https://communityfund.stellar.org/project/stellar-ai-agent-kit-mr6) | Developer toolkit: generates MCP server bindings for Soroban contracts, a policy-signer generator and sandbox, and an npm SDK. | **Discard for #6.** It is tooling for letting agents call contracts, not a registry. Its SDK is npm, which we do not use. |
| [**OpenZeppelin/stellar-contracts**](https://github.com/OpenZeppelin/stellar-contracts) | Audited Soroban building blocks (`stellar-tokens` NFT, `stellar-access` ownable). Stellar 8004 is built on it. | **Discard for the MVP.** The latest release, `stellar-tokens` 0.7.2, requires `soroban-sdk ^26.1`, while testnet runs protocol 28 and #12 must pin a matching SDK major. Revisit when a release supports SDK 28. |

### Why not reuse the code

- **SDK version:** Stellar 8004 pins `soroban-sdk = "25"` and an OpenZeppelin git revision. #12 requires the SDK major to match testnet (protocol 28, checked with RPC `getVersionInfo` on 2026-09-23). Porting their code to SDK 28 means replacing the OpenZeppelin NFT base anyway.
- **Scope:** their Identity Registry includes transfers, approvals, and a timelocked upgrade system. The MVP needs none of these, and each is attack surface we would have to test.
- **Our rules:** their `register_full` panics with string messages; our contracts return `#[contracterror]` codes.
- **Hackathon evaluation:** the Stellar Odyssey demo needs a Soroban contract written by the team during the event.

## 3. Mapping EVM concepts to Soroban

| Concept | ERC-8004 on EVM | Soroban (puls3) | Source |
|---|---|---|---|
| **Identity token** | ERC-721 token, `agentId` is a `uint256` | No NFT in the MVP. The registry stores `Owner(agent_id)` itself; `agent_id` is a sequential `u32` starting at 0, the same as Stellar 8004. Read functions keep NFT-style names (`owner_of`, `token_uri`, `balance`) so an NFT can replace it later. | [Stellar 8004 identity contract](https://github.com/trionlabs/stellar-8004/tree/main/contracts/identity-registry) |
| **Auth** | `msg.sender` is implicitly the caller | The caller is an explicit `caller: Address` argument and the function calls `caller.require_auth()`. Works for G-accounts and C-accounts (smart wallets). Changing the agent wallet also calls `new_wallet.require_auth()`, the Soroban equivalent of ERC-8004's EIP-712 signature from the new wallet. | [Auth example](https://developers.stellar.org/docs/build/smart-contracts/example-contracts/auth) |
| **Events** | Solidity events with indexed fields | `#[contractevent]` structs; `#[topic]` fields are indexed topics. Identity events and the unmodified reputation events keep Stellar 8004 names and topic order. puls3 adds `hire_id` to `NewFeedback` data, so that event is not ABI-identical. | [Events example](https://developers.stellar.org/docs/build/guides/events/publish) |
| **Storage** | Contract storage, paid once | Three storage types. **Instance** for contract-wide config (admin, counters, linked registry). **Persistent** for per-agent and per-feedback data that may archive and later be restored. No **temporary** storage. | [Choosing the right storage](https://developers.stellar.org/docs/build/guides/storage/storage-strategies) |
| **Rent / TTL** | None: data lives forever | Every entry has a TTL and persistent entries archive when it expires. Nothing extends TTL automatically: puls3 write paths explicitly extend the instance and touched persistent keys (threshold 518,400 ledgers ≈ 30 days, bump to 1,036,800 ≈ 60 days); reads do not mutate TTL. Public maintenance methods let anyone keep identity data alive, while reputation maintenance extends contract instance state. This avoids hidden resource costs on read paths, at the cost of restoring inactive persistent records before use. | [Storage strategies](https://developers.stellar.org/docs/build/guides/storage/storage-strategies#the-three-storage-tiers) |
| **Upgrades** | Proxy pattern | Current Soroban guidance replaces a contract's executable in place with `env.deployer().update_current_contract(ContractExecutable::Wasm(new_wasm_hash))`; the contract address stays unchanged and the new WASM must already be uploaded. Authorization and any timelock are contract policy, not automatic platform behavior. **Not in the MVP:** on testnet we redeploy and update `contracts/deployments/testnet.json` (#15). Before mainnet, add an admin-gated, timelocked upgrade like Stellar 8004's. | [Upgrading contracts](https://developers.stellar.org/docs/build/guides/conventions/upgrading-contracts) |
| **Amounts / scores** | `int128 value` + `uint8 valueDecimals` | `value: i128` + `value_decimals: u32` (Soroban has no `u8` contract type). Aggregation uses checked arithmetic. | Stellar 8004 reputation contract |
| **Singleton per chain** | One deployment per chain | One deployment per network; contract IDs in `contracts/deployments/<network>.json`. | — |

## 4. MVP decision

| Registry | MVP? | Issue | Why |
|---|---|---|---|
| **Identity** | **P0, in** | #13 | Every agent needs an owner, a payment address, and a metadata URI before it can be listed or paid. Required for the Odyssey demo. |
| **Reputation** | **P1, in** | #14 | Needed for the "rate the agent" step in the vision's demo criteria. Built after Identity (HackMeridian milestone). |
| **Validation** | **Out** | — | Needs validators (re-execution, zkML, TEE) that do not exist for our agents. Listed as out of scope in the vision. |

The interfaces #13 and #14 implement are in [ADR-0002 §Interfaces](../adr/0002-agent-registry-on-soroban.md#interfaces).

## 5. Open questions

1. **Discoverability in the Stellar 8004 ecosystem.** Tools such as stellar-agent-search read the stellar8004.com indexer, which only indexes the Stellar 8004 contracts. Do we ask the Stellar 8004 team to index our registry, register puls3 agents in their registry as well, or move to their contracts after the hackathons? The shared subset reduces integration work, but the payment-backed write path needs a puls3 adapter.
2. **Setting the agent wallet at registration.** `register*` sets `agentWallet` to the owner, and `set_agent_wallet` needs signatures from both the owner and the new wallet. With server-custodied agent wallets (ADR-0003, #7), deploying an agent means a second transaction, or one transaction that carries both the builder's signature and a server-signed auth entry. #7 and #18 decide which.
3. **What goes in `agent_uri`.** ERC-8004 expects a registration file. Who hosts it (our server over HTTPS, or IPFS), and its schema, depend on the Agent Studio manifest (#33, #34).
4. **Reputation aggregation for puls3.** `get_summary` only aggregates the clients passed in, capped at 5 by Stellar 8004. ADR-0002 now requires the write path to consume a unique, pre-authorized paid hire, so every stored feedback entry is payment-backed. #11 still decides which eligible clients and tags the product includes in displayed summaries.
5. **Upgrades before mainnet.** Whether to adopt Stellar 8004's timelocked upgrade functions (`propose_upgrade`, `execute_upgrade`, ...) with the same signatures.
6. **SDK major and CLI.** Testnet is on protocol 28 (RPC `getVersionInfo`, 2026-09-23) and `soroban-sdk` 28.0.0 was released on 2026-09-18. Building a contract with it needs `stellar` CLI v25.2.0 or newer. #12 confirms both and records them.
