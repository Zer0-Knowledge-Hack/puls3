#![cfg(test)]

extern crate std;

use super::*;
use soroban_sdk::testutils::storage::{Instance as _, Persistent as _};
use soroban_sdk::testutils::{Address as _, Events as _, Ledger as _, MockAuth, MockAuthInvoke};
use soroban_sdk::{map as soroban_map, vec as soroban_vec, IntoVal, Map, Symbol, Val};

fn setup() -> (Env, Address) {
    setup_with_auth(true)
}

fn client<'a>(env: &'a Env, contract_id: &'a Address) -> IdentityRegistryContractClient<'a> {
    IdentityRegistryContractClient::new(env, contract_id)
}

fn setup_with_auth(mock_all: bool) -> (Env, Address) {
    let env = Env::default();
    if mock_all {
        env.mock_all_auths();
    }
    let admin = Address::generate(&env);
    let contract_id = env.register(
        IdentityRegistryContract,
        (
            &admin,
            &String::from_str(&env, "Puls3 Agent"),
            &String::from_str(&env, "P3A"),
        ),
    );
    (env, contract_id)
}

fn test_uri(env: &Env, path: &str) -> String {
    String::from_str(env, path)
}

#[test]
fn constructor_sets_name_symbol_version_and_zero_agents() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    assert_eq!(client.name(), test_uri(&env, "Puls3 Agent"));
    assert_eq!(client.symbol(), test_uri(&env, "P3A"));
    assert_eq!(client.version(), test_uri(&env, "0.1.0"));
    assert_eq!(client.total_agents(), 0);
}

#[test]
fn register_mints_sequential_ids_to_caller_with_wallet() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let first = client.register(&owner);
    let second = client.register(&owner);
    assert_eq!(first, 0);
    assert_eq!(second, 1);
    assert_eq!(client.total_agents(), 2);
    assert_eq!(client.owner_of(&0), owner);
    assert_eq!(client.owner_of(&1), owner);
    assert_eq!(client.balance(&owner), 2);
    assert_eq!(client.find_owner(&0), Some(owner.clone()));
    assert!(client.agent_exists(&0));
    assert!(!client.agent_exists(&99));
    assert!(client.is_authorized_or_owner(&owner, &0));
    assert_eq!(client.get_agent_wallet(&0), Some(owner.clone()));
    // Token URI is empty when no URI was registered.
    assert_eq!(client.token_uri(&0), test_uri(&env, ""));
    // Wallet is readable as StrKey bytes through metadata.
    let wallet_bytes = client.get_metadata(&0, &test_uri(&env, AGENT_WALLET_KEY));
    assert_eq!(wallet_bytes, Some(address_str_bytes(&env, &owner)));
    // Unknown lookups stay empty and non-panicking.
    assert_eq!(client.find_owner(&99), None);
    assert!(!client.is_authorized_or_owner(&owner, &99));
    assert_eq!(
        client.try_owner_of(&99),
        Err(Ok(IdentityError::AgentNotFound))
    );
    assert_eq!(
        client.try_token_uri(&99),
        Err(Ok(IdentityError::AgentNotFound))
    );
    assert_eq!(client.try_agent_uri(&99), Err(Ok(IdentityError::UriNotSet)));
    assert_eq!(client.balance(&Address::generate(&env)), 0);
    assert_eq!(client.get_agent_wallet(&99), None);
    assert_eq!(client.get_metadata(&99, &test_uri(&env, "role")), None);
    assert_eq!(client.agent_id_by_uri(&test_uri(&env, "https://x")), None);
}

#[test]
fn register_with_uri_claims_lookup_and_token_uri() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let uri = test_uri(&env, "https://puls3.test/agents/0.json");
    let id = client.register_with_uri(&owner, &uri);
    assert_eq!(id, 0);
    assert_eq!(client.agent_uri(&id), uri);
    assert_eq!(client.token_uri(&id), uri);
    assert_eq!(client.agent_id_by_uri(&uri), Some(0));
    // An agent without a URI reports UriNotSet, like Stellar 8004.
    let bare = client.register(&owner);
    assert_eq!(
        client.try_agent_uri(&bare),
        Err(Ok(IdentityError::UriNotSet))
    );
}

