#![no_std]

//! Agent identity registry: sequential IDs, unique URIs, owner metadata, payment wallet.

use soroban_sdk::{
    contract, contracterror, contractevent, contractimpl, contracttype, Address, Bytes, Env,
    String, Vec,
};

/// TTL bump config: extend to TTL_BUMP when fewer than TTL_THRESHOLD ledgers remain.
pub const TTL_THRESHOLD: u32 = 518_400;
pub const TTL_BUMP: u32 = 1_036_800;

pub const MAX_METADATA_KEY_LEN: u32 = 64;
pub const MAX_METADATA_VALUE_LEN: u32 = 4096;
/// Max metadata keys per agent, including the reserved `agentWallet` key.
pub const MAX_METADATA_KEYS: u32 = 100;
pub const AGENT_WALLET_KEY: &str = "agentWallet";

const CONTRACT_VERSION: &str = "0.1.0";

#[contracttype]
#[derive(Clone)]
pub struct MetadataEntry {
    pub key: String,
    pub value: Bytes,
}

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
    /// Puls3 addition: this agent URI already belongs to another agent.
    UriAlreadyRegistered = 100,
}

#[contractevent]
#[derive(Clone)]
pub struct Registered {
    #[topic]
    pub agent_id: u32,
    #[topic]
    pub owner: Address,
    pub agent_uri: String,
}

#[contractevent]
#[derive(Clone)]
pub struct UriUpdated {
    #[topic]
    pub agent_id: u32,
    #[topic]
    pub updated_by: Address,
    pub new_uri: String,
}

#[contractevent]
#[derive(Clone)]
pub struct MetadataSet {
    #[topic]
    pub agent_id: u32,
    #[topic]
    pub key: String,
    pub value: Bytes,
}

#[contracttype]
#[derive(Clone)]
pub enum DataKey {
    Admin,
    Name,
    Symbol,
    NextId,
    Owner(u32),
    Balance(Address),
    AgentUri(u32),
    UriIndex(String),
    AgentWallet(u32),
    Metadata(u32, String),
    MetadataKeys(u32),
}

#[contract]
pub struct IdentityRegistryContract;

#[contractimpl]
impl IdentityRegistryContract {
    pub fn __constructor(e: &Env, owner: Address, name: String, symbol: String) {
        e.storage().instance().set(&DataKey::Admin, &owner);
        e.storage().instance().set(&DataKey::Name, &name);
        e.storage().instance().set(&DataKey::Symbol, &symbol);
        e.storage().instance().set(&DataKey::NextId, &0u32);
        extend_instance(e);
    }

    pub fn register(e: &Env, caller: Address) -> Result<u32, IdentityError> {
        caller.require_auth();
        mint(e, &caller, None, Vec::new(e))
    }

    pub fn register_with_uri(
        e: &Env,
        caller: Address,
        agent_uri: String,
    ) -> Result<u32, IdentityError> {
        caller.require_auth();
        if agent_uri.is_empty() {
            return Err(IdentityError::EmptyValue);
        }
        if e.storage()
            .persistent()
            .has(&DataKey::UriIndex(agent_uri.clone()))
        {
            return Err(IdentityError::UriAlreadyRegistered);
        }
        mint(e, &caller, Some(agent_uri), Vec::new(e))
    }

    /// Fails with `UriAlreadyRegistered` on duplicate URI. Emits one `MetadataSet` per entry.
    pub fn register_full(
        e: &Env,
        caller: Address,
        agent_uri: String,
        metadata: Vec<MetadataEntry>,
    ) -> Result<u32, IdentityError> {
        caller.require_auth();
        if agent_uri.is_empty() {
            return Err(IdentityError::EmptyValue);
        }
        if e.storage()
            .persistent()
            .has(&DataKey::UriIndex(agent_uri.clone()))
        {
            return Err(IdentityError::UriAlreadyRegistered);
        }
        let mut distinct = Vec::new(e);
        for entry in metadata.iter() {
            validate_metadata_entry(e, &entry.key, &entry.value)?;
            if !vec_contains(&distinct, &entry.key) {
                distinct.push_back(entry.key.clone());
            }
        }
        // The reserved wallet key counts toward the limit.
        if distinct.len() + 1 > MAX_METADATA_KEYS {
            return Err(IdentityError::TooManyMetadataKeys);
        }
        mint(e, &caller, Some(agent_uri), metadata)
    }

