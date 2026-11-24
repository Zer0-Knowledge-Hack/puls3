//! ADR-0011: budget-bearing escrow and agent-initiated subcontracting (#334).
//!
//! The consumer funds `budget + reserve` with `fund_with_reserve`; the parent's
//! provider (agent A) draws child jobs from the reserve with `create_child_job`.

use super::*;

const RESERVE: i128 = 20_000_000;
const CHILD_BUDGET: i128 = 5_000_000;
/// Long enough for two levels of children inside `MAX_EXPIRY`.
const PARENT_EXPIRY: u64 = NOW + 80_000;
/// The latest expiry a child of a `PARENT_EXPIRY` job may have.
const CHILD_EXPIRY: u64 = PARENT_EXPIRY - APPROVAL_WINDOW - CHILD_EXPIRY_MARGIN;
/// The latest expiry a grandchild may have.
const GRANDCHILD_EXPIRY: u64 = CHILD_EXPIRY - APPROVAL_WINDOW - CHILD_EXPIRY_MARGIN;

/// A registered agent: its registry wallet and id.
struct Agent {
    wallet: Address,
    id: u32,
}

impl Ctx {
    fn agent(&self) -> Agent {
        let wallet = Address::generate(&self.env);
        let id = self.registry().register(&wallet);
        Agent { wallet, id }
    }

    /// Agent A as stored by `setup`.
    fn agent_a(&self) -> Agent {
        Agent {
            wallet: self.provider.clone(),
            id: self.agent_id,
        }
    }

    /// Creates the consumer's job with A as provider and funds it with a reserve.
    fn reserved(&self, reserve: i128) -> u64 {
        let id = self.create(PARENT_EXPIRY);
        self.escrow()
            .fund_with_reserve(&self.client, &id, &BUDGET, &reserve, &MAX_FEE);
        id
    }

    #[allow(clippy::too_many_arguments)]
    fn try_child(
        &self,
        caller: &Address,
        parent: u64,
        provider: &Agent,
        expired_at: u64,
        budget: i128,
        reserve: i128,
    ) -> Result<u64, EscrowError> {
        match self.escrow().try_create_child_job(
            caller,
            &parent,
            &provider.wallet,
            caller,
            &expired_at,
            &self.desc("subtask"),
            &provider.id,
            &budget,
            &reserve,
        ) {
            Ok(Ok(id)) => Ok(id),
            Err(Ok(e)) => Err(e),
            other => panic!("unexpected host result: {other:?}"),
        }
    }

    /// `caller` (the parent's provider) hires `provider`, evaluating it itself.
    fn child(
        &self,
        caller: &Address,
        parent: u64,
        provider: &Agent,
        expired_at: u64,
        budget: i128,
        reserve: i128,
    ) -> u64 {
        self.try_child(caller, parent, provider, expired_at, budget, reserve)
            .expect("child job")
    }

    fn job(&self, id: u64) -> Job {
        self.escrow().get_job(&id)
    }

    /// Funds held by non-terminal jobs: `budget + reserve` each (invariant 3).
    fn held(&self, ids: &[u64]) -> i128 {
        ids.iter()
            .map(|id| self.job(*id))
            .filter(|j| matches!(j.state, JobState::Funded | JobState::Submitted))
            .map(|j| j.budget + j.reserve)
            .sum()
    }

    fn assert_conserved(&self, ids: &[u64], claimants: &[&Address]) {
        let claimable: i128 = claimants.iter().map(|who| self.claimable(who)).sum();
        assert_eq!(
            self.balance(&self.escrow_id),
            self.held(ids) + claimable,
            "escrow balance must equal held funds plus claimable balances"
        );
    }
}

fn returned(
    ctx: &Ctx,
    parent_job_id: u64,
    child_job_id: u64,
    amount: i128,
    to_client: bool,
) -> soroban_sdk::xdr::ContractEvent {
    ReserveReturned {
        parent_job_id,
        child_job_id,
        amount,
        to_client,
    }
    .to_xdr(&ctx.env, &ctx.escrow_id)
}