#[test]
fn register_with_uri_rejects_empty_and_duplicate_uris() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let other = Address::generate(&env);
    assert_eq!(
        client.try_register_with_uri(&owner, &test_uri(&env, "")),
        Err(Ok(IdentityError::EmptyValue))
    );
    let uri = test_uri(&env, "https://puls3.test/agents/once.json");
    assert_eq!(client.register_with_uri(&owner, &uri), 0);
    assert_eq!(
        client.try_register_with_uri(&other, &uri),
        Err(Ok(IdentityError::UriAlreadyRegistered))
    );
    // Same owner registering the same URI twice is also a duplicate.
    assert_eq!(
        client.try_register_with_uri(&owner, &uri),
        Err(Ok(IdentityError::UriAlreadyRegistered))
    );
}

#[test]
fn register_full_writes_uri_and_metadata_entries() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let uri = test_uri(&env, "https://puls3.test/agents/full.json");
    let mut metadata = Vec::new(&env);
    metadata.push_back(MetadataEntry {
        key: test_uri(&env, "role"),
        value: Bytes::from_slice(&env, &[1, 2, 3]),
    });
    metadata.push_back(MetadataEntry {
        key: test_uri(&env, "endpoint"),
        value: Bytes::from_slice(&env, &[4, 5]),
    });
    let id = client.register_full(&owner, &uri, &metadata);
    assert_eq!(id, 0);
    assert_eq!(client.agent_uri(&id), uri);
    assert_eq!(
        client.get_metadata(&id, &test_uri(&env, "role")),
        Some(Bytes::from_slice(&env, &[1, 2, 3]))
    );
    assert_eq!(
        client.get_metadata(&id, &test_uri(&env, "endpoint")),
        Some(Bytes::from_slice(&env, &[4, 5]))
    );
}

#[test]
fn register_full_validates_everything_before_writing() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let uri = test_uri(&env, "https://puls3.test/agents/validated.json");
    // Reserved key aborts the whole registration.
    let mut reserved = Vec::new(&env);
    reserved.push_back(MetadataEntry {
        key: test_uri(&env, "role"),
        value: Bytes::from_slice(&env, &[1]),
    });
    reserved.push_back(MetadataEntry {
        key: test_uri(&env, AGENT_WALLET_KEY),
        value: Bytes::from_slice(&env, &[2]),
    });
    assert_eq!(
        client.try_register_full(&owner, &uri, &reserved),
        Err(Ok(IdentityError::ReservedMetadataKey))
    );
    assert_eq!(client.total_agents(), 0);
    assert_eq!(client.agent_id_by_uri(&uri), None);
    // Empty key aborts as well.
    let mut empty_key = Vec::new(&env);
    empty_key.push_back(MetadataEntry {
        key: test_uri(&env, ""),
        value: Bytes::from_slice(&env, &[1]),
    });
    assert_eq!(
        client.try_register_full(&owner, &uri, &empty_key),
        Err(Ok(IdentityError::EmptyValue))
    );
    assert_eq!(client.total_agents(), 0);
    // Too many keys (wallet plus user entries over the limit) aborts.
    let mut distinct_over = Vec::new(&env);
    for i in 0..MAX_METADATA_KEYS {
        let suffix = std::format!("key-{i:03}");
        distinct_over.push_back(MetadataEntry {
            key: String::from_str(&env, suffix.as_str()),
            value: Bytes::from_slice(&env, &[1]),
        });
    }
    assert_eq!(
        client.try_register_full(&owner, &uri, &distinct_over),
        Err(Ok(IdentityError::TooManyMetadataKeys))
    );
    assert_eq!(client.total_agents(), 0);
}

#[test]
fn set_agent_uri_updates_lookup_and_frees_old_uri() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let first = test_uri(&env, "https://puls3.test/agents/old.json");
    let second = test_uri(&env, "https://puls3.test/agents/new.json");
    let id = client.register_with_uri(&owner, &first);
    client.set_agent_uri(&owner, &id, &second);
    assert_eq!(client.agent_uri(&id), second);
    assert_eq!(client.agent_id_by_uri(&second), Some(id));
    assert_eq!(client.agent_id_by_uri(&first), None);
    // The new index entry gets the same TTL as the URI it points to.
    assert_eq!(
        env.as_contract(&contract_id, || env
            .storage()
            .persistent()
            .get_ttl(&DataKey::UriIndex(second.clone()))),
        TTL_BUMP
    );
    // The freed URI can be claimed by another agent.
    let other = Address::generate(&env);
    let taken = client.register_with_uri(&other, &first);
    assert_eq!(client.agent_id_by_uri(&first), Some(taken));
}