    /// Owner only. Frees the old URI and claims the new one. Emits `UriUpdated`.
    pub fn set_agent_uri(
        e: &Env,
        caller: Address,
        agent_id: u32,
        new_uri: String,
    ) -> Result<(), IdentityError> {
        caller.require_auth();
        let owner = Self::owner_of(e, agent_id)?;
        if owner != caller {
            return Err(IdentityError::NotOwnerOrApproved);
        }
        if new_uri.is_empty() {
            return Err(IdentityError::EmptyValue);
        }
        if let Some(other) = e
            .storage()
            .persistent()
            .get::<DataKey, u32>(&DataKey::UriIndex(new_uri.clone()))
        {
            if other != agent_id {
                return Err(IdentityError::UriAlreadyRegistered);
            }
        }
        let old: Option<String> = e.storage().persistent().get(&DataKey::AgentUri(agent_id));
        if let Some(previous) = old {
            if previous != new_uri {
                e.storage()
                    .persistent()
                    .remove(&DataKey::UriIndex(previous));
            }
        }
        e.storage()
            .persistent()
            .set(&DataKey::AgentUri(agent_id), &new_uri);
        let index_key = DataKey::UriIndex(new_uri.clone());
        e.storage().persistent().set(&index_key, &agent_id);
        UriUpdated {
            agent_id,
            updated_by: caller,
            new_uri,
        }
        .publish(e);
        extend_instance(e);
        extend_persistent(e, &DataKey::Owner(agent_id));
        extend_persistent(e, &DataKey::AgentUri(agent_id));
        extend_persistent(e, &index_key);
        Ok(())
    }

    /// Fails with `UriNotSet` when the agent does not exist or has no URI.
    pub fn agent_uri(e: &Env, agent_id: u32) -> Result<String, IdentityError> {
        e.storage()
            .persistent()
            .get(&DataKey::AgentUri(agent_id))
            .ok_or(IdentityError::UriNotSet)
    }

    pub fn agent_id_by_uri(e: &Env, agent_uri: String) -> Option<u32> {
        e.storage().persistent().get(&DataKey::UriIndex(agent_uri))
    }

    /// Owner only. Emits `MetadataSet`.
    pub fn set_metadata(
        e: &Env,
        caller: Address,
        agent_id: u32,
        key: String,
        value: Bytes,
    ) -> Result<(), IdentityError> {
        caller.require_auth();
        let owner = Self::owner_of(e, agent_id)?;
        if owner != caller {
            return Err(IdentityError::NotOwnerOrApproved);
        }
        validate_metadata_entry(e, &key, &value)?;
        let store = e.storage().persistent();
        let value_key = DataKey::Metadata(agent_id, key.clone());
        if !store.has(&value_key) {
            let keys_key = DataKey::MetadataKeys(agent_id);
            let keys: Vec<String> = store.get(&keys_key).unwrap_or(Vec::new(e));
            if keys.len() + 1 > MAX_METADATA_KEYS {
                return Err(IdentityError::TooManyMetadataKeys);
            }
            let mut updated = keys;
            updated.push_back(key.clone());
            store.set(&keys_key, &updated);
            extend_persistent(e, &keys_key);
        }
        store.set(&value_key, &value);
        MetadataSet {
            agent_id,
            key: key.clone(),
            value,
        }
        .publish(e);
        extend_instance(e);
        extend_persistent(e, &DataKey::Owner(agent_id));
        extend_persistent(e, &value_key);
        Ok(())
    }

    pub fn get_metadata(e: &Env, agent_id: u32, key: String) -> Option<Bytes> {
        e.storage()
            .persistent()
            .get(&DataKey::Metadata(agent_id, key))
    }

    /// Owner only, and the new wallet must also authorize, so nobody can point
    /// payments at a wallet they do not control. Emits `MetadataSet`.
    pub fn set_agent_wallet(
        e: &Env,
        caller: Address,
        agent_id: u32,
        new_wallet: Address,
    ) -> Result<(), IdentityError> {
        caller.require_auth();
        new_wallet.require_auth();
        let owner = Self::owner_of(e, agent_id)?;
        if owner != caller {
            return Err(IdentityError::NotOwnerOrApproved);
        }
        let store = e.storage().persistent();
        store.set(&DataKey::AgentWallet(agent_id), &new_wallet);
        let key = String::from_str(e, AGENT_WALLET_KEY);
        let value = address_str_bytes(e, &new_wallet);
        let value_key = DataKey::Metadata(agent_id, key.clone());
        store.set(&value_key, &value);
        ensure_key_tracked(e, agent_id, &key);
        MetadataSet {
            agent_id,
            key: key.clone(),
            value,
        }
        .publish(e);
        extend_instance(e);
        extend_persistent(e, &DataKey::Owner(agent_id));
        extend_persistent(e, &DataKey::AgentWallet(agent_id));
        extend_persistent(e, &value_key);
        extend_persistent(e, &DataKey::MetadataKeys(agent_id));
        Ok(())
    }

