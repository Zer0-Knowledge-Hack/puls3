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

// --- #199: one poisoned feedback must not make get_summary fail ---

/// 1e30, the value of the audit's proof of concept.
const POISON: i128 = 1_000_000_000_000_000_000_000_000_000_000;
/// The largest accepted whole value: `MAX_ABS_WAD` with 0 decimals.
const MAX_WHOLE: i128 = 10_000_000_000;
/// 1e20 with 0 decimals: 1e38 normalized, fits alone, two of them do not.
const HALF_OVERFLOW: i128 = 100_000_000_000_000_000_000;

type GiveResult = Result<
    Result<(), soroban_sdk::ConversionError>,
    Result<ReputationError, soroban_sdk::InvokeError>,
>;

impl Ctx {
    fn try_give(&self, caller: &Address, value: i128, decimals: u32) -> GiveResult {
        self.rep().try_give_feedback(
            caller,
            &self.agent_id,
            &value,
            &decimals,
            &self.s("quality"),
            &self.s("speed"),
            &self.s("https://agent.example/endpoint"),
            &self.s("https://reviews.example/1"),
            &self.hash(7),
        )
    }

    /// Writes a record straight into storage, as one accepted before the
    /// #199 bound would be: the fixed `give_feedback` refuses these values.
    fn store_legacy(&self, client: &Address, value: i128, decimals: u32, revoked: bool) {
        self.env.as_contract(&self.rep_id, || {
            if !client_exists(&self.env, self.agent_id, client) {
                add_client(&self.env, self.agent_id, client).unwrap();
            }
            let index = get_last_index(&self.env, self.agent_id, client) + 1;
            set_last_index(&self.env, self.agent_id, client, index);
            set_feedback(
                &self.env,
                self.agent_id,
                client,
                index,
                &FeedbackData {
                    value,
                    value_decimals: decimals,
                    is_revoked: revoked,
                    tag1: self.s("quality"),
                    tag2: self.s("speed"),
                },
            );
        });
    }

    fn summary(&self, clients: &Vec<Address>) -> SummaryResult {
        self.rep()
            .get_summary(&self.agent_id, clients, &self.s(""), &self.s(""))
    }
}

#[test]
fn audit_poc_value_1e30_is_rejected_at_give_feedback() {
    let ctx = setup();
    let attacker = Address::generate(&ctx.env);

    assert!(matches!(
        ctx.try_give(&attacker, POISON, 0),
        Err(Ok(ReputationError::ValueOutOfRange)),
    ));
    assert!(matches!(
        ctx.try_give(&attacker, -POISON, 0),
        Err(Ok(ReputationError::ValueOutOfRange)),
    ));
    // Nothing was stored and nothing was emitted.
    assert_eq!(ctx.rep().get_last_index(&ctx.agent_id, &attacker), 0);
    assert_eq!(ctx.events(), 0);
}

#[test]
fn wad_bound_accepts_the_limit_and_rejects_one_more_for_every_decimals() {
    let ctx = setup();
    let client = Address::generate(&ctx.env);
    for decimals in [0u32, 2, 7, 18] {
        // MAX_ABS_WAD / 10^(18 - decimals): the largest value with these decimals.
        let limit = MAX_ABS_WAD / pow10(18 - decimals);
        assert!(
            ctx.try_give(&client, limit, decimals).is_ok(),
            "dec {decimals}"
        );
        assert!(
            ctx.try_give(&client, -limit, decimals).is_ok(),
            "dec {decimals}"
        );
        assert!(
            matches!(
                ctx.try_give(&client, limit + 1, decimals),
                Err(Ok(ReputationError::ValueOutOfRange)),
            ),
            "dec {decimals}"
        );
        assert!(
            matches!(
                ctx.try_give(&client, -(limit + 1), decimals),
                Err(Ok(ReputationError::ValueOutOfRange)),
            ),
            "dec {decimals}"
        );
    }
    assert_eq!(MAX_ABS_WAD / pow10(18), MAX_WHOLE);
    // The ±1e38 range check still comes first.
    assert!(matches!(
        ctx.try_give(&client, MAX_ABS_VALUE + 1, 18),
        Err(Ok(ReputationError::ValueOutOfRange)),
    ));
    // Eight accepted records: two signs, four decimals.
    assert_eq!(ctx.rep().get_last_index(&ctx.agent_id, &client), 8);
}