#[test]
fn set_agent_uri_rejects_bad_input_and_strangers() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let stranger = Address::generate(&env);
    let uri = test_uri(&env, "https://puls3.test/agents/owned.json");
    let taken_uri = test_uri(&env, "https://puls3.test/agents/taken.json");
    let id = client.register_with_uri(&owner, &uri);
    client.register_with_uri(&stranger, &taken_uri);
    assert_eq!(
        client.try_set_agent_uri(&owner, &99, &test_uri(&env, "https://x")),
        Err(Ok(IdentityError::AgentNotFound))
    );
    assert_eq!(
        client.try_set_agent_uri(&stranger, &id, &test_uri(&env, "https://evil")),
        Err(Ok(IdentityError::NotOwnerOrApproved))
    );
    assert_eq!(
        client.try_set_agent_uri(&owner, &id, &test_uri(&env, "")),
        Err(Ok(IdentityError::EmptyValue))
    );
    assert_eq!(
        client.try_set_agent_uri(&owner, &id, &taken_uri),
        Err(Ok(IdentityError::UriAlreadyRegistered))
    );
}

#[test]
fn set_metadata_round_trips_and_validates() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let stranger = Address::generate(&env);
    let id = client.register(&owner);
    let key = test_uri(&env, "description");
    let value = Bytes::from_slice(&env, &[9, 9, 9]);
    client.set_metadata(&owner, &id, &key, &value);
    assert_eq!(client.get_metadata(&id, &key), Some(value));
    // Overwriting the same key keeps working.
    let updated = Bytes::from_slice(&env, &[7]);
    client.set_metadata(&owner, &id, &key, &updated);
    assert_eq!(client.get_metadata(&id, &key), Some(updated));
    // Failures.
    assert_eq!(
        client.try_set_metadata(&stranger, &id, &key, &Bytes::from_slice(&env, &[1])),
        Err(Ok(IdentityError::NotOwnerOrApproved))
    );
    assert_eq!(
        client.try_set_metadata(&owner, &77, &key, &Bytes::from_slice(&env, &[1])),
        Err(Ok(IdentityError::AgentNotFound))
    );
    assert_eq!(
        client.try_set_metadata(
            &owner,
            &id,
            &test_uri(&env, ""),
            &Bytes::from_slice(&env, &[1])
        ),
        Err(Ok(IdentityError::EmptyValue))
    );
    assert_eq!(
        client.try_set_metadata(
            &owner,
            &id,
            &test_uri(&env, AGENT_WALLET_KEY),
            &Bytes::from_slice(&env, &[1])
        ),
        Err(Ok(IdentityError::ReservedMetadataKey))
    );
    let long_key = test_uri(
        &env,
        "012345678901234567890123456789012345678901234567890123456789012345",
    );
    assert!(long_key.len() > MAX_METADATA_KEY_LEN);
    assert_eq!(
        client.try_set_metadata(&owner, &id, &long_key, &Bytes::from_slice(&env, &[1])),
        Err(Ok(IdentityError::MetadataKeyTooLong))
    );
    let big = std::vec![1u8; (MAX_METADATA_VALUE_LEN + 1) as usize];
    assert_eq!(
        client.try_set_metadata(
            &owner,
            &id,
            &test_uri(&env, "blob"),
            &Bytes::from_slice(&env, &big)
        ),
        Err(Ok(IdentityError::MetadataValueTooLong))
    );
}

#[test]
fn set_metadata_rejects_new_keys_over_the_limit_but_allows_updates() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let id = client.register(&owner);
    // Wallet already occupies one slot; fill the rest with distinct keys.
    for i in 0..(MAX_METADATA_KEYS - 1) {
        let name = std::format!("k-{i:03}");
        client.set_metadata(
            &owner,
            &id,
            &String::from_str(&env, name.as_str()),
            &Bytes::from_slice(&env, &[1]),
        );
    }
    assert_eq!(
        client.try_set_metadata(
            &owner,
            &id,
            &test_uri(&env, "one-too-many"),
            &Bytes::from_slice(&env, &[1])
        ),
        Err(Ok(IdentityError::TooManyMetadataKeys))
    );
    // Updating an existing key still works at the limit.
    client.set_metadata(
        &owner,
        &id,
        &test_uri(&env, "k-000"),
        &Bytes::from_slice(&env, &[2]),
    );
    assert_eq!(
        client.get_metadata(&id, &test_uri(&env, "k-000")),
        Some(Bytes::from_slice(&env, &[2]))
    );
}