fn refunded(
    ctx: &Ctx,
    job_id: u64,
    amount: i128,
    deferred: bool,
) -> soroban_sdk::xdr::ContractEvent {
    ReserveRefunded {
        job_id,
        client: ctx.client.clone(),
        amount,
        deferred,
    }
    .to_xdr(&ctx.env, &ctx.escrow_id)
}

// ---------------------------------------------------------------------------
// Constants and error codes
// ---------------------------------------------------------------------------

#[test]
fn subcontract_constants_match_the_adr() {
    assert_eq!(CHILD_EXPIRY_MARGIN, 600);
    assert_eq!(MAX_DEPTH, 2);
}

#[test]
fn subcontract_error_codes_are_appended_and_stable() {
    assert_eq!(EscrowError::ReserveExceeded as u32, 124);
    assert_eq!(EscrowError::ChildrenOpen as u32, 125);
    assert_eq!(EscrowError::DepthExceeded as u32, 126);
    assert_eq!(EscrowError::SubcontractCycle as u32, 127);
}

// ---------------------------------------------------------------------------
// D1: fund_with_reserve
// ---------------------------------------------------------------------------

#[test]
fn fund_with_reserve_pulls_budget_plus_reserve_in_one_call() {
    let ctx = setup();
    let id = ctx.create(PARENT_EXPIRY);
    ctx.escrow()
        .fund_with_reserve(&ctx.client, &id, &BUDGET, &RESERVE, &MAX_FEE);
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - BUDGET - RESERVE);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET + RESERVE);
    let job = ctx.job(id);
    assert_eq!(job.state, JobState::Funded);
    assert_eq!(job.budget, BUDGET);
    assert_eq!(job.reserve, RESERVE);
    assert_eq!(job.reserve_funded, RESERVE);
    assert_eq!(job.open_children, 0);
    assert_eq!(job.parent_job_id, None);
    assert_eq!(job.depth, 0);
    assert_eq!(
        events,
        [
            JobFunded {
                job_id: id,
                client: ctx.client.clone(),
                amount: BUDGET,
                fee_bps: 0,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
            ReserveFunded {
                job_id: id,
                client: ctx.client.clone(),
                reserve: RESERVE,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
        ]
    );
}

#[test]
fn fund_is_fund_with_reserve_zero() {
    let ctx = setup();
    let id = ctx.funded(PARENT_EXPIRY);
    let job = ctx.job(id);
    assert_eq!(job.reserve, 0);
    assert_eq!(job.reserve_funded, 0);
    assert_eq!(job.open_children, 0);
    assert_eq!(job.parent_job_id, None);
    assert_eq!(job.depth, 0);

    // A zero reserve through the new entry point emits only `JobFunded`, as `fund`.
    let other = ctx.create(PARENT_EXPIRY);
    ctx.escrow()
        .fund_with_reserve(&ctx.client, &other, &BUDGET, &0, &MAX_FEE);
    assert_eq!(ctx.job_events().events().len(), 1);
    assert_eq!(ctx.balance(&ctx.escrow_id), 2 * BUDGET);
}

#[test]
fn fund_with_reserve_refuses_a_negative_reserve_and_keeps_fund_checks() {
    let ctx = setup();
    let id = ctx.create(PARENT_EXPIRY);
    let e = ctx.escrow();
    assert_eq!(
        err(e.try_fund_with_reserve(&ctx.client, &id, &BUDGET, &-1, &MAX_FEE)),
        EscrowError::InvalidAmount
    );
    assert_eq!(
        err(e.try_fund_with_reserve(&ctx.provider, &id, &BUDGET, &RESERVE, &MAX_FEE)),
        EscrowError::NotClient
    );
    assert_eq!(
        err(e.try_fund_with_reserve(&ctx.client, &id, &(BUDGET + 1), &RESERVE, &MAX_FEE)),
        EscrowError::BudgetMismatch
    );
    assert_eq!(
        err(e.try_fund_with_reserve(&ctx.client, &id, &BUDGET, &i128::MAX, &MAX_FEE)),
        EscrowError::ArithmeticOverflow
    );
    assert_eq!(ctx.job(id).state, JobState::Open);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
}

// ---------------------------------------------------------------------------
// D2: create_child_job
// ---------------------------------------------------------------------------

#[test]
fn create_child_job_draws_from_the_parent_reserve() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let a_before = ctx.balance(&ctx.provider);
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    let events = ctx.job_events();

    let job = ctx.job(child);
    assert_eq!(job.state, JobState::Funded);
    assert_eq!(job.client, ctx.provider);
    assert_eq!(job.provider, b.wallet);
    assert_eq!(job.evaluator, ctx.provider);
    assert_eq!(job.agent_id, b.id);
    assert_eq!(job.token, ctx.token);
    assert_eq!(job.budget, CHILD_BUDGET);
    assert_eq!(job.reserve, 0);
    assert_eq!(job.parent_job_id, Some(parent));
    assert_eq!(job.depth, 1);
    assert_eq!(job.expired_at, CHILD_EXPIRY);

    let p = ctx.job(parent);
    assert_eq!(p.reserve, RESERVE - CHILD_BUDGET);
    assert_eq!(p.reserve_funded, RESERVE);
    assert_eq!(p.open_children, 1);
    // No transfer: A's wallet never pays and the escrow holds the same total.
    assert_eq!(ctx.balance(&ctx.provider), a_before);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET + RESERVE);

    assert_eq!(
        events,
        [
            JobCreated {
                job_id: child,
                client: ctx.provider.clone(),
                provider: b.wallet.clone(),
                evaluator: ctx.provider.clone(),
                agent_id: b.id,
                token: ctx.token.clone(),
                budget: CHILD_BUDGET,
                expired_at: CHILD_EXPIRY,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
            JobFunded {
                job_id: child,
                client: ctx.provider.clone(),
                amount: CHILD_BUDGET,
                fee_bps: 0,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
            ChildJobCreated {
                parent_job_id: parent,
                child_job_id: child,
                provider: b.wallet.clone(),
                agent_id: b.id,
                budget: CHILD_BUDGET,
                reserve: 0,
                depth: 1,
                parent_reserve_left: RESERVE - CHILD_BUDGET,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
        ]
    );
}

#[test]
fn only_the_parent_provider_can_create_a_child() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    for caller in [&ctx.client, &b.wallet] {
        assert_eq!(
            ctx.try_child(caller, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0),
            Err(EscrowError::NotProvider)
        );
    }
    assert_eq!(
        ctx.try_child(&ctx.provider, 99, &b, CHILD_EXPIRY, CHILD_BUDGET, 0),
        Err(EscrowError::JobNotFound)
    );
}

#[test]
fn create_child_job_requires_the_parent_provider_signature() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    let auths = ctx.env.auths();
    assert_eq!(auths.len(), 1);
    assert_eq!(auths[0].0, ctx.provider);
}

