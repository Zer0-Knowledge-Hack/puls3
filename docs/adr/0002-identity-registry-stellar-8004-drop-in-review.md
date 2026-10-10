# Identity Registry: Stellar 8004 drop-in gap review

- **Issue:** #74 · **Type:** docs only (no code change)
- **Context:** [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D5 ("own registries, drop-in compatible with Stellar 8004"); [ADR-0002](0002-agent-registry-on-soroban.md) §Identity Registry (built by #13)
- **Puls3 side:** `contracts/contracts/identity-registry/src/lib.rs` (`IdentityRegistryContract`, `CONTRACT_VERSION = "0.1.0"`)
- **Compared against:** [trionlabs/stellar-8004](https://github.com/trionlabs/stellar-8004) at commit [`d92c2f4ee01858b6da9bf4404ac49322c324958b`](https://github.com/trionlabs/stellar-8004/tree/d92c2f4ee01858b6da9bf4404ac49322c324958b) — the `main` head on 2026-10-09 and the same commit ADR-0002 pinned. Contract `IdentityRegistryContract`, `contractmeta` `Version = "0.1.0"`.
- **Stellar 8004 build context:** `soroban-sdk = "25"`; OpenZeppelin `stellar-contracts` at rev `9dd85c30` (`stellar-tokens::non_fungible::NonFungibleToken`, `stellar-access::ownable::Ownable`).

## How to read this

- The vocabulary is ADR-0005 D5 / the #74 issue: **fix** (change puls3 to match), **additive extension** (a named puls3 addition, per the ADR-0005 D1 conformance rule), **document** (an accepted, documented difference).
- Every public function and event of the Stellar 8004 Identity Registry is listed. Functions inherited from OpenZeppelin's `NonFungibleToken` and `Ownable` traits are part of Stellar 8004's public ABI (`#[contractimpl(contracttrait)]`) and are therefore in scope.
- Gap IDs (`G1`…) are stable references for the [follow-ups](#follow-ups).

## Decisions at a glance

| Gap | Subject | Decision |
|---|---|---|
| [G1](#g1-typed-result-vs-panics) | Typed `Result` errors vs Stellar 8004 panics (`register*`, `owner_of`, `token_uri`) | document |
| [G2](#g2-urialreadyregistered--agent_id_by_uri) | `UriAlreadyRegistered` + `agent_id_by_uri` + URI uniqueness | additive extension |
| [G3](#g3-register_full-validation) | `register_full` validation timing and key counting | document |
| [G4](#g4-error-precedence) | Error precedence in `set_metadata` / `set_agent_uri` | document |
| [G5](#g5-ttl-on-reads) | Stellar 8004 reads extend TTL; puls3 reads do not | document |
| [G6](#g6-upgrade-functions) | Missing upgrade functions (`propose_upgrade` …) | document |
| [G7](#g7-authorization-semantics) | `is_authorized_or_owner` ignores approvals | document |
| [G8](#g8-nft-transfer--approval-functions) | Missing NFT transfer/approval functions and their events | document |
| [G9](#g9-ownable-interface) | Missing `Ownable` interface (`get_owner` …) | **fix** |
| [G10](#g10-event-emission-order) | `MetadataSet` emission order during `register_full` | document |
| [G11](#g11-mint-event) | Stellar 8004 emits an OZ `mint` event; puls3 does not | document |
| [G12](#g12-storage-layout) | Storage keys / layout are not interchangeable | document |
| [G13](#g13-wasm-contractmeta) | Missing WASM `contractmeta` (`Description`, `Version`) | document |
| [G14](#g14-metadata-key-accounting) | `agentWallet` counts toward the metadata-key limit | document |

Only **G9** is a **fix**; all other gaps are accepted deviations already implied by ADR-0002, or named puls3 additions.

## Public functions

Legend for the puls3 column: ✔ identical name/args/return; ⚠ same name/args but different return type or behavior; ✗ absent.

| # | Stellar 8004 `d92c2f4` | Puls3 `identity-registry` | Verdict | Gap | Decision |
|---|---|---|---|---|---|
| 1 | `__constructor(owner, name, symbol)` | same | ✔ | — | — |
| 2 | `register(caller) -> u32` | `register(caller) -> Result<u32, IdentityError>` | ⚠ | G1 | document |
| 3 | `register_with_uri(caller, agent_uri) -> u32` | `register_with_uri(...) -> Result<u32, IdentityError>` | ⚠ | G1, G2 | G1 document · G2 additive |
| 4 | `register_full(caller, agent_uri, metadata) -> u32` | `register_full(...) -> Result<u32, IdentityError>` | ⚠ | G1, G3 | G1 document · G3 document |
| 5 | `set_agent_uri(caller, agent_id, new_uri) -> Result<(), IdentityError>` | same | ⚠ (behavior) | G2, G4 | G2 additive · G4 document |
| 6 | `agent_uri(agent_id) -> Result<String, IdentityError>` | same | ✔ | — | — |
| 7 | `set_metadata(caller, agent_id, key, value) -> Result<(), IdentityError>` | same | ⚠ (behavior) | G4, G14 | document |
| 8 | `get_metadata(agent_id, key) -> Option<Bytes>` | same (also routes `agentWallet`) | ✔ | — | — |
| 9 | `set_agent_wallet(caller, agent_id, new_wallet) -> Result<(), IdentityError>` | same (dual auth: caller + new wallet) | ✔ | — | — |
| 10 | `get_agent_wallet(agent_id) -> Option<Address>` | same | ✔ | — | — |
| 11 | `unset_agent_wallet(caller, agent_id) -> Result<(), IdentityError>` | same | ✔ | — | — |
| 12 | `extend_ttl(agent_id) -> ()` | same | ⚠ (behavior) | G5 | document |
| 13 | `propose_upgrade(new_wasm_hash) -> Result<(), IdentityError>` | ✗ | ✗ | G6 | document |
| 14 | `cancel_upgrade() -> Result<(), IdentityError>` | ✗ | ✗ | G6 | document |
| 15 | `execute_upgrade() -> Result<(), IdentityError>` | ✗ | ✗ | G6 | document |
| 16 | `pending_upgrade() -> Option<UpgradeProposal>` | ✗ | ✗ | G6 | document |
| 17 | `version() -> String` | same (`"0.1.0"`) | ✔ | — | — |
| 18 | `find_owner(agent_id) -> Option<Address>` | same | ✔ | — | — |
| 19 | `agent_exists(agent_id) -> bool` | same | ✔ | — | — |
| 20 | `is_authorized_or_owner(spender, agent_id) -> bool` | same | ⚠ (behavior) | G7 | document |
| 21 | `total_agents() -> u32` | same | ✔ | — | — |
| 22 | `balance(account) -> u32` | same | ✔ | — | — |
| 23 | `owner_of(token_id) -> Address` (panics) | `owner_of(...) -> Result<Address, IdentityError>` | ⚠ | G1 | document |
| 24 | `transfer(from, to, token_id) -> ()` | ✗ | ✗ | G8 | document |
| 25 | `transfer_from(spender, from, to, token_id) -> ()` | ✗ | ✗ | G8 | document |
| 26 | `approve(approver, approved, token_id, live_until_ledger) -> ()` | ✗ | ✗ | G8 | document |
| 27 | `approve_for_all(owner, operator, live_until_ledger) -> ()` | ✗ | ✗ | G8 | document |
| 28 | `get_approved(token_id) -> Option<Address>` | ✗ | ✗ | G8 | document |
| 29 | `is_approved_for_all(owner, operator) -> bool` | ✗ | ✗ | G8 | document |
| 30 | `name() -> String` | same | ✔ | — | — |
| 31 | `symbol() -> String` | same | ✔ | — | — |
| 32 | `token_uri(token_id) -> String` (panics) | `token_uri(...) -> Result<String, IdentityError>` | ⚠ | G1 | document |
| 33 | `get_owner() -> Option<Address>` | ✗ | ✗ | G9 | **fix** |
| 34 | `transfer_ownership(new_owner, live_until_ledger) -> ()` | ✗ | ✗ | G9 | **fix** |
| 35 | `accept_ownership() -> ()` | ✗ | ✗ | G9 | **fix** |
| 36 | `renounce_ownership() -> ()` | ✗ | ✗ | G9 | **fix** |

Puls3-only function:

| Puls3 addition | Stellar 8004 | Decision |
|---|---|---|
| `agent_id_by_uri(agent_uri) -> Option<u32>` | absent | additive extension (G2) |

## Events

| Stellar 8004 `d92c2f4` | Puls3 | Verdict | Gap | Decision |
|---|---|---|---|---|
| `registered { agent_id(t), owner(t), agent_uri }` | `Registered` — same name, topics and data | ✔ | — | — |
| `uri_updated { agent_id(t), updated_by(t), new_uri }` | `UriUpdated` — same | ✔ | — | — |
| `metadata_set { agent_id(t), key(t), value }` | `MetadataSet` — same | ⚠ (order) | G10 | document |
| OZ `mint { to(t), token_id }` (emitted by `sequential_mint` on every `register*`) | absent | ✗ | G11 | document |
| OZ `transfer`, `approve`, `approve_for_all` (emitted only by the G8 functions) | absent | ✗ | G8 | document |

All three identity events keep the Stellar 8004 struct name, topic set (the `#[topic]` fields) and data shape. Puls3 topic names are the snake_case struct names (`metadata_set`, `registered`, `uri_updated`), identical to Stellar 8004's.

## Gap details and rationale

### G1. Typed `Result` vs panics

**Gap.** Stellar 8004's `register`, `register_with_uri` and `register_full` return `u32` and signal bad input with `assert!`/panic (string panics). `owner_of` returns `Address` and panics (`NonFungibleTokenError::NonExistentToken = 200`) for a missing token; `token_uri` returns `String` and panics for a missing token. Puls3 returns `Result<_, IdentityError>` for all five, and `owner_of`/`token_uri` return `Err(AgentNotFound)` (code 3).

**Decision: document.** ADR-0002 decision 3 fixes "no string panics: return `Result<_, Error>`", so on success the value is the same but the return type (and therefore the ABI) differs, and errors are typed codes instead of panics. This is the single largest deviation from D5's "identical" wording and is called out there for a deliberate acceptance.

**Reason:** keeping typed errors is a product rule; changing puls3 to panic would reintroduce the behaviour ADR-0002 rejected.

### G2. `UriAlreadyRegistered` + `agent_id_by_uri`

**Gap.** Stellar 8004 allows any number of agents to share a URI and has no URI→agent lookup. Puls3 adds: a `UriIndex(String) -> u32` storage entry, the `UriAlreadyRegistered = 100` error raised by `register_with_uri`, `register_full` and `set_agent_uri`, and the `agent_id_by_uri(agent_uri) -> Option<u32>` view. `set_agent_uri` also frees the previous URI's index entry.

**Decision: additive extension.** A named puls3 addition (ADR-0002 decision 3), it adds a new error code, a new storage key and a new function without renaming or renumbering anything Stellar 8004 exposes. A caller that reuses a URI sees a new failure Stellar 8004 would not produce; the API is otherwise unchanged.

**Reason:** the uniqueness guarantee is required by the marketplace (one URI, one agent) and is additive by construction.

### G3. `register_full` validation

**Gap.** Stellar 8004 asserts `metadata.len() <= MAX_METADATA_KEYS` and per-entry key/value length and reserved-key rules *before* minting, but does not reject an empty `agent_uri`, does not reject empty metadata keys, and counts the raw vector length (duplicates included). Puls3 rejects an empty `agent_uri` and empty keys, validates every entry before writing anything, and counts *distinct* keys plus the reserved `agentWallet` slot (G14).

**Decision: document.** ADR-0002 already specifies "validates every entry before writing anything" and the stricter validation set; the difference only changes which error a bad call returns, not a valid call.

**Reason:** stricter, atomic validation is intentional and superset-safe for well-formed inputs.

### G4. Error precedence

**Gap.** Puls3 checks ownership (`owner_of` first, then `caller == owner`) before validating `new_uri`/`key`; Stellar 8004 validates the string args first and only then calls `require_owner_or_approved`. For a non-owner (or unknown agent) that also passes an invalid value, the two contracts return different error codes.

**Decision: document.** Same error set and codes; only the order of checks in an already-erroneous call differs.

**Reason:** invisible to callers that pass valid input, and either ordering is defensible.

### G5. TTL on reads

**Gap.** Stellar 8004's `get_agent_uri`, `get_metadata` and `get_agent_wallet` call `extend_ttl` when the value is present (a side effect on a read). Puls3's reads never mutate TTL; ADR-0002 states "Reads do not extend TTLs", and only write paths plus the explicit `extend_ttl(agent_id)` do.

**Decision: document.** A deliberate TTL policy difference; puls3 exposes `extend_ttl(agent_id)` for the same maintenance purpose, but a Stellar-8004-style caller that relies on reads to keep keys alive would have to call it explicitly.

**Reason:** keeping reads free of hidden resource costs is an ADR-0002 decision.

### G6. Upgrade functions

**Gap.** Stellar 8004 exposes a timelocked upgrade system: `propose_upgrade`, `cancel_upgrade`, `execute_upgrade`, `pending_upgrade`, backed by `UpgradeProposal`, with error codes 9–11 (`NoUpgradeProposed`, `TimelockNotExpired`, `UpgradeAlreadyProposed`) and the `only_owner` guard. Puls3 has none; it reserves error codes 9–11 so they can be added without renumbering.

**Decision: document.** ADR-0002 decision 3 lists upgrades as out of the MVP; on testnet puls3 redeploys and re-seeds (#15). Codes 9–11 are intentionally reserved.

**Reason:** upgrades are explicitly out of scope until mainnet (spike open question 5).

### G7. Authorization semantics

**Gap.** `is_authorized_or_owner(spender, agent_id)` in Stellar 8004 returns true for the owner, an approved operator, or an operator approved for all (`Base::get_approved`, `is_approved_for_all`). Puls3 returns true only for the owner, because approvals are out of the MVP.

**Decision: document.** The signature is identical; the difference only materializes when approvals exist, which puls3 does not implement (G8). ADR-0002: "approvals are out of scope, so 'or approved' never applies".

**Reason:** no approvals means the two functions agree on every agent puls3 can hold.

### G8. NFT transfer / approval functions

**Gap.** Stellar 8004 inherits the full OZ `NonFungibleToken` write surface — `transfer`, `transfer_from`, `approve`, `approve_for_all`, `get_approved`, `is_approved_for_all` — and their events (`transfer`, `approve`, `approve_for_all`). A transfer also clears the agent's wallet and metadata. Puls3 has none of these; ownership is immutable in the MVP.

**Decision: document.** ADR-0002 decision 3 lists NFT transfers and approvals as out of the MVP; the read functions (`owner_of`, `balance`, `token_uri`, `name`, `symbol`) are kept by name so an NFT base can be swapped in later.

**Reason:** explicitly scoped out by ADR-0002; adding them is future work.

### G9. Ownable interface

**Gap.** Stellar 8004 implements OpenZeppelin `Ownable` (`#[contractimpl(contracttrait)]`), exposing `get_owner() -> Option<Address>`, `transfer_ownership(new_owner, live_until_ledger)`, `accept_ownership()` and `renounce_ownership()` in the public ABI. Puls3's `__constructor` stores an `Admin` address but exposes **no** getter or transfer function. Unlike the NFT write surface and the upgrades, ADR-0002 does not list `Ownable` as out of the MVP, so this is an unaccounted drop-in gap.

**Decision: fix.** Add the Stellar 8004 `Ownable` interface (at minimum the read `get_owner`, plus the transfer/accept/renounce functions for parity) so admin tooling written against Stellar 8004 works unchanged. Follow-up: [F1](#follow-ups).

**Reason:** a public ABI surface that ADR-0002 never excluded; low-risk and mostly read-only.

### G10. Event emission order

**Gap.** On `register`: Stellar 8004 order is `mint` → `metadata_set(agentWallet)` → `registered`. Puls3 order is `metadata_set(agentWallet)` → `registered`. On `register_full`: Stellar 8004 is `mint` → `metadata_set(agentWallet)` → `metadata_set(entry)`… → `registered`; puls3 is `metadata_set(entry)`… → `metadata_set(agentWallet)` → `registered`, i.e. the `agentWallet` write is emitted last rather than first. The set of identity events is the same.

**Decision: document.** Identical event names, topics and data; only intra-invocation ordering differs, and Soroban indexers key by topic, not by position.

**Reason:** not part of the ABI; no consumer contract can observe event order from another contract call.

### G11. Mint event

**Gap.** Stellar 8004's `register*` call `Base::sequential_mint`, which publishes OpenZeppelin's `mint { to(t), token_id }` event. Puls3 mints its own sequential id and publishes only `MetadataSet` + `Registered`.

**Decision: document.** The `mint` event belongs to the OZ NFT base that ADR-0002 keeps out of the MVP, alongside G8.

**Reason:** tied to the out-of-MVP NFT base; puls3's `Registered` event is the registration signal.

### G12. Storage layout

**Gap.** Stellar 8004 stores owner/balance under OZ `NFTStorageKey::{Owner, Balance}` and its own `DataKey::{AgentUri, Metadata, AgentWallet, MetadataKeys, PendingUpgrade}`; puls3 uses a single `DataKey` enum (`Admin`, `Name`, `Symbol`, `NextId`, `Owner`, `Balance`, `AgentUri`, `UriIndex`, `AgentWallet`, `Metadata`, `MetadataKeys`). The XDR encodings of the storage keys are not interchangeable, and puls3 adds `UriIndex`.

**Decision: document.** "Drop-in" is an interface (ABI) property; puls3 and Stellar 8004 are separate deployments with separate storage, so no client reads one contract's storage through the other. The table in ADR-0002 already documents puls3's keys.

**Reason:** storage layout is implementation-private; only the function/event interface is shared.

### G13. WASM `contractmeta`

**Gap.** Stellar 8004's crate declares `contractmeta!(key = "Description", val = "8004 Identity Registry")` and `contractmeta!(key = "Version", val = "0.1.0")`. Puls3's crate declares neither, so the deployed WASM carries no `Description`/`Version` metadata (its `version()` function still returns `"0.1.0"`).

**Decision: document.** Tooling-visible WASM metadata, not part of the callable ABI; both `version()` functions return `"0.1.0"`.

**Reason:** cosmetic/diagnostic only; adding the `contractmeta` attributes is optional future polish.

### G14. Metadata key accounting

**Gap.** Stellar 8004 stores the wallet in a dedicated slot and keeps it out of `MetadataKeys`; its `MAX_METADATA_KEYS` allows up to 100 user metadata keys plus the wallet. Puls3 writes `agentWallet` through the metadata store and counts it in `MetadataKeys`, so the limit is 99 user keys + the wallet.

**Decision: document.** ADR-0002 says "including the reserved `agentWallet` key" and the #13 tests assert this behaviour. The observable interface (`set_metadata` returning `TooManyMetadataKeys` at the limit) is the same, one key earlier for puls3.

**Reason:** an intentional puls3 accounting choice recorded in ADR-0002.

## Follow-ups

| ID | Gap | Follow-up | Tracked as |
|---|---|---|---|
| F1 | [G9](#g9-ownable-interface) | **Task — `fix(contracts): expose the Stellar 8004 Ownable interface on the Identity Registry`.** Add `get_owner() -> Option<Address>`, `transfer_ownership(new_owner, live_until_ledger)`, `accept_ownership()` and `renounce_ownership()` with the Stellar 8004 (OpenZeppelin `9dd85c30`) signatures, backed by the `Admin` address stored in the constructor. Add a test that `get_owner` returns the constructor owner and that only the owner can call the mutators; keep the error codes unchanged. | This review (F1); to be filed on the puls3 tracker as a follow-up issue when the PR for #74 lands. |

Gaps marked **document** or **additive extension** become no follow-up work.

## Verification

Spot-checked against both sources on 2026-10-09 (Stellar 8004 `d92c2f4`, puls3 `main`):

1. **`register_full`** — Stellar 8004 `contracts/identity-registry/src/contract.rs:72-108`: `-> u32`, `assert!` on `metadata.len() <= MAX_METADATA_KEYS`, key/value lengths and reserved key, then mint. Puls3 `contracts/contracts/identity-registry/src/lib.rs:129-157` and the helper `mint` (lines 434-503): `-> Result<u32, IdentityError>`, validates before minting, counts distinct keys + wallet. Confirms G1 and G3.
2. **`owner_of`** — Stellar 8004 `contract.rs:320-323` (the OZ `NonFungibleToken` impl); `owner_of` (OZ `packages/tokens/src/non_fungible/mod.rs:151`) returns `Address` and panics via `NonFungibleTokenError::NonExistentToken = 200`. Puls3 `lib.rs:367-372` returns `Err(IdentityError::AgentNotFound)` (`= 3`, `lib.rs:35`). Confirms G1.
3. **`get_metadata` / `agentWallet`** — Stellar 8004 `contract.rs:172-178` routes the `agentWallet` key to `storage::get_agent_wallet` and returns StrKey bytes; puls3 `lib.rs:261-265` reads the metadata entry that `set_agent_wallet`/mint write (`lib.rs:283-286`, `451-456`). Both return `Option<Bytes>` of StrKey ASCII. Confirms the row #8 match and G14.

Additional sources consulted: `errors.rs`, `events.rs`, `storage.rs`, `types.rs` in the Stellar 8004 crate; OZ `packages/access/src/ownable/mod.rs` and `packages/tokens/src/non_fungible/{mod,storage}.rs` at rev `9dd85c30`.
