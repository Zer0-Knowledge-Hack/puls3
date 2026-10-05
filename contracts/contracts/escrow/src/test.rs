#![cfg(test)]

extern crate std;

use super::*;
use identity_registry::{IdentityRegistryContract, IdentityRegistryContractClient};
use soroban_sdk::testutils::{Address as _, Events as _, Ledger as _};
use soroban_sdk::token::{StellarAssetClient, TokenClient};
use soroban_sdk::{Address, BytesN, Env, Event, String};

// Task 1.2: the real identity registry links as a dev-dependency and runs natively.
#[test]
fn registry_links_as_dev_dependency_and_resolves_wallet() {
    let env = Env::default();
    env.mock_all_auths();
    let registry_id = deploy_registry(&env);
    let registry = IdentityRegistryContractClient::new(&env, &registry_id);
    let owner = Address::generate(&env);
    let agent_id = registry.register(&owner);
    assert_eq!(registry.get_agent_wallet(&agent_id), Some(owner));
    assert!(registry.agent_exists(&agent_id));
    assert!(!registry.agent_exists(&99));
}

// Task 1.3: TokenClient::transfer accepts `&Address` for `to` (MuxedAddress conversion).
#[test]
fn token_client_transfer_accepts_plain_address() {
    let env = Env::default();
    env.mock_all_auths();
    let issuer = Address::generate(&env);
    let sac = env.register_stellar_asset_contract_v2(issuer);
    let token = TokenClient::new(&env, &sac.address());
    let minter = StellarAssetClient::new(&env, &sac.address());
    let from = Address::generate(&env);
    let to = Address::generate(&env);
    minter.mint(&from, &1_000);
    token.transfer(&from, &to, &400);
    assert_eq!(token.balance(&from), 600);
    assert_eq!(token.balance(&to), 400);
}

// ---------------------------------------------------------------------------
// Shared harness
// ---------------------------------------------------------------------------

/// Explicit test values. The contract itself hard-codes no durations.
const NOW: u64 = 1_000_000;
const MAX_EXPIRY: u64 = 86_400;
const APPROVAL_WINDOW: u64 = 3_600;
/// 7-decimal token units: 1.0 token.
const BUDGET: i128 = 10_000_000;
const CLIENT_FUNDS: i128 = 50_000_000;
/// `max_fee_bps` that never blocks `fund`: the contract caps `fee_bps` at `MAX_FEE_BPS`.
const MAX_FEE: u32 = MAX_FEE_BPS;

struct Ctx {
    env: Env,
    escrow_id: Address,
    registry_id: Address,
    admin: Address,
    token: Address,
    client: Address,
    provider: Address,
    agent_id: u32,
}

fn deploy_registry(env: &Env) -> Address {
    let owner = Address::generate(env);
    env.register(
        IdentityRegistryContract,
        (
            &owner,
            &String::from_str(env, "Puls3 Agent"),
            &String::from_str(env, "P3A"),
        ),
    )
}

fn deploy_escrow(
    env: &Env,
    admin: &Address,
    registry: &Address,
    treasury: Option<Address>,
    fee_bps: u32,
) -> Address {
    env.register(
        EscrowContract,
        (
            admin,
            registry,
            &treasury,
            &fee_bps,
            &MAX_EXPIRY,
            &APPROVAL_WINDOW,
        ),
    )
}

fn setup() -> Ctx {
    let env = Env::default();
    env.mock_all_auths();
    env.ledger().set_timestamp(NOW);
    let admin = Address::generate(&env);
    let registry_id = deploy_registry(&env);
    let escrow_id = deploy_escrow(&env, &admin, &registry_id, None, 0);
    let issuer = Address::generate(&env);
    let token = env.register_stellar_asset_contract_v2(issuer).address();
    let client = Address::generate(&env);
    let provider = Address::generate(&env);
    StellarAssetClient::new(&env, &token).mint(&client, &CLIENT_FUNDS);
    let agent_id = IdentityRegistryContractClient::new(&env, &registry_id).register(&provider);
    let ctx = Ctx {
        env,
        escrow_id,
        registry_id,
        admin,
        token,
        client,
        provider,
        agent_id,
    };
    ctx.escrow()
        .set_token_allowed(&ctx.admin, &ctx.token, &true);
    ctx
}

impl Ctx {
    fn escrow(&self) -> EscrowContractClient<'_> {
        EscrowContractClient::new(&self.env, &self.escrow_id)
    }

    fn registry(&self) -> IdentityRegistryContractClient<'_> {
        IdentityRegistryContractClient::new(&self.env, &self.registry_id)
    }

    fn balance(&self, who: &Address) -> i128 {
        TokenClient::new(&self.env, &self.token).balance(who)
    }

    fn desc(&self, text: &str) -> String {
        String::from_str(&self.env, text)
    }

    fn hash(&self, byte: u8) -> BytesN<32> {
        BytesN::from_array(&self.env, &[byte; 32])
    }

    fn set_time(&self, ts: u64) {
        self.env.ledger().set_timestamp(ts);
    }

    /// Creates a job with the default actors (evaluator = client).
    fn create(&self, expired_at: u64) -> u64 {
        self.escrow().create_job(
            &self.client,
            &self.provider,
            &self.client,
            &expired_at,
            &self.desc("job"),
            &None,
            &self.agent_id,
            &self.token,
            &BUDGET,
        )
    }

    fn try_create(
        &self,
        provider: &Address,
        expired_at: u64,
        hook: Option<Address>,
        agent_id: u32,
        token: &Address,
        budget: i128,
    ) -> Result<u64, EscrowError> {
        match self.escrow().try_create_job(
            &self.client,
            provider,
            &self.client,
            &expired_at,
            &self.desc("job"),
            &hook,
            &agent_id,
            token,
            &budget,
        ) {
            Ok(Ok(id)) => Ok(id),
            Err(Ok(err)) => Err(err),
            other => panic!("unexpected host result: {other:?}"),
        }
    }

    fn job_events(&self) -> soroban_sdk::testutils::ContractEvents {
        self.env.events().all().filter_by_contract(&self.escrow_id)
    }
}

/// Unwraps the typed contract error from a `try_*` client result.
fn err<T: core::fmt::Debug, C: core::fmt::Debug>(
    r: Result<Result<T, C>, Result<EscrowError, soroban_sdk::InvokeError>>,
) -> EscrowError {
    match r {
        Err(Ok(e)) => e,
        other => panic!("expected contract error, got {other:?}"),
    }
}

// ---------------------------------------------------------------------------
// 1.5 A1: constructor
// ---------------------------------------------------------------------------

#[test]
fn constructor_stores_explicit_config() {
    let ctx = setup();
    let e = ctx.escrow();
    assert_eq!(e.admin(), ctx.admin);
    assert_eq!(e.identity_registry(), ctx.registry_id);
    assert_eq!(e.treasury(), None);
    assert_eq!(e.fee_bps(), 0);
    assert_eq!(e.max_expiry(), MAX_EXPIRY);
    assert_eq!(e.approval_window(), APPROVAL_WINDOW);
    assert_eq!(e.job_count(), 0);
    assert!(!e.is_token_allowed(&Address::generate(&ctx.env)));
}

#[test]
fn constructor_stores_different_values_and_treasury() {
    let env = Env::default();
    let admin = Address::generate(&env);
    let registry = Address::generate(&env);
    let treasury = Address::generate(&env);
    let id = env.register(
        EscrowContract,
        (
            &admin,
            &registry,
            &Some(treasury.clone()),
            &250u32,
            &7_200u64,
            &600u64,
        ),
    );
    let e = EscrowContractClient::new(&env, &id);
    assert_eq!(e.treasury(), Some(treasury));
    assert_eq!(e.fee_bps(), 250);
    assert_eq!(e.max_expiry(), 7_200);
    assert_eq!(e.approval_window(), 600);
}

#[test]
#[should_panic(expected = "Error(Contract, #109)")]
fn constructor_rejects_fee_above_max_fee_bps() {
    let env = Env::default();
    let a = Address::generate(&env);
    env.register(
        EscrowContract,
        (
            &a,
            &a,
            &Some(a.clone()),
            &(MAX_FEE_BPS + 1),
            &86_400u64,
            &3_600u64,
        ),
    );
}

#[test]
fn constructor_accepts_fee_at_max_fee_bps() {
    let env = Env::default();
    let a = Address::generate(&env);
    let id = env.register(
        EscrowContract,
        (
            &a,
            &a,
            &Some(a.clone()),
            &MAX_FEE_BPS,
            &86_400u64,
            &3_600u64,
        ),
    );
    assert_eq!(EscrowContractClient::new(&env, &id).fee_bps(), MAX_FEE_BPS);
}

#[test]
#[should_panic(expected = "Error(Contract, #110)")]
fn constructor_rejects_fee_without_treasury() {
    let env = Env::default();
    let a = Address::generate(&env);
    env.register(
        EscrowContract,
        (&a, &a, &None::<Address>, &100u32, &86_400u64, &3_600u64),
    );
}

#[test]
#[should_panic(expected = "Error(Contract, #111)")]
fn constructor_rejects_zero_max_expiry() {
    let env = Env::default();
    let a = Address::generate(&env);
    env.register(
        EscrowContract,
        (&a, &a, &None::<Address>, &0u32, &0u64, &3_600u64),
    );
}

#[test]
#[should_panic(expected = "Error(Contract, #111)")]
fn constructor_rejects_zero_approval_window() {
    let env = Env::default();
    let a = Address::generate(&env);
    env.register(
        EscrowContract,
        (&a, &a, &None::<Address>, &0u32, &86_400u64, &0u64),
    );
}

#[test]
#[should_panic(expected = "Error(Contract, #111)")]
fn constructor_rejects_window_not_below_max_expiry() {
    let env = Env::default();
    let a = Address::generate(&env);
    env.register(
        EscrowContract,
        (&a, &a, &None::<Address>, &0u32, &3_600u64, &3_600u64),
    );
}

// ---------------------------------------------------------------------------
// 1.6: catalogue, types, getters, version
// ---------------------------------------------------------------------------

