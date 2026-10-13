#![no_std]

//! Agent reputation registry: ERC-8004 feedback on Soroban, drop-in with the
//! Stellar 8004 Reputation Registry ABI (see docs/adr/0002-agent-registry-on-soroban.md,
//! ADR-0005 D5 and issue #14).
//!
//! The contract stores individual feedback records and computes simple
//! aggregates. The paid-hire gate, the one-feedback-per-hire rule and the
//! reputation formula (#11) live off-chain; readers filter feedback by clients
//! with completed ERC-8183 jobs.

use soroban_sdk::{
    contract, contractclient, contracterror, contractevent, contractimpl, contracttype, Address,
    BytesN, ContractExecutable, Env, String, Vec,
};

/// TTL bump config: extend to TTL_BUMP when fewer than TTL_THRESHOLD ledgers remain.
pub const TTL_THRESHOLD: u32 = 518_400;
pub const TTL_BUMP: u32 = 1_036_800;
/// Ledgers an upgrade proposal must wait before it can be executed.
pub const TIMELOCK_LEDGERS: u32 = 51_840;
/// `get_summary` reads at most this many clients per call.
pub const MAX_SUMMARY_CLIENTS: u32 = 5;
/// `value` must be within ±1e38.
pub const MAX_ABS_VALUE: i128 = 100_000_000_000_000_000_000_000_000_000_000_000_000;
const CONTRACT_VERSION: &str = "0.1.0";

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

#[contracttype]
#[derive(Clone)]
pub struct UpgradeProposal {
    pub wasm_hash: BytesN<32>,
    pub proposed_at: u32,
}

#[contracttype]
#[derive(Clone)]
pub struct PendingOwnership {
    pub new_owner: Address,
    pub live_until_ledger: u32,
}

#[contracttype]
#[derive(Clone)]
pub enum DataKey {
    IdentityRegistry,
    Feedback(u32, Address, u64),
    LastIndex(u32, Address),
    ClientCount(u32),
    ClientAtIndex(u32, u32),
    ClientExists(u32, Address),
    ResponseCount(u32, Address, u64),
    PendingUpgrade,
    Owner,
    PendingOwner,
}

/// Error codes shared with the Stellar 8004 Reputation Registry. Values and
/// meanings are kept identical for drop-in compatibility.
#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
#[repr(u32)]
pub enum ReputationError {
    SelfFeedback = 1,
    FeedbackNotFound = 2,
    InvalidValueDecimals = 3,
    /// Unused; kept for ABI stability (as in Stellar 8004).
    NotOwnerOrApproved = 4,
    AggregateOverflow = 5,
    AgentNotFound = 6,
    EmptyValue = 7,
    ValueOutOfRange = 8,
    ClientAddressesRequired = 9,
    NoUpgradeProposed = 10,
    TimelockNotExpired = 11,
    UpgradeAlreadyProposed = 12,
}

/// Ownership errors, matching the OpenZeppelin Stellar `OwnableError` codes.
#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
#[repr(u32)]
pub enum OwnableError {
    OwnerNotSet = 2100,
    TransferInProgress = 2101,
    OwnerAlreadySet = 2102,
}

#[contractevent]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct NewFeedback {
    #[topic]
    pub agent_id: u32,
    #[topic]
    pub client_address: Address,
    #[topic]
    pub tag1: String,
    pub feedback_index: u64,
    pub value: i128,
    pub value_decimals: u32,
    pub tag2: String,
    pub endpoint: String,
    pub feedback_uri: String,
    pub feedback_hash: BytesN<32>,
}

#[contractevent]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FeedbackRevoked {
    #[topic]
    pub agent_id: u32,
    #[topic]
    pub client_address: Address,
    #[topic]
    pub feedback_index: u64,
}

#[contractevent]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ResponseAppended {
    #[topic]
    pub agent_id: u32,
    #[topic]
    pub client_address: Address,
    #[topic]
    pub responder: Address,
    pub feedback_index: u64,
    pub response_uri: String,
    pub response_hash: BytesN<32>,
}

#[contractevent]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct OwnershipTransfer {
    pub old_owner: Address,
    pub new_owner: Address,
    pub live_until_ledger: u32,
}

#[contractevent]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct OwnershipTransferCompleted {
    pub new_owner: Address,
}

#[contractevent]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct OwnershipRenounced {
    pub old_owner: Address,
}