    pub fn get_agent_wallet(e: &Env, agent_id: u32) -> Option<Address> {
        e.storage()
            .persistent()
            .get(&DataKey::AgentWallet(agent_id))
    }

    /// Owner only. Clears the payment wallet and emits `MetadataSet` with key
    /// `agentWallet` and an empty value.
    pub fn unset_agent_wallet(
        e: &Env,
        caller: Address,
        agent_id: u32,
    ) -> Result<(), IdentityError> {
        caller.require_auth();
        let owner = Self::owner_of(e, agent_id)?;
        if owner != caller {
            return Err(IdentityError::NotOwnerOrApproved);
        }
        let store = e.storage().persistent();
        let wallet_key = DataKey::AgentWallet(agent_id);
        if store.has(&wallet_key) {
            store.remove(&wallet_key);
        }
        let key = String::from_str(e, AGENT_WALLET_KEY);
        let value = Bytes::new(e);
        let value_key = DataKey::Metadata(agent_id, key.clone());
        store.set(&value_key, &value);
        ensure_key_tracked(e, agent_id, &key);
        MetadataSet {
            agent_id,
            key: key.clone(),
            value,
        }
        .publish(e);
        extend_instance(e);
        extend_persistent(e, &DataKey::Owner(agent_id));
        extend_persistent(e, &value_key);
        extend_persistent(e, &DataKey::MetadataKeys(agent_id));
        Ok(())
    }

    pub fn find_owner(e: &Env, agent_id: u32) -> Option<Address> {
        e.storage().persistent().get(&DataKey::Owner(agent_id))
    }

    pub fn agent_exists(e: &Env, agent_id: u32) -> bool {
        e.storage().persistent().has(&DataKey::Owner(agent_id))
    }

    /// Approvals are out of scope, so "or approved" never applies.
    pub fn is_authorized_or_owner(e: &Env, spender: Address, agent_id: u32) -> bool {
        e.storage()
            .persistent()
            .get::<DataKey, Address>(&DataKey::Owner(agent_id))
            .is_some_and(|owner| owner == spender)
    }

    pub fn total_agents(e: &Env) -> u32 {
        e.storage().instance().get(&DataKey::NextId).unwrap_or(0)
    }

    pub fn version(e: &Env) -> String {
        String::from_str(e, CONTRACT_VERSION)
    }

    pub fn owner_of(e: &Env, token_id: u32) -> Result<Address, IdentityError> {
        e.storage()
            .persistent()
            .get(&DataKey::Owner(token_id))
            .ok_or(IdentityError::AgentNotFound)
    }

    pub fn balance(e: &Env, account: Address) -> u32 {
        e.storage()
            .persistent()
            .get(&DataKey::Balance(account))
            .unwrap_or(0)
    }

    /// Returns empty string when no URI is set. Fails with `AgentNotFound` for unknown ids.
    pub fn token_uri(e: &Env, token_id: u32) -> Result<String, IdentityError> {
        if !Self::agent_exists(e, token_id) {
            return Err(IdentityError::AgentNotFound);
        }
        Ok(e.storage()
            .persistent()
            .get(&DataKey::AgentUri(token_id))
            .unwrap_or(String::from_str(e, "")))
    }

    pub fn name(e: &Env) -> String {
        e.storage()
            .instance()
            .get(&DataKey::Name)
            .unwrap_or(String::from_str(e, ""))
    }

    pub fn symbol(e: &Env) -> String {
        e.storage()
            .instance()
            .get(&DataKey::Symbol)
            .unwrap_or(String::from_str(e, ""))
    }

    /// Anyone can call it. Extends instance TTL plus owner, balance, URI, wallet, and metadata keys.
    pub fn extend_ttl(e: &Env, agent_id: u32) {
        extend_instance(e);
        let store = e.storage().persistent();
        let owner_key = DataKey::Owner(agent_id);
        let Some(owner) = store.get::<DataKey, Address>(&owner_key) else {
            return;
        };
        extend_persistent(e, &owner_key);
        extend_persistent(e, &DataKey::Balance(owner));
        if let Some(uri) = store.get::<DataKey, String>(&DataKey::AgentUri(agent_id)) {
            extend_persistent(e, &DataKey::AgentUri(agent_id));
            extend_persistent(e, &DataKey::UriIndex(uri));
        }
        if store.has(&DataKey::AgentWallet(agent_id)) {
            extend_persistent(e, &DataKey::AgentWallet(agent_id));
        }
        let keys_key = DataKey::MetadataKeys(agent_id);
        if let Some(keys) = store.get::<DataKey, Vec<String>>(&keys_key) {
            extend_persistent(e, &keys_key);
            for key in keys.iter() {
                extend_persistent(e, &DataKey::Metadata(agent_id, key));
            }
        }
    }
}