#[test]
fn the_parent_must_be_funded_and_live() {
    let ctx = setup();
    let b = ctx.agent();
    let open = ctx.create(PARENT_EXPIRY);
    assert_eq!(
        ctx.try_child(&ctx.provider, open, &b, CHILD_EXPIRY, CHILD_BUDGET, 0),
        Err(EscrowError::InvalidState)
    );

    let submitted = ctx.reserved(CHILD_BUDGET);
    ctx.submit(submitted);
    assert_eq!(
        ctx.try_child(&ctx.provider, submitted, &b, CHILD_EXPIRY, CHILD_BUDGET, 0),
        Err(EscrowError::InvalidState)
    );

    let expired = ctx.reserved(CHILD_BUDGET);
    ctx.set_time(PARENT_EXPIRY);
    assert_eq!(
        ctx.try_child(&ctx.provider, expired, &b, CHILD_EXPIRY, CHILD_BUDGET, 0),
        Err(EscrowError::JobExpired)
    );
}

#[test]
fn a_child_cannot_exceed_the_remaining_reserve() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let c = ctx.agent();
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &b, CHILD_EXPIRY, RESERVE + 1, 0),
        Err(EscrowError::ReserveExceeded)
    );
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &b, CHILD_EXPIRY, RESERVE, 1),
        Err(EscrowError::ReserveExceeded)
    );
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &b, CHILD_EXPIRY, 1, i128::MAX),
        Err(EscrowError::ArithmeticOverflow)
    );
    ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, RESERVE - 1, 0);
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &c, CHILD_EXPIRY, 2, 0),
        Err(EscrowError::ReserveExceeded)
    );
    ctx.child(&ctx.provider, parent, &c, CHILD_EXPIRY, 1, 0);
    assert_eq!(ctx.job(parent).reserve, 0);
    assert_eq!(ctx.job(parent).open_children, 2);

    // A job funded with `fund` has no reserve to draw from.
    let plain = ctx.funded(PARENT_EXPIRY);
    assert_eq!(
        ctx.try_child(&ctx.provider, plain, &b, CHILD_EXPIRY, 1, 0),
        Err(EscrowError::ReserveExceeded)
    );
}