/// Cross-contract view of the puls3 Identity Registry (issue #13). Names and
/// argument order match the deployed Identity Registry.
#[contractclient(name = "IdentityRegistryClient")]
pub trait IdentityRegistryInterface {
    fn agent_exists(e: &Env, agent_id: u32) -> bool;
    fn is_authorized_or_owner(e: &Env, spender: Address, agent_id: u32) -> bool;
}

#[contract]
pub struct ReputationRegistryContract;

#[contractimpl]
impl ReputationRegistryContract {
    /// `owner` controls upgrades; `identity_registry` is the puls3 Identity
    /// Registry contract id.
    pub fn __constructor(e: &Env, owner: Address, identity_registry: Address) {
        e.storage().instance().set(&DataKey::Owner, &owner);
        e.storage()
            .instance()
            .set(&DataKey::IdentityRegistry, &identity_registry);
        extend_instance(e);
    }

    /// Stores one feedback record for `agent_id` under `caller`. Emits `NewFeedback`.
    #[allow(clippy::too_many_arguments)]
    pub fn give_feedback(
        e: &Env,
        caller: Address,
        agent_id: u32,
        value: i128,
        value_decimals: u32,
        tag1: String,
        tag2: String,
        endpoint: String,
        feedback_uri: String,
        feedback_hash: BytesN<32>,
    ) -> Result<(), ReputationError> {
        caller.require_auth();

        if value_decimals > 18 {
            return Err(ReputationError::InvalidValueDecimals);
        }
        if !(-MAX_ABS_VALUE..=MAX_ABS_VALUE).contains(&value) {
            return Err(ReputationError::ValueOutOfRange);
        }

        let identity = IdentityRegistryClient::new(e, &get_identity_registry(e));
        if !identity.agent_exists(&agent_id) {
            return Err(ReputationError::AgentNotFound);
        }
        if identity.is_authorized_or_owner(&caller, &agent_id) {
            return Err(ReputationError::SelfFeedback);
        }

        if !client_exists(e, agent_id, &caller) {
            add_client(e, agent_id, &caller)?;
        }

        let feedback_index = get_last_index(e, agent_id, &caller) + 1;
        set_last_index(e, agent_id, &caller, feedback_index);

        let data = FeedbackData {
            value,
            value_decimals,
            is_revoked: false,
            tag1: tag1.clone(),
            tag2: tag2.clone(),
        };
        set_feedback(e, agent_id, &caller, feedback_index, &data);

        NewFeedback {
            agent_id,
            client_address: caller.clone(),
            tag1,
            feedback_index,
            value,
            value_decimals,
            tag2,
            endpoint,
            feedback_uri,
            feedback_hash,
        }
        .publish(e);

        extend_instance(e);
        Ok(())
    }

    /// Marks the caller's feedback at `feedback_index` as revoked. Emits
    /// `FeedbackRevoked`. A second revoke is `FeedbackNotFound`.
    pub fn revoke_feedback(
        e: &Env,
        caller: Address,
        agent_id: u32,
        feedback_index: u64,
    ) -> Result<(), ReputationError> {
        caller.require_auth();

        let mut data = get_feedback(e, agent_id, &caller, feedback_index)
            .ok_or(ReputationError::FeedbackNotFound)?;
        if data.is_revoked {
            return Err(ReputationError::FeedbackNotFound);
        }
        data.is_revoked = true;
        set_feedback(e, agent_id, &caller, feedback_index, &data);

        FeedbackRevoked {
            agent_id,
            client_address: caller,
            feedback_index,
        }
        .publish(e);

        extend_instance(e);
        Ok(())
    }

    /// Appends a response to `client_address`'s feedback. Callable by anyone.
    /// Emits `ResponseAppended`.
    pub fn append_response(
        e: &Env,
        caller: Address,
        agent_id: u32,
        client_address: Address,
        feedback_index: u64,
        response_uri: String,
        response_hash: BytesN<32>,
    ) -> Result<(), ReputationError> {
        caller.require_auth();

        if response_uri.is_empty() {
            return Err(ReputationError::EmptyValue);
        }
        get_feedback(e, agent_id, &client_address, feedback_index)
            .ok_or(ReputationError::FeedbackNotFound)?;

        increment_response_count(e, agent_id, &client_address, feedback_index)?;

        ResponseAppended {
            agent_id,
            client_address,
            responder: caller,
            feedback_index,
            response_uri,
            response_hash,
        }
        .publish(e);

        extend_instance(e);
        Ok(())
    }

    pub fn read_feedback(
        e: &Env,
        agent_id: u32,
        client_address: Address,
        feedback_index: u64,
    ) -> Result<FeedbackData, ReputationError> {
        get_feedback(e, agent_id, &client_address, feedback_index)
            .ok_or(ReputationError::FeedbackNotFound)
    }

