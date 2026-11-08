#![cfg(test)]

extern crate std;

use super::*;
use identity_registry::{IdentityRegistryContract, IdentityRegistryContractClient};
use soroban_sdk::testutils::{
    storage::Persistent as _, Address as _, Events as _, Ledger as _, MockAuth, MockAuthInvoke,
};
use soroban_sdk::{vec as soroban_vec, Event, IntoVal};

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

/// `give_feedback` from `caller` with valid arguments, returning the result.
fn try_give(
    ctx: &Ctx,
    caller: &Address,
) -> Result<
    Result<(), soroban_sdk::ConversionError>,
    Result<ReputationError, soroban_sdk::InvokeError>,
> {
    ctx.rep().try_give_feedback(
        caller,
        &ctx.agent_id,
        &5,
        &0,
        &ctx.s("quality"),
        &ctx.s("speed"),
        &ctx.s("https://agent.example/endpoint"),
        &ctx.s("https://reviews.example/1"),
        &ctx.hash(7),
    )
}

/// Audit finding R-3 (#200): after `set_agent_wallet` points payments at a
/// different address, that wallet must not be able to rate its own agent.
#[test]
fn agent_wallet_cannot_rate_own_agent() {
    let ctx = setup();
    let identity = IdentityRegistryContractClient::new(&ctx.env, &ctx.identity_id);
    let payout = Address::generate(&ctx.env);
    identity.set_agent_wallet(&ctx.agent_owner, &ctx.agent_id, &payout);
    assert_eq!(
        identity.get_agent_wallet(&ctx.agent_id),
        Some(payout.clone())
    );

    assert!(matches!(
        try_give(&ctx, &payout),
        Err(Ok(ReputationError::SelfFeedback)),
    ));
    // Nothing was stored for the rejected wallet.
    assert_eq!(ctx.rep().get_last_index(&ctx.agent_id, &payout), 0);
    assert_eq!(ctx.events(), 0);

    // The owner is still rejected, and an honest client still rates.
    assert!(matches!(
        try_give(&ctx, &ctx.agent_owner),
        Err(Ok(ReputationError::SelfFeedback)),
    ));
    let client = Address::generate(&ctx.env);
    ctx.give(&client, ctx.agent_id, 5, 0);
    assert_eq!(ctx.rep().get_last_index(&ctx.agent_id, &client), 1);
}

/// A wallet that stopped being the agent's payment wallet is an ordinary
/// client again.
#[test]
fn former_agent_wallet_can_rate_after_it_is_replaced() {
    let ctx = setup();
    let identity = IdentityRegistryContractClient::new(&ctx.env, &ctx.identity_id);
    let old_wallet = Address::generate(&ctx.env);
    let new_wallet = Address::generate(&ctx.env);
    identity.set_agent_wallet(&ctx.agent_owner, &ctx.agent_id, &old_wallet);
    identity.set_agent_wallet(&ctx.agent_owner, &ctx.agent_id, &new_wallet);

    ctx.give(&old_wallet, ctx.agent_id, 5, 0);
    assert_eq!(ctx.rep().get_last_index(&ctx.agent_id, &old_wallet), 1);
    assert!(matches!(
        try_give(&ctx, &new_wallet),
        Err(Ok(ReputationError::SelfFeedback)),
    ));
}

/// An agent with no payment wallet still accepts honest feedback.
#[test]
fn agent_without_wallet_accepts_client_feedback() {
    let ctx = setup();
    let identity = IdentityRegistryContractClient::new(&ctx.env, &ctx.identity_id);
    identity.unset_agent_wallet(&ctx.agent_owner, &ctx.agent_id);
    assert_eq!(identity.get_agent_wallet(&ctx.agent_id), None);

    let client = Address::generate(&ctx.env);
    ctx.give(&client, ctx.agent_id, 4, 0);
    assert_eq!(ctx.rep().get_last_index(&ctx.agent_id, &client), 1);
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

// ---------------------------------------------------------------------------
// Audit hardening (#205)
// ---------------------------------------------------------------------------

impl Ctx {
    fn respond(&self, responder: &Address, client: &Address) -> Result<(), ReputationError> {
        match self.rep().try_append_response(
            responder,
            &self.agent_id,
            client,
            &1,
            &self.s("https://reply.example/1"),
            &self.hash(9),
        ) {
            Ok(Ok(())) => Ok(()),
            Err(Ok(e)) => Err(e),
            other => panic!("unexpected result {other:?}"),
        }
    }

    fn summary_count(&self, clients: &[&Address]) -> u64 {
        let mut list = Vec::new(&self.env);
        for client in clients {
            list.push_back((*client).clone());
        }
        self.rep()
            .get_summary(&self.agent_id, &list, &self.s(""), &self.s(""))
            .count
    }

    fn feedback_ttl(&self, client: &Address, index: u64) -> u32 {
        self.env.as_contract(&self.rep_id, || {
            self.env.storage().persistent().get_ttl(&DataKey::Feedback(
                self.agent_id,
                client.clone(),
                index,
            ))
        })
    }

    fn advance_ledgers(&self, ledgers: u32) {
        let now = self.env.ledger().sequence();
        self.env.ledger().set_sequence_number(now + ledgers);
    }
}

/// R-4: `get_summary` stops at `MAX_SUMMARY_RECORDS` records, across clients.
#[test]
fn summary_reads_at_most_max_summary_records() {
    let ctx = setup();
    let first = Address::generate(&ctx.env);
    let second = Address::generate(&ctx.env);
    for _ in 0..MAX_SUMMARY_RECORDS + 5 {
        ctx.give(&first, ctx.agent_id, 5, 0);
    }
    ctx.give(&second, ctx.agent_id, 1, 0);

    assert_eq!(ctx.summary_count(&[&first]), MAX_SUMMARY_RECORDS);
    // The cap is shared: the second client's record is past it.
    assert_eq!(ctx.summary_count(&[&first, &second]), MAX_SUMMARY_RECORDS);
    // Under the cap, every record still counts.
    assert_eq!(ctx.summary_count(&[&second]), 1);
}

/// R-4: `get_summary` is a view and does not extend the TTL of what it reads.
#[test]
fn summary_does_not_extend_ttl() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);
    ctx.give(&reviewer, ctx.agent_id, 5, 0);
    // Below TTL_THRESHOLD, where any extending read would bump it.
    ctx.advance_ledgers(TTL_BUMP - TTL_THRESHOLD + 10);
    let before = ctx.feedback_ttl(&reviewer, 1);
    assert!(before < TTL_THRESHOLD);

    assert_eq!(ctx.summary_count(&[&reviewer]), 1);
    assert_eq!(ctx.feedback_ttl(&reviewer, 1), before);

    // `read_feedback` still keeps the record alive, as before.
    ctx.rep().read_feedback(&ctx.agent_id, &reviewer, &1);
    assert!(ctx.feedback_ttl(&reviewer, 1) > before);
}