#[test]
fn agent_wallet_lifecycle_with_dual_auth() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let wallet = Address::generate(&env);
    let id = client.register(&owner);
    client.set_agent_wallet(&owner, &id, &wallet);
    assert_eq!(client.get_agent_wallet(&id), Some(wallet.clone()));
    assert_eq!(
        client.get_metadata(&id, &test_uri(&env, AGENT_WALLET_KEY)),
        Some(address_str_bytes(&env, &wallet))
    );
    // Pointing payments elsewhere works again.
    let wallet_two = Address::generate(&env);
    client.set_agent_wallet(&owner, &id, &wallet_two);
    assert_eq!(client.get_agent_wallet(&id), Some(wallet_two));
    // Unset clears the wallet and leaves an empty metadata value.
    client.unset_agent_wallet(&owner, &id);
    assert_eq!(client.get_agent_wallet(&id), None);
    assert_eq!(
        client.get_metadata(&id, &test_uri(&env, AGENT_WALLET_KEY)),
        Some(Bytes::new(&env))
    );
    // Strangers cannot touch the wallet.
    let stranger = Address::generate(&env);
    assert_eq!(
        client.try_set_agent_wallet(&stranger, &id, &wallet),
        Err(Ok(IdentityError::NotOwnerOrApproved))
    );
    assert_eq!(
        client.try_unset_agent_wallet(&stranger, &id),
        Err(Ok(IdentityError::NotOwnerOrApproved))
    );
    assert_eq!(
        client.try_set_agent_wallet(&owner, &42, &wallet),
        Err(Ok(IdentityError::AgentNotFound))
    );
}

#[test]
fn auth_is_enforced_without_mock_all_auths() {
    let (env, contract_id) = setup_with_auth(false);
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let attacker = Address::generate(&env);
    // Owner registers with an explicit auth mock.
    env.mock_auths(&[MockAuth {
        address: &owner,
        invoke: &MockAuthInvoke {
            contract: &contract_id,
            fn_name: "register",
            args: (&owner,).into_val(&env),
            sub_invokes: &[],
        },
    }]);
    let id = client.register(&owner);
    assert_eq!(id, 0);
    // Attacker authorizes their own call, but the contract rejects them as
    // non-owner with a typed error.
    let new_uri = test_uri(&env, "https://puls3.test/agents/evil.json");
    env.mock_auths(&[MockAuth {
        address: &attacker,
        invoke: &MockAuthInvoke {
            contract: &contract_id,
            fn_name: "set_agent_uri",
            args: (&attacker, &id, &new_uri).into_val(&env),
            sub_invokes: &[],
        },
    }]);
    assert_eq!(
        client.try_set_agent_uri(&attacker, &id, &new_uri),
        Err(Ok(IdentityError::NotOwnerOrApproved))
    );
    // With no auth at all, the host rejects the call before contract logic.
    env.mock_auths(&[]);
    assert!(client.try_set_agent_uri(&attacker, &id, &new_uri).is_err());
}