/// Mints the next sequential id. Emits `MetadataSet` entries then `Registered`.
fn mint(
    e: &Env,
    caller: &Address,
    agent_uri: Option<String>,
    metadata: Vec<MetadataEntry>,
) -> Result<u32, IdentityError> {
    let store = e.storage().persistent();
    let agent_id = e.storage().instance().get(&DataKey::NextId).unwrap_or(0u32);
    let balance_key = DataKey::Balance(caller.clone());
    let balance: u32 = store.get(&balance_key).unwrap_or(0);
    store.set(&DataKey::Owner(agent_id), caller);
    store.set(&balance_key, &(balance + 1));
    if let Some(uri) = agent_uri.clone() {
        store.set(&DataKey::AgentUri(agent_id), &uri);
        store.set(&DataKey::UriIndex(uri), &agent_id);
    }
    store.set(&DataKey::AgentWallet(agent_id), caller);
    let wallet_key = String::from_str(e, AGENT_WALLET_KEY);
    let wallet_value = address_str_bytes(e, caller);
    store.set(
        &DataKey::Metadata(agent_id, wallet_key.clone()),
        &wallet_value,
    );
    let mut keys = Vec::new(e);
    keys.push_back(wallet_key.clone());
    for entry in metadata.iter() {
        let value_key = DataKey::Metadata(agent_id, entry.key.clone());
        let is_new = !store.has(&value_key);
        store.set(&value_key, &entry.value);
        if is_new {
            keys.push_back(entry.key.clone());
        }
        MetadataSet {
            agent_id,
            key: entry.key.clone(),
            value: entry.value.clone(),
        }
        .publish(e);
    }
    store.set(&DataKey::MetadataKeys(agent_id), &keys);
    MetadataSet {
        agent_id,
        key: wallet_key.clone(),
        value: wallet_value,
    }
    .publish(e);
    Registered {
        agent_id,
        owner: caller.clone(),
        agent_uri: agent_uri.clone().unwrap_or(String::from_str(e, "")),
    }
    .publish(e);
    e.storage()
        .instance()
        .set(&DataKey::NextId, &(agent_id + 1));
    extend_instance(e);
    extend_persistent(e, &DataKey::Owner(agent_id));
    extend_persistent(e, &balance_key);
    extend_persistent(e, &DataKey::AgentWallet(agent_id));
    extend_persistent(e, &DataKey::Metadata(agent_id, wallet_key));
    extend_persistent(e, &DataKey::MetadataKeys(agent_id));
    if let Some(uri) = agent_uri {
        extend_persistent(e, &DataKey::AgentUri(agent_id));
        extend_persistent(e, &DataKey::UriIndex(uri));
    }
    for key in keys.iter() {
        extend_persistent(e, &DataKey::Metadata(agent_id, key));
    }
    Ok(agent_id)
}

fn validate_metadata_entry(e: &Env, key: &String, value: &Bytes) -> Result<(), IdentityError> {
    if key.is_empty() {
        return Err(IdentityError::EmptyValue);
    }
    if *key == String::from_str(e, AGENT_WALLET_KEY) {
        return Err(IdentityError::ReservedMetadataKey);
    }
    if key.len() > MAX_METADATA_KEY_LEN {
        return Err(IdentityError::MetadataKeyTooLong);
    }
    if value.len() > MAX_METADATA_VALUE_LEN {
        return Err(IdentityError::MetadataValueTooLong);
    }
    Ok(())
}

fn ensure_key_tracked(e: &Env, agent_id: u32, key: &String) {
    let store = e.storage().persistent();
    let keys_key = DataKey::MetadataKeys(agent_id);
    let keys: Vec<String> = store.get(&keys_key).unwrap_or(Vec::new(e));
    if !vec_contains(&keys, key) {
        let mut updated = keys;
        updated.push_back(key.clone());
        store.set(&keys_key, &updated);
    }
}

fn vec_contains(items: &Vec<String>, key: &String) -> bool {
    for item in items.iter() {
        if item == *key {
            return true;
        }
    }
    false
}

fn address_str_bytes(e: &Env, addr: &Address) -> Bytes {
    let text = addr.to_string();
    let len = text.len() as usize;
    let mut buf = [0u8; 128];
    text.copy_into_slice(&mut buf[..len]);
    Bytes::from_slice(e, &buf[..len])
}

fn extend_instance(e: &Env) {
    e.storage().instance().extend_ttl(TTL_THRESHOLD, TTL_BUMP);
}

fn extend_persistent(e: &Env, key: &DataKey) {
    e.storage()
        .persistent()
        .extend_ttl(key, TTL_THRESHOLD, TTL_BUMP);
}

mod test;