#[test]
fn error_codes_are_stable_and_distinct() {
    let erc_shaped = [
        EscrowError::JobNotFound as u32,
        EscrowError::InvalidState as u32,
        EscrowError::NotClient as u32,
        EscrowError::NotProvider as u32,
        EscrowError::NotEvaluator as u32,
        EscrowError::InvalidAmount as u32,
        EscrowError::BudgetMismatch as u32,
        EscrowError::InvalidExpiry as u32,
        EscrowError::JobExpired as u32,
        EscrowError::NotExpired as u32,
        EscrowError::HookNotSupported as u32,
    ];
    let puls3 = [
        EscrowError::NotAdmin as u32,
        EscrowError::TokenNotAllowed as u32,
        EscrowError::ProviderMismatch as u32,
        EscrowError::AgentWalletNotSet as u32,
        EscrowError::AgentNotFound as u32,
        EscrowError::ClientIsProvider as u32,
        EscrowError::SubmitTooLate as u32,
        EscrowError::ApprovalWindowOpen as u32,
        EscrowError::ApprovalWindowClosed as u32,
        EscrowError::InvalidFeeBps as u32,
        EscrowError::TreasuryNotSet as u32,
        EscrowError::InvalidDuration as u32,
        EscrowError::RegistryNotSet as u32,
        EscrowError::DescriptionTooLong as u32,
        EscrowError::ArithmeticOverflow as u32,
        EscrowError::FeeExceedsMax as u32,
        EscrowError::NothingToWithdraw as u32,
    ];
    assert_eq!(erc_shaped, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    assert_eq!(
        puls3,
        [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116]
    );
}

#[test]
fn job_state_discriminants_are_stable() {
    assert_eq!(JobState::Open as u32, 0);
    assert_eq!(JobState::Funded as u32, 1);
    assert_eq!(JobState::Submitted as u32, 2);
    assert_eq!(JobState::Completed as u32, 3);
    assert_eq!(JobState::Rejected as u32, 4);
    assert_eq!(JobState::Expired as u32, 5);
}

#[test]
fn version_matches_crate_version() {
    let ctx = setup();
    assert_eq!(ctx.escrow().version(), ctx.desc("0.1.0"));
}

#[test]
fn unknown_job_is_reported_by_views() {
    let ctx = setup();
    let e = ctx.escrow();
    assert_eq!(err(e.try_get_job(&42)), EscrowError::JobNotFound);
    assert_eq!(err(e.try_is_expired(&42)), EscrowError::JobNotFound);
}

// ---------------------------------------------------------------------------
// 1.7 A2: token allow-list
// ---------------------------------------------------------------------------

#[test]
fn admin_allows_and_removes_a_token() {
    let ctx = setup();
    let e = ctx.escrow();
    let other = Address::generate(&ctx.env);
    assert!(!e.is_token_allowed(&other));
    e.set_token_allowed(&ctx.admin, &other, &true);
    let events = ctx.job_events();
    assert!(e.is_token_allowed(&other));
    assert_eq!(
        events,
        [TokenAllowedSet {
            token: other.clone(),
            allowed: true
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
    e.set_token_allowed(&ctx.admin, &other, &false);
    let events = ctx.job_events();
    assert!(!e.is_token_allowed(&other));
    assert_eq!(
        events,
        [TokenAllowedSet {
            token: other,
            allowed: false
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn non_admin_cannot_change_the_allow_list() {
    let ctx = setup();
    let e = ctx.escrow();
    let other = Address::generate(&ctx.env);
    let attacker = Address::generate(&ctx.env);
    assert_eq!(
        err(e.try_set_token_allowed(&attacker, &other, &true)),
        EscrowError::NotAdmin
    );
    assert!(!e.is_token_allowed(&other));
}

// ---------------------------------------------------------------------------
// 1.8 R1: create_job
// ---------------------------------------------------------------------------

#[test]
fn create_job_stores_an_open_job_and_emits_job_created() {
    let ctx = setup();
    let expired_at = NOW + 10_000;
    let before = ctx.balance(&ctx.client);
    let id = ctx.create(expired_at);
    // Events belong to the last invocation, so capture them before any view call.
    let events = ctx.job_events();
    assert_eq!(id, 1);
    let job = ctx.escrow().get_job(&id);
    assert_eq!(job.state, JobState::Open);
    assert_eq!(job.client, ctx.client);
    assert_eq!(job.provider, ctx.provider);
    assert_eq!(job.evaluator, ctx.client);
    assert_eq!(job.agent_id, ctx.agent_id);
    assert_eq!(job.token, ctx.token);
    assert_eq!(job.budget, BUDGET);
    assert_eq!(job.expired_at, expired_at);
    assert_eq!(job.description, ctx.desc("job"));
    assert_eq!(job.fee_bps, 0);
    assert_eq!(job.deliverable, None);
    assert_eq!(ctx.balance(&ctx.client), before);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(
        events,
        [JobCreated {
            job_id: 1,
            client: ctx.client.clone(),
            provider: ctx.provider.clone(),
            evaluator: ctx.client.clone(),
            agent_id: ctx.agent_id,
            token: ctx.token.clone(),
            budget: BUDGET,
            expired_at,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn job_ids_are_sequential_and_counted() {
    let ctx = setup();
    assert_eq!(ctx.create(NOW + 100), 1);
    assert_eq!(ctx.create(NOW + 200), 2);
    assert_eq!(ctx.escrow().job_count(), 2);
    assert_eq!(ctx.escrow().get_job(&2).expired_at, NOW + 200);
}

#[test]
fn third_party_evaluator_is_stored() {
    let ctx = setup();
    let evaluator = Address::generate(&ctx.env);
    let id = ctx.escrow().create_job(
        &ctx.client,
        &ctx.provider,
        &evaluator,
        &(NOW + 100),
        &ctx.desc("job"),
        &None,
        &ctx.agent_id,
        &ctx.token,
        &BUDGET,
    );
    assert_eq!(ctx.escrow().get_job(&id).evaluator, evaluator);
}

#[test]
fn non_empty_hook_is_rejected_and_nothing_is_stored() {
    let ctx = setup();
    let hook = Some(Address::generate(&ctx.env));
    assert_eq!(
        ctx.try_create(
            &ctx.provider,
            NOW + 100,
            hook,
            ctx.agent_id,
            &ctx.token,
            BUDGET
        ),
        Err(EscrowError::HookNotSupported)
    );
    assert_eq!(ctx.escrow().job_count(), 0);
}

#[test]
fn token_must_be_allow_listed() {
    let ctx = setup();
    let other = Address::generate(&ctx.env);
    assert_eq!(
        ctx.try_create(&ctx.provider, NOW + 100, None, ctx.agent_id, &other, BUDGET),
        Err(EscrowError::TokenNotAllowed)
    );
}

#[test]
fn budget_must_be_positive() {
    let ctx = setup();
    for budget in [0, -1] {
        assert_eq!(
            ctx.try_create(
                &ctx.provider,
                NOW + 100,
                None,
                ctx.agent_id,
                &ctx.token,
                budget
            ),
            Err(EscrowError::InvalidAmount)
        );
    }
    assert_eq!(
        ctx.try_create(&ctx.provider, NOW + 100, None, ctx.agent_id, &ctx.token, 1),
        Ok(1)
    );
}

#[test]
fn expiry_bounds_are_enforced() {
    let ctx = setup();
    for bad in [NOW, NOW - 1, NOW + MAX_EXPIRY + 1] {
        assert_eq!(
            ctx.try_create(&ctx.provider, bad, None, ctx.agent_id, &ctx.token, BUDGET),
            Err(EscrowError::InvalidExpiry),
            "expired_at {bad}"
        );
    }
    assert_eq!(
        ctx.try_create(
            &ctx.provider,
            NOW + 1,
            None,
            ctx.agent_id,
            &ctx.token,
            BUDGET
        ),
        Ok(1)
    );
    assert_eq!(
        ctx.try_create(
            &ctx.provider,
            NOW + MAX_EXPIRY,
            None,
            ctx.agent_id,
            &ctx.token,
            BUDGET
        ),
        Ok(2)
    );
}

#[test]
fn description_limit_is_256_bytes() {
    let ctx = setup();
    let long = "x".repeat(257);
    let exact = "x".repeat(256);
    let call = |text: &str| {
        ctx.escrow().try_create_job(
            &ctx.client,
            &ctx.provider,
            &ctx.client,
            &(NOW + 100),
            &ctx.desc(text),
            &None,
            &ctx.agent_id,
            &ctx.token,
            &BUDGET,
        )
    };
    assert_eq!(err(call(&long)), EscrowError::DescriptionTooLong);
    assert_eq!(call(&exact), Ok(Ok(1)));
}

#[test]
fn provider_must_match_registry_wallet() {
    let ctx = setup();
    let other = Address::generate(&ctx.env);
    assert_eq!(
        ctx.try_create(&other, NOW + 100, None, ctx.agent_id, &ctx.token, BUDGET),
        Err(EscrowError::ProviderMismatch)
    );
    assert_eq!(ctx.escrow().job_count(), 0);
}

#[test]
fn agent_without_wallet_is_rejected() {
    let ctx = setup();
    ctx.registry()
        .unset_agent_wallet(&ctx.provider, &ctx.agent_id);
    assert_eq!(
        ctx.try_create(
            &ctx.provider,
            NOW + 100,
            None,
            ctx.agent_id,
            &ctx.token,
            BUDGET
        ),
        Err(EscrowError::AgentWalletNotSet)
    );
}

#[test]
fn unknown_agent_is_rejected() {
    let ctx = setup();
    assert_eq!(
        ctx.try_create(&ctx.provider, NOW + 100, None, 99, &ctx.token, BUDGET),
        Err(EscrowError::AgentNotFound)
    );
}

#[test]
fn client_cannot_be_the_provider() {
    let ctx = setup();
    let r = ctx.escrow().try_create_job(
        &ctx.provider,
        &ctx.provider,
        &ctx.provider,
        &(NOW + 100),
        &ctx.desc("job"),
        &None,
        &ctx.agent_id,
        &ctx.token,
        &BUDGET,
    );
    assert_eq!(err(r), EscrowError::ClientIsProvider);
}

#[test]
fn create_job_requires_client_authorization() {
    let ctx = setup();
    ctx.env.mock_auths(&[]);
    let r = ctx.escrow().try_create_job(
        &ctx.client,
        &ctx.provider,
        &ctx.client,
        &(NOW + 100),
        &ctx.desc("job"),
        &None,
        &ctx.agent_id,
        &ctx.token,
        &BUDGET,
    );
    assert!(r.is_err());
    assert_eq!(ctx.escrow().job_count(), 0);
}

#[test]
fn failed_create_emits_no_event() {
    let ctx = setup();
    assert_eq!(
        ctx.try_create(&ctx.provider, NOW + 100, None, ctx.agent_id, &ctx.token, 0),
        Err(EscrowError::InvalidAmount)
    );
    assert!(ctx.job_events().events().is_empty());
}

// ---------------------------------------------------------------------------
// 1.9: payee frozen at creation
// ---------------------------------------------------------------------------

#[test]
fn payee_is_frozen_after_a_registry_wallet_change() {
    let ctx = setup();
    let id = ctx.create(NOW + 100);
    let new_wallet = Address::generate(&ctx.env);
    ctx.registry()
        .set_agent_wallet(&ctx.provider, &ctx.agent_id, &new_wallet);
    assert_eq!(
        ctx.registry().get_agent_wallet(&ctx.agent_id),
        Some(new_wallet)
    );
    assert_eq!(ctx.escrow().get_job(&id).provider, ctx.provider);
}

// ===========================================================================
// PR 2: funding, refunds, views
// ===========================================================================

impl Ctx {
    fn fund(&self, job_id: u64) {
        self.escrow().fund(&self.client, &job_id, &BUDGET, &MAX_FEE);
    }

    /// Creates and funds a job; the contract then holds `BUDGET`.
    fn funded(&self, expired_at: u64) -> u64 {
        let id = self.create(expired_at);
        self.fund(id);
        id
    }
}

/// Same actors as `setup`, but the escrow is deployed with a fee and a treasury.
fn setup_with_fee(fee_bps: u32) -> (Ctx, Address) {
    let ctx = setup();
    let treasury = Address::generate(&ctx.env);
    let escrow_id = deploy_escrow(
        &ctx.env,
        &ctx.admin,
        &ctx.registry_id,
        Some(treasury.clone()),
        fee_bps,
    );
    let ctx = Ctx { escrow_id, ..ctx };
    ctx.escrow()
        .set_token_allowed(&ctx.admin, &ctx.token, &true);
    (ctx, treasury)
}

// ---------------------------------------------------------------------------
// 2.1 R2: fund
// ---------------------------------------------------------------------------

#[test]
fn fund_pulls_the_budget_and_emits_job_funded() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    ctx.escrow().fund(&ctx.client, &id, &BUDGET, &MAX_FEE);
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Funded);
    assert_eq!(
        events,
        [JobFunded {
            job_id: id,
            client: ctx.client.clone(),
            amount: BUDGET,
            fee_bps: 0,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn fund_snapshots_the_fee_in_force_at_fund_time() {
    let (ctx, _treasury) = setup_with_fee(250);
    let id = ctx.create(NOW + 1_000);
    assert_eq!(ctx.escrow().get_job(&id).fee_bps, 0);
    ctx.fund(id);
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().get_job(&id).fee_bps, 250);
    assert_eq!(
        events,
        [JobFunded {
            job_id: id,
            client: ctx.client.clone(),
            amount: BUDGET,
            fee_bps: 250,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn only_the_client_can_fund() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    let outsider = Address::generate(&ctx.env);
    assert_eq!(
        err(ctx.escrow().try_fund(&outsider, &id, &BUDGET, &MAX_FEE)),
        EscrowError::NotClient
    );
    assert_eq!(
        err(ctx.escrow().try_fund(&ctx.provider, &id, &BUDGET, &MAX_FEE)),
        EscrowError::NotClient
    );
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Open);
}

#[test]
fn fund_rejects_a_budget_mismatch() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    for wrong in [BUDGET - 1, BUDGET + 1, 0] {
        assert_eq!(
            err(ctx.escrow().try_fund(&ctx.client, &id, &wrong, &MAX_FEE)),
            EscrowError::BudgetMismatch
        );
    }
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Open);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

#[test]
fn fund_after_expiry_is_refused() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let id = ctx.create(expired_at);
    ctx.set_time(expired_at - 1);
    ctx.fund(id);
    let late = ctx.create(expired_at + 500);
    ctx.set_time(expired_at + 500);
    assert_eq!(
        err(ctx.escrow().try_fund(&ctx.client, &late, &BUDGET, &MAX_FEE)),
        EscrowError::JobExpired
    );
    assert_eq!(ctx.escrow().get_job(&late).state, JobState::Open);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
}

#[test]
fn fund_twice_is_an_invalid_state() {
    let ctx = setup();
    let id = ctx.funded(NOW + 1_000);
    assert_eq!(
        err(ctx.escrow().try_fund(&ctx.client, &id, &BUDGET, &MAX_FEE)),
        EscrowError::InvalidState
    );
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
}

#[test]
fn fund_fails_cleanly_on_insufficient_balance() {
    let ctx = setup();
    let too_much = CLIENT_FUNDS + 1;
    let id = ctx.escrow().create_job(
        &ctx.client,
        &ctx.provider,
        &ctx.client,
        &(NOW + 1_000),
        &ctx.desc("job"),
        &None,
        &ctx.agent_id,
        &ctx.token,
        &too_much,
    );
    assert!(ctx
        .escrow()
        .try_fund(&ctx.client, &id, &too_much, &MAX_FEE)
        .is_err());
    assert!(ctx.job_events().events().is_empty());
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Open);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
}

#[test]
fn fund_requires_the_token_to_still_be_allow_listed() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    ctx.escrow()
        .set_token_allowed(&ctx.admin, &ctx.token, &false);
    assert_eq!(
        err(ctx.escrow().try_fund(&ctx.client, &id, &BUDGET, &MAX_FEE)),
        EscrowError::TokenNotAllowed
    );
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

#[test]
fn fund_unknown_job_is_not_found() {
    let ctx = setup();
    assert_eq!(
        err(ctx.escrow().try_fund(&ctx.client, &7, &BUDGET, &MAX_FEE)),
        EscrowError::JobNotFound
    );
}

// ---------------------------------------------------------------------------
// 2.2 R6 (Open / Funded): reject
// ---------------------------------------------------------------------------

#[test]
fn client_cancels_an_open_job_without_moving_funds() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    let reason = ctx.hash(9);
    ctx.escrow().reject(&ctx.client, &id, &reason);
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Rejected);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(
        events,
        [JobRejected {
            job_id: id,
            rejector: ctx.client.clone(),
            reason,
            from_state: JobState::Open,
            refunded: 0,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn only_the_client_can_reject_an_open_job() {
    let ctx = setup();
    let evaluator = Address::generate(&ctx.env);
    let id = ctx.escrow().create_job(
        &ctx.client,
        &ctx.provider,
        &evaluator,
        &(NOW + 1_000),
        &ctx.desc("job"),
        &None,
        &ctx.agent_id,
        &ctx.token,
        &BUDGET,
    );
    for caller in [&evaluator, &ctx.provider] {
        assert_eq!(
            err(ctx.escrow().try_reject(caller, &id, &ctx.hash(1))),
            EscrowError::NotClient
        );
    }
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Open);
}

#[test]
fn evaluator_rejects_a_funded_job_with_a_full_refund() {
    let ctx = setup();
    let id = ctx.funded(NOW + 1_000);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - BUDGET);
    let reason = ctx.hash(3);
    ctx.escrow().reject(&ctx.client, &id, &reason);
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Rejected);
    assert_eq!(
        events,
        [JobRejected {
            job_id: id,
            rejector: ctx.client.clone(),
            reason,
            from_state: JobState::Funded,
            refunded: BUDGET,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn only_the_evaluator_can_reject_a_funded_job() {
    let ctx = setup();
    let evaluator = Address::generate(&ctx.env);
    let id = ctx.escrow().create_job(
        &ctx.client,
        &ctx.provider,
        &evaluator,
        &(NOW + 1_000),
        &ctx.desc("job"),
        &None,
        &ctx.agent_id,
        &ctx.token,
        &BUDGET,
    );
    ctx.fund(id);
    for caller in [&ctx.client, &ctx.provider] {
        assert_eq!(
            err(ctx.escrow().try_reject(caller, &id, &ctx.hash(1))),
            EscrowError::NotEvaluator
        );
    }
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    // The third-party evaluator can reject, and the refund still goes to the client.
    ctx.escrow().reject(&evaluator, &id, &ctx.hash(1));
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&evaluator), 0);
}

#[test]
fn reject_is_final_for_terminal_jobs() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    ctx.escrow().reject(&ctx.client, &id, &ctx.hash(1));
    assert_eq!(
        err(ctx.escrow().try_reject(&ctx.client, &id, &ctx.hash(1))),
        EscrowError::InvalidState
    );
    assert_eq!(
        err(ctx.escrow().try_fund(&ctx.client, &id, &BUDGET, &MAX_FEE)),
        EscrowError::InvalidState
    );
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&id)),
        EscrowError::InvalidState
    );
}

// ---------------------------------------------------------------------------
// 2.3 R7: claim_refund
// ---------------------------------------------------------------------------

#[test]
fn claim_refund_returns_the_budget_to_the_client_after_expiry() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let id = ctx.funded(expired_at);
    ctx.set_time(expired_at + 1);
    ctx.escrow().claim_refund(&id);
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Expired);
    assert_eq!(
        events,
        [JobExpired {
            job_id: id,
            client: ctx.client.clone(),
            refunded: BUDGET,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn claim_refund_works_exactly_at_expiry_and_not_before() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let id = ctx.funded(expired_at);
    ctx.set_time(expired_at - 1);
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&id)),
        EscrowError::NotExpired
    );
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    ctx.set_time(expired_at);
    ctx.escrow().claim_refund(&id);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Expired);
}

#[test]
fn claim_refund_refuses_open_jobs_and_double_refunds() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let open = ctx.create(expired_at);
    let funded = ctx.funded(expired_at);
    ctx.set_time(expired_at);
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&open)),
        EscrowError::InvalidState
    );
    ctx.escrow().claim_refund(&funded);
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&funded)),
        EscrowError::InvalidState
    );
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
}