#[test]
fn register_and_update_emit_topics_and_data() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let uri = test_uri(&env, "https://puls3.test/agents/events.json");
    let wallet_key = test_uri(&env, AGENT_WALLET_KEY);
    let wallet_value = address_str_bytes(&env, &owner);
    client.register_with_uri(&owner, &uri);
    // `all()` returns the events of the last invocation: MetadataSet for the
    // wallet, then Registered. Topics and data are asserted exactly.
    let wallet_data: Map<Symbol, Val> = soroban_map![
        &env,
        (
            Symbol::new(&env, "value"),
            wallet_value.clone().into_val(&env)
        )
    ];
    let registered_data: Map<Symbol, Val> = soroban_map![
        &env,
        (Symbol::new(&env, "agent_uri"), uri.clone().into_val(&env))
    ];
    let expected = soroban_vec![
        &env,
        (
            contract_id.clone(),
            soroban_vec![
                &env,
                Symbol::new(&env, "metadata_set").into_val(&env),
                0u32.into_val(&env),
                wallet_key.clone().into_val(&env)
            ],
            wallet_data.into_val(&env)
        ),
        (
            contract_id.clone(),
            soroban_vec![
                &env,
                Symbol::new(&env, "registered").into_val(&env),
                0u32.into_val(&env),
                owner.clone().into_val(&env)
            ],
            registered_data.into_val(&env)
        )
    ];
    assert!(env.events().all() == expected);
    // The URI update emits exactly one UriUpdated event with the new URI.
    let updated = test_uri(&env, "https://puls3.test/agents/events-v2.json");
    client.set_agent_uri(&owner, &0, &updated);
    let update_data: Map<Symbol, Val> = soroban_map![
        &env,
        (Symbol::new(&env, "new_uri"), updated.clone().into_val(&env))
    ];
    let expected_update = soroban_vec![
        &env,
        (
            contract_id.clone(),
            soroban_vec![
                &env,
                Symbol::new(&env, "uri_updated").into_val(&env),
                0u32.into_val(&env),
                owner.clone().into_val(&env)
            ],
            update_data.into_val(&env)
        )
    ];
    assert!(env.events().all() == expected_update);
}

#[test]
fn extend_ttl_refreshes_every_agent_key() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let uri = test_uri(&env, "https://puls3.test/agents/ttl.json");
    let id = client.register_with_uri(&owner, &uri);
    let role = test_uri(&env, "role");
    client.set_metadata(&owner, &id, &role, &Bytes::from_slice(&env, &[1]));
    let wallet_key = test_uri(&env, AGENT_WALLET_KEY);
    let owner_key = DataKey::Owner(id);
    let balance_key = DataKey::Balance(owner.clone());
    let uri_key = DataKey::AgentUri(id);
    let index_key = DataKey::UriIndex(uri.clone());
    let agent_wallet_key = DataKey::AgentWallet(id);
    let keys_key = DataKey::MetadataKeys(id);
    let wallet_meta_key = DataKey::Metadata(id, wallet_key.clone());
    let role_meta_key = DataKey::Metadata(id, role.clone());
    // Age the ledger until every key sits below the extension threshold.
    let current = env.ledger().sequence();
    let remaining = env.as_contract(&contract_id, || {
        env.storage().persistent().get_ttl(&owner_key)
    });
    assert!(remaining > TTL_THRESHOLD);
    env.ledger()
        .set_sequence_number(current + (remaining - TTL_THRESHOLD) + 10);
    client.extend_ttl(&id);
    assert_eq!(
        env.as_contract(&contract_id, || env.storage().instance().get_ttl()),
        TTL_BUMP
    );
    for key in [
        &owner_key,
        &balance_key,
        &uri_key,
        &index_key,
        &agent_wallet_key,
        &keys_key,
        &wallet_meta_key,
        &role_meta_key,
    ] {
        assert_eq!(
            env.as_contract(&contract_id, || env.storage().persistent().get_ttl(key)),
            TTL_BUMP
        );
    }
}

#[test]
fn writes_extend_ttl_of_touched_keys() {
    let (env, contract_id) = setup();
    let client = client(&env, &contract_id);
    let owner = Address::generate(&env);
    let id = client.register(&owner);
    let role = test_uri(&env, "role");
    client.set_metadata(&owner, &id, &role, &Bytes::from_slice(&env, &[1]));
    let owner_key = DataKey::Owner(id);
    let meta_key = DataKey::Metadata(id, role);
    let current = env.ledger().sequence();
    let remaining = env.as_contract(&contract_id, || {
        env.storage().persistent().get_ttl(&meta_key)
    });
    assert!(remaining > TTL_THRESHOLD);
    env.ledger()
        .set_sequence_number(current + (remaining - TTL_THRESHOLD) + 10);
    client.set_metadata(
        &owner,
        &id,
        &test_uri(&env, "role"),
        &Bytes::from_slice(&env, &[2]),
    );
    assert_eq!(
        env.as_contract(&contract_id, || env
            .storage()
            .persistent()
            .get_ttl(&meta_key)),
        TTL_BUMP
    );
    assert_eq!(
        env.as_contract(&contract_id, || env
            .storage()
            .persistent()
            .get_ttl(&owner_key)),
        TTL_BUMP
    );
    assert_eq!(
        env.as_contract(&contract_id, || env.storage().instance().get_ttl()),
        TTL_BUMP
    );
}