    /// WAD-normalized average of the non-revoked feedback of the first
    /// `MAX_SUMMARY_CLIENTS` clients, filtered by `tag1`/`tag2` when not empty.
    pub fn get_summary(
        e: &Env,
        agent_id: u32,
        client_addresses: Vec<Address>,
        tag1: String,
        tag2: String,
    ) -> Result<SummaryResult, ReputationError> {
        if client_addresses.is_empty() {
            return Err(ReputationError::ClientAddressesRequired);
        }

        let limit = core::cmp::min(client_addresses.len(), MAX_SUMMARY_CLIENTS);
        let mut sum_wad: i128 = 0;
        let mut count: u64 = 0;
        let mut decimal_counts = [0u64; 19];

        for idx in 0..limit {
            let client = client_addresses.get(idx).unwrap();
            let last = get_last_index(e, agent_id, &client);
            for i in 1..=last {
                let Some(fb) = get_feedback(e, agent_id, &client, i) else {
                    continue;
                };
                if fb.is_revoked {
                    continue;
                }
                if !tag1.is_empty() && fb.tag1 != tag1 {
                    continue;
                }
                if !tag2.is_empty() && fb.tag2 != tag2 {
                    continue;
                }
                let dec = if fb.value_decimals > 18 {
                    18
                } else {
                    fb.value_decimals
                };
                let normalized = fb
                    .value
                    .checked_mul(pow10(18 - dec))
                    .ok_or(ReputationError::AggregateOverflow)?;
                sum_wad = sum_wad
                    .checked_add(normalized)
                    .ok_or(ReputationError::AggregateOverflow)?;
                decimal_counts[dec as usize] += 1;
                count = count
                    .checked_add(1)
                    .ok_or(ReputationError::AggregateOverflow)?;
            }
        }

        if count == 0 {
            return Ok(SummaryResult {
                count: 0,
                summary_value: 0,
                summary_value_decimals: 0,
            });
        }

        // Mode decimals; ties resolve to the lowest.
        let mut mode_dec: u32 = 0;
        let mut max_freq: u64 = 0;
        for (d, freq) in decimal_counts.iter().enumerate() {
            if *freq > max_freq {
                max_freq = *freq;
                mode_dec = d as u32;
            }
        }

        let avg_wad = sum_wad / (count as i128);
        Ok(SummaryResult {
            count,
            summary_value: avg_wad / pow10(18 - mode_dec),
            summary_value_decimals: mode_dec,
        })
    }

    pub fn get_clients_paginated(e: &Env, agent_id: u32, start: u32, limit: u32) -> Vec<Address> {
        let count = get_client_count(e, agent_id);
        let mut result = Vec::new(e);
        let end = core::cmp::min(start.saturating_add(limit), count);
        for i in start..end {
            let key = DataKey::ClientAtIndex(agent_id, i);
            if let Some(addr) = e.storage().persistent().get::<DataKey, Address>(&key) {
                e.storage()
                    .persistent()
                    .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
                result.push_back(addr);
            }
        }
        result
    }

    pub fn get_last_index(e: &Env, agent_id: u32, client_address: Address) -> u64 {
        get_last_index(e, agent_id, &client_address)
    }

    pub fn get_response_count(
        e: &Env,
        agent_id: u32,
        client_address: Address,
        feedback_index: u64,
    ) -> u32 {
        get_response_count(e, agent_id, &client_address, feedback_index)
    }

    pub fn get_identity_registry(e: &Env) -> Address {
        get_identity_registry(e)
    }

    /// Anyone can call it. Extends the instance TTL.
    pub fn extend_ttl(e: &Env) {
        extend_instance(e);
    }

    // --- Timelocked upgrade ---

    pub fn propose_upgrade(e: &Env, new_wasm_hash: BytesN<32>) -> Result<(), ReputationError> {
        require_owner(e);
        if get_pending_upgrade(e).is_some() {
            return Err(ReputationError::UpgradeAlreadyProposed);
        }
        set_pending_upgrade(
            e,
            &UpgradeProposal {
                wasm_hash: new_wasm_hash,
                proposed_at: e.ledger().sequence(),
            },
        );
        Ok(())
    }

    pub fn cancel_upgrade(e: &Env) -> Result<(), ReputationError> {
        require_owner(e);
        if get_pending_upgrade(e).is_none() {
            return Err(ReputationError::NoUpgradeProposed);
        }
        remove_pending_upgrade(e);
        Ok(())
    }