#[test]
fn claim_refund_needs_no_authorization_and_pays_only_the_client() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let id = ctx.funded(expired_at);
    ctx.set_time(expired_at);
    ctx.env.mock_auths(&[]);
    let bystander = Address::generate(&ctx.env);
    ctx.escrow().claim_refund(&id);
    assert_eq!(ctx.balance(&bystander), 0);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
}

// ---------------------------------------------------------------------------
// 2.4 R8: views
// ---------------------------------------------------------------------------

#[test]
fn unfunded_expiry_is_derived_not_stored() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let id = ctx.create(expired_at);
    assert!(!ctx.escrow().is_expired(&id));
    ctx.set_time(expired_at);
    assert!(ctx.escrow().is_expired(&id));
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Open);
}

#[test]
fn live_funded_job_is_not_expired_but_an_expired_one_is() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let id = ctx.funded(expired_at);
    assert!(!ctx.escrow().is_expired(&id));
    ctx.set_time(expired_at);
    assert!(ctx.escrow().is_expired(&id));
    ctx.escrow().claim_refund(&id);
    assert!(ctx.escrow().is_expired(&id));
}

#[test]
fn rejected_job_is_never_reported_expired() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    ctx.escrow().reject(&ctx.client, &id, &ctx.hash(1));
    ctx.set_time(NOW + 5_000);
    assert!(!ctx.escrow().is_expired(&id));
}