/// R-5: third parties are capped per feedback; the agent's side never is.
#[test]
fn third_party_responses_are_capped_but_the_agent_can_always_answer() {
    let ctx = setup();
    let reviewer = Address::generate(&ctx.env);
    ctx.give(&reviewer, ctx.agent_id, 2, 0);

    let spammer = Address::generate(&ctx.env);
    for _ in 0..MAX_THIRD_PARTY_RESPONSES {
        ctx.respond(&spammer, &reviewer).unwrap();
    }
    assert_eq!(
        ctx.respond(&spammer, &reviewer),
        Err(ReputationError::TooManyResponses)
    );
    let other = Address::generate(&ctx.env);
    assert_eq!(
        ctx.respond(&other, &reviewer),
        Err(ReputationError::TooManyResponses)
    );

    // The owner and the payment wallet still answer.
    ctx.respond(&ctx.agent_owner, &reviewer).unwrap();
    let identity = IdentityRegistryContractClient::new(&ctx.env, &ctx.identity_id);
    let payout = Address::generate(&ctx.env);
    identity.set_agent_wallet(&ctx.agent_owner, &ctx.agent_id, &payout);
    ctx.respond(&payout, &reviewer).unwrap();
    assert_eq!(
        ctx.rep().get_response_count(&ctx.agent_id, &reviewer, &1),
        MAX_THIRD_PARTY_RESPONSES + 2
    );
}

/// R-6: proposing and cancelling an upgrade emit events.
#[test]
fn upgrade_proposal_and_cancel_emit_events() {
    let ctx = setup();
    let now = ctx.env.ledger().sequence();
    ctx.rep().propose_upgrade(&ctx.hash(1));
    let events = ctx.env.events().all().filter_by_contract(&ctx.rep_id);
    assert_eq!(
        events,
        [UpgradeProposed {
            wasm_hash: ctx.hash(1),
            proposed_at: now,
            executable_at: now + TIMELOCK_LEDGERS,
            expires_at: now + TIMELOCK_LEDGERS + UPGRADE_EXECUTION_WINDOW,
        }
        .to_xdr(&ctx.env, &ctx.rep_id)]
    );

    ctx.rep().cancel_upgrade();
    let events = ctx.env.events().all().filter_by_contract(&ctx.rep_id);
    assert_eq!(
        events,
        [UpgradeCancelled {
            wasm_hash: ctx.hash(1),
        }
        .to_xdr(&ctx.env, &ctx.rep_id)]
    );
    assert!(ctx.rep().pending_upgrade().is_none());
}

/// R-6: a proposal expires after its execution window and can then be replaced.
#[test]
fn upgrade_proposal_expires_after_its_window() {
    let ctx = setup();
    ctx.rep().propose_upgrade(&ctx.hash(1));

    assert!(matches!(
        ctx.rep().try_execute_upgrade(),
        Err(Ok(ReputationError::TimelockNotExpired)),
    ));
    // Still pending inside the window: a second proposal is refused.
    ctx.advance_ledgers(TIMELOCK_LEDGERS + UPGRADE_EXECUTION_WINDOW);
    assert!(matches!(
        ctx.rep().try_propose_upgrade(&ctx.hash(2)),
        Err(Ok(ReputationError::UpgradeAlreadyProposed)),
    ));

    ctx.advance_ledgers(1);
    assert!(matches!(
        ctx.rep().try_execute_upgrade(),
        Err(Ok(ReputationError::UpgradeProposalExpired)),
    ));
    // The expired proposal is replaced by a new one.
    ctx.rep().propose_upgrade(&ctx.hash(2));
    assert_eq!(ctx.rep().pending_upgrade().unwrap().wasm_hash, ctx.hash(2));
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
