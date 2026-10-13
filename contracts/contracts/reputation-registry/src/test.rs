#![cfg(test)]

extern crate std;

use super::*;
use identity_registry::{IdentityRegistryContract, IdentityRegistryContractClient};
use soroban_sdk::testutils::{Address as _, Events as _, MockAuth, MockAuthInvoke};
use soroban_sdk::{vec as soroban_vec, IntoVal};

struct Ctx {
    env: Env,
    rep_id: Address,
    identity_id: Address,
    agent_id: u32,
    agent_owner: Address,
}

impl Ctx {
    fn rep(&self) -> ReputationRegistryContractClient<'_> {
        ReputationRegistryContractClient::new(&self.env, &self.rep_id)
    }

    fn s(&self, text: &str) -> String {
        String::from_str(&self.env, text)
    }

    fn hash(&self, byte: u8) -> BytesN<32> {
        BytesN::from_array(&self.env, &[byte; 32])
    }

    /// Number of events emitted by the reputation contract so far.
    fn events(&self) -> usize {
        self.env
            .events()
            .all()
            .filter_by_contract(&self.rep_id)
            .events()
            .len()
    }

    /// Calls `give_feedback` for a valid, in-range value (panics on error).
    fn give(&self, caller: &Address, agent_id: u32, value: i128, decimals: u32) {
        self.rep().give_feedback(
            caller,
            &agent_id,
            &value,
            &decimals,
            &self.s("quality"),
            &self.s("speed"),
            &self.s("https://agent.example/endpoint"),
            &self.s("https://reviews.example/1"),
            &self.hash(7),
        );
    }
}

fn setup() -> Ctx {
    let env = Env::default();
    env.mock_all_auths();

    let identity_admin = Address::generate(&env);
    let identity_id = env.register(
        IdentityRegistryContract,
        (
            &identity_admin,
            &String::from_str(&env, "Puls3 Agent"),
            &String::from_str(&env, "P3A"),
        ),
    );
    let identity = IdentityRegistryContractClient::new(&env, &identity_id);
    let agent_owner = Address::generate(&env);
    let agent_id = identity.register(&agent_owner);

    let rep_owner = Address::generate(&env);
    let rep_id = env.register(ReputationRegistryContract, (&rep_owner, &identity_id));

    Ctx {
        env,
        rep_id,
        identity_id,
        agent_id,
        agent_owner,
    }
}

#[test]
fn version_and_identity_registry_are_set() {
    let ctx = setup();
    assert_eq!(ctx.rep().version(), ctx.s("0.1.0"));
    assert_eq!(ctx.rep().get_identity_registry(), ctx.identity_id);
}

#[test]
fn give_feedback_stores_and_emits_one_event() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);

    ctx.give(&reviewer, ctx.agent_id, 5, 0);

    assert_eq!(ctx.events(), 1, "NewFeedback must be emitted once");
    let stored = ctx.rep().read_feedback(&ctx.agent_id, &reviewer, &1);
    assert_eq!(stored.value, 5);
    assert_eq!(stored.value_decimals, 0);
    assert!(!stored.is_revoked);
    assert_eq!(ctx.rep().get_last_index(&ctx.agent_id, &reviewer), 1);
    let clients = ctx.rep().get_clients_paginated(&ctx.agent_id, &0, &10);
    assert_eq!(clients, soroban_vec![&ctx.env, reviewer]);
}

#[test]
fn feedback_for_unregistered_agent_is_rejected_cross_contract() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);
    assert!(matches!(
        ctx.rep().try_give_feedback(
            &reviewer,
            &999,
            &5,
            &0,
            &ctx.s("quality"),
            &ctx.s("speed"),
            &ctx.s("https://agent.example/endpoint"),
            &ctx.s("https://reviews.example/1"),
            &ctx.hash(7),
        ),
        Err(Ok(ReputationError::AgentNotFound)),
    ));
}

#[test]
fn owner_cannot_rate_own_agent() {
    let ctx = setup();
    assert!(matches!(
        ctx.rep().try_give_feedback(
            &ctx.agent_owner,
            &ctx.agent_id,
            &5,
            &0,
            &ctx.s("quality"),
            &ctx.s("speed"),
            &ctx.s("https://agent.example/endpoint"),
            &ctx.s("https://reviews.example/1"),
            &ctx.hash(7),
        ),
        Err(Ok(ReputationError::SelfFeedback)),
    ));
}

#[test]
fn value_decimals_and_range_are_checked() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);
    assert!(matches!(
        ctx.rep().try_give_feedback(
            &reviewer,
            &ctx.agent_id,
            &5,
            &19,
            &ctx.s("quality"),
            &ctx.s("speed"),
            &ctx.s("https://agent.example/endpoint"),
            &ctx.s("https://reviews.example/1"),
            &ctx.hash(7),
        ),
        Err(Ok(ReputationError::InvalidValueDecimals)),
    ));
    assert!(matches!(
        ctx.rep().try_give_feedback(
            &reviewer,
            &ctx.agent_id,
            &(MAX_ABS_VALUE + 1),
            &0,
            &ctx.s("quality"),
            &ctx.s("speed"),
            &ctx.s("https://agent.example/endpoint"),
            &ctx.s("https://reviews.example/1"),
            &ctx.hash(7),
        ),
        Err(Ok(ReputationError::ValueOutOfRange)),
    ));
}