// ---------------------------------------------------------------------------
// 2.5: conservation and event discipline
// ---------------------------------------------------------------------------

#[test]
fn refund_paths_conserve_funds() {
    let ctx = setup();
    let expired_at = NOW + 1_000;
    let by_reject = ctx.funded(expired_at);
    let by_expiry = ctx.funded(expired_at);
    assert_eq!(ctx.balance(&ctx.escrow_id), 2 * BUDGET);
    ctx.escrow().reject(&ctx.client, &by_reject, &ctx.hash(1));
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    ctx.set_time(expired_at);
    ctx.escrow().claim_refund(&by_expiry);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
}

#[test]
fn failed_transitions_emit_no_event() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&id)),
        EscrowError::InvalidState
    );
    assert!(ctx.job_events().events().is_empty());
    assert_eq!(
        err(ctx
            .escrow()
            .try_fund(&ctx.client, &id, &(BUDGET + 1), &MAX_FEE)),
        EscrowError::BudgetMismatch
    );
    assert!(ctx.job_events().events().is_empty());
}

// ===========================================================================
// PR 3: submit, completion, settlement
// ===========================================================================

impl Ctx {
    fn submit(&self, job_id: u64) {
        self.escrow()
            .submit(&self.provider, &job_id, &self.hash(0xAB));
    }

    /// Funds and submits at `NOW`; `approval_deadline == NOW + APPROVAL_WINDOW`.
    fn submitted(&self, expired_at: u64) -> u64 {
        let id = self.funded(expired_at);
        self.submit(id);
        id
    }
}

/// Far enough out that `NOW + APPROVAL_WINDOW < expired_at` for default tests.
const LATE_EXPIRY: u64 = NOW + 20_000;
const DEADLINE: u64 = NOW + APPROVAL_WINDOW;

// ---------------------------------------------------------------------------
// 3.1 R3: submit
// ---------------------------------------------------------------------------

#[test]
fn provider_submits_a_funded_job() {
    let ctx = setup();
    let id = ctx.funded(LATE_EXPIRY);
    let deliverable = ctx.hash(0xAB);
    ctx.escrow().submit(&ctx.provider, &id, &deliverable);
    let events = ctx.job_events();
    let job = ctx.escrow().get_job(&id);
    assert_eq!(job.state, JobState::Submitted);
    assert_eq!(job.deliverable, Some(deliverable.clone()));
    assert_eq!(job.submitted_at, NOW);
    assert_eq!(job.approval_deadline, DEADLINE);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    assert_eq!(
        events,
        [JobSubmitted {
            job_id: id,
            provider: ctx.provider.clone(),
            deliverable,
            approval_deadline: DEADLINE,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn deadline_uses_the_submission_time() {
    let ctx = setup();
    let id = ctx.funded(LATE_EXPIRY);
    ctx.set_time(NOW + 500);
    ctx.submit(id);
    let job = ctx.escrow().get_job(&id);
    assert_eq!(job.submitted_at, NOW + 500);
    assert_eq!(job.approval_deadline, NOW + 500 + APPROVAL_WINDOW);
}

#[test]
fn only_the_stored_provider_can_submit() {
    let ctx = setup();
    let id = ctx.funded(LATE_EXPIRY);
    let outsider = Address::generate(&ctx.env);
    for caller in [&ctx.client, &outsider] {
        assert_eq!(
            err(ctx.escrow().try_submit(caller, &id, &ctx.hash(1))),
            EscrowError::NotProvider
        );
    }
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Funded);
}

#[test]
fn submit_requires_a_funded_job() {
    let ctx = setup();
    let open = ctx.create(LATE_EXPIRY);
    assert_eq!(
        err(ctx.escrow().try_submit(&ctx.provider, &open, &ctx.hash(1))),
        EscrowError::InvalidState
    );
    let submitted = ctx.submitted(LATE_EXPIRY);
    assert_eq!(
        err(ctx
            .escrow()
            .try_submit(&ctx.provider, &submitted, &ctx.hash(1))),
        EscrowError::InvalidState
    );
    ctx.escrow().reject(&ctx.client, &open, &ctx.hash(1));
    assert_eq!(
        err(ctx.escrow().try_submit(&ctx.provider, &open, &ctx.hash(1))),
        EscrowError::InvalidState
    );
}

#[test]
fn submit_after_expiry_is_refused() {
    let ctx = setup();
    let id = ctx.funded(LATE_EXPIRY);
    ctx.set_time(LATE_EXPIRY);
    assert_eq!(
        err(ctx.escrow().try_submit(&ctx.provider, &id, &ctx.hash(1))),
        EscrowError::JobExpired
    );
}

#[test]
fn submit_must_leave_room_for_the_approval_window() {
    let ctx = setup();
    let expired_at = NOW + 10_000;
    let id = ctx.funded(expired_at);
    // now + window == expired_at is too late; one second earlier is fine.
    ctx.set_time(expired_at - APPROVAL_WINDOW);
    assert_eq!(
        err(ctx.escrow().try_submit(&ctx.provider, &id, &ctx.hash(1))),
        EscrowError::SubmitTooLate
    );
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Funded);
    ctx.set_time(expired_at - APPROVAL_WINDOW - 1);
    ctx.escrow().submit(&ctx.provider, &id, &ctx.hash(1));
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Submitted);
}

#[test]
fn a_job_too_late_to_submit_stays_refundable() {
    let ctx = setup();
    let expired_at = NOW + 10_000;
    let id = ctx.funded(expired_at);
    ctx.set_time(expired_at - 1);
    assert_eq!(
        err(ctx.escrow().try_submit(&ctx.provider, &id, &ctx.hash(1))),
        EscrowError::SubmitTooLate
    );
    ctx.set_time(expired_at);
    ctx.escrow().claim_refund(&id);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
}

// ---------------------------------------------------------------------------
// 3.2 R9: fee math
// ---------------------------------------------------------------------------

#[test]
fn fee_rounds_down() {
    assert_eq!(compute_fee(999, 250), 24);
    assert_eq!(compute_fee(39, 250), 0);
    assert_eq!(compute_fee(10_000_000, 250), 250_000);
    assert_eq!(compute_fee(10_000_000, 0), 0);
}

#[test]
fn fee_at_maximum_bps_takes_the_whole_budget() {
    assert_eq!(compute_fee(10_000_000, 10_000), 10_000_000);
    assert_eq!(compute_fee(1, 10_000), 1);
}

#[test]
fn fee_never_overflows_and_is_exact_at_the_largest_budget() {
    let max = i128::MAX;
    assert_eq!(compute_fee(max, 0), 0);
    assert_eq!(compute_fee(max, 1), 17014118346046923173168730371588410);
    assert_eq!(compute_fee(max, 250), 4253529586511730793292182592897102643);
    assert_eq!(
        compute_fee(max, 5_000),
        85070591730234615865843651857942052863
    );
    assert_eq!(
        compute_fee(max, 9_999),
        170124169342123184808514134985512517316
    );
    assert_eq!(compute_fee(max, 10_000), max);
}

#[test]
fn fee_equals_floor_of_budget_times_bps_over_10_000() {
    let budgets = [
        0,
        1,
        2,
        39,
        999,
        9_999,
        10_000,
        10_001,
        19_999,
        123_456_789,
        10_000_000,
        i128::from(u64::MAX),
        i128::MAX / 10_000,
        i128::MAX / 10_000 - 1,
    ];
    for budget in budgets {
        for bps in 0..=BPS_DENOMINATOR {
            let naive = budget * i128::from(bps) / i128::from(BPS_DENOMINATOR);
            let fee = compute_fee(budget, bps);
            assert_eq!(fee, naive, "budget {budget} bps {bps}");
            assert!(fee <= budget);
        }
    }
}

#[test]
fn payout_plus_fee_always_equals_the_budget() {
    for (budget, bps) in [
        (999, 250),
        (39, 250),
        (10_000_000, 1),
        (7, 10_000),
        (1, 0),
        (i128::MAX, 1),
        (i128::MAX, 9_999),
        (i128::MAX, 10_000),
    ] {
        let fee = compute_fee(budget, bps);
        assert!(fee <= budget);
        assert_eq!((budget - fee) + fee, budget);
    }
}

// ---------------------------------------------------------------------------
// 3.3 R4: complete
// ---------------------------------------------------------------------------

#[test]
fn complete_with_zero_fee_pays_the_provider_in_full() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    let reason = ctx.hash(5);
    ctx.escrow().complete(&ctx.client, &id, &reason);
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - BUDGET);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
    assert_eq!(
        events,
        [JobCompleted {
            job_id: id,
            evaluator: ctx.client.clone(),
            reason,
            payout: BUDGET,
            fee: 0,
            auto_released: false,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn complete_with_a_fee_splits_between_provider_and_treasury() {
    let (ctx, treasury) = setup_with_fee(250);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.provider), 9_750_000);
    assert_eq!(ctx.balance(&treasury), 250_000);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(
        events,
        [JobCompleted {
            job_id: id,
            evaluator: ctx.client.clone(),
            reason: ctx.hash(5),
            payout: 9_750_000,
            fee: 250_000,
            auto_released: false,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn complete_at_max_fee_bps_splits_between_provider_and_treasury() {
    let (ctx, treasury) = setup_with_fee(MAX_FEE_BPS);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    let fee = compute_fee(BUDGET, MAX_FEE_BPS);
    assert_eq!(ctx.balance(&treasury), fee);
    assert_eq!(ctx.balance(&ctx.provider), BUDGET - fee);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
}

#[test]
fn the_largest_budget_settles_for_several_fee_rates() {
    for bps in [0u32, 1, 250, 500, MAX_FEE_BPS] {
        let (ctx, treasury) = setup_with_fee(bps);
        StellarAssetClient::new(&ctx.env, &ctx.token)
            .mint(&ctx.client, &(i128::MAX - CLIENT_FUNDS));
        let id = ctx.escrow().create_job(
            &ctx.client,
            &ctx.provider,
            &ctx.client,
            &LATE_EXPIRY,
            &ctx.desc("huge"),
            &None,
            &ctx.agent_id,
            &ctx.token,
            &i128::MAX,
        );
        ctx.escrow().fund(&ctx.client, &id, &i128::MAX, &MAX_FEE);
        ctx.submit(id);
        ctx.escrow().complete(&ctx.client, &id, &ctx.hash(1));
        let fee = compute_fee(i128::MAX, bps);
        assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
        assert_eq!(ctx.balance(&treasury), fee, "bps {bps}");
        assert_eq!(ctx.balance(&ctx.provider), i128::MAX - fee, "bps {bps}");
        assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    }
}

#[test]
fn only_the_evaluator_can_complete() {
    let ctx = setup();
    let evaluator = Address::generate(&ctx.env);
    let id = ctx.escrow().create_job(
        &ctx.client,
        &ctx.provider,
        &evaluator,
        &LATE_EXPIRY,
        &ctx.desc("job"),
        &None,
        &ctx.agent_id,
        &ctx.token,
        &BUDGET,
    );
    ctx.fund(id);
    ctx.submit(id);
    for caller in [&ctx.client, &ctx.provider] {
        assert_eq!(
            err(ctx.escrow().try_complete(caller, &id, &ctx.hash(1))),
            EscrowError::NotEvaluator
        );
    }
    ctx.escrow().complete(&evaluator, &id, &ctx.hash(1));
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
    assert_eq!(ctx.balance(&evaluator), 0);
}

#[test]
fn complete_requires_a_submitted_job() {
    let ctx = setup();
    let open = ctx.create(LATE_EXPIRY);
    let funded = ctx.funded(LATE_EXPIRY);
    for id in [open, funded] {
        assert_eq!(
            err(ctx.escrow().try_complete(&ctx.client, &id, &ctx.hash(1))),
            EscrowError::InvalidState
        );
    }
    let done = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().complete(&ctx.client, &done, &ctx.hash(1));
    assert_eq!(
        err(ctx.escrow().try_complete(&ctx.client, &done, &ctx.hash(1))),
        EscrowError::InvalidState
    );
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
}

#[test]
fn complete_still_works_after_the_approval_deadline() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.set_time(DEADLINE + 10);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(1));
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
}

// ---------------------------------------------------------------------------
// 3.4 R5: release
// ---------------------------------------------------------------------------

#[test]
fn silence_pays_the_provider_after_the_deadline() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.set_time(DEADLINE + 1);
    ctx.escrow().release(&id);
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
    assert_eq!(
        events,
        [JobCompleted {
            job_id: id,
            evaluator: ctx.client.clone(),
            reason: ctx.hash(0),
            payout: BUDGET,
            fee: 0,
            auto_released: true,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn release_works_exactly_at_the_deadline_and_not_before() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.set_time(DEADLINE - 1);
    assert_eq!(
        err(ctx.escrow().try_release(&id)),
        EscrowError::ApprovalWindowOpen
    );
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Submitted);
    ctx.set_time(DEADLINE);
    ctx.escrow().release(&id);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
}

#[test]
fn release_requires_a_submitted_job() {
    let ctx = setup();
    let open = ctx.create(LATE_EXPIRY);
    let funded = ctx.funded(LATE_EXPIRY);
    ctx.set_time(DEADLINE + 1);
    for id in [open, funded] {
        assert_eq!(
            err(ctx.escrow().try_release(&id)),
            EscrowError::InvalidState
        );
    }
}

#[test]
fn release_is_permissionless_and_pays_fee_and_provider_only() {
    let (ctx, treasury) = setup_with_fee(250);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.set_time(DEADLINE);
    ctx.env.mock_auths(&[]);
    let bystander = Address::generate(&ctx.env);
    ctx.escrow().release(&id);
    assert_eq!(ctx.balance(&bystander), 0);
    assert_eq!(ctx.balance(&ctx.provider), 9_750_000);
    assert_eq!(ctx.balance(&treasury), 250_000);
}

#[test]
fn a_submitted_job_past_expiry_settles_by_release_not_refund() {
    let ctx = setup();
    let expired_at = NOW + 10_000;
    let id = ctx.funded(expired_at);
    ctx.set_time(NOW + 100);
    ctx.submit(id);
    ctx.set_time(expired_at + 1);
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&id)),
        EscrowError::InvalidState
    );
    assert!(!ctx.escrow().is_expired(&id));
    ctx.escrow().release(&id);
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
}

// ---------------------------------------------------------------------------
// 3.5 R6 (Submitted): reject and finality
// ---------------------------------------------------------------------------

#[test]
fn evaluator_rejects_a_submitted_job_in_the_window_without_a_fee() {
    let (ctx, treasury) = setup_with_fee(250);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.set_time(DEADLINE - 1);
    ctx.escrow().reject(&ctx.client, &id, &ctx.hash(2));
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&treasury), 0);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(
        events,
        [JobRejected {
            job_id: id,
            rejector: ctx.client.clone(),
            reason: ctx.hash(2),
            from_state: JobState::Submitted,
            refunded: BUDGET,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn reject_after_the_window_is_closed() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    for t in [DEADLINE, DEADLINE + 100] {
        ctx.set_time(t);
        assert_eq!(
            err(ctx.escrow().try_reject(&ctx.client, &id, &ctx.hash(1))),
            EscrowError::ApprovalWindowClosed
        );
    }
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Submitted);
}

#[test]
fn provider_cannot_reject_a_submitted_job() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    assert_eq!(
        err(ctx.escrow().try_reject(&ctx.provider, &id, &ctx.hash(1))),
        EscrowError::NotEvaluator
    );
}

