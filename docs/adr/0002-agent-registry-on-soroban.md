# ADR-0002: Agent registries on Soroban, aligned with a Stellar 8004 subset

- **Status:** Proposed
- **Date:** 2026-09-23
- **Issue:** #6
- **Research:** [Spike: ERC-8004 on Soroban](../spikes/erc8004-soroban.md)
- **Implemented by:** #13 (Identity Registry), #14 (Reputation Registry)

## Context

Every puls3 agent needs an on-chain identity (owner, payment address, metadata) and, later, a reputation built from consumer feedback. On EVM chains this is [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004). The spike found that [Stellar 8004](https://github.com/trionlabs/stellar-8004) already implements ERC-8004 on Soroban, on testnet and mainnet, and that ecosystem tools (explorer, SDK, an MCP search server) are built around its interface.

We need to decide whether puls3 uses those contracts, copies them, or writes its own, and fix an interface precise enough that #13 and #14 can start without design questions.

## Decision

1. **puls3 deploys its own Identity Registry (#13) and Reputation Registry (#14).** They are written by the team, in `contracts/identity-registry/` and `contracts/reputation-registry/`, on the `soroban-sdk` version pinned by #12.
2. **Both align with the Stellar 8004 interface where the MVP subset permits it** (inspected at commit [`d92c2f4`](https://github.com/trionlabs/stellar-8004/tree/d92c2f4ee01858b6da9bf4404ac49322c324958b)). Functions explicitly marked as shared keep the same name, argument order, and types. Unmodified events and error codes retain their Stellar 8004 shape and values. This is **not drop-in compatibility**: clients need a puls3 adapter for omitted functions, typed-error differences, URI uniqueness, and the payment-backed feedback extension; in particular, puls3 changes the `NewFeedback` data and `give_feedback` signature.
3. **The supported subset and differences are explicit:**
   - Functions that panic in Stellar 8004 on bad input return `Result<_, Error>` in ours (our rule: no string panics). On success they return the same value.
   - **Out of the MVP:** NFT transfers and approvals (`transfer`, `transfer_from`, `approve`, `approve_for_all`, `get_approved`, `is_approved_for_all`) and upgrades (`propose_upgrade`, `cancel_upgrade`, `execute_upgrade`, `pending_upgrade`). Without approvals, "owner or approved" means "owner".
   - **puls3 additions:** an agent URI can be registered only once (`UriAlreadyRegistered`), plus a lookup `agent_id_by_uri`; and reputation feedback must consume a unique, pre-authorized paid hire. ERC-8004 lets one owner hold many agents, so a duplicate is defined by the URI, not by the owner.
4. **Validation Registry: out of the MVP.**
5. **No dependency on OpenZeppelin `stellar-tokens`** until a release supports our SDK major (0.7.2 requires `soroban-sdk ^26.1`). The Identity Registry stores ownership itself and exposes the NFT read functions by name, so an NFT base can be swapped in later without changing the interface.

## Interfaces

These are the public interfaces #13 and #14 must implement. **Names and signatures are final.** Bodies, private helpers, and module layout are up to the implementer. `Error` codes are part of the interface: never renumber them.

Common constants (both contracts):

```rust
/// Extend a key's TTL when it has fewer than this many ledgers left (~30 days at ~5 s per ledger).
pub const TTL_THRESHOLD: u32 = 518_400;
/// Extend it to this many ledgers (~60 days).
pub const TTL_BUMP: u32 = 1_036_800;
```

### Identity Registry (`contracts/identity-registry`, #13)

```rust
#[contracttype]
#[derive(Clone)]
pub struct MetadataEntry {
    pub key: String,
    pub value: Bytes,
}

pub const MAX_METADATA_KEY_LEN: u32 = 64;
pub const MAX_METADATA_VALUE_LEN: u32 = 4096;
pub const MAX_METADATA_KEYS: u32 = 100;
/// Reserved metadata key. Read through `get_metadata`, written only through `set_agent_wallet`.
pub const AGENT_WALLET_KEY: &str = "agentWallet";

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
#[repr(u32)]
pub enum IdentityError {
    NotOwnerOrApproved = 1,
    UriNotSet = 2,
    AgentNotFound = 3,
    MetadataKeyTooLong = 4,
    MetadataValueTooLong = 5,
    TooManyMetadataKeys = 6,
    ReservedMetadataKey = 7,
    EmptyValue = 8,
    // 9, 10, 11: reserved for the upgrade errors of Stellar 8004. Do not use.
    /// puls3 addition: this agent URI already belongs to another agent.
    UriAlreadyRegistered = 100,
}

#[contractimpl]
impl IdentityRegistryContract {
    /// Sets the admin and the collection name and symbol (kept for NFT compatibility).
    /// The admin has no power over agents in the MVP.
    pub fn __constructor(e: &Env, owner: Address, name: String, symbol: String);

    // --- Registration. All three: `caller.require_auth()`, mint the next sequential
    // `agent_id` (starting at 0) to `caller`, set `agentWallet` to `caller`, emit
    // `MetadataSet` for `agentWallet`, then `Registered`. ---

    /// Registers an agent with no URI.
    pub fn register(e: &Env, caller: Address) -> Result<u32, IdentityError>;

    /// Registers an agent with its registration-file URI.
    /// Errors: `EmptyValue` if `agent_uri` is empty, `UriAlreadyRegistered`.
    pub fn register_with_uri(e: &Env, caller: Address, agent_uri: String) -> Result<u32, IdentityError>;

    /// Registers an agent with a URI and initial metadata. Validates every entry
    /// before writing anything. Emits one `MetadataSet` per entry.
    /// Errors: those of `register_with_uri`, plus `TooManyMetadataKeys`,
    /// `MetadataKeyTooLong`, `MetadataValueTooLong`, `ReservedMetadataKey`, `EmptyValue` (empty key).
    pub fn register_full(
        e: &Env,
        caller: Address,
        agent_uri: String,
        metadata: Vec<MetadataEntry>,
    ) -> Result<u32, IdentityError>;

    // --- URI ---

    /// Owner only (`caller.require_auth()`). Frees the old URI and claims the new one.
    /// Emits `UriUpdated`.
    /// Errors: `EmptyValue`, `AgentNotFound`, `NotOwnerOrApproved`, `UriAlreadyRegistered`.
    pub fn set_agent_uri(e: &Env, caller: Address, agent_id: u32, new_uri: String) -> Result<(), IdentityError>;

    /// Errors: `UriNotSet` (also when the agent does not exist, as in Stellar 8004).
    pub fn agent_uri(e: &Env, agent_id: u32) -> Result<String, IdentityError>;

    /// puls3 addition. The agent that owns this URI, if any.
    pub fn agent_id_by_uri(e: &Env, agent_uri: String) -> Option<u32>;

    // --- Metadata ---

    /// Owner only. Emits `MetadataSet`.
    /// Errors: `EmptyValue` (empty key), `MetadataKeyTooLong`, `MetadataValueTooLong`,
    /// `ReservedMetadataKey`, `AgentNotFound`, `NotOwnerOrApproved`, `TooManyMetadataKeys` (new key only).
    pub fn set_metadata(e: &Env, caller: Address, agent_id: u32, key: String, value: Bytes) -> Result<(), IdentityError>;

    /// For `agentWallet`, returns the wallet address as StrKey ASCII bytes.
    pub fn get_metadata(e: &Env, agent_id: u32, key: String) -> Option<Bytes>;

    // --- Agent wallet (the address that receives payments) ---

    /// Owner only, and the new wallet must also authorize (`new_wallet.require_auth()`),
    /// so nobody can point payments at a wallet they do not control.
    /// Emits `MetadataSet` with key `agentWallet` and the StrKey bytes as value.
    /// Errors: `AgentNotFound`, `NotOwnerOrApproved`.
    pub fn set_agent_wallet(e: &Env, caller: Address, agent_id: u32, new_wallet: Address) -> Result<(), IdentityError>;

    pub fn get_agent_wallet(e: &Env, agent_id: u32) -> Option<Address>;

    /// Owner only. Emits `MetadataSet` with key `agentWallet` and an empty value.
    pub fn unset_agent_wallet(e: &Env, caller: Address, agent_id: u32) -> Result<(), IdentityError>;

    // --- Queries ---

    /// Non-panicking owner lookup, safe for cross-contract calls (used by #14).
    pub fn find_owner(e: &Env, agent_id: u32) -> Option<Address>;
    pub fn agent_exists(e: &Env, agent_id: u32) -> bool;
    /// True if `spender` owns the agent. False if the agent does not exist.
    /// (Approvals are out of the MVP, so "or approved" never applies.)
    pub fn is_authorized_or_owner(e: &Env, spender: Address, agent_id: u32) -> bool;
    /// Number of agents ever registered. Agent IDs are `0..total_agents()`.
    pub fn total_agents(e: &Env) -> u32;
    pub fn version(e: &Env) -> String; // "0.1.0"

    // --- NFT read functions (names and argument types from OpenZeppelin `NonFungibleToken`) ---

    /// Errors: `AgentNotFound` (Stellar 8004 panics here instead).
    pub fn owner_of(e: &Env, token_id: u32) -> Result<Address, IdentityError>;
    /// Number of agents owned by `account`.
    pub fn balance(e: &Env, account: Address) -> u32;
    /// The agent URI, or an empty string if none. Errors: `AgentNotFound`.
    pub fn token_uri(e: &Env, token_id: u32) -> Result<String, IdentityError>;
    pub fn name(e: &Env) -> String;
    pub fn symbol(e: &Env) -> String;

    // --- TTL ---

    /// Anyone can call it. Extends the instance and every persistent key of `agent_id`.
    pub fn extend_ttl(e: &Env, agent_id: u32);
}
```

**Events.** Declared with `#[contractevent]` and default names, so the first topic is the snake_case struct name, the same as in Stellar 8004.

```rust
#[contractevent]
pub struct Registered {
    #[topic] pub agent_id: u32,
    #[topic] pub owner: Address,
    pub agent_uri: String,        // empty for `register`
}

#[contractevent]
pub struct UriUpdated {
    #[topic] pub agent_id: u32,
    #[topic] pub updated_by: Address,
    pub new_uri: String,
}

/// Every metadata write, including `agentWallet`, goes through this event.
#[contractevent]
pub struct MetadataSet {
    #[topic] pub agent_id: u32,
    #[topic] pub key: String,
    pub value: Bytes,
}
```

**Storage.**

| Key | Type | Value | Why this storage type |
|---|---|---|---|
| `Admin` | Instance | `Address` | Contract-wide config, small, read on every call |
| `Name`, `Symbol` | Instance | `String` | Contract-wide config |
| `NextId` | Instance | `u32` | Global counter; lives as long as the contract |
| `Owner(u32)` | Persistent | `Address` | Per agent; losing it means losing the agent |
| `Balance(Address)` | Persistent | `u32` | Per owner, grows with users |
| `AgentUri(u32)` | Persistent | `String` | Per agent |
| `UriIndex(String)` | Persistent | `u32` | puls3 addition: URI → agent, enforces uniqueness |
| `AgentWallet(u32)` | Persistent | `Address` | Per agent |
| `Metadata(u32, String)` | Persistent | `Bytes` | Per agent and key |
| `MetadataKeys(u32)` | Persistent | `Vec<String>` | Keys of an agent, to count them and to extend their TTL |

**TTL rules.**

- Every write extends the instance TTL and the TTL of each persistent key it writes, plus `Owner(agent_id)`.
- `extend_ttl(agent_id)` extends the instance and all of the agent's keys: `Owner`, the owner's `Balance`, `AgentUri`, its `UriIndex`, `AgentWallet`, `MetadataKeys`, and every `Metadata` entry.
- Reads do not extend TTLs.
- "Extend" means `extend_ttl(key, TTL_THRESHOLD, TTL_BUMP)`: it only acts when the key's TTL is below `TTL_THRESHOLD`, and then sets it to `TTL_BUMP` ([`soroban-sdk` docs](https://docs.rs/soroban-sdk/latest/soroban_sdk/storage/struct.Persistent.html#method.extend_ttl)).
- #13 tests these rules: advance the test ledger until the keys' TTL is below `TTL_THRESHOLD`, call the write or `extend_ttl`, and assert that each listed key's TTL equals `TTL_BUMP`.

### Reputation Registry (`contracts/reputation-registry`, #14)

The read model and shared feedback fields follow the Stellar 8004 Reputation Registry subset below. puls3 deliberately extends the write path so the contract enforces "one verified paid hire, at most one reputation entry." This makes the Reputation Registry non-drop-in-compatible with Stellar 8004.

Before feedback, the Serverpod payment verifier confirms the expected asset, amount, recipient, successful transaction, and that the payment reference has not already funded another hire. It derives a deterministic `hire_id` from the puls3 hire record and verified transaction reference, then asks the configured authorizer to register `(hire_id, agent_id, client_address)`. The authorizer must authenticate, and the contract rejects a second authorization for the same `hire_id`. `give_feedback` requires the same client to authenticate, checks the tuple, and marks the authorization consumed in the same contract invocation that stores feedback. If that invocation fails, neither state change may persist. Revocation does not reset the consumed flag.

The registry therefore enforces **one authorization and at most one feedback per `hire_id`**; it does not prove that the identifier represents a real payment. Payment validity and one-payment/one-hire idempotency remain trusted responsibilities of the Serverpod verifier and authorizer. The authorizer custody and recovery policy remains owned by ADR-0003.

```rust
#[contracttype]
#[derive(Clone)]
pub struct FeedbackData {
    pub value: i128,
    pub value_decimals: u32,
    pub is_revoked: bool,
    pub tag1: String,
    pub tag2: String,
}

#[contracttype]
#[derive(Clone)]
pub struct SummaryResult {
    pub count: u64,
    pub summary_value: i128,
    pub summary_value_decimals: u32,
}

/// `get_summary` reads at most this many clients per call.
pub const MAX_SUMMARY_CLIENTS: u32 = 5;
/// `value` must be within ±1e38.
pub const MAX_ABS_VALUE: i128 = 100_000_000_000_000_000_000_000_000_000_000_000_000;

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
#[repr(u32)]
pub enum ReputationError {
    SelfFeedback = 1,
    FeedbackNotFound = 2,
    InvalidValueDecimals = 3,
    NotOwnerOrApproved = 4,       // unused, kept for ABI stability (as in Stellar 8004)
    AggregateOverflow = 5,
    AgentNotFound = 6,
    EmptyValue = 7,
    ValueOutOfRange = 8,
    ClientAddressesRequired = 9,
    // 10, 11, 12: reserved for the upgrade errors of Stellar 8004. Do not use.
    HireNotAuthorized = 100,
    HireAlreadyAuthorized = 101,
    HireAuthorizationConsumed = 102,
}

#[contractimpl]
impl ReputationRegistryContract {
    /// `identity_registry` is the puls3 Identity Registry contract ID.
    /// `feedback_authorizer` authenticates hires after the server verifies payment.
    pub fn __constructor(e: &Env, owner: Address, identity_registry: Address, feedback_authorizer: Address);

    /// puls3 extension. Loads `FeedbackAuthorizer` from instance storage, requires
    /// that configured address to authenticate, and registers one payment-backed
    /// hire. A `hire_id` may be registered only once.
    pub fn authorize_feedback(
        e: &Env,
        hire_id: BytesN<32>,
        agent_id: u32,
        client_address: Address,
    ) -> Result<(), ReputationError>;

    /// `caller.require_auth()`. The agent must exist (`AgentNotFound`), and the caller
    /// must not own it (`SelfFeedback`, checked with `is_authorized_or_owner` on the
    /// Identity Registry). `hire_id` must be authorized for this agent and caller and
    /// not previously consumed. Consumption and feedback storage are atomic.
    /// Stores feedback under the next index for (agent, caller),
    /// starting at 1. `endpoint`, `feedback_uri`, `feedback_hash` are only emitted.
    /// Errors also: `InvalidValueDecimals` (> 18), `ValueOutOfRange`.
    pub fn give_feedback(
        e: &Env,
        caller: Address,
        hire_id: BytesN<32>,
        agent_id: u32,
        value: i128,
        value_decimals: u32,
        tag1: String,
        tag2: String,
        endpoint: String,
        feedback_uri: String,
        feedback_hash: BytesN<32>,
    ) -> Result<(), ReputationError>;

    /// Only the client who gave it. Errors: `FeedbackNotFound` (also if already revoked).
    pub fn revoke_feedback(e: &Env, caller: Address, agent_id: u32, feedback_index: u64) -> Result<(), ReputationError>;

    /// Anyone can respond (e.g. the agent owner disputing a review).
    /// Errors: `EmptyValue` (empty `response_uri`), `FeedbackNotFound`.
    pub fn append_response(
        e: &Env,
        caller: Address,
        agent_id: u32,
        client_address: Address,
        feedback_index: u64,
        response_uri: String,
        response_hash: BytesN<32>,
    ) -> Result<(), ReputationError>;

    pub fn read_feedback(e: &Env, agent_id: u32, client_address: Address, feedback_index: u64) -> Result<FeedbackData, ReputationError>;

    /// Average of the non-revoked feedback from the first `MAX_SUMMARY_CLIENTS` of
    /// `client_addresses`, filtered by `tag1`/`tag2` when not empty. Values are
    /// normalized to 18 decimals, averaged with checked arithmetic, and returned in the
    /// most frequent `value_decimals` (ties go to the lowest).
    /// Errors: `ClientAddressesRequired` (empty list), `AggregateOverflow`.
    pub fn get_summary(
        e: &Env,
        agent_id: u32,
        client_addresses: Vec<Address>,
        tag1: String,
        tag2: String,
    ) -> Result<SummaryResult, ReputationError>;

    pub fn get_clients_paginated(e: &Env, agent_id: u32, start: u32, limit: u32) -> Vec<Address>;
    pub fn get_last_index(e: &Env, agent_id: u32, client_address: Address) -> u64;
    pub fn get_response_count(e: &Env, agent_id: u32, client_address: Address, feedback_index: u64) -> u32;
    pub fn get_identity_registry(e: &Env) -> Address;
    pub fn extend_ttl(e: &Env);
    pub fn version(e: &Env) -> String; // "0.1.0"
}
```

**Events.**

```rust
#[contractevent]
pub struct NewFeedback {
    #[topic] pub agent_id: u32,
    #[topic] pub client_address: Address,
    #[topic] pub tag1: String,
    pub hire_id: BytesN<32>,
    pub feedback_index: u64,
    pub value: i128,
    pub value_decimals: u32,
    pub tag2: String,
    pub endpoint: String,
    pub feedback_uri: String,
    pub feedback_hash: BytesN<32>,
}

#[contractevent]
pub struct FeedbackRevoked {
    #[topic] pub agent_id: u32,
    #[topic] pub client_address: Address,
    #[topic] pub feedback_index: u64,
}

#[contractevent]
pub struct ResponseAppended {
    #[topic] pub agent_id: u32,
    #[topic] pub client_address: Address,
    #[topic] pub responder: Address,
    pub feedback_index: u64,
    pub response_uri: String,
    pub response_hash: BytesN<32>,
}
```

**Storage.**

| Key | Type | Value | Why this storage type |
|---|---|---|---|
| `Admin` | Instance | `Address` | Contract-wide config |
| `IdentityRegistry` | Instance | `Address` | Contract-wide config, read on every `give_feedback` |
| `FeedbackAuthorizer` | Instance | `Address` | Account allowed to register payment-verified hires |
| `HireAuthorization(BytesN<32>)` | Persistent | `(u32, Address, bool)` | Agent, client, and consumed flag; replay-protection record that must be restored if archived |
| `Feedback(u32, Address, u64)` | Persistent | `FeedbackData` | Per feedback; restorable after archival |
| `LastIndex(u32, Address)` | Persistent | `u64` | Per (agent, client) |
| `ClientCount(u32)` | Persistent | `u32` | Per agent |
| `ClientAtIndex(u32, u32)` | Persistent | `Address` | Per agent, for pagination |
| `ClientExists(u32, Address)` | Persistent | `bool` | Per (agent, client) |
| `ResponseCount(u32, Address, u64)` | Persistent | `u32` | Per feedback |

**TTL rules.** Every write explicitly extends the instance and each persistent key it writes; Soroban does not extend TTL merely because a key was read or written. `authorize_feedback` extends the new authorization key, and `give_feedback` extends that same key when marking it consumed plus all feedback/index keys it writes. Reads do not extend TTL. The public `extend_ttl()` method extends only instance storage, matching the Stellar 8004-shaped maintenance method; inactive persistent entries can archive and must be restored before use. TTL expiry is storage lifecycle, not a replay-protection deadline: the consumed flag remains authoritative after restoration.

### Implementation notes

The original Stellar 8004-aligned interfaces were checked on 2026-09-23 with stub bodies against `soroban-sdk` 28.0.0 (`cargo check` and `cargo clippy --all-targets -- -D warnings`). The payment-backed feedback additions in this Proposed revision have not yet been implemented or compile-checked:

- The previously checked shared signatures, errors, and events compiled as written. #14 must repeat that check for the revised constructor, authorization method, feedback signature, and event.
- `give_feedback` and `append_response` have more than 7 arguments, which clippy rejects under `-D warnings`, also in the code generated by `#[contractimpl]`. An `#[allow]` on the `impl` block is **not** enough. #14 adds `#![allow(clippy::too_many_arguments)]` at the top of the crate's `lib.rs` and documents why at the crate boundary.
- `soroban-sdk` 28 refuses to build a contract with `stellar` CLI older than **v25.2.0** ("soroban-sdk requires stellar-cli v25.2.0+ to build a contract"). #12 records this in the prerequisites.

## Consequences

- #13 and #14 can start now: the interface, errors, events, storage keys, and TTL rules are fixed above.
- Shared read operations and unmodified events can reuse Stellar 8004 mappings, but clients require a puls3 adapter for omitted methods, typed-error differences, URI uniqueness, and payment-backed feedback authorization. Moving to Stellar 8004 deployments would require code and product-policy changes, not only a contract ID change.
- **Our agents do not appear in stellar8004.com or tools built on its indexer** (such as stellar-agent-search) unless that indexer adds our contracts. The spike lists the options.
- Without transfers, an agent's ownership cannot change in the MVP. A builder who loses their wallet loses control of their agents.
- Without upgrades, fixing a bug on testnet means redeploying and re-seeding (#15). Mainnet needs an upgrade path first.
- `set_agent_wallet` needs the agent wallet's authorization, so the custody decision in ADR-0003 (#7) must say how the server provides that signature.
- ADR-0001 is unchanged: the builder's wallet signs registration and metadata changes; the consumer's wallet signs feedback.

## Alternatives considered

1. **Use the Stellar 8004 contracts already deployed.** Fastest, and puls3 agents would appear in stellar8004.com and its tools right away. Rejected for now: the team would have no Soroban contract of its own for the hackathon evaluations, we would depend on a third party's admin and upgrade keys, and the deployed write interface does not enforce puls3's one-payment/one-feedback invariant. A later migration needs an adapter or a deliberate reduction of that product guarantee.
2. **Fork Stellar 8004's code.** Fastest path to our own deployment. Rejected: it pins `soroban-sdk` 25 and an OpenZeppelin git revision that does not support the SDK major #12 must use, it includes transfers, approvals and upgrades we would have to own and test, and it panics with strings where our rules require typed errors.
3. **A puls3-specific interface** (the original plan in #6). Rejected: it would split the ERC-8004 ecosystem on Stellar for no benefit, and our agents could never be read by existing tools.
4. **Only off-chain identity in Serverpod.** Rejected: agent identity and reputation are what the Stellar hackathons evaluate and what makes reputation hard to fake.