    pub fn execute_upgrade(e: &Env) -> Result<(), ReputationError> {
        require_owner(e);
        let proposal = get_pending_upgrade(e).ok_or(ReputationError::NoUpgradeProposed)?;
        let elapsed = e.ledger().sequence().saturating_sub(proposal.proposed_at);
        if elapsed < TIMELOCK_LEDGERS {
            return Err(ReputationError::TimelockNotExpired);
        }
        remove_pending_upgrade(e);
        e.deployer()
            .update_current_contract(ContractExecutable::Wasm(proposal.wasm_hash));
        Ok(())
    }

    pub fn pending_upgrade(e: &Env) -> Option<UpgradeProposal> {
        get_pending_upgrade(e)
    }

    pub fn version(e: &Env) -> String {
        String::from_str(e, CONTRACT_VERSION)
    }

    // --- Ownable (hand-rolled, OpenZeppelin-compatible ABI) ---

    /// `Some(owner)`, or `None` when ownership was renounced.
    pub fn get_owner(e: &Env) -> Option<Address> {
        e.storage().instance().get(&DataKey::Owner)
    }

    /// Starts a two-step ownership transfer. `live_until_ledger == 0` cancels
    /// a pending transfer. Requires the current owner's authorization.
    pub fn transfer_ownership(e: &Env, new_owner: Address, live_until_ledger: u32) {
        let owner: Address = e
            .storage()
            .instance()
            .get(&DataKey::Owner)
            .unwrap_or_else(|| soroban_sdk::panic_with_error!(e, OwnableError::OwnerNotSet));
        owner.require_auth();

        if live_until_ledger == 0 {
            e.storage().instance().remove(&DataKey::PendingOwner);
            return;
        }
        if new_owner == owner {
            soroban_sdk::panic_with_error!(e, OwnableError::OwnerAlreadySet);
        }
        if live_until_ledger <= e.ledger().sequence() {
            panic!("live_until_ledger is in the past");
        }
        let pending = PendingOwnership {
            new_owner: new_owner.clone(),
            live_until_ledger,
        };
        e.storage().instance().set(&DataKey::PendingOwner, &pending);
        OwnershipTransfer {
            old_owner: owner,
            new_owner,
            live_until_ledger,
        }
        .publish(e);
    }

    /// Completes a pending transfer. Requires the pending owner's authorization.
    pub fn accept_ownership(e: &Env) {
        let pending: PendingOwnership = e
            .storage()
            .instance()
            .get(&DataKey::PendingOwner)
            .unwrap_or_else(|| panic!("no pending ownership transfer"));
        if e.ledger().sequence() > pending.live_until_ledger {
            panic!("ownership transfer expired");
        }
        pending.new_owner.require_auth();
        e.storage()
            .instance()
            .set(&DataKey::Owner, &pending.new_owner);
        e.storage().instance().remove(&DataKey::PendingOwner);
        OwnershipTransferCompleted {
            new_owner: pending.new_owner,
        }
        .publish(e);
    }

    /// Renounces ownership permanently. Requires the current owner's
    /// authorization, and fails while a transfer is pending.
    pub fn renounce_ownership(e: &Env) {
        let owner: Address = e
            .storage()
            .instance()
            .get(&DataKey::Owner)
            .unwrap_or_else(|| soroban_sdk::panic_with_error!(e, OwnableError::OwnerNotSet));
        owner.require_auth();
        if e.storage().instance().has(&DataKey::PendingOwner) {
            soroban_sdk::panic_with_error!(e, OwnableError::TransferInProgress);
        }
        e.storage().instance().remove(&DataKey::Owner);
        OwnershipRenounced { old_owner: owner }.publish(e);
    }
}

// --- Storage ---

fn get_identity_registry(e: &Env) -> Address {
    e.storage()
        .instance()
        .get(&DataKey::IdentityRegistry)
        .expect("identity registry not set")
}

/// Requires the current owner's authorization, panicking like OpenZeppelin's
/// `only_owner` when ownership is unset or the caller is not the owner.
fn require_owner(e: &Env) {
    let owner: Address = e
        .storage()
        .instance()
        .get(&DataKey::Owner)
        .unwrap_or_else(|| soroban_sdk::panic_with_error!(e, OwnableError::OwnerNotSet));
    owner.require_auth();
}

fn set_feedback(e: &Env, agent_id: u32, client: &Address, index: u64, data: &FeedbackData) {
    let key = DataKey::Feedback(agent_id, client.clone(), index);
    e.storage().persistent().set(&key, data);
    e.storage()
        .persistent()
        .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
}