#[test]
fn rejected_is_final_for_every_function() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().reject(&ctx.client, &id, &ctx.hash(1));
    let e = ctx.escrow();
    assert_eq!(
        err(e.try_fund(&ctx.client, &id, &BUDGET, &MAX_FEE)),
        EscrowError::InvalidState
    );
    assert_eq!(
        err(e.try_submit(&ctx.provider, &id, &ctx.hash(1))),
        EscrowError::InvalidState
    );
    assert_eq!(
        err(e.try_complete(&ctx.client, &id, &ctx.hash(1))),
        EscrowError::InvalidState
    );
    assert_eq!(err(e.try_release(&id)), EscrowError::InvalidState);
    assert_eq!(
        err(e.try_reject(&ctx.client, &id, &ctx.hash(1))),
        EscrowError::InvalidState
    );
    assert_eq!(err(e.try_claim_refund(&id)), EscrowError::InvalidState);
}

// ---------------------------------------------------------------------------
// 3.6: allow-list removal never blocks settlement
// ---------------------------------------------------------------------------

#[test]
fn funded_jobs_settle_after_the_token_is_removed_from_the_allow_list() {
    let ctx = setup();
    let by_complete = ctx.submitted(LATE_EXPIRY);
    let by_release = ctx.submitted(LATE_EXPIRY);
    let by_reject = ctx.funded(LATE_EXPIRY);
    let by_refund = ctx.funded(NOW + 5_000);
    ctx.escrow()
        .set_token_allowed(&ctx.admin, &ctx.token, &false);
    assert!(!ctx.escrow().is_token_allowed(&ctx.token));
    ctx.escrow()
        .complete(&ctx.client, &by_complete, &ctx.hash(1));
    ctx.escrow().reject(&ctx.client, &by_reject, &ctx.hash(1));
    ctx.set_time(DEADLINE);
    ctx.escrow().release(&by_release);
    ctx.set_time(NOW + 5_000);
    ctx.escrow().claim_refund(&by_refund);
    assert_eq!(ctx.balance(&ctx.provider), 2 * BUDGET);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - 2 * BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

// ===========================================================================
// PR 4: admin, auth, TTL, non-goals
// ===========================================================================

use soroban_sdk::testutils::storage::{Instance as _, Persistent as _};
use soroban_sdk::testutils::{MockAuth, MockAuthInvoke};
use soroban_sdk::IntoVal;

// ---------------------------------------------------------------------------
// 4.1 A3: fee configuration
// ---------------------------------------------------------------------------

#[test]
fn admin_enables_a_fee_and_emits_fee_config_updated() {
    let (ctx, treasury) = setup_with_fee(0);
    let e = ctx.escrow();
    e.set_fee_bps(&ctx.admin, &250);
    let events = ctx.job_events();
    assert_eq!(e.fee_bps(), 250);
    assert_eq!(
        events,
        [FeeConfigUpdated {
            fee_bps: 250,
            treasury: Some(treasury),
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn admin_sets_the_treasury() {
    let ctx = setup();
    let e = ctx.escrow();
    let treasury = Address::generate(&ctx.env);
    e.set_treasury(&ctx.admin, &treasury);
    let events = ctx.job_events();
    assert_eq!(e.treasury(), Some(treasury.clone()));
    assert_eq!(
        events,
        [FeeConfigUpdated {
            fee_bps: 0,
            treasury: Some(treasury),
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
    // With a treasury in place a fee can now be enabled.
    e.set_fee_bps(&ctx.admin, &100);
    assert_eq!(e.fee_bps(), 100);
}

#[test]
fn fee_setter_validates_bps_and_treasury() {
    let ctx = setup();
    let e = ctx.escrow();
    assert_eq!(
        err(e.try_set_fee_bps(&ctx.admin, &100)),
        EscrowError::TreasuryNotSet
    );
    assert_eq!(
        err(e.try_set_fee_bps(&ctx.admin, &(MAX_FEE_BPS + 1))),
        EscrowError::InvalidFeeBps
    );
    assert_eq!(e.fee_bps(), 0);
    // Zero is always allowed, even without a treasury.
    e.set_fee_bps(&ctx.admin, &0);
    e.set_treasury(&ctx.admin, &Address::generate(&ctx.env));
    e.set_fee_bps(&ctx.admin, &MAX_FEE_BPS);
    assert_eq!(e.fee_bps(), MAX_FEE_BPS);
}

#[test]
fn a_later_fee_change_keeps_earlier_snapshots() {
    let (ctx, treasury) = setup_with_fee(0);
    let early = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().set_fee_bps(&ctx.admin, &250);
    let late = ctx.submitted(LATE_EXPIRY);
    assert_eq!(ctx.escrow().get_job(&early).fee_bps, 0);
    assert_eq!(ctx.escrow().get_job(&late).fee_bps, 250);
    ctx.escrow().complete(&ctx.client, &early, &ctx.hash(1));
    assert_eq!(ctx.balance(&treasury), 0);
    ctx.escrow().complete(&ctx.client, &late, &ctx.hash(1));
    assert_eq!(ctx.balance(&treasury), 250_000);
}

// ---------------------------------------------------------------------------
// 4.2 A4: limits
// ---------------------------------------------------------------------------

#[test]
fn admin_updates_limits_and_emits_limits_updated() {
    let ctx = setup();
    let e = ctx.escrow();
    e.set_max_expiry(&ctx.admin, &172_800);
    assert_eq!(
        ctx.job_events(),
        [LimitsUpdated {
            max_expiry: 172_800,
            approval_window: APPROVAL_WINDOW,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
    e.set_approval_window(&ctx.admin, &7_200);
    let events = ctx.job_events();
    assert_eq!(e.max_expiry(), 172_800);
    assert_eq!(e.approval_window(), 7_200);
    assert_eq!(
        events,
        [LimitsUpdated {
            max_expiry: 172_800,
            approval_window: 7_200,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn limits_are_validated_against_each_other() {
    let ctx = setup();
    let e = ctx.escrow();
    assert_eq!(
        err(e.try_set_approval_window(&ctx.admin, &0)),
        EscrowError::InvalidDuration
    );
    assert_eq!(
        err(e.try_set_approval_window(&ctx.admin, &MAX_EXPIRY)),
        EscrowError::InvalidDuration
    );
    assert_eq!(
        err(e.try_set_max_expiry(&ctx.admin, &0)),
        EscrowError::InvalidDuration
    );
    assert_eq!(
        err(e.try_set_max_expiry(&ctx.admin, &APPROVAL_WINDOW)),
        EscrowError::InvalidDuration
    );
    assert_eq!(e.max_expiry(), MAX_EXPIRY);
    assert_eq!(e.approval_window(), APPROVAL_WINDOW);
}

#[test]
fn lowering_max_expiry_affects_only_new_jobs() {
    let ctx = setup();
    let old = ctx.create(NOW + 50_000);
    ctx.escrow().set_max_expiry(&ctx.admin, &10_000);
    assert_eq!(ctx.escrow().get_job(&old).expired_at, NOW + 50_000);
    assert_eq!(
        ctx.try_create(
            &ctx.provider,
            NOW + 10_001,
            None,
            ctx.agent_id,
            &ctx.token,
            BUDGET
        ),
        Err(EscrowError::InvalidExpiry)
    );
    assert_eq!(
        ctx.try_create(
            &ctx.provider,
            NOW + 10_000,
            None,
            ctx.agent_id,
            &ctx.token,
            BUDGET
        ),
        Ok(2)
    );
}

#[test]
fn a_window_change_does_not_move_a_stored_deadline() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().set_approval_window(&ctx.admin, &1_800);
    assert_eq!(ctx.escrow().get_job(&id).approval_deadline, DEADLINE);
    ctx.set_time(DEADLINE - 1);
    assert_eq!(
        err(ctx.escrow().try_release(&id)),
        EscrowError::ApprovalWindowOpen
    );
    // The next submission uses the new window.
    let next = ctx.funded(LATE_EXPIRY);
    ctx.submit(next);
    assert_eq!(
        ctx.escrow().get_job(&next).approval_deadline,
        DEADLINE - 1 + 1_800
    );
}

// ---------------------------------------------------------------------------
// 4.3 A5 / A6: registry binding and admin handover
// ---------------------------------------------------------------------------

#[test]
fn rebinding_the_registry_emits_an_event_and_updates_the_getter() {
    let ctx = setup();
    let other = deploy_registry(&ctx.env);
    ctx.escrow().set_identity_registry(&ctx.admin, &other);
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().identity_registry(), other);
    assert_eq!(
        events,
        [RegistryUpdated { registry: other }.to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn new_jobs_resolve_the_wallet_from_the_rebound_registry() {
    let ctx = setup();
    let other_id = deploy_registry(&ctx.env);
    let other = IdentityRegistryContractClient::new(&ctx.env, &other_id);
    let new_provider = Address::generate(&ctx.env);
    let new_agent = other.register(&new_provider);
    ctx.escrow().set_identity_registry(&ctx.admin, &other_id);
    // Agent 0 now resolves to the rebound registry's wallet, not the old provider.
    assert_eq!(
        ctx.try_create(
            &ctx.provider,
            NOW + 100,
            None,
            new_agent,
            &ctx.token,
            BUDGET
        ),
        Err(EscrowError::ProviderMismatch)
    );
    assert_eq!(
        ctx.try_create(
            &new_provider,
            NOW + 100,
            None,
            new_agent,
            &ctx.token,
            BUDGET
        ),
        Ok(1)
    );
}

#[test]
fn in_flight_jobs_settle_with_no_registry_call() {
    let ctx = setup();
    let by_complete = ctx.submitted(LATE_EXPIRY);
    let by_release = ctx.submitted(LATE_EXPIRY);
    let by_reject = ctx.funded(LATE_EXPIRY);
    let by_refund = ctx.funded(NOW + 5_000);
    // Rebind to an address with no contract behind it: any registry call would trap.
    let dead = Address::generate(&ctx.env);
    ctx.escrow().set_identity_registry(&ctx.admin, &dead);
    ctx.escrow()
        .complete(&ctx.client, &by_complete, &ctx.hash(1));
    ctx.escrow().reject(&ctx.client, &by_reject, &ctx.hash(1));
    ctx.set_time(DEADLINE);
    ctx.escrow().release(&by_release);
    ctx.set_time(NOW + 5_000);
    ctx.escrow().claim_refund(&by_refund);
    assert_eq!(ctx.balance(&ctx.provider), 2 * BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    // Only new jobs are affected: creation fails and nothing is stored.
    let count = ctx.escrow().job_count();
    assert!(ctx
        .escrow()
        .try_create_job(
            &ctx.client,
            &ctx.provider,
            &ctx.client,
            &(NOW + 6_000),
            &ctx.desc("job"),
            &None,
            &ctx.agent_id,
            &ctx.token,
            &BUDGET,
        )
        .is_err());
    assert_eq!(ctx.escrow().job_count(), count);
}

#[test]
fn admin_handover_moves_authority() {
    let ctx = setup();
    let new_admin = Address::generate(&ctx.env);
    ctx.escrow().set_admin(&ctx.admin, &new_admin);
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().admin(), new_admin);
    assert_eq!(
        events,
        [AdminChanged {
            old_admin: ctx.admin.clone(),
            new_admin: new_admin.clone(),
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
    assert_eq!(
        err(ctx.escrow().try_set_fee_bps(&ctx.admin, &0)),
        EscrowError::NotAdmin
    );
    ctx.escrow().set_fee_bps(&new_admin, &0);
}

// ---------------------------------------------------------------------------
// 4.4: explicit authorization
// ---------------------------------------------------------------------------

#[test]
fn every_setter_rejects_a_non_admin() {
    let ctx = setup();
    let e = ctx.escrow();
    let x = Address::generate(&ctx.env);
    assert_eq!(
        err(e.try_set_token_allowed(&x, &ctx.token, &false)),
        EscrowError::NotAdmin
    );
    assert_eq!(err(e.try_set_fee_bps(&x, &0)), EscrowError::NotAdmin);
    assert_eq!(err(e.try_set_treasury(&x, &x)), EscrowError::NotAdmin);
    assert_eq!(
        err(e.try_set_max_expiry(&x, &MAX_EXPIRY)),
        EscrowError::NotAdmin
    );
    assert_eq!(
        err(e.try_set_approval_window(&x, &APPROVAL_WINDOW)),
        EscrowError::NotAdmin
    );
    assert_eq!(
        err(e.try_set_identity_registry(&x, &ctx.registry_id)),
        EscrowError::NotAdmin
    );
    assert_eq!(err(e.try_set_admin(&x, &x)), EscrowError::NotAdmin);
    assert_eq!(e.admin(), ctx.admin);
    assert!(e.is_token_allowed(&ctx.token));
    assert!(ctx.job_events().events().is_empty());
}

#[test]
fn every_setter_needs_the_admin_signature() {
    let ctx = setup();
    let e = ctx.escrow();
    ctx.env.mock_auths(&[]);
    let a = &ctx.admin;
    assert!(e.try_set_token_allowed(a, &ctx.token, &false).is_err());
    assert!(e.try_set_fee_bps(a, &0).is_err());
    assert!(e.try_set_treasury(a, a).is_err());
    assert!(e.try_set_max_expiry(a, &MAX_EXPIRY).is_err());
    assert!(e.try_set_approval_window(a, &APPROVAL_WINDOW).is_err());
    assert!(e.try_set_identity_registry(a, &ctx.registry_id).is_err());
    assert!(e.try_set_admin(a, a).is_err());
    assert!(e.is_token_allowed(&ctx.token));
}

#[test]
fn fund_needs_the_client_auth_including_the_token_transfer() {
    let ctx = setup();
    let id = ctx.create(LATE_EXPIRY);
    let transfer = MockAuthInvoke {
        contract: &ctx.token,
        fn_name: "transfer",
        args: (&ctx.client, &ctx.escrow_id, &BUDGET).into_val(&ctx.env),
        sub_invokes: &[],
    };
    let fund_args = (&ctx.client, &id, &BUDGET, &MAX_FEE).into_val(&ctx.env);
    // Authorizing only the escrow call is not enough: the transfer is unauthorized.
    ctx.env.mock_auths(&[MockAuth {
        address: &ctx.client,
        invoke: &MockAuthInvoke {
            contract: &ctx.escrow_id,
            fn_name: "fund",
            args: fund_args,
            sub_invokes: &[],
        },
    }]);
    assert!(ctx
        .escrow()
        .try_fund(&ctx.client, &id, &BUDGET, &MAX_FEE)
        .is_err());
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    // With the transfer sub-invocation authorized the call succeeds.
    ctx.env.mock_auths(&[MockAuth {
        address: &ctx.client,
        invoke: &MockAuthInvoke {
            contract: &ctx.escrow_id,
            fn_name: "fund",
            args: (&ctx.client, &id, &BUDGET, &MAX_FEE).into_val(&ctx.env),
            sub_invokes: &[transfer],
        },
    }]);
    ctx.escrow().fund(&ctx.client, &id, &BUDGET, &MAX_FEE);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Funded);
}

#[test]
fn state_changing_calls_need_their_caller_signature() {
    let ctx = setup();
    let id = ctx.funded(LATE_EXPIRY);
    ctx.env.mock_auths(&[]);
    let e = ctx.escrow();
    assert!(e.try_submit(&ctx.provider, &id, &ctx.hash(1)).is_err());
    assert!(e.try_reject(&ctx.client, &id, &ctx.hash(1)).is_err());
    assert_eq!(e.get_job(&id).state, JobState::Funded);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
}

// ---------------------------------------------------------------------------
// 4.5 R11: TTL
// ---------------------------------------------------------------------------

fn job_ttl(ctx: &Ctx, id: u64) -> u32 {
    ctx.env.as_contract(&ctx.escrow_id, || {
        ctx.env.storage().persistent().get_ttl(&DataKey::Job(id))
    })
}

fn instance_ttl(ctx: &Ctx) -> u32 {
    ctx.env
        .as_contract(&ctx.escrow_id, || ctx.env.storage().instance().get_ttl())
}

/// Moves the ledger forward until entries written earlier are below the threshold.
fn age_ledger(ctx: &Ctx) {
    let info = ctx.env.ledger().get();
    ctx.env
        .ledger()
        .set_sequence_number(info.sequence_number + (TTL_BUMP - TTL_THRESHOLD) + 100);
}

#[test]
fn transitions_bump_the_job_and_instance_ttl() {
    let ctx = setup();
    let id = ctx.create(LATE_EXPIRY);
    assert_eq!(job_ttl(&ctx, id), TTL_BUMP);
    age_ledger(&ctx);
    assert!(job_ttl(&ctx, id) < TTL_THRESHOLD);
    assert!(instance_ttl(&ctx) < TTL_THRESHOLD);
    ctx.fund(id);
    assert_eq!(job_ttl(&ctx, id), TTL_BUMP);
    assert_eq!(instance_ttl(&ctx), TTL_BUMP);
}

#[test]
fn extend_ttl_keeps_terminal_jobs_readable() {
    let ctx = setup();
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(1));
    age_ledger(&ctx);
    assert!(job_ttl(&ctx, id) < TTL_THRESHOLD);
    ctx.escrow().extend_ttl(&id);
    assert_eq!(job_ttl(&ctx, id), TTL_BUMP);
    assert_eq!(instance_ttl(&ctx), TTL_BUMP);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
}

#[test]
fn extend_ttl_for_an_unknown_job_only_bumps_the_instance() {
    let ctx = setup();
    age_ledger(&ctx);
    assert!(instance_ttl(&ctx) < TTL_THRESHOLD);
    ctx.escrow().extend_ttl(&99);
    assert_eq!(instance_ttl(&ctx), TTL_BUMP);
}

#[test]
fn allow_list_entries_are_bumped_when_they_are_used() {
    let ctx = setup();
    let key = DataKey::AllowedToken(ctx.token.clone());
    let allow_ttl = || {
        ctx.env.as_contract(&ctx.escrow_id, || {
            ctx.env.storage().persistent().get_ttl(&key)
        })
    };
    assert_eq!(allow_ttl(), TTL_BUMP);
    age_ledger(&ctx);
    assert!(allow_ttl() < TTL_THRESHOLD);
    ctx.create(LATE_EXPIRY + 50_000);
    assert_eq!(allow_ttl(), TTL_BUMP);
}

// ---------------------------------------------------------------------------
// 4.6 R13 / A6: testable absences
// ---------------------------------------------------------------------------

#[test]
fn contract_exports_exactly_the_specified_functions() {
    let source = include_str!("lib.rs");
    let mut exported: std::vec::Vec<&str> = source
        .lines()
        .filter_map(|line| line.strip_prefix("    pub fn "))
        .filter_map(|rest| rest.split('(').next())
        .collect();
    exported.sort_unstable();
    let mut expected = std::vec![
        "__constructor",
        "set_token_allowed",
        "create_job",
        "fund",
        "submit",
        "complete",
        "release",
        "reject",
        "claim_refund",
        "get_job",
        "job_count",
        "is_expired",
        "is_token_allowed",
        "set_fee_bps",
        "set_treasury",
        "set_max_expiry",
        "set_approval_window",
        "set_identity_registry",
        "set_admin",
        "admin",
        "identity_registry",
        "treasury",
        "fee_bps",
        "max_expiry",
        "approval_window",
        "version",
        "extend_ttl",
        "withdraw",
        "claimable",
    ];
    expected.sort_unstable();
    // No dispute, arbiter, pause, split, set_budget, set_provider, sweep or upgrade entry point.
    assert_eq!(exported, expected);
}

// ===========================================================================
// Review fixes: pull payment, fee cap at fund, fee-free refunds, TTL
// ===========================================================================

/// Test-only token whose `transfer` fails for blocked recipients, standing in for a
/// Stellar asset whose holder has no trustline or is frozen. Mode 1 fails with a host
/// panic, mode 2 with a typed contract error; 0 unblocks.
#[contracttype]
#[derive(Clone)]
enum MockKey {
    Balance(Address),
    Blocked(Address),
}

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
#[repr(u32)]
enum MockError {
    Blocked = 1,
}

#[contract]
struct MockToken;

#[contractimpl]
impl MockToken {
    pub fn mint(e: Env, to: Address, amount: i128) {
        let key = MockKey::Balance(to);
        let current: i128 = e.storage().instance().get(&key).unwrap_or(0);
        e.storage().instance().set(&key, &(current + amount));
    }

    pub fn set_blocked(e: Env, who: Address, mode: u32) {
        e.storage().instance().set(&MockKey::Blocked(who), &mode);
    }

    pub fn balance(e: Env, id: Address) -> i128 {
        e.storage()
            .instance()
            .get(&MockKey::Balance(id))
            .unwrap_or(0)
    }

    pub fn transfer(e: Env, from: Address, to: Address, amount: i128) {
        from.require_auth();
        let mode: u32 = e
            .storage()
            .instance()
            .get(&MockKey::Blocked(to.clone()))
            .unwrap_or(0);
        match mode {
            1 => panic!("no trustline"),
            2 => panic_with_error!(&e, MockError::Blocked),
            _ => {}
        }
        let from_balance = Self::balance(e.clone(), from.clone());
        assert!(from_balance >= amount, "insufficient balance");
        e.storage()
            .instance()
            .set(&MockKey::Balance(from), &(from_balance - amount));
        let to_balance = Self::balance(e.clone(), to.clone());
        e.storage()
            .instance()
            .set(&MockKey::Balance(to), &(to_balance + amount));
    }
}

impl Ctx {
    fn mock(&self) -> MockTokenClient<'_> {
        MockTokenClient::new(&self.env, &self.token)
    }

    fn claimable(&self, who: &Address) -> i128 {
        self.escrow().claimable(who, &self.token)
    }
}

/// Like `setup_with_fee`, but the job token is the failing mock token.
fn setup_mock(fee_bps: u32) -> (Ctx, Address) {
    let (ctx, treasury) = setup_with_fee(fee_bps);
    let token = ctx.env.register(MockToken, ());
    let ctx = Ctx { token, ..ctx };
    ctx.mock().mint(&ctx.client, &CLIENT_FUNDS);
    ctx.escrow()
        .set_token_allowed(&ctx.admin, &ctx.token, &true);
    (ctx, treasury)
}

fn deferred(
    ctx: &Ctx,
    job_id: u64,
    recipient: &Address,
    amount: i128,
) -> soroban_sdk::xdr::ContractEvent {
    PayoutDeferred {
        job_id,
        recipient: recipient.clone(),
        token: ctx.token.clone(),
        amount,
    }
    .to_xdr(&ctx.env, &ctx.escrow_id)
}

fn completed(
    ctx: &Ctx,
    job_id: u64,
    payout: i128,
    fee: i128,
    reason: BytesN<32>,
    auto: bool,
) -> soroban_sdk::xdr::ContractEvent {
    JobCompleted {
        job_id,
        evaluator: ctx.client.clone(),
        reason,
        payout,
        fee,
        auto_released: auto,
    }
    .to_xdr(&ctx.env, &ctx.escrow_id)
}

// ---------------------------------------------------------------------------
// Pull payment: provider payout
// ---------------------------------------------------------------------------

#[test]
fn complete_defers_the_payout_when_the_provider_cannot_receive() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    assert_eq!(ctx.claimable(&ctx.provider), BUDGET);
    assert_eq!(
        events,
        [
            deferred(&ctx, id, &ctx.provider, BUDGET),
            completed(&ctx, id, BUDGET, 0, ctx.hash(5), false),
        ]
    );
}

#[test]
fn release_defers_the_payout_when_the_provider_cannot_receive() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.set_time(DEADLINE);
    ctx.escrow().release(&id);
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    assert_eq!(ctx.claimable(&ctx.provider), BUDGET);
    assert_eq!(
        events,
        [
            deferred(&ctx, id, &ctx.provider, BUDGET),
            completed(&ctx, id, BUDGET, 0, ctx.hash(0), true),
        ]
    );
}

#[test]
fn both_failure_layers_fall_back_to_the_claimable_balance() {
    for mode in [1u32, 2] {
        let (ctx, _treasury) = setup_mock(0);
        let id = ctx.submitted(LATE_EXPIRY);
        ctx.mock().set_blocked(&ctx.provider, &mode);
        ctx.escrow().complete(&ctx.client, &id, &ctx.hash(1));
        assert_eq!(
            ctx.escrow().get_job(&id).state,
            JobState::Completed,
            "mode {mode}"
        );
        assert_eq!(ctx.claimable(&ctx.provider), BUDGET, "mode {mode}");
    }
}

#[test]
fn a_working_payout_is_never_deferred() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
    assert_eq!(ctx.claimable(&ctx.provider), 0);
    assert_eq!(events, [completed(&ctx, id, BUDGET, 0, ctx.hash(5), false)]);
}

#[test]
fn withdraw_pays_the_deferred_amount_once_the_provider_can_receive() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    ctx.mock().set_blocked(&ctx.provider, &0);
    let paid = ctx.escrow().withdraw(&ctx.provider, &ctx.token);
    let events = ctx.job_events();
    assert_eq!(paid, BUDGET);
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.claimable(&ctx.provider), 0);
    assert_eq!(
        events,
        [PayoutWithdrawn {
            recipient: ctx.provider.clone(),
            token: ctx.token.clone(),
            amount: BUDGET,
        }
        .to_xdr(&ctx.env, &ctx.escrow_id)]
    );
}

#[test]
fn withdraw_twice_is_refused() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    ctx.mock().set_blocked(&ctx.provider, &0);
    ctx.escrow().withdraw(&ctx.provider, &ctx.token);
    assert_eq!(
        err(ctx.escrow().try_withdraw(&ctx.provider, &ctx.token)),
        EscrowError::NothingToWithdraw
    );
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
}

#[test]
fn withdraw_without_a_balance_is_refused() {
    let (ctx, _treasury) = setup_mock(0);
    let stranger = Address::generate(&ctx.env);
    assert_eq!(ctx.claimable(&stranger), 0);
    assert_eq!(
        err(ctx.escrow().try_withdraw(&stranger, &ctx.token)),
        EscrowError::NothingToWithdraw
    );
}

#[test]
fn a_failing_withdraw_reverts_and_the_balance_stays_claimable() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    assert!(ctx
        .escrow()
        .try_withdraw(&ctx.provider, &ctx.token)
        .is_err());
    assert_eq!(ctx.claimable(&ctx.provider), BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    ctx.mock().set_blocked(&ctx.provider, &0);
    assert_eq!(ctx.escrow().withdraw(&ctx.provider, &ctx.token), BUDGET);
}

#[test]
fn withdraw_needs_the_callers_signature() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    ctx.mock().set_blocked(&ctx.provider, &0);
    ctx.env.mock_auths(&[]);
    assert!(ctx
        .escrow()
        .try_withdraw(&ctx.provider, &ctx.token)
        .is_err());
    assert_eq!(ctx.claimable(&ctx.provider), BUDGET);
    assert_eq!(ctx.balance(&ctx.provider), 0);
}

#[test]
fn nobody_can_withdraw_for_another_recipient() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    ctx.mock().set_blocked(&ctx.provider, &0);
    // Any other caller only touches their own (empty) balance.
    assert_eq!(
        err(ctx.escrow().try_withdraw(&ctx.client, &ctx.token)),
        EscrowError::NothingToWithdraw
    );
    assert_eq!(ctx.claimable(&ctx.provider), BUDGET);
}

#[test]
fn withdraw_works_after_the_token_leaves_the_allow_list() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    ctx.escrow()
        .set_token_allowed(&ctx.admin, &ctx.token, &false);
    ctx.mock().set_blocked(&ctx.provider, &0);
    assert_eq!(ctx.escrow().withdraw(&ctx.provider, &ctx.token), BUDGET);
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
}

#[test]
fn deferred_payouts_accumulate_per_recipient_and_token() {
    let (ctx, _treasury) = setup_mock(0);
    let first = ctx.submitted(LATE_EXPIRY);
    let second = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &first, &ctx.hash(1));
    ctx.escrow().complete(&ctx.client, &second, &ctx.hash(1));
    assert_eq!(ctx.claimable(&ctx.provider), 2 * BUDGET);
    let other_token = Address::generate(&ctx.env);
    assert_eq!(ctx.escrow().claimable(&ctx.provider, &other_token), 0);
    ctx.mock().set_blocked(&ctx.provider, &0);
    assert_eq!(ctx.escrow().withdraw(&ctx.provider, &ctx.token), 2 * BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

#[test]
fn a_claimable_entry_is_bumped_and_kept_alive() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    let key = DataKey::Claimable(ctx.provider.clone(), ctx.token.clone());
    let ttl = ctx.env.as_contract(&ctx.escrow_id, || {
        ctx.env.storage().persistent().get_ttl(&key)
    });
    assert_eq!(ttl, TTL_BUMP);
}

// ---------------------------------------------------------------------------
// Pull payment: treasury fee
// ---------------------------------------------------------------------------

#[test]
fn a_failing_treasury_transfer_still_pays_the_provider() {
    let (ctx, treasury) = setup_mock(250);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&treasury, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
    assert_eq!(ctx.balance(&ctx.provider), 9_750_000);
    assert_eq!(ctx.balance(&treasury), 0);
    assert_eq!(ctx.claimable(&treasury), 250_000);
    assert_eq!(ctx.claimable(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), 250_000);
    assert_eq!(
        ctx.balance(&ctx.provider) + ctx.balance(&treasury) + ctx.balance(&ctx.escrow_id),
        BUDGET
    );
    assert_eq!(
        events,
        [
            deferred(&ctx, id, &treasury, 250_000),
            completed(&ctx, id, 9_750_000, 250_000, ctx.hash(5), false),
        ]
    );
    ctx.mock().set_blocked(&treasury, &0);
    assert_eq!(ctx.escrow().withdraw(&treasury, &ctx.token), 250_000);
    assert_eq!(ctx.balance(&treasury), 250_000);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.claimable(&treasury), 0);
}

#[test]
fn provider_and_treasury_payouts_are_independent() {
    let (ctx, treasury) = setup_mock(250);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &2);
    ctx.mock().set_blocked(&treasury, &1);
    ctx.set_time(DEADLINE);
    ctx.escrow().release(&id);
    let events = ctx.job_events();
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Completed);
    assert_eq!(ctx.claimable(&ctx.provider), 9_750_000);
    assert_eq!(ctx.claimable(&treasury), 250_000);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    assert_eq!(
        events,
        [
            deferred(&ctx, id, &ctx.provider, 9_750_000),
            deferred(&ctx, id, &treasury, 250_000),
            completed(&ctx, id, 9_750_000, 250_000, ctx.hash(0), true),
        ]
    );
}

#[test]
fn a_failing_provider_transfer_still_pays_the_treasury() {
    let (ctx, treasury) = setup_mock(250);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.escrow().complete(&ctx.client, &id, &ctx.hash(5));
    assert_eq!(ctx.balance(&treasury), 250_000);
    assert_eq!(ctx.claimable(&ctx.provider), 9_750_000);
    assert_eq!(ctx.balance(&ctx.escrow_id), 9_750_000);
}

// ---------------------------------------------------------------------------
// Deferred payouts never open a refund path (ADR-0005 D4)
// ---------------------------------------------------------------------------

#[test]
fn the_client_cannot_reclaim_a_job_whose_payout_was_deferred() {
    let (ctx, _treasury) = setup_mock(0);
    let id = ctx.submitted(NOW + 10_000);
    ctx.mock().set_blocked(&ctx.provider, &1);
    ctx.set_time(DEADLINE);
    ctx.escrow().release(&id);
    ctx.set_time(NOW + 10_000 + 1);
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&id)),
        EscrowError::InvalidState
    );
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - BUDGET);
    assert_eq!(ctx.claimable(&ctx.provider), BUDGET);
}