#[test]
fn revoke_is_single_use_and_persists_the_flag() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);
    ctx.give(&reviewer, ctx.agent_id, 5, 0);

    ctx.rep().revoke_feedback(&reviewer, &ctx.agent_id, &1);
    assert_eq!(ctx.events(), 1, "FeedbackRevoked must be emitted once");
    assert!(
        ctx.rep()
            .read_feedback(&ctx.agent_id, &reviewer, &1)
            .is_revoked
    );
    assert!(matches!(
        ctx.rep().try_revoke_feedback(&reviewer, &ctx.agent_id, &1),
        Err(Ok(ReputationError::FeedbackNotFound)),
    ));
}

#[test]
fn only_the_submitter_can_revoke_their_feedback() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);
    let stranger = Address::generate(&ctx.env);
    ctx.give(&reviewer, ctx.agent_id, 5, 0);
    assert!(matches!(
        ctx.rep().try_revoke_feedback(&stranger, &ctx.agent_id, &1),
        Err(Ok(ReputationError::FeedbackNotFound)),
    ));
}

#[test]
fn summary_averages_excludes_revoked_and_requires_clients() {
    let ctx = setup();
    let a = Address::generate(&ctx.env);
    let b = Address::generate(&ctx.env);
    ctx.give(&a, ctx.agent_id, 5, 0);
    ctx.give(&b, ctx.agent_id, 3, 0);

    let clients = soroban_vec![&ctx.env, a.clone(), b.clone()];
    let summary = ctx
        .rep()
        .get_summary(&ctx.agent_id, &clients, &ctx.s(""), &ctx.s(""));
    assert_eq!(summary.count, 2);
    assert_eq!(summary.summary_value, 4);

    ctx.rep().revoke_feedback(&a, &ctx.agent_id, &1);
    let summary = ctx
        .rep()
        .get_summary(&ctx.agent_id, &clients, &ctx.s(""), &ctx.s(""));
    assert_eq!(summary.count, 1);
    assert_eq!(summary.summary_value, 3);
    assert_eq!(summary.summary_value_decimals, 0);

    let empty: Vec<Address> = soroban_vec![&ctx.env];
    assert!(matches!(
        ctx.rep()
            .try_get_summary(&ctx.agent_id, &empty, &ctx.s(""), &ctx.s("")),
        Err(Ok(ReputationError::ClientAddressesRequired)),
    ));
}

#[test]
fn append_response_is_open_but_needs_feedback_and_a_uri() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);
    let responder = Address::generate(&ctx.env);
    ctx.give(&reviewer, ctx.agent_id, 5, 0);

    ctx.rep().append_response(
        &responder,
        &ctx.agent_id,
        &reviewer,
        &1,
        &ctx.s("https://agent.example/reply"),
        &ctx.hash(9),
    );
    assert_eq!(
        ctx.rep().get_response_count(&ctx.agent_id, &reviewer, &1),
        1
    );

    assert!(matches!(
        ctx.rep().try_append_response(
            &responder,
            &ctx.agent_id,
            &reviewer,
            &1,
            &ctx.s(""),
            &ctx.hash(9),
        ),
        Err(Ok(ReputationError::EmptyValue)),
    ));
    assert!(matches!(
        ctx.rep().try_append_response(
            &responder,
            &ctx.agent_id,
            &reviewer,
            &2,
            &ctx.s("https://agent.example/reply"),
            &ctx.hash(9),
        ),
        Err(Ok(ReputationError::FeedbackNotFound)),
    ));
}

#[test]
fn submitter_auth_is_required_without_mock_all_auths() {
    let env = Env::default();

    let identity_admin = Address::generate(&env);
    let identity_id = env.register(
        IdentityRegistryContract,
        (
            &identity_admin,
            &String::from_str(&env, "Puls3 Agent"),
            &String::from_str(&env, "P3A"),
        ),
    );
    let identity = IdentityRegistryContractClient::new(&env, &identity_id);
    let agent_owner = Address::generate(&env);
    env.mock_auths(&[MockAuth {
        address: &agent_owner,
        invoke: &MockAuthInvoke {
            contract: &identity_id,
            fn_name: "register",
            args: (&agent_owner,).into_val(&env),
            sub_invokes: &[],
        },
    }]);
    let agent_id = identity.register(&agent_owner);

    let rep_owner = Address::generate(&env);
    let rep_id = env.register(ReputationRegistryContract, (&rep_owner, &identity_id));
    let rep = ReputationRegistryContractClient::new(&env, &rep_id);

    let reviewer = Address::generate(&env);
    let tag1 = String::from_str(&env, "quality");
    let tag2 = String::from_str(&env, "speed");
    let endpoint = String::from_str(&env, "https://agent.example/endpoint");
    let uri = String::from_str(&env, "https://reviews.example/1");
    let fhash = BytesN::from_array(&env, &[7u8; 32]);

    env.mock_auths(&[MockAuth {
        address: &reviewer,
        invoke: &MockAuthInvoke {
            contract: &rep_id,
            fn_name: "give_feedback",
            args: (
                reviewer.clone(),
                agent_id,
                5i128,
                0u32,
                tag1.clone(),
                tag2.clone(),
                endpoint.clone(),
                uri.clone(),
                fhash.clone(),
            )
                .into_val(&env),
            sub_invokes: &[],
        },
    }]);

    rep.give_feedback(
        &reviewer, &agent_id, &5, &0, &tag1, &tag2, &endpoint, &uri, &fhash,
    );
    assert_eq!(rep.get_last_index(&agent_id, &reviewer), 1);
}