#[test]
fn the_audit_cumulative_case_is_rejected_at_write_time() {
    let ctx = setup();
    let a = Address::generate(&ctx.env);
    // Fits the WAD scale alone, but two of them overflow the sum: refused.
    assert!(matches!(
        ctx.try_give(&a, HALF_OVERFLOW, 0),
        Err(Ok(ReputationError::ValueOutOfRange)),
    ));
}

#[test]
fn many_records_at_the_bound_still_sum_without_overflow() {
    let ctx = setup();
    let mut clients: Vec<Address> = soroban_vec![&ctx.env];
    for _ in 0..MAX_SUMMARY_CLIENTS {
        let client = Address::generate(&ctx.env);
        for _ in 0..5 {
            ctx.give(&client, ctx.agent_id, MAX_WHOLE, 0);
        }
        clients.push_back(client);
    }

    let summary = ctx.summary(&clients);

    assert_eq!(summary.count, 25);
    assert_eq!(summary.summary_value, MAX_WHOLE);
    assert_eq!(summary.summary_value_decimals, 0);
}

#[test]
fn a_poisoned_stored_record_is_skipped_and_the_summary_still_returns() {
    let ctx = setup();
    let honest = Address::generate(&ctx.env);
    let other = Address::generate(&ctx.env);
    let attacker = Address::generate(&ctx.env);
    ctx.give(&honest, ctx.agent_id, 5, 0);
    ctx.give(&other, ctx.agent_id, 3, 0);
    // The PoC record, stored before the bound existed.
    ctx.store_legacy(&attacker, POISON, 0, false);

    let clients = soroban_vec![&ctx.env, honest.clone(), attacker.clone(), other.clone()];
    let summary = ctx.summary(&clients);

    // Only the two valid records count: (5 + 3) / 2.
    assert_eq!(summary.count, 2);
    assert_eq!(summary.summary_value, 4);
    assert_eq!(summary.summary_value_decimals, 0);
}

#[test]
fn stored_records_whose_sum_overflows_are_skipped_not_fatal() {
    let ctx = setup();
    let honest = Address::generate(&ctx.env);
    let a = Address::generate(&ctx.env);
    let b = Address::generate(&ctx.env);
    ctx.give(&honest, ctx.agent_id, 5, 0);
    // The second large record would overflow the running sum: skipped.
    ctx.store_legacy(&a, HALF_OVERFLOW, 0, false);
    ctx.store_legacy(&b, HALF_OVERFLOW, 0, false);

    let clients = soroban_vec![&ctx.env, honest.clone(), a.clone(), b.clone()];
    let summary = ctx.summary(&clients);

    assert_eq!(summary.count, 2);
    // (5 + 1e20) / 2, in whole units (decimals 0).
    assert_eq!(summary.summary_value, (5 + HALF_OVERFLOW) / 2);
}

#[test]
fn a_summary_of_only_poisoned_records_is_empty_not_an_error() {
    let ctx = setup();
    let attacker = Address::generate(&ctx.env);
    ctx.store_legacy(&attacker, POISON, 0, false);

    let summary = ctx.summary(&soroban_vec![&ctx.env, attacker.clone()]);

    assert_eq!(summary.count, 0);
    assert_eq!(summary.summary_value, 0);
    assert_eq!(summary.summary_value_decimals, 0);
}