#[test]
fn the_client_cannot_reclaim_a_submitted_job_past_expiry() {
    let ctx = setup();
    let expired_at = NOW + 10_000;
    let id = ctx.submitted(expired_at);
    ctx.set_time(expired_at + 1);
    assert_eq!(
        err(ctx.escrow().try_claim_refund(&id)),
        EscrowError::InvalidState
    );
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Submitted);
}

// ---------------------------------------------------------------------------
// fund: max_fee_bps guard
// ---------------------------------------------------------------------------

#[test]
fn fund_accepts_a_fee_at_or_below_the_clients_maximum() {
    let (ctx, _treasury) = setup_with_fee(250);
    for (max, expected_id) in [(250u32, 1u64), (251, 2), (10_000, 3)] {
        let id = ctx.create(NOW + 1_000);
        assert_eq!(id, expected_id);
        ctx.escrow().fund(&ctx.client, &id, &BUDGET, &max);
        assert_eq!(ctx.escrow().get_job(&id).state, JobState::Funded);
        assert_eq!(ctx.escrow().get_job(&id).fee_bps, 250);
    }
}

#[test]
fn fund_rejects_a_fee_above_the_clients_maximum() {
    let (ctx, _treasury) = setup_with_fee(250);
    let id = ctx.create(NOW + 1_000);
    for max in [0u32, 100, 249] {
        assert_eq!(
            err(ctx.escrow().try_fund(&ctx.client, &id, &BUDGET, &max)),
            EscrowError::FeeExceedsMax,
            "max {max}"
        );
    }
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Open);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
}

