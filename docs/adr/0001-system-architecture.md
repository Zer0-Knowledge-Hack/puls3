# ADR-0001: System architecture

- **Status:** Proposed
- **Date:** 2026-09-23
- **Issue:** #5
- **Related:** [Product vision](../vision.md) (#2) · [C4 diagrams](../architecture/c4.md) · ADR-0002 agent registry (#6) · ADR-0003 payment rail and custody (#7)

## Context

puls3 lets builders create AI agents, and lets consumers find, hire, and pay them in USDC on Stellar ([vision](../vision.md)). Three technologies are fixed by the hackathons we target:

- **Flutter** for the app (web first)
- **Serverpod** (Dart) for the backend, which is judged on "use of the Serverpod stack"
- **Soroban** (Rust) for the on-chain agent registries

Before anyone writes feature code, the team needs one agreed answer to: which components exist, which layer owns which rule, how the code is laid out in the repo, who signs which transaction, and how we move between networks.

Two constraints shape the answer:

1. [`stellar_flutter_sdk`](https://pub.dev/packages/stellar_flutter_sdk) declares `flutter: sdk: flutter` as a dependency (checked on pub.dev on 2026-09-23, version 3.7.0), so it **cannot run inside the Serverpod server**, which is a plain Dart process.
2. The repo is public and the MVP moves real (testnet) assets, so private keys must live in as few places as possible.

## Decision

### 1. Hexagonal architecture with a pure Dart domain

Business rules live in one **pure Dart package**, `puls3_domain`. It defines the ubiquitous language (entities such as `Agent`, `Skill`, `Hire`, `Payment`, `Feedback`, and value objects such as `UsdcAmount` and `StellarAddress`) and the **ports** that the outside world must implement.

**Dependency rule:** `puls3_server` and `puls3_flutter` depend on `puls3_domain`. **Never the other way.** The domain must not import `package:serverpod`, `package:flutter`, `package:stellar_flutter_sdk`, `package:stellar_dart`, or any HTTP or database library.

```
puls3_flutter ──┐
                ├──► puls3_domain   (pure Dart: entities, rules, ports)
puls3_server  ──┘
```

Ports defined in the domain (names are final, signatures are defined by #9):

| Port | Responsibility | Adapter (backend) |
|---|---|---|
| `AgentRepository` | Store and load agents, drafts, and hires | Serverpod ORM on PostgreSQL |
| `LedgerPort` | Read on-chain state (agent identity, payments, events) and submit server-signed transactions | Stellar RPC over HTTP + `stellar_dart` (see §4) |
| `AgentRuntimePort` | Run a deployed agent's task and return the result | LLM provider HTTP API |

The domain is tested with `dart test` and no network, database, or chain. A CI check (#29) fails if the domain imports a forbidden package:

```bash
grep -rnE "package:(serverpod|flutter|stellar_flutter_sdk|stellar_dart|http)" puls3_domain/lib   # must print nothing
```

### 2. Layers and what each one owns

| Layer | Owns | Does not own |
|---|---|---|
| **Soroban contracts** | The source of truth for agent identity (owner, payment address, metadata URI) and reputation. Rules that must hold even if our server is down or dishonest. | Prices, prompts, task results, anything that changes often or is private |
| **Domain** (`puls3_domain`) | Business rules: the hire lifecycle (#10), price and amount rules, manifest validation (#34), reputation rules (#11) | I/O of any kind |
| **Server** (`puls3_server`) | Endpoints, persistence, verifying payments on-chain before running an agent, running agents, indexing on-chain data for the catalog | User keys. The user's decisions to pay or register. |
| **App** (`puls3_flutter`) | UI, the user's wallet connection, building and signing the user's transactions | Business rules beyond input validation |

### 3. Repo layout

| Folder | Responsibility | Area label |
|---|---|---|
| `docs/` | Product docs, pitch, submission packages | `area: docs` |
| `docs/adr/`, `docs/architecture/`, `docs/spikes/` | Decisions, diagrams, and time-boxed research | `area: architecture` |
| `docs/blueprints/` | User flows, wireframes, screen specs (#22, #23, #36) | `area: blueprints` |
| `puls3_domain/` | Pure Dart domain package, part of the root pub workspace | `area: domain` |
| `contracts/` | Soroban Cargo workspace: one crate per contract, `deployments/<network>.json` with contract IDs | `area: contracts` |
| `puls3_server/` | Serverpod server: endpoints, adapters, migrations | `area: backend` |
| `puls3_client/` | Serverpod-generated client. Never edited by hand: it changes only through `serverpod generate` inside a `backend` PR | `area: backend` |
| `puls3_flutter/` | Flutter app (Studio and Marketplace) | `area: frontend` |
| `.github/`, `scripts/` | CI workflows, deploy, seed, and setup scripts | `area: infra` |
| `spikes/` | Throwaway proofs of concept from spikes (e.g. #7). Never imported by product code | `area: architecture` |
| `assets/`, `design/` | Brand assets and design sources (#24, #38) | `area: docs` |

`puls3_domain/` sits at the repo root next to the other `puls3_*` packages, instead of the `packages/puls3_domain/` default mentioned in #9, so the workspace stays flat and consistent. It is added to the root `pubspec.yaml` workspace list by #9.

### 4. Who signs what

The rule: **a transaction is signed by whoever is spending or committing to something.** Users sign with their own wallet, in the app. The server signs only for accounts it controls.

| Transaction | Signed by | Where | Why |
|---|---|---|---|
| Register an agent in the Identity Registry (`register`, owner auth) | The **builder's wallet** | App (`puls3_flutter`, `stellar_flutter_sdk` + wallet) | The builder is the on-chain owner. The server must not be able to register or change agents on a builder's behalf. |
| Update an agent's metadata | The **builder's wallet** | App | Owner-only operation (#13) |
| Pay an agent for a hire (USDC) | The **consumer's wallet** | App | Only the payer can authorize spending their funds |
| Submit feedback to the Reputation Registry | The **consumer's wallet** | App | Ties feedback to a real payer (#14) |
| Create and fund an agent's wallet, add its USDC trustline, move funds out of it | The **agent's wallet key**, held by the server | Server (`stellar_dart`) | The agent is a server-side actor. Custody model decided in ADR-0003 (#7). |
| Verify a hire payment before running the agent | Nobody (read only) | Server, Stellar RPC `getTransaction` with `xdrFormat: "json"` | Reads need no key |

How the server reaches the chain:

- **Reads and verification:** Stellar RPC JSON-RPC over plain HTTP, with [`xdrFormat: "json"`](https://developers.stellar.org/docs/data/apis/rpc/api-reference/structure/data-format) so responses can be parsed without an XDR library.
- **Signing and submitting:** the pure Dart library [`stellar_dart`](https://pub.dev/packages/stellar_dart), which has no Flutter dependency. Its adoption risk and the fallback are recorded in ADR-0003 (#7), which owns the final answer.

Both live **only** in the `LedgerPort` adapter in `puls3_server`. Nothing else in the server imports a Stellar library.

### 5. Networks

- **MVP network: testnet.** Mainnet is out of scope ([vision](../vision.md#out)).
- Everything that differs per network is **configuration, never code**: RPC URL, network passphrase, USDC asset and its Stellar Asset Contract ID, and our contract IDs.
- Contract IDs come from `contracts/deployments/<network>.json`, written by the deploy script (#15).
- The server reads the active network from its environment. The app gets the network settings from the server, so both always point to the same network.
- Switching from `local` to `testnet` (or later to `mainnet`) means changing environment variables and redeploying, not editing code (#30).

| Setting | Testnet value | Source |
|---|---|---|
| RPC URL | `https://soroban-testnet.stellar.org` | [Networks](https://developers.stellar.org/docs/networks) |
| Network passphrase | `Test SDF Network ; September 2015` | [Networks](https://developers.stellar.org/docs/networks) |

## Consequences

- The domain can be built and tested before any contract or endpoint exists (#9, #10 start in parallel with #12, #13).
- The Serverpod server is where all orchestration happens (catalog indexing, payment verification, agent runtime), which is what the Serverpod judging criteria reward.
- User keys never touch our server. The server holds agent wallet keys, which makes it a custodian of agent earnings: ADR-0003 (#7) must state how those keys are stored and what an attacker could take.
- Every chain call from the server goes through one adapter, so replacing `stellar_dart` (if it fails us) touches one folder.
- The app needs a Stellar library and a wallet connection for signing (#25). This duplicates some transaction-building logic between app and server, which we accept.
- ADR-0002 (#6) and ADR-0003 (#7) update this section if their decisions change what is written here.

## Alternatives considered

1. **Layered architecture with business rules in Serverpod endpoints.** Faster to start, but rules would depend on Serverpod types, could not be shared with the app, and could not be tested without a database. Rejected: the hire lifecycle and price rules are the core of the product and must be testable on their own.
2. **Server signs everything (custodial for users too).** Simplest UX: no wallet in the app. Rejected: the server would hold users' funds and could register agents on behalf of any builder, which defeats the point of an on-chain identity and makes a server breach much worse.
3. **Business logic in Soroban contracts (hire lifecycle and escrow on-chain).** Most trustless, but every state change costs a transaction and a fee, contract changes need redeploys, and it doubles the contracts work before the Serverpod deadline. Rejected for the MVP; escrow is listed as out of scope in the vision and can move on-chain later.
4. **A TypeScript sidecar for all chain access** (using the reference Stellar SDKs). Mature libraries, but adds a second runtime and deployment to the backend, and takes chain work out of Serverpod. Kept only as the fallback in ADR-0003 if `stellar_dart` does not work.