#[test]
fn child_amounts_must_be_valid() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    for (budget, reserve) in [(0, 0), (-1, 0), (CHILD_BUDGET, -1)] {
        assert_eq!(
            ctx.try_child(&ctx.provider, parent, &b, CHILD_EXPIRY, budget, reserve),
            Err(EscrowError::InvalidAmount)
        );
    }
}

#[test]
fn a_child_must_expire_before_its_parent_with_room_to_resume() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    for late in [CHILD_EXPIRY + 1, PARENT_EXPIRY, PARENT_EXPIRY + 1] {
        assert_eq!(
            ctx.try_child(&ctx.provider, parent, &b, late, CHILD_BUDGET, 0),
            Err(EscrowError::InvalidExpiry)
        );
    }
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &b, NOW, CHILD_BUDGET, 0),
        Err(EscrowError::InvalidExpiry)
    );
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    let (c, p) = (ctx.job(child), ctx.job(parent));
    assert!(c.expired_at + APPROVAL_WINDOW + CHILD_EXPIRY_MARGIN <= p.expired_at);
}

#[test]
fn the_provider_must_be_the_agents_registry_wallet() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let impostor = Agent {
        wallet: Address::generate(&ctx.env),
        id: b.id,
    };
    assert_eq!(
        ctx.try_child(
            &ctx.provider,
            parent,
            &impostor,
            CHILD_EXPIRY,
            CHILD_BUDGET,
            0
        ),
        Err(EscrowError::ProviderMismatch)
    );
    let unknown = Agent {
        wallet: b.wallet.clone(),
        id: 999,
    };
    assert_eq!(
        ctx.try_child(
            &ctx.provider,
            parent,
            &unknown,
            CHILD_EXPIRY,
            CHILD_BUDGET,
            0
        ),
        Err(EscrowError::AgentNotFound)
    );
}

#[test]
fn the_child_evaluator_cannot_be_its_provider() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let result = ctx.escrow().try_create_child_job(
        &ctx.provider,
        &parent,
        &b.wallet,
        &b.wallet,
        &CHILD_EXPIRY,
        &ctx.desc("subtask"),
        &b.id,
        &CHILD_BUDGET,
        &0,
    );
    assert_eq!(err(result), EscrowError::EvaluatorIsProvider);
}

#[test]
fn no_agent_appears_twice_in_an_ancestor_chain() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let a = ctx.agent_a();
    let b = ctx.agent();
    // A cannot hire itself.
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &a, CHILD_EXPIRY, CHILD_BUDGET, 0),
        Err(EscrowError::SubcontractCycle)
    );
    // B cannot hire A back: A is its parent's provider.
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 1_000);
    assert_eq!(
        ctx.try_child(&b.wallet, child, &a, GRANDCHILD_EXPIRY, 1_000, 0),
        Err(EscrowError::SubcontractCycle)
    );
}