#[test]
fn a_fee_raised_before_fund_cannot_divert_the_budget() {
    let (ctx, treasury) = setup_with_fee(0);
    let id = ctx.create(NOW + 1_000);
    ctx.escrow().set_fee_bps(&ctx.admin, &MAX_FEE_BPS);
    assert_eq!(
        err(ctx.escrow().try_fund(&ctx.client, &id, &BUDGET, &0)),
        EscrowError::FeeExceedsMax
    );
    assert_eq!(ctx.balance(&treasury), 0);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
}

#[test]
fn zero_maximum_accepts_a_zero_fee() {
    let ctx = setup();
    let id = ctx.create(NOW + 1_000);
    ctx.escrow().fund(&ctx.client, &id, &BUDGET, &0);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Funded);
    assert_eq!(ctx.escrow().get_job(&id).fee_bps, 0);
}

// ---------------------------------------------------------------------------
// D7: the fee is charged only on completion
// ---------------------------------------------------------------------------

#[test]
fn claim_refund_returns_the_full_budget_even_with_a_fee() {
    let (ctx, treasury) = setup_with_fee(250);
    let expired_at = NOW + 1_000;
    let id = ctx.funded(expired_at);
    ctx.set_time(expired_at);
    ctx.escrow().claim_refund(&id);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&treasury), 0);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