#[test]
fn revoked_records_are_skipped_before_normalization() {
    let ctx = setup();
    let honest = Address::generate(&ctx.env);
    let attacker = Address::generate(&ctx.env);
    ctx.give(&honest, ctx.agent_id, 4, 0);
    ctx.give(&honest, ctx.agent_id, 2, 0);
    // A revoked poisoned record and a revoked normal one: neither counts.
    ctx.store_legacy(&attacker, POISON, 0, true);
    ctx.rep().revoke_feedback(&honest, &ctx.agent_id, &2);

    let summary = ctx.summary(&soroban_vec![&ctx.env, honest.clone(), attacker.clone()]);

    assert_eq!(summary.count, 1);
    assert_eq!(summary.summary_value, 4);
}

#[test]
fn normal_values_with_mixed_decimals_still_average_correctly() {
    let ctx = setup();
    let a = Address::generate(&ctx.env);
    let b = Address::generate(&ctx.env);
    let c = Address::generate(&ctx.env);
    ctx.give(&a, ctx.agent_id, 45, 1); // 4.5
    ctx.give(&b, ctx.agent_id, 35, 1); // 3.5
    ctx.give(&c, ctx.agent_id, 3, 0); // 3

    let summary = ctx.summary(&soroban_vec![&ctx.env, a.clone(), b.clone(), c.clone()]);

    // Mode decimals 1; (4.5 + 3.5 + 3) / 3 = 3.666, truncated to 3.6.
    assert_eq!(summary.count, 3);
    assert_eq!(summary.summary_value_decimals, 1);
    assert_eq!(summary.summary_value, 36);
}

#[test]
fn an_empty_client_list_is_still_an_error() {
    let ctx = setup();
    let empty: Vec<Address> = soroban_vec![&ctx.env];
    assert!(matches!(
        ctx.rep()
            .try_get_summary(&ctx.agent_id, &empty, &ctx.s(""), &ctx.s("")),
        Err(Ok(ReputationError::ClientAddressesRequired)),
    ));
}

#[test]
fn stored_records_whose_negative_sum_overflows_are_skipped_not_fatal() {
    // The mirror of the positive case: two legacy records of -1e20 (decimals
    // 0) each fit, but together they go below i128::MIN once normalized.
    let ctx = setup();
    let honest = Address::generate(&ctx.env);
    let a = Address::generate(&ctx.env);
    let b = Address::generate(&ctx.env);
    ctx.give(&honest, ctx.agent_id, 5, 0);
    ctx.store_legacy(&a, -HALF_OVERFLOW, 0, false);
    // The second one would underflow the running sum: skipped.
    ctx.store_legacy(&b, -HALF_OVERFLOW, 0, false);

    let clients = soroban_vec![&ctx.env, honest.clone(), a.clone(), b.clone()];
    let summary = ctx.summary(&clients);

    assert_eq!(summary.count, 2);
    assert_eq!(summary.summary_value_decimals, 0);
    // (5 - 1e20) / 2, in whole units, truncated toward zero like the contract.
    assert_eq!(summary.summary_value, (5 - HALF_OVERFLOW) / 2);
}

#[test]
fn skipped_records_still_use_up_the_summary_read_cap() {
    // #199 skips a record it cannot normalize, #205 stops after
    // MAX_SUMMARY_RECORDS reads. A skipped record is still a read, so a client
    // with that many poisoned legacy records leaves no room for the next
    // client; listed first, the honest client still counts.
    let ctx = setup();
    let poisoned = Address::generate(&ctx.env);
    let honest = Address::generate(&ctx.env);
    for _ in 0..MAX_SUMMARY_RECORDS {
        ctx.store_legacy(&poisoned, POISON, 0, false);
    }
    ctx.give(&honest, ctx.agent_id, 4, 0);

    let poisoned_first = ctx.summary(&soroban_vec![&ctx.env, poisoned.clone(), honest.clone()]);
    assert_eq!(poisoned_first.count, 0);
    assert_eq!(poisoned_first.summary_value, 0);

    let honest_first = ctx.summary(&soroban_vec![&ctx.env, honest.clone(), poisoned.clone()]);
    assert_eq!(honest_first.count, 1);
    assert_eq!(honest_first.summary_value, 4);
}