#[test]
fn depth_is_limited_to_two() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let (b, c, d) = (ctx.agent(), ctx.agent(), ctx.agent());
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 2_000);
    let grandchild = ctx.child(&b.wallet, child, &c, GRANDCHILD_EXPIRY, 1_000, 0);
    assert_eq!(ctx.job(grandchild).depth, MAX_DEPTH);
    assert_eq!(ctx.job(grandchild).client, b.wallet);
    assert_eq!(ctx.job(child).reserve, 1_000);
    let last = GRANDCHILD_EXPIRY - APPROVAL_WINDOW - CHILD_EXPIRY_MARGIN;
    assert_eq!(
        ctx.try_child(&c.wallet, grandchild, &d, last, 1, 0),
        Err(EscrowError::DepthExceeded)
    );
    // A depth-2 job could never use a reserve, so it cannot be given one.
    assert_eq!(
        ctx.try_child(&b.wallet, child, &d, GRANDCHILD_EXPIRY, 1, 1),
        Err(EscrowError::DepthExceeded)
    );
}

#[test]
fn a_child_fee_cannot_exceed_the_parent_snapshot() {
    let (ctx, _treasury) = setup_with_fee(100);
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    ctx.escrow().set_fee_bps(&ctx.admin, &200);
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0),
        Err(EscrowError::FeeExceedsMax)
    );
    ctx.escrow().set_fee_bps(&ctx.admin, &50);
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    assert_eq!(ctx.job(child).fee_bps, 50);
}

// ---------------------------------------------------------------------------
// D3: child settlement
// ---------------------------------------------------------------------------

#[test]
fn a_rejected_child_returns_to_the_parent_reserve() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    ctx.escrow().reject(&ctx.provider, &child, &ctx.hash(3));
    let events = ctx.job_events();
    assert_eq!(ctx.job(child).state, JobState::Rejected);
    let p = ctx.job(parent);
    assert_eq!(p.reserve, RESERVE);
    assert_eq!(p.open_children, 0);
    assert_eq!(ctx.balance(&b.wallet), 0);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET + RESERVE);
    assert_eq!(
        events,
        [
            returned(&ctx, parent, child, CHILD_BUDGET, false),
            JobRejected {
                job_id: child,
                rejector: ctx.provider.clone(),
                reason: ctx.hash(3),
                from_state: JobState::Funded,
                refunded: CHILD_BUDGET,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
        ]
    );
    // The returned amount can fund another child.
    let c = ctx.agent();
    ctx.child(&ctx.provider, parent, &c, CHILD_EXPIRY, RESERVE, 0);
}

#[test]
fn a_child_rejected_after_submission_returns_to_the_reserve() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    ctx.escrow().submit(&b.wallet, &child, &ctx.hash(7));
    ctx.escrow().reject(&ctx.provider, &child, &ctx.hash(3));
    assert_eq!(ctx.job(parent).reserve, RESERVE);
    assert_eq!(ctx.job(parent).open_children, 0);
}

#[test]
fn an_expired_child_returns_to_the_parent_reserve() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    ctx.set_time(CHILD_EXPIRY);
    ctx.escrow().claim_refund(&child);
    let events = ctx.job_events();
    assert_eq!(ctx.job(child).state, JobState::Expired);
    assert_eq!(ctx.job(parent).reserve, RESERVE);
    assert_eq!(ctx.job(parent).open_children, 0);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(
        events,
        [
            returned(&ctx, parent, child, CHILD_BUDGET, false),
            JobExpired {
                job_id: child,
                client: ctx.provider.clone(),
                refunded: CHILD_BUDGET,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
        ]
    );
}