#[test]
fn rejecting_a_funded_job_refunds_in_full_even_with_a_fee() {
    let (ctx, treasury) = setup_with_fee(250);
    let id = ctx.funded(LATE_EXPIRY);
    ctx.escrow().reject(&ctx.client, &id, &ctx.hash(1));
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&treasury), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

#[test]
fn rejecting_a_submitted_job_leaves_the_contract_empty_even_with_a_fee() {
    let (ctx, treasury) = setup_with_fee(250);
    let id = ctx.submitted(LATE_EXPIRY);
    ctx.escrow().reject(&ctx.client, &id, &ctx.hash(1));
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&treasury), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

#[test]
fn cancelling_an_open_job_moves_no_funds_even_with_a_fee() {
    let (ctx, treasury) = setup_with_fee(250);
    let id = ctx.create(LATE_EXPIRY);
    ctx.escrow().reject(&ctx.client, &id, &ctx.hash(1));
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&treasury), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

// ---------------------------------------------------------------------------
// TTL: extend_ttl keeps a long-lived job alive
// ---------------------------------------------------------------------------

#[test]
fn extend_ttl_keeps_a_long_funded_job_alive() {
    let ctx = setup();
    let id = ctx.funded(LATE_EXPIRY);
    age_ledger(&ctx);
    assert!(job_ttl(&ctx, id) < TTL_THRESHOLD);
    ctx.escrow().extend_ttl(&id);
    assert_eq!(job_ttl(&ctx, id), TTL_BUMP);
    assert_eq!(ctx.escrow().get_job(&id).state, JobState::Funded);
}