fn get_feedback(e: &Env, agent_id: u32, client: &Address, index: u64) -> Option<FeedbackData> {
    let key = DataKey::Feedback(agent_id, client.clone(), index);
    let data = e.storage().persistent().get(&key);
    if data.is_some() {
        e.storage()
            .persistent()
            .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
    }
    data
}

fn set_last_index(e: &Env, agent_id: u32, client: &Address, index: u64) {
    let key = DataKey::LastIndex(agent_id, client.clone());
    e.storage().persistent().set(&key, &index);
    e.storage()
        .persistent()
        .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
}

fn get_last_index(e: &Env, agent_id: u32, client: &Address) -> u64 {
    let key = DataKey::LastIndex(agent_id, client.clone());
    if let Some(index) = e.storage().persistent().get::<DataKey, u64>(&key) {
        e.storage()
            .persistent()
            .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
        index
    } else {
        0
    }
}

fn client_exists(e: &Env, agent_id: u32, client: &Address) -> bool {
    let key = DataKey::ClientExists(agent_id, client.clone());
    if e.storage().persistent().has(&key) {
        e.storage()
            .persistent()
            .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
        true
    } else {
        false
    }
}

fn add_client(e: &Env, agent_id: u32, client: &Address) -> Result<(), ReputationError> {
    let count_key = DataKey::ClientCount(agent_id);
    let count: u32 = e.storage().persistent().get(&count_key).unwrap_or(0);
    let next = count
        .checked_add(1)
        .ok_or(ReputationError::AggregateOverflow)?;

    let at_key = DataKey::ClientAtIndex(agent_id, count);
    e.storage().persistent().set(&at_key, client);
    e.storage()
        .persistent()
        .extend_ttl(&at_key, TTL_THRESHOLD, TTL_BUMP);

    let exists_key = DataKey::ClientExists(agent_id, client.clone());
    e.storage().persistent().set(&exists_key, &true);
    e.storage()
        .persistent()
        .extend_ttl(&exists_key, TTL_THRESHOLD, TTL_BUMP);

    e.storage().persistent().set(&count_key, &next);
    e.storage()
        .persistent()
        .extend_ttl(&count_key, TTL_THRESHOLD, TTL_BUMP);
    Ok(())
}

fn get_client_count(e: &Env, agent_id: u32) -> u32 {
    let key = DataKey::ClientCount(agent_id);
    if let Some(count) = e.storage().persistent().get::<DataKey, u32>(&key) {
        e.storage()
            .persistent()
            .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
        count
    } else {
        0
    }
}

fn get_response_count(e: &Env, agent_id: u32, client: &Address, index: u64) -> u32 {
    let key = DataKey::ResponseCount(agent_id, client.clone(), index);
    if let Some(count) = e.storage().persistent().get::<DataKey, u32>(&key) {
        e.storage()
            .persistent()
            .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
        count
    } else {
        0
    }
}

fn increment_response_count(
    e: &Env,
    agent_id: u32,
    client: &Address,
    index: u64,
) -> Result<(), ReputationError> {
    let count = get_response_count(e, agent_id, client, index);
    let next = count
        .checked_add(1)
        .ok_or(ReputationError::AggregateOverflow)?;
    let key = DataKey::ResponseCount(agent_id, client.clone(), index);
    e.storage().persistent().set(&key, &next);
    e.storage()
        .persistent()
        .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
    Ok(())
}

fn set_pending_upgrade(e: &Env, proposal: &UpgradeProposal) {
    e.storage()
        .instance()
        .set(&DataKey::PendingUpgrade, proposal);
}

fn get_pending_upgrade(e: &Env) -> Option<UpgradeProposal> {
    e.storage().instance().get(&DataKey::PendingUpgrade)
}

fn remove_pending_upgrade(e: &Env) {
    e.storage().instance().remove(&DataKey::PendingUpgrade);
}

fn extend_instance(e: &Env) {
    e.storage().instance().extend_ttl(TTL_THRESHOLD, TTL_BUMP);
}

const POW10: [i128; 19] = [
    1,
    10,
    100,
    1_000,
    10_000,
    100_000,
    1_000_000,
    10_000_000,
    100_000_000,
    1_000_000_000,
    10_000_000_000,
    100_000_000_000,
    1_000_000_000_000,
    10_000_000_000_000,
    100_000_000_000_000,
    1_000_000_000_000_000,
    10_000_000_000_000_000,
    100_000_000_000_000_000,
    1_000_000_000_000_000_000,
];

fn pow10(exp: u32) -> i128 {
    POW10[exp as usize]
}

mod test;