#[test]
fn a_completed_child_pays_b_and_stays_paid_when_the_parent_is_rejected() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    ctx.escrow().submit(&b.wallet, &child, &ctx.hash(7));
    ctx.escrow().complete(&ctx.provider, &child, &ctx.hash(8));
    assert_eq!(ctx.balance(&b.wallet), CHILD_BUDGET);
    assert_eq!(ctx.job(parent).open_children, 0);
    assert_eq!(ctx.job(parent).reserve, RESERVE - CHILD_BUDGET);

    // The consumer (evaluator of the parent) rejects A: B keeps its pay.
    ctx.escrow().reject(&ctx.client, &parent, &ctx.hash(9));
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&b.wallet), CHILD_BUDGET);
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - CHILD_BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.job(parent).reserve, 0);
    assert_eq!(
        events,
        [
            refunded(&ctx, parent, RESERVE - CHILD_BUDGET, false),
            JobRejected {
                job_id: parent,
                rejector: ctx.client.clone(),
                reason: ctx.hash(9),
                from_state: JobState::Funded,
                refunded: BUDGET,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
        ]
    );
}

#[test]
fn a_released_child_pays_b() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    ctx.escrow().submit(&b.wallet, &child, &ctx.hash(7));
    ctx.set_time(NOW + APPROVAL_WINDOW);
    ctx.escrow().release(&child);
    assert_eq!(ctx.balance(&b.wallet), CHILD_BUDGET);
    assert_eq!(ctx.job(parent).open_children, 0);
}

// ---------------------------------------------------------------------------
// D4: parent close
// ---------------------------------------------------------------------------

#[test]
fn the_parent_cannot_submit_while_a_child_is_open() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    assert_eq!(
        err(ctx
            .escrow()
            .try_submit(&ctx.provider, &parent, &ctx.hash(1))),
        EscrowError::ChildrenOpen
    );
    assert_eq!(ctx.job(parent).state, JobState::Funded);
    ctx.escrow().submit(&b.wallet, &child, &ctx.hash(7));
    ctx.escrow().complete(&ctx.provider, &child, &ctx.hash(8));
    ctx.submit(parent);
    assert_eq!(ctx.job(parent).state, JobState::Submitted);
}

#[test]
fn parent_complete_pays_a_and_refunds_the_unspent_reserve() {
    let (ctx, treasury) = setup_with_fee(100);
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    ctx.escrow().submit(&b.wallet, &child, &ctx.hash(7));
    ctx.escrow().complete(&ctx.provider, &child, &ctx.hash(8));
    let child_fee = CHILD_BUDGET / 100;
    assert_eq!(ctx.balance(&b.wallet), CHILD_BUDGET - child_fee);

    ctx.submit(parent);
    ctx.escrow().complete(&ctx.client, &parent, &ctx.hash(5));
    let events = ctx.job_events();
    let fee = BUDGET / 100;
    // No fee on the reserve or its refund.
    assert_eq!(ctx.balance(&ctx.provider), BUDGET - fee);
    assert_eq!(ctx.balance(&treasury), fee + child_fee);
    assert_eq!(
        ctx.balance(&ctx.client),
        CLIENT_FUNDS - BUDGET - CHILD_BUDGET
    );
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.job(parent).reserve, 0);
    assert_eq!(ctx.job(parent).reserve_funded, RESERVE);
    assert_eq!(
        events,
        [
            refunded(&ctx, parent, RESERVE - CHILD_BUDGET, false),
            completed(&ctx, parent, BUDGET - fee, fee, ctx.hash(5), false),
        ]
    );
}

#[test]
fn an_unreceivable_reserve_refund_is_deferred_not_blocking() {
    let (ctx, _treasury) = setup_mock(0);
    let parent = ctx.reserved(RESERVE);
    ctx.submit(parent);
    ctx.mock().set_blocked(&ctx.client, &1);
    ctx.escrow().complete(&ctx.client, &parent, &ctx.hash(5));
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.provider), BUDGET);
    assert_eq!(ctx.claimable(&ctx.client), RESERVE);
    assert_eq!(ctx.balance(&ctx.escrow_id), RESERVE);
    assert_eq!(
        events,
        [
            deferred(&ctx, parent, &ctx.client, RESERVE),
            refunded(&ctx, parent, RESERVE, true),
            completed(&ctx, parent, BUDGET, 0, ctx.hash(5), false),
        ]
    );
    ctx.mock().set_blocked(&ctx.client, &0);
    assert_eq!(ctx.escrow().withdraw(&ctx.client, &ctx.token), RESERVE);
}

#[test]
fn parent_reject_refunds_budget_and_unspent_reserve_and_later_returns_go_to_the_client() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    // The consumer is never held hostage by an open child.
    ctx.escrow().reject(&ctx.client, &parent, &ctx.hash(9));
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS - CHILD_BUDGET);
    assert_eq!(ctx.balance(&ctx.escrow_id), CHILD_BUDGET);
    assert_eq!(ctx.job(parent).open_children, 1);

    ctx.escrow().reject(&ctx.provider, &child, &ctx.hash(3));
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(ctx.job(parent).open_children, 0);
    assert_eq!(ctx.job(parent).reserve, 0);
    assert_eq!(
        events.events()[0],
        returned(&ctx, parent, child, CHILD_BUDGET, true)
    );
}

#[test]
fn parent_claim_refund_refunds_budget_and_unspent_reserve() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    ctx.set_time(PARENT_EXPIRY);
    ctx.escrow().claim_refund(&parent);
    let events = ctx.job_events();
    assert_eq!(ctx.balance(&ctx.client), CLIENT_FUNDS);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);
    assert_eq!(
        events,
        [
            refunded(&ctx, parent, RESERVE, false),
            JobExpired {
                job_id: parent,
                client: ctx.client.clone(),
                refunded: BUDGET,
            }
            .to_xdr(&ctx.env, &ctx.escrow_id),
        ]
    );
}

// ---------------------------------------------------------------------------
// D6 invariants over a full tree
// ---------------------------------------------------------------------------

#[test]
fn a_full_tree_conserves_funds_and_keeps_the_reserve_invariants() {
    let (ctx, treasury) = setup_with_fee(100);
    let parent = ctx.reserved(RESERVE);
    let (b, c, d, e) = (ctx.agent(), ctx.agent(), ctx.agent(), ctx.agent());
    let claimants = [&ctx.client, &ctx.provider, &b.wallet, &c.wallet, &d.wallet];

    // A hires B (with a sub-reserve) and D; B hires C.
    let child_b = ctx.child(
        &ctx.provider,
        parent,
        &b,
        CHILD_EXPIRY,
        CHILD_BUDGET,
        4_000_000,
    );
    let child_d = ctx.child(&ctx.provider, parent, &d, CHILD_EXPIRY, 3_000_000, 0);
    let grand_c = ctx.child(&b.wallet, child_b, &c, GRANDCHILD_EXPIRY, 2_500_000, 0);
    let ids = [parent, child_b, child_d, grand_c];
    ctx.assert_conserved(&ids, &claimants);

    // Invariant 1 for A while every child is open.
    let p = ctx.job(parent);
    let drawn = (CHILD_BUDGET + 4_000_000) + 3_000_000;
    assert_eq!(p.reserve_funded, p.reserve + drawn);
    assert!(p.reserve >= 0);
    // Invariant 2 along every edge.
    for (child, parent_id) in [(child_b, parent), (child_d, parent), (grand_c, child_b)] {
        let (cj, pj) = (ctx.job(child), ctx.job(parent_id));
        assert!(cj.expired_at + APPROVAL_WINDOW + CHILD_EXPIRY_MARGIN <= pj.expired_at);
        assert!(cj.depth <= MAX_DEPTH);
        assert_eq!(cj.depth, pj.depth + 1);
        assert_ne!(cj.provider, pj.provider);
    }
    // The reserve bound holds while children are open.
    assert_eq!(
        ctx.try_child(&ctx.provider, parent, &e, CHILD_EXPIRY, RESERVE, 0),
        Err(EscrowError::ReserveExceeded)
    );

    // D fails and is rejected: back to A's reserve.
    ctx.escrow().reject(&ctx.provider, &child_d, &ctx.hash(1));
    ctx.assert_conserved(&ids, &claimants);
    assert_eq!(ctx.job(parent).reserve, RESERVE - drawn + 3_000_000);

    // C delivers to B; B completes it, then B delivers to A, which completes B.
    ctx.escrow().submit(&c.wallet, &grand_c, &ctx.hash(2));
    ctx.escrow().complete(&b.wallet, &grand_c, &ctx.hash(3));
    ctx.assert_conserved(&ids, &claimants);
    ctx.escrow().submit(&b.wallet, &child_b, &ctx.hash(4));
    ctx.escrow().complete(&ctx.provider, &child_b, &ctx.hash(5));
    ctx.assert_conserved(&ids, &claimants);
    // B's unspent sub-reserve went back to A's reserve, never to A's wallet.
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.job(child_b).reserve, 0);
    assert_eq!(ctx.job(parent).reserve, RESERVE - CHILD_BUDGET - 2_500_000);
    assert_eq!(ctx.job(parent).open_children, 0);

    // A delivers and the consumer completes: the tree is fully settled.
    ctx.submit(parent);
    ctx.escrow().complete(&ctx.client, &parent, &ctx.hash(6));
    ctx.assert_conserved(&ids, &claimants);
    assert_eq!(ctx.balance(&ctx.escrow_id), 0);

    let fee = |x: i128| x / 100;
    let spent = BUDGET + CHILD_BUDGET + 2_500_000;
    // Invariant 5: the consumer paid at most budget + reserve, exactly what was used.
    assert_eq!(CLIENT_FUNDS - ctx.balance(&ctx.client), spent);
    assert!(spent <= BUDGET + RESERVE);
    assert_eq!(ctx.balance(&ctx.provider), BUDGET - fee(BUDGET));
    assert_eq!(ctx.balance(&b.wallet), CHILD_BUDGET - fee(CHILD_BUDGET));
    assert_eq!(ctx.balance(&c.wallet), 2_500_000 - fee(2_500_000));
    assert_eq!(ctx.balance(&d.wallet), 0);
    assert_eq!(
        ctx.balance(&treasury),
        fee(BUDGET) + fee(CHILD_BUDGET) + fee(2_500_000)
    );
}

#[test]
fn a_grandchild_return_skips_a_closed_intermediate_parent() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    let (b, c) = (ctx.agent(), ctx.agent());
    let child_b = ctx.child(
        &ctx.provider,
        parent,
        &b,
        CHILD_EXPIRY,
        CHILD_BUDGET,
        4_000_000,
    );
    let grand_c = ctx.child(&b.wallet, child_b, &c, GRANDCHILD_EXPIRY, 2_500_000, 0);
    // A rejects B while C is still open: B's budget and unspent sub-reserve return
    // to A's reserve, and C stays open.
    ctx.escrow().reject(&ctx.provider, &child_b, &ctx.hash(1));
    assert_eq!(ctx.job(parent).reserve, RESERVE - 2_500_000);
    assert_eq!(ctx.job(child_b).open_children, 1);
    // C expires; its funds skip the closed B and reach A's live reserve, not B or A.
    ctx.set_time(GRANDCHILD_EXPIRY);
    ctx.escrow().claim_refund(&grand_c);
    let events = ctx.job_events();
    assert_eq!(ctx.job(parent).reserve, RESERVE);
    assert_eq!(ctx.job(child_b).open_children, 0);
    assert_eq!(ctx.balance(&b.wallet), 0);
    assert_eq!(ctx.balance(&ctx.provider), 0);
    assert_eq!(ctx.balance(&ctx.escrow_id), BUDGET + RESERVE);
    assert_eq!(
        events.events()[0],
        returned(&ctx, parent, grand_c, 2_500_000, false)
    );
}

#[test]
fn the_reserve_fields_survive_ttl_and_the_parent_ttl_is_bumped() {
    let ctx = setup();
    let parent = ctx.reserved(RESERVE);
    age_ledger(&ctx);
    let before = job_ttl(&ctx, parent);
    let b = ctx.agent();
    let child = ctx.child(&ctx.provider, parent, &b, CHILD_EXPIRY, CHILD_BUDGET, 0);
    assert!(job_ttl(&ctx, parent) > before);
    assert!(job_ttl(&ctx, child) >= TTL_THRESHOLD);
}
