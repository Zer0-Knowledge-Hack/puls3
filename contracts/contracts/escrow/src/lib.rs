#![no_std]

//! Agent escrow: ERC-8183 style job escrow for puls3 agent payments.
//!
//! One job per hire. The client funds a job, the provider (the agent wallet bound in
//! the identity registry) submits a deliverable, and the evaluator completes or
//! rejects it. Silence past the approval window pays the provider (`release`), and an
//! unfunded or unanswered job refunds the client (`claim_refund`). The admin only
//! configures the contract: it has no power over job funds.

use soroban_sdk::{
    contract, contractclient, contracterror, contractevent, contractimpl, contracttype,
    panic_with_error, token::TokenClient, Address, BytesN, Env, String,
};

/// TTL bump config: extend to TTL_BUMP when fewer than TTL_THRESHOLD ledgers remain.
///
/// `TTL_BUMP` is about 60 days at 5-second ledgers. It is unrelated to `max_expiry`: a
/// job whose lifetime exceeds the TTL is archived unless someone keeps it alive with
/// the permissionless `extend_ttl(job_id)` (or restores it afterwards). No cap ties the
/// two values together; `max_expiry` only bounds `expired_at - now` at `create_job`.
pub const TTL_THRESHOLD: u32 = 518_400;
/// See [`TTL_THRESHOLD`].
pub const TTL_BUMP: u32 = 1_036_800;

/// Maximum job description length in bytes.
pub const MAX_DESCRIPTION_LEN: u32 = 256;
/// Basis-point denominator (used in `compute_fee`).
pub const BPS_DENOMINATOR: u32 = 10_000;
/// Hard fee ceiling: at most 10% (1,000 bps) to protect providers.
pub const MAX_FEE_BPS: u32 = 1_000;
/// Seconds a Stellar ledger is assumed to take when a TTL in ledgers is turned
/// into time. Ledgers close in about 5 s; a faster network only makes the
/// margin below smaller, never negative (see [`MAX_EXPIRY_CEILING`]).
pub const LEDGER_SECONDS: u64 = 5;
/// The longest `max_expiry` the escrow accepts: 30 days (audit E-5, #206).
///
/// A job lives from `create_job` until it settles, at the latest a little after
/// `expired_at`, which is at most `max_expiry` after creation (`submit` must
/// leave the approval window before `expired_at`). Every transition extends the
/// job's TTL to [`TTL_BUMP`] ledgers, about 60 days, and the job is never left
/// below [`TTL_THRESHOLD`] ledgers, about 30 days, after a write. Capping
/// `max_expiry` at [`TTL_THRESHOLD`] ledgers ties the two: an open, funded or
/// submitted job cannot archive before its own deadline, with the TTL bump
/// leaving twice that much room. The admin cannot raise `max_expiry` past it.
pub const MAX_EXPIRY_CEILING: u64 = TTL_THRESHOLD as u64 * LEDGER_SECONDS;
/// Ledgers a proposed identity registry waits before it can take effect (about
/// 3 days at 5 s a ledger), so a compromised admin cannot redirect new jobs at
/// once and the change is public before it applies (audit E-2, #206).
pub const REGISTRY_TIMELOCK_LEDGERS: u32 = 51_840;
/// Ledgers after the timelock during which the proposal can still be executed
/// (about 7 days). After that it has expired and must be proposed again.
pub const REGISTRY_EXECUTION_WINDOW: u32 = 120_960;

/// Seconds a child job must expire before its parent beyond the approval window
/// (ADR-0011 D2): room for the parent's run to resume with the child's result and
/// `submit`, with the parent's own approval window still closing before it expires.
pub const CHILD_EXPIRY_MARGIN: u64 = 600;
/// Deepest job in a subcontract tree (ADR-0011 D5): consumer -> A (0) -> B (1) -> C (2).
/// A job at this depth cannot have children, so it never holds a reserve.
pub const MAX_DEPTH: u32 = 2;

const CONTRACT_VERSION: &str = "0.2.0";

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
#[repr(u32)]
pub enum EscrowError {
    JobNotFound = 1,
    InvalidState = 2,
    NotClient = 3,
    NotProvider = 4,
    NotEvaluator = 5,
    InvalidAmount = 6,
    BudgetMismatch = 7,
    InvalidExpiry = 8,
    JobExpired = 9,
    NotExpired = 10,
    HookNotSupported = 11,
    // 100+: puls3 additions.
    NotAdmin = 100,
    TokenNotAllowed = 101,
    ProviderMismatch = 102,
    AgentWalletNotSet = 103,
    AgentNotFound = 104,
    ClientIsProvider = 105,
    SubmitTooLate = 106,
    ApprovalWindowOpen = 107,
    ApprovalWindowClosed = 108,
    InvalidFeeBps = 109,
    TreasuryNotSet = 110,
    InvalidDuration = 111,
    RegistryNotSet = 112,
    DescriptionTooLong = 113,
    ArithmeticOverflow = 114,
    /// `fund`: the fee about to be snapshotted is above the `max_fee_bps` of the client.
    FeeExceedsMax = 115,
    /// `withdraw`: the caller has no claimable balance for that token.
    NothingToWithdraw = 116,
    /// `create_job`: the evaluator is the provider (a provider cannot approve its own work).
    EvaluatorIsProvider = 117,
    /// `accept_admin`: no admin transfer is pending.
    NoPendingAdmin = 118,
    /// `accept_admin`: the caller is not the pending admin.
    NotPendingAdmin = 119,
    /// A proposed identity registry is waiting and has not expired: cancel it
    /// first (audit E-2).
    RegistryChangePending = 120,
    /// No identity registry change is proposed.
    NoRegistryChange = 121,
    /// The proposed identity registry's timelock has not passed yet.
    RegistryTimelockNotExpired = 122,
    /// The proposed identity registry was not executed in time; propose it again.
    RegistryChangeExpired = 123,
    /// `create_child_job`: `budget + reserve` exceeds the parent's unspent reserve.
    ReserveExceeded = 124,
    /// `submit`: the job still has open child jobs (ADR-0011 D4).
    ChildrenOpen = 125,
    /// `create_child_job`: the child would be deeper than `MAX_DEPTH` (ADR-0011 D5).
    DepthExceeded = 126,
    /// `create_child_job`: the provider or agent is already in the ancestor chain.
    SubcontractCycle = 127,
}

#[contracttype]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
#[repr(u32)]
pub enum JobState {
    Open = 0,
    Funded = 1,
    Submitted = 2,
    Completed = 3,
    Rejected = 4,
    Expired = 5,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Job {
    pub client: Address,
    pub provider: Address,
    pub evaluator: Address,
    pub agent_id: u32,
    pub token: Address,
    pub budget: i128,
    /// Snapshot taken at `fund`; 0 until then.
    pub fee_bps: u32,
    pub expired_at: u64,
    pub description: String,
    pub state: JobState,
    pub submitted_at: u64,
    pub approval_deadline: u64,
    pub deliverable: Option<BytesN<32>>,
    /// puls3 (ADR-0011 D1): unspent subcontract reserve. It decreases on each child
    /// draw, grows when a child returns funds, and is 0 once the job is closed.
    pub reserve: i128,
    /// What was put into the reserve at funding (by the client, or drawn from the
    /// parent for a child job). Never changes afterwards; kept for receipts.
    pub reserve_funded: i128,
    /// Child jobs created from this job that have not settled yet.
    pub open_children: u32,
    /// The job whose reserve funded this one; `None` for a consumer's job.
    pub parent_job_id: Option<u64>,
    /// 0 for a consumer's job, `parent.depth + 1` for a child.
    pub depth: u32,
}

#[contracttype]
#[derive(Clone)]
pub enum DataKey {
    Admin,
    IdentityRegistry,
    Treasury,
    FeeBps,
    MaxExpiry,
    ApprovalWindow,
    JobCount,
    Job(u64),
    AllowedToken(Address),
    /// Pull-payment balance owed to `(recipient, token)` after a failed payout.
    Claimable(Address, Address),
    /// The admin proposed by `set_admin`, until it calls `accept_admin`.
    PendingAdmin,
    /// The treasury snapshotted at `fund` for a job with a fee, read at settlement.
    JobTreasury(u64),
    /// The identity registry proposed by `propose_identity_registry`, until it is
    /// executed or cancelled (audit E-2).
    PendingIdentityRegistry,
}

/// A proposed identity registry (audit E-2). It takes effect only through
/// `execute_identity_registry`, `REGISTRY_TIMELOCK_LEDGERS` after `proposed_at`.
#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RegistryProposal {
    pub registry: Address,
    pub proposed_at: u32,
}

#[contractevent]
#[derive(Clone)]
pub struct JobCreated {
    #[topic]
    pub job_id: u64,
    pub client: Address,
    pub provider: Address,
    pub evaluator: Address,
    pub agent_id: u32,
    pub token: Address,
    pub budget: i128,
    pub expired_at: u64,
}

#[contractevent]
#[derive(Clone)]
pub struct TokenAllowedSet {
    #[topic]
    pub token: Address,
    pub allowed: bool,
}

#[contractevent]
#[derive(Clone)]
pub struct JobFunded {
    #[topic]
    pub job_id: u64,
    pub client: Address,
    pub amount: i128,
    pub fee_bps: u32,
}

#[contractevent]
#[derive(Clone)]
pub struct JobRejected {
    #[topic]
    pub job_id: u64,
    pub rejector: Address,
    pub reason: BytesN<32>,
    /// State the job was in when `reject` was called.
    pub from_state: JobState,
    pub refunded: i128,
}

#[contractevent]
#[derive(Clone)]
pub struct JobExpired {
    #[topic]
    pub job_id: u64,
    pub client: Address,
    pub refunded: i128,
}

#[contractevent]
#[derive(Clone)]
pub struct JobSubmitted {
    #[topic]
    pub job_id: u64,
    pub provider: Address,
    pub deliverable: BytesN<32>,
    pub approval_deadline: u64,
}

#[contractevent]
#[derive(Clone)]
pub struct JobCompleted {
    #[topic]
    pub job_id: u64,
    pub evaluator: Address,
    pub reason: BytesN<32>,
    pub payout: i128,
    pub fee: i128,
    /// True when settled by the permissionless `release`.
    pub auto_released: bool,
}

/// `fund_with_reserve` put a non-zero subcontract reserve on a job (ADR-0011 D6).
#[contractevent]
#[derive(Clone)]
pub struct ReserveFunded {
    #[topic]
    pub job_id: u64,
    pub client: Address,
    pub reserve: i128,
}

/// A child job was drawn from its parent's reserve (ADR-0011 D6). The child also
/// emits the usual `JobCreated` and `JobFunded`.
#[contractevent]
#[derive(Clone)]
pub struct ChildJobCreated {
    #[topic]
    pub parent_job_id: u64,
    pub child_job_id: u64,
    pub provider: Address,
    pub agent_id: u32,
    pub budget: i128,
    pub reserve: i128,
    pub depth: u32,
    pub parent_reserve_left: i128,
}

/// A closing child sent funds back up its tree (ADR-0011 D3). With
/// `to_client == false`, `amount` was added to the reserve of `parent_job_id`, the
/// nearest ancestor still `Funded`. With `to_client == true` no ancestor was, and
/// `amount` went to the client of the root job `parent_job_id` (paid or deferred).
#[contractevent]
#[derive(Clone)]
pub struct ReserveReturned {
    #[topic]
    pub parent_job_id: u64,
    pub child_job_id: u64,
    pub amount: i128,
    pub to_client: bool,
}

/// A consumer's job closed and its unspent reserve went back to the client
/// (ADR-0011 D4). `deferred` is true when it was credited as a claimable balance.
#[contractevent]
#[derive(Clone)]
pub struct ReserveRefunded {
    #[topic]
    pub job_id: u64,
    pub client: Address,
    pub amount: i128,
    pub deferred: bool,
}

/// A payout transfer failed (for example no trustline), so the amount was credited to
/// the claimable balance of the recipient instead. The funds stay in the contract.
#[contractevent]
#[derive(Clone)]
pub struct PayoutDeferred {
    #[topic]
    pub job_id: u64,
    pub recipient: Address,
    pub token: Address,
    pub amount: i128,
}

/// A recipient pulled their claimable balance with `withdraw`.
#[contractevent]
#[derive(Clone)]
pub struct PayoutWithdrawn {
    #[topic]
    pub recipient: Address,
    pub token: Address,
    pub amount: i128,
}

#[contractevent]
#[derive(Clone)]
pub struct FeeConfigUpdated {
    pub fee_bps: u32,
    pub treasury: Option<Address>,
}

#[contractevent]
#[derive(Clone)]
pub struct LimitsUpdated {
    pub max_expiry: u64,
    pub approval_window: u64,
}

#[contractevent]
#[derive(Clone)]
pub struct RegistryUpdated {
    pub registry: Address,
}

#[contractevent]
#[derive(Clone)]
pub struct RegistryChangeProposed {
    pub registry: Address,
    pub proposed_at: u32,
    pub executable_at: u32,
    pub expires_at: u32,
}

#[contractevent]
#[derive(Clone)]
pub struct RegistryChangeCancelled {
    pub registry: Address,
}

#[contractevent]
#[derive(Clone)]
pub struct AdminProposed {
    pub current_admin: Address,
    pub pending_admin: Address,
}

#[contractevent]
#[derive(Clone)]
pub struct AdminChanged {
    pub old_admin: Address,
    pub new_admin: Address,
}

/// The two identity-registry functions the escrow depends on.
#[contractclient(name = "RegistryClient")]
pub trait Registry {
    fn agent_exists(e: Env, agent_id: u32) -> bool;
    fn get_agent_wallet(e: Env, agent_id: u32) -> Option<Address>;
}

#[contract]
pub struct EscrowContract;

#[contractimpl]
impl EscrowContract {
    /// `max_expiry` and `approval_window` are deployment parameters, never defaults.
    ///
    /// `max_expiry` bounds `expired_at - now` and is independent of the persistent
    /// storage TTL (`TTL_BUMP`, about 60 days): a job that outlives the TTL needs
    /// `extend_ttl(job_id)` calls or a restore.
    pub fn __constructor(
        e: &Env,
        admin: Address,
        identity_registry: Address,
        treasury: Option<Address>,
        fee_bps: u32,
        max_expiry: u64,
        approval_window: u64,
    ) -> Result<(), EscrowError> {
        validate_fee(fee_bps, treasury.is_some())?;
        validate_limits(max_expiry, approval_window)?;
        let instance = e.storage().instance();
        instance.set(&DataKey::Admin, &admin);
        instance.set(&DataKey::IdentityRegistry, &identity_registry);
        if let Some(treasury) = treasury {
            instance.set(&DataKey::Treasury, &treasury);
        }
        instance.set(&DataKey::FeeBps, &fee_bps);
        instance.set(&DataKey::MaxExpiry, &max_expiry);
        instance.set(&DataKey::ApprovalWindow, &approval_window);
        instance.set(&DataKey::JobCount, &0u64);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. Removal blocks only new `create_job` and `fund` calls.
    pub fn set_token_allowed(
        e: &Env,
        caller: Address,
        token: Address,
        allowed: bool,
    ) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let key = DataKey::AllowedToken(token.clone());
        if allowed {
            e.storage().persistent().set(&key, &true);
            extend_persistent(e, &key);
        } else {
            e.storage().persistent().remove(&key);
        }
        TokenAllowedSet { token, allowed }.publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. A change applies to jobs funded afterwards (`fee_bps` is snapshotted
    /// at `fund`). Zero is always allowed; a non-zero fee needs a treasury.
    pub fn set_fee_bps(e: &Env, caller: Address, fee_bps: u32) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let treasury = Self::treasury(e);
        validate_fee(fee_bps, treasury.is_some())?;
        e.storage().instance().set(&DataKey::FeeBps, &fee_bps);
        FeeConfigUpdated { fee_bps, treasury }.publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. Applies to jobs funded afterwards: a job with a fee snapshots the
    /// treasury at `fund`, like `fee_bps`, and is paid there (audit E-3).
    pub fn set_treasury(e: &Env, caller: Address, treasury: Address) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        e.storage().instance().set(&DataKey::Treasury, &treasury);
        FeeConfigUpdated {
            fee_bps: Self::fee_bps(e),
            treasury: Some(treasury),
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. Bounds `expired_at - now` at `create_job`; existing jobs are unchanged.
    /// It is not tied to the storage TTL (`TTL_BUMP`, about 60 days): a longer job must
    /// be kept alive with the permissionless `extend_ttl(job_id)`, or restored.
    pub fn set_max_expiry(e: &Env, caller: Address, max_expiry: u64) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let approval_window = Self::approval_window(e);
        validate_limits(max_expiry, approval_window)?;
        e.storage().instance().set(&DataKey::MaxExpiry, &max_expiry);
        LimitsUpdated {
            max_expiry,
            approval_window,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. Read at `submit`; stored `approval_deadline` values never move.
    pub fn set_approval_window(
        e: &Env,
        caller: Address,
        approval_window: u64,
    ) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let max_expiry = Self::max_expiry(e);
        validate_limits(max_expiry, approval_window)?;
        e.storage()
            .instance()
            .set(&DataKey::ApprovalWindow, &approval_window);
        LimitsUpdated {
            max_expiry,
            approval_window,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. The first of two steps (audit E-2, #206): records `registry` as
    /// proposed and emits `RegistryChangeProposed`. The registry names the wallet of
    /// every new job's provider, so it changes only through `execute_identity_registry`,
    /// after `REGISTRY_TIMELOCK_LEDGERS`: a compromised admin cannot redirect new jobs at
    /// once, and the change is public for days before it applies. Only `create_job`
    /// consults the registry, so in-flight jobs are unaffected either way. A live
    /// proposal must be cancelled first (`RegistryChangePending`); an expired one can be
    /// replaced.
    pub fn propose_identity_registry(
        e: &Env,
        caller: Address,
        registry: Address,
    ) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let now = e.ledger().sequence();
        if let Some(pending) = Self::pending_identity_registry(e) {
            if !registry_change_expired(&pending, now) {
                return Err(EscrowError::RegistryChangePending);
            }
        }
        e.storage().instance().set(
            &DataKey::PendingIdentityRegistry,
            &RegistryProposal {
                registry: registry.clone(),
                proposed_at: now,
            },
        );
        RegistryChangeProposed {
            registry,
            proposed_at: now,
            executable_at: now.saturating_add(REGISTRY_TIMELOCK_LEDGERS),
            expires_at: registry_change_expires_at(now),
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. Drops the proposed registry and emits `RegistryChangeCancelled`.
    pub fn cancel_identity_registry(e: &Env, caller: Address) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let pending = Self::pending_identity_registry(e).ok_or(EscrowError::NoRegistryChange)?;
        e.storage()
            .instance()
            .remove(&DataKey::PendingIdentityRegistry);
        RegistryChangeCancelled {
            registry: pending.registry,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. Applies the proposed registry once its timelock has passed
    /// (`RegistryTimelockNotExpired` before) and before it expires
    /// (`RegistryChangeExpired`), and emits `RegistryUpdated`.
    pub fn execute_identity_registry(e: &Env, caller: Address) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let pending = Self::pending_identity_registry(e).ok_or(EscrowError::NoRegistryChange)?;
        let now = e.ledger().sequence();
        if now.saturating_sub(pending.proposed_at) < REGISTRY_TIMELOCK_LEDGERS {
            return Err(EscrowError::RegistryTimelockNotExpired);
        }
        if registry_change_expired(&pending, now) {
            return Err(EscrowError::RegistryChangeExpired);
        }
        let instance = e.storage().instance();
        instance.set(&DataKey::IdentityRegistry, &pending.registry);
        instance.remove(&DataKey::PendingIdentityRegistry);
        RegistryUpdated {
            registry: pending.registry,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// The identity registry proposed by `propose_identity_registry` and not executed
    /// or cancelled yet.
    pub fn pending_identity_registry(e: &Env) -> Option<RegistryProposal> {
        e.storage()
            .instance()
            .get(&DataKey::PendingIdentityRegistry)
    }

    /// Admin only. The admin configures the contract and has no power over job funds.
    ///
    /// The first of two steps (audit E-3): it records `new_admin` as pending and emits
    /// `AdminProposed`. The admin changes only when `new_admin` calls `accept_admin`, so
    /// a mistyped address cannot take configuration control away. Calling it again
    /// replaces the pending admin; proposing the current admin cancels the transfer.
    pub fn set_admin(e: &Env, caller: Address, new_admin: Address) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        let instance = e.storage().instance();
        if new_admin == caller {
            instance.remove(&DataKey::PendingAdmin);
        } else {
            instance.set(&DataKey::PendingAdmin, &new_admin);
        }
        AdminProposed {
            current_admin: caller,
            pending_admin: new_admin,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Pending admin only. Completes `set_admin` and emits `AdminChanged`.
    pub fn accept_admin(e: &Env, caller: Address) -> Result<(), EscrowError> {
        caller.require_auth();
        let instance = e.storage().instance();
        let pending: Address = instance
            .get(&DataKey::PendingAdmin)
            .ok_or(EscrowError::NoPendingAdmin)?;
        if pending != caller {
            return Err(EscrowError::NotPendingAdmin);
        }
        let old_admin = Self::admin(e);
        instance.set(&DataKey::Admin, &caller);
        instance.remove(&DataKey::PendingAdmin);
        AdminChanged {
            old_admin,
            new_admin: caller,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// The admin proposed by `set_admin` and not accepted yet.
    pub fn pending_admin(e: &Env) -> Option<Address> {
        e.storage().instance().get(&DataKey::PendingAdmin)
    }

    /// Creates an `Open` job. The provider must be the registry wallet of `agent_id`.
    #[allow(clippy::too_many_arguments)]
    pub fn create_job(
        e: &Env,
        caller: Address,
        provider: Address,
        evaluator: Address,
        expired_at: u64,
        description: String,
        hook: Option<Address>,
        agent_id: u32,
        token: Address,
        budget: i128,
    ) -> Result<u64, EscrowError> {
        caller.require_auth();
        if hook.is_some() {
            return Err(EscrowError::HookNotSupported);
        }
        if budget <= 0 {
            return Err(EscrowError::InvalidAmount);
        }
        if description.len() > MAX_DESCRIPTION_LEN {
            return Err(EscrowError::DescriptionTooLong);
        }
        let now = e.ledger().timestamp();
        if expired_at <= now || expired_at > now.saturating_add(Self::max_expiry(e)) {
            return Err(EscrowError::InvalidExpiry);
        }
        require_token_allowed(e, &token)?;
        if caller == provider {
            return Err(EscrowError::ClientIsProvider);
        }
        if evaluator == provider {
            return Err(EscrowError::EvaluatorIsProvider);
        }
        verify_provider(e, agent_id, &provider)?;
        let job_id = next_job_id(e);
        let job = Job {
            client: caller.clone(),
            provider: provider.clone(),
            evaluator: evaluator.clone(),
            agent_id,
            token: token.clone(),
            budget,
            fee_bps: 0,
            expired_at,
            description,
            state: JobState::Open,
            submitted_at: 0,
            approval_deadline: 0,
            deliverable: None,
            reserve: 0,
            reserve_funded: 0,
            open_children: 0,
            parent_job_id: None,
            depth: 0,
        };
        save_job(e, job_id, &job);
        JobCreated {
            job_id,
            client: caller,
            provider,
            evaluator,
            agent_id,
            token,
            budget,
            expired_at,
        }
        .publish(e);
        extend_instance(e);
        Ok(job_id)
    }

    /// Client only. Pulls exactly `budget` from the client and snapshots `fee_bps`.
    /// `max_fee_bps` protects the client: if the current fee is above it the call fails
    /// with `FeeExceedsMax`, so a fee change made after `create_job` cannot be imposed.
    pub fn fund(
        e: &Env,
        caller: Address,
        job_id: u64,
        expected_budget: i128,
        max_fee_bps: u32,
    ) -> Result<(), EscrowError> {
        fund_job(e, caller, job_id, expected_budget, 0, max_fee_bps)
    }

    /// puls3 (ADR-0011 D1). Client only. `fund` plus a subcontract `reserve`, pulled
    /// in the same transfer: the job's provider may draw child jobs from it with
    /// `create_child_job`, and whatever is unspent returns to the client when the job
    /// closes. A `reserve` of 0 is exactly `fund`. No fee is ever taken on the reserve.
    pub fn fund_with_reserve(
        e: &Env,
        caller: Address,
        job_id: u64,
        expected_budget: i128,
        reserve: i128,
        max_fee_bps: u32,
    ) -> Result<(), EscrowError> {
        fund_job(e, caller, job_id, expected_budget, reserve, max_fee_bps)
    }

    /// puls3 (ADR-0011 D2). Parent provider only. Creates a `Funded` child job whose
    /// client is the caller, paid from the parent's reserve with no transfer: the
    /// caller's wallet never pays. The token is inherited and there is no hook.
    /// `reserve` is the child's own sub-reserve, only possible below `MAX_DEPTH`.
    #[allow(clippy::too_many_arguments)]
    pub fn create_child_job(
        e: &Env,
        caller: Address,
        parent_job_id: u64,
        provider: Address,
        evaluator: Address,
        expired_at: u64,
        description: String,
        agent_id: u32,
        budget: i128,
        reserve: i128,
    ) -> Result<u64, EscrowError> {
        caller.require_auth();
        let mut parent = load_job(e, parent_job_id)?;
        if caller != parent.provider {
            return Err(EscrowError::NotProvider);
        }
        if parent.state != JobState::Funded {
            return Err(EscrowError::InvalidState);
        }
        let now = e.ledger().timestamp();
        if now >= parent.expired_at {
            return Err(EscrowError::JobExpired);
        }
        let depth = parent.depth + 1;
        if depth > MAX_DEPTH || (depth == MAX_DEPTH && reserve > 0) {
            return Err(EscrowError::DepthExceeded);
        }
        if budget <= 0 || reserve < 0 {
            return Err(EscrowError::InvalidAmount);
        }
        let drawn = budget
            .checked_add(reserve)
            .ok_or(EscrowError::ArithmeticOverflow)?;
        if drawn > parent.reserve {
            return Err(EscrowError::ReserveExceeded);
        }
        if description.len() > MAX_DESCRIPTION_LEN {
            return Err(EscrowError::DescriptionTooLong);
        }
        let latest = parent
            .expired_at
            .saturating_sub(Self::approval_window(e))
            .saturating_sub(CHILD_EXPIRY_MARGIN);
        if expired_at <= now
            || expired_at > now.saturating_add(Self::max_expiry(e))
            || expired_at > latest
        {
            return Err(EscrowError::InvalidExpiry);
        }
        require_no_cycle(e, &parent, &provider, agent_id)?;
        if caller == provider {
            return Err(EscrowError::ClientIsProvider);
        }
        if evaluator == provider {
            return Err(EscrowError::EvaluatorIsProvider);
        }
        require_token_allowed(e, &parent.token)?;
        verify_provider(e, agent_id, &provider)?;
        // The fee the consumer accepted at funding binds the whole tree (D6).
        let fee_bps = Self::fee_bps(e);
        if fee_bps > parent.fee_bps {
            return Err(EscrowError::FeeExceedsMax);
        }

        // `drawn <= parent.reserve`, so this cannot go below zero.
        parent.reserve -= drawn;
        parent.open_children = parent
            .open_children
            .checked_add(1)
            .ok_or(EscrowError::ArithmeticOverflow)?;
        save_job(e, parent_job_id, &parent);
        let child_job_id = next_job_id(e);
        let child = Job {
            client: caller.clone(),
            provider: provider.clone(),
            evaluator: evaluator.clone(),
            agent_id,
            token: parent.token.clone(),
            budget,
            fee_bps,
            expired_at,
            description,
            state: JobState::Funded,
            submitted_at: 0,
            approval_deadline: 0,
            deliverable: None,
            reserve,
            reserve_funded: reserve,
            open_children: 0,
            parent_job_id: Some(parent_job_id),
            depth,
        };
        save_job(e, child_job_id, &child);
        if fee_bps > 0 {
            snapshot_treasury(e, child_job_id)?;
        }
        JobCreated {
            job_id: child_job_id,
            client: caller.clone(),
            provider: provider.clone(),
            evaluator,
            agent_id,
            token: parent.token,
            budget,
            expired_at,
        }
        .publish(e);
        JobFunded {
            job_id: child_job_id,
            client: caller,
            amount: budget,
            fee_bps,
        }
        .publish(e);
        ChildJobCreated {
            parent_job_id,
            child_job_id,
            provider,
            agent_id,
            budget,
            reserve,
            depth,
            parent_reserve_left: parent.reserve,
        }
        .publish(e);
        extend_instance(e);
        Ok(child_job_id)
    }

    /// Provider only. Starts the approval window; it must close before the job expires.
    /// puls3 (ADR-0011 D4): refused with `ChildrenOpen` while a child job is open.
    pub fn submit(
        e: &Env,
        caller: Address,
        job_id: u64,
        deliverable: BytesN<32>,
    ) -> Result<(), EscrowError> {
        caller.require_auth();
        let mut job = load_job(e, job_id)?;
        if caller != job.provider {
            return Err(EscrowError::NotProvider);
        }
        if job.state != JobState::Funded {
            return Err(EscrowError::InvalidState);
        }
        if job.open_children > 0 {
            return Err(EscrowError::ChildrenOpen);
        }
        let now = e.ledger().timestamp();
        if now >= job.expired_at {
            return Err(EscrowError::JobExpired);
        }
        let approval_deadline = now.saturating_add(Self::approval_window(e));
        if approval_deadline >= job.expired_at {
            return Err(EscrowError::SubmitTooLate);
        }
        job.state = JobState::Submitted;
        job.deliverable = Some(deliverable.clone());
        job.submitted_at = now;
        job.approval_deadline = approval_deadline;
        save_job(e, job_id, &job);
        JobSubmitted {
            job_id,
            provider: caller,
            deliverable,
            approval_deadline,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Evaluator only. Pays `budget - fee` to the provider and `fee` to the treasury.
    /// A payout whose transfer fails is credited as claimable (see `withdraw`); the job
    /// is `Completed` either way.
    pub fn complete(
        e: &Env,
        caller: Address,
        job_id: u64,
        reason: BytesN<32>,
    ) -> Result<(), EscrowError> {
        caller.require_auth();
        let job = load_job(e, job_id)?;
        if caller != job.evaluator {
            return Err(EscrowError::NotEvaluator);
        }
        if job.state != JobState::Submitted {
            return Err(EscrowError::InvalidState);
        }
        settle(e, job_id, job, reason, false)
    }

    /// Anyone, no authorization. Pays the provider once `approval_deadline` has passed.
    /// Failed payouts become claimable balances exactly as in `complete`.
    pub fn release(e: &Env, job_id: u64) -> Result<(), EscrowError> {
        let job = load_job(e, job_id)?;
        if job.state != JobState::Submitted {
            return Err(EscrowError::InvalidState);
        }
        if e.ledger().timestamp() < job.approval_deadline {
            return Err(EscrowError::ApprovalWindowOpen);
        }
        settle(e, job_id, job, BytesN::from_array(e, &[0; 32]), true)
    }

    /// Final. `Open`: the client cancels. `Funded` and `Submitted` (before
    /// `approval_deadline`): the evaluator rejects with a full refund and no fee.
    pub fn reject(
        e: &Env,
        caller: Address,
        job_id: u64,
        reason: BytesN<32>,
    ) -> Result<(), EscrowError> {
        caller.require_auth();
        let mut job = load_job(e, job_id)?;
        let from_state = job.state;
        let refunded = match from_state {
            JobState::Open => {
                if caller != job.client {
                    return Err(EscrowError::NotClient);
                }
                0
            }
            JobState::Funded => {
                if caller != job.evaluator {
                    return Err(EscrowError::NotEvaluator);
                }
                job.budget
            }
            JobState::Submitted => {
                if caller != job.evaluator {
                    return Err(EscrowError::NotEvaluator);
                }
                if e.ledger().timestamp() >= job.approval_deadline {
                    return Err(EscrowError::ApprovalWindowClosed);
                }
                job.budget
            }
            _ => return Err(EscrowError::InvalidState),
        };
        job.state = JobState::Rejected;
        let reserve = take_reserve(&mut job);
        save_job(e, job_id, &job);
        drop_job_treasury(e, job_id);
        if refunded > 0 {
            refund_exit(e, job_id, &job, reserve)?;
        }
        JobRejected {
            job_id,
            rejector: caller,
            reason,
            from_state,
            refunded,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Anyone, no authorization. Refunds a `Funded` job at or after `expired_at`.
    /// Deliberately `Funded` only: a `Submitted` job is never refundable, so a silent
    /// client cannot wait out `expired_at` and keep the deliverable (ADR-0005 D4).
    pub fn claim_refund(e: &Env, job_id: u64) -> Result<(), EscrowError> {
        let mut job = load_job(e, job_id)?;
        if job.state != JobState::Funded {
            return Err(EscrowError::InvalidState);
        }
        if e.ledger().timestamp() < job.expired_at {
            return Err(EscrowError::NotExpired);
        }
        job.state = JobState::Expired;
        let reserve = take_reserve(&mut job);
        save_job(e, job_id, &job);
        drop_job_treasury(e, job_id);
        refund_exit(e, job_id, &job, reserve)?;
        JobExpired {
            job_id,
            client: job.client,
            refunded: job.budget,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Pull payment. The caller withdraws their own claimable balance of `token`. The
    /// balance is cleared before the transfer, and a failing transfer reverts the whole
    /// call. The token allow-list is deliberately not consulted: funds must always be
    /// able to leave.
    pub fn withdraw(e: &Env, caller: Address, token: Address) -> Result<i128, EscrowError> {
        caller.require_auth();
        let key = DataKey::Claimable(caller.clone(), token.clone());
        let amount: i128 = e.storage().persistent().get(&key).unwrap_or(0);
        if amount <= 0 {
            return Err(EscrowError::NothingToWithdraw);
        }
        e.storage().persistent().remove(&key);
        TokenClient::new(e, &token).transfer(&e.current_contract_address(), &caller, &amount);
        PayoutWithdrawn {
            recipient: caller,
            token,
            amount,
        }
        .publish(e);
        extend_instance(e);
        Ok(amount)
    }

    /// Amount `recipient` can pull with `withdraw` for `token`; 0 when none.
    pub fn claimable(e: &Env, recipient: Address, token: Address) -> i128 {
        e.storage()
            .persistent()
            .get(&DataKey::Claimable(recipient, token))
            .unwrap_or(0)
    }

    pub fn get_job(e: &Env, job_id: u64) -> Result<Job, EscrowError> {
        load_job(e, job_id)
    }

    pub fn job_count(e: &Env) -> u64 {
        e.storage().instance().get(&DataKey::JobCount).unwrap_or(0)
    }

    /// True for `Expired`, and for `Open` or `Funded` jobs past `expired_at`.
    pub fn is_expired(e: &Env, job_id: u64) -> Result<bool, EscrowError> {
        let job = load_job(e, job_id)?;
        let now = e.ledger().timestamp();
        Ok(match job.state {
            JobState::Expired => true,
            JobState::Open | JobState::Funded => now >= job.expired_at,
            _ => false,
        })
    }

    pub fn is_token_allowed(e: &Env, token: Address) -> bool {
        e.storage()
            .persistent()
            .get(&DataKey::AllowedToken(token))
            .unwrap_or(false)
    }

    pub fn admin(e: &Env) -> Address {
        e.storage()
            .instance()
            .get(&DataKey::Admin)
            .unwrap_or_else(|| panic_with_error!(e, EscrowError::NotAdmin))
    }

    pub fn identity_registry(e: &Env) -> Address {
        e.storage()
            .instance()
            .get(&DataKey::IdentityRegistry)
            .unwrap_or_else(|| panic_with_error!(e, EscrowError::RegistryNotSet))
    }

    pub fn treasury(e: &Env) -> Option<Address> {
        e.storage().instance().get(&DataKey::Treasury)
    }

    pub fn fee_bps(e: &Env) -> u32 {
        e.storage().instance().get(&DataKey::FeeBps).unwrap_or(0)
    }

    pub fn max_expiry(e: &Env) -> u64 {
        e.storage().instance().get(&DataKey::MaxExpiry).unwrap_or(0)
    }

    pub fn approval_window(e: &Env) -> u64 {
        e.storage()
            .instance()
            .get(&DataKey::ApprovalWindow)
            .unwrap_or(0)
    }

    pub fn version(e: &Env) -> String {
        String::from_str(e, CONTRACT_VERSION)
    }

    /// Anyone can call it. Keeps the instance and a (possibly terminal) job readable.
    pub fn extend_ttl(e: &Env, job_id: u64) {
        extend_instance(e);
        let key = DataKey::Job(job_id);
        if e.storage().persistent().has(&key) {
            extend_persistent(e, &key);
        }
        let treasury = DataKey::JobTreasury(job_id);
        if e.storage().persistent().has(&treasury) {
            extend_persistent(e, &treasury);
        }
    }

    /// Anyone can call it. Keeps the instance and a deferred payout entry alive. It does
    /// nothing to the entry when it is absent, and never credits or moves funds.
    pub fn extend_claimable_ttl(e: &Env, recipient: Address, token: Address) {
        extend_instance(e);
        let key = DataKey::Claimable(recipient, token);
        if e.storage().persistent().has(&key) {
            extend_persistent(e, &key);
        }
    }
}

/// `fee_bps <= MAX_FEE_BPS`, and a non-zero fee needs a treasury.
fn validate_fee(fee_bps: u32, has_treasury: bool) -> Result<(), EscrowError> {
    if fee_bps > MAX_FEE_BPS {
        return Err(EscrowError::InvalidFeeBps);
    }
    if fee_bps > 0 && !has_treasury {
        return Err(EscrowError::TreasuryNotSet);
    }
    Ok(())
}

/// Both durations positive and `approval_window < max_expiry`.
/// Last ledger at which a registry change proposed at `proposed_at` can be executed.
fn registry_change_expires_at(proposed_at: u32) -> u32 {
    proposed_at
        .saturating_add(REGISTRY_TIMELOCK_LEDGERS)
        .saturating_add(REGISTRY_EXECUTION_WINDOW)
}

fn registry_change_expired(proposal: &RegistryProposal, now: u32) -> bool {
    now > registry_change_expires_at(proposal.proposed_at)
}

fn validate_limits(max_expiry: u64, approval_window: u64) -> Result<(), EscrowError> {
    if max_expiry == 0
        || approval_window == 0
        || approval_window >= max_expiry
        || max_expiry > MAX_EXPIRY_CEILING
    {
        return Err(EscrowError::InvalidDuration);
    }
    Ok(())
}

/// Checks the allow-list and keeps a used entry alive.
fn require_token_allowed(e: &Env, token: &Address) -> Result<(), EscrowError> {
    if !EscrowContract::is_token_allowed(e, token.clone()) {
        return Err(EscrowError::TokenNotAllowed);
    }
    extend_persistent(e, &DataKey::AllowedToken(token.clone()));
    Ok(())
}

fn require_admin(e: &Env, caller: &Address) -> Result<(), EscrowError> {
    caller.require_auth();
    let admin: Address = e
        .storage()
        .instance()
        .get(&DataKey::Admin)
        .ok_or(EscrowError::NotAdmin)?;
    if admin != *caller {
        return Err(EscrowError::NotAdmin);
    }
    Ok(())
}

/// Resolves the registry wallet of `agent_id` and requires it to equal `provider`.
fn verify_provider(e: &Env, agent_id: u32, provider: &Address) -> Result<(), EscrowError> {
    let registry: Address = e
        .storage()
        .instance()
        .get(&DataKey::IdentityRegistry)
        .ok_or(EscrowError::RegistryNotSet)?;
    let registry = RegistryClient::new(e, &registry);
    if !registry.agent_exists(&agent_id) {
        return Err(EscrowError::AgentNotFound);
    }
    match registry.get_agent_wallet(&agent_id) {
        None => Err(EscrowError::AgentWalletNotSet),
        Some(wallet) if wallet != *provider => Err(EscrowError::ProviderMismatch),
        Some(_) => Ok(()),
    }
}

/// `floor(budget * fee_bps / 10_000)` without an intermediate product that can
/// overflow: `(budget / D) * bps + (budget % D) * bps / D`. Exact for `bps <= D`, and
/// the result never exceeds `budget`.
fn compute_fee(budget: i128, fee_bps: u32) -> i128 {
    let denominator = i128::from(BPS_DENOMINATOR);
    let bps = i128::from(fee_bps);
    (budget / denominator) * bps + (budget % denominator) * bps / denominator
}

/// Shared by `complete` and `release`. State is written before any transfer. Each
/// payout (provider, treasury) is attempted independently; a failed one is credited as
/// a claimable balance, so settlement cannot get stuck on a recipient that cannot
/// receive the token.
fn settle(
    e: &Env,
    job_id: u64,
    mut job: Job,
    reason: BytesN<32>,
    auto_released: bool,
) -> Result<(), EscrowError> {
    let fee = compute_fee(job.budget, job.fee_bps);
    let payout = job.budget - fee;
    // The treasury snapshotted at `fund`. A job without a snapshot falls back to the
    // current treasury.
    let snapshot_key = DataKey::JobTreasury(job_id);
    let snapshot: Option<Address> = e.storage().persistent().get(&snapshot_key);
    let treasury = if fee > 0 {
        Some(
            snapshot
                .or_else(|| EscrowContract::treasury(e))
                .ok_or(EscrowError::TreasuryNotSet)?,
        )
    } else {
        None
    };
    drop_job_treasury(e, job_id);
    job.state = JobState::Completed;
    let reserve = take_reserve(&mut job);
    save_job(e, job_id, &job);
    if payout > 0 {
        pay_or_defer(e, job_id, &job.token, &job.provider, payout)?;
    }
    if let Some(treasury) = treasury {
        pay_or_defer(e, job_id, &job.token, &treasury, fee)?;
    }
    // ADR-0011 D3/D4: the budget is paid; only the unspent reserve goes back. A
    // child's goes up its tree and is final for its provider; a consumer's job
    // refunds it to the client with the same pull-payment fallback as payouts.
    if job.parent_job_id.is_some() {
        close_child(e, job_id, &job, reserve)?;
    } else if reserve > 0 {
        let deferred = pay_or_defer(e, job_id, &job.token, &job.client, reserve)?;
        ReserveRefunded {
            job_id,
            client: job.client.clone(),
            amount: reserve,
            deferred,
        }
        .publish(e);
    }
    JobCompleted {
        job_id,
        evaluator: job.evaluator,
        reason,
        payout,
        fee,
        auto_released,
    }
    .publish(e);
    extend_instance(e);
    Ok(())
}

/// Pays `recipient` from the escrow. Both failure layers of the token call (host error
/// and contract error) fall back to a claimable credit and a `PayoutDeferred` event.
/// Returns true when the amount was deferred.
fn pay_or_defer(
    e: &Env,
    job_id: u64,
    token: &Address,
    recipient: &Address,
    amount: i128,
) -> Result<bool, EscrowError> {
    let sent =
        TokenClient::new(e, token).try_transfer(&e.current_contract_address(), recipient, &amount);
    if matches!(sent, Ok(Ok(()))) {
        return Ok(false);
    }
    let key = DataKey::Claimable(recipient.clone(), token.clone());
    let current: i128 = e.storage().persistent().get(&key).unwrap_or(0);
    let credited = current
        .checked_add(amount)
        .ok_or(EscrowError::ArithmeticOverflow)?;
    e.storage().persistent().set(&key, &credited);
    extend_persistent(e, &key);
    PayoutDeferred {
        job_id,
        recipient: recipient.clone(),
        token: token.clone(),
        amount,
    }
    .publish(e);
    Ok(true)
}

/// Removes the treasury snapshotted at `fund`: a settled or refunded job pays no fee
/// any more.
fn drop_job_treasury(e: &Env, job_id: u64) {
    e.storage()
        .persistent()
        .remove(&DataKey::JobTreasury(job_id));
}

/// Shared by `fund` and `fund_with_reserve`. With `reserve == 0` it is the original
/// `fund`: the same checks, storage, transfer and single `JobFunded` event.
fn fund_job(
    e: &Env,
    caller: Address,
    job_id: u64,
    expected_budget: i128,
    reserve: i128,
    max_fee_bps: u32,
) -> Result<(), EscrowError> {
    caller.require_auth();
    let mut job = load_job(e, job_id)?;
    if caller != job.client {
        return Err(EscrowError::NotClient);
    }
    if job.state != JobState::Open {
        return Err(EscrowError::InvalidState);
    }
    if e.ledger().timestamp() >= job.expired_at {
        return Err(EscrowError::JobExpired);
    }
    if expected_budget != job.budget {
        return Err(EscrowError::BudgetMismatch);
    }
    if reserve < 0 {
        return Err(EscrowError::InvalidAmount);
    }
    let total = job
        .budget
        .checked_add(reserve)
        .ok_or(EscrowError::ArithmeticOverflow)?;
    let fee_bps = EscrowContract::fee_bps(e);
    if fee_bps > max_fee_bps {
        return Err(EscrowError::FeeExceedsMax);
    }
    require_token_allowed(e, &job.token)?;
    job.fee_bps = fee_bps;
    job.state = JobState::Funded;
    job.reserve = reserve;
    job.reserve_funded = reserve;
    save_job(e, job_id, &job);
    if fee_bps > 0 {
        snapshot_treasury(e, job_id)?;
    }
    TokenClient::new(e, &job.token).transfer(&job.client, e.current_contract_address(), &total);
    JobFunded {
        job_id,
        client: job.client.clone(),
        amount: job.budget,
        fee_bps: job.fee_bps,
    }
    .publish(e);
    if reserve > 0 {
        ReserveFunded {
            job_id,
            client: job.client,
            reserve,
        }
        .publish(e);
    }
    extend_instance(e);
    Ok(())
}

/// Records the current treasury for a job with a fee: a later `set_treasury` must not
/// redirect this job's fee (audit E-3).
fn snapshot_treasury(e: &Env, job_id: u64) -> Result<(), EscrowError> {
    let treasury = EscrowContract::treasury(e).ok_or(EscrowError::TreasuryNotSet)?;
    let key = DataKey::JobTreasury(job_id);
    e.storage().persistent().set(&key, &treasury);
    extend_persistent(e, &key);
    Ok(())
}

/// Zeroes the unspent reserve of a closing job and returns it. `reserve_funded` stays.
fn take_reserve(job: &mut Job) -> i128 {
    core::mem::replace(&mut job.reserve, 0)
}

/// The refund exit of `reject` and `claim_refund`, never to the caller and with no
/// fee. A consumer's job returns `budget` plus the unspent `reserve` to its client in
/// one transfer, as `fund` pulled them. A child job returns both up its tree
/// (ADR-0011 D3): the reserve is never its client's (agent A's) money.
fn refund_exit(e: &Env, job_id: u64, job: &Job, reserve: i128) -> Result<(), EscrowError> {
    let amount = job
        .budget
        .checked_add(reserve)
        .ok_or(EscrowError::ArithmeticOverflow)?;
    if job.parent_job_id.is_some() {
        return close_child(e, job_id, job, amount);
    }
    TokenClient::new(e, &job.token).transfer(&e.current_contract_address(), &job.client, &amount);
    if reserve > 0 {
        ReserveRefunded {
            job_id,
            client: job.client.clone(),
            amount: reserve,
            deferred: false,
        }
        .publish(e);
    }
    Ok(())
}

/// A child job reached a terminal state: its parent has one open child less, and
/// `amount` (refunded budget and unspent sub-reserve) goes back up the tree.
fn close_child(e: &Env, child_job_id: u64, child: &Job, amount: i128) -> Result<(), EscrowError> {
    let Some(parent_job_id) = child.parent_job_id else {
        return Ok(());
    };
    let mut parent = load_job(e, parent_job_id)?;
    parent.open_children = parent
        .open_children
        .checked_sub(1)
        .ok_or(EscrowError::ArithmeticOverflow)?;
    if amount > 0 && parent.state == JobState::Funded {
        return credit_reserve(e, child_job_id, parent_job_id, parent, amount);
    }
    save_job(e, parent_job_id, &parent);
    if amount > 0 {
        return_up_tree(e, child_job_id, parent_job_id, parent, amount)?;
    }
    Ok(())
}

/// Adds `amount` to the reserve of a `Funded` job, which may spend it on another child.
fn credit_reserve(
    e: &Env,
    child_job_id: u64,
    job_id: u64,
    mut job: Job,
    amount: i128,
) -> Result<(), EscrowError> {
    job.reserve = job
        .reserve
        .checked_add(amount)
        .ok_or(EscrowError::ArithmeticOverflow)?;
    save_job(e, job_id, &job);
    ReserveReturned {
        parent_job_id: job_id,
        child_job_id,
        amount,
        to_client: false,
    }
    .publish(e);
    Ok(())
}

/// `job` is closed, so it no longer holds a reserve. `amount` goes to the nearest
/// ancestor still `Funded`, or, when none is, to the client of the root job with the
/// pull-payment fallback, so a child's exit never depends on the consumer being able
/// to receive (ADR-0011 D3, closed parent exception). It walks at most `MAX_DEPTH`
/// ancestors: parent ids always precede their children's.
fn return_up_tree(
    e: &Env,
    child_job_id: u64,
    mut job_id: u64,
    mut job: Job,
    amount: i128,
) -> Result<(), EscrowError> {
    loop {
        match job.parent_job_id {
            None => {
                pay_or_defer(e, job_id, &job.token, &job.client, amount)?;
                ReserveReturned {
                    parent_job_id: job_id,
                    child_job_id,
                    amount,
                    to_client: true,
                }
                .publish(e);
                return Ok(());
            }
            Some(up) => {
                let ancestor = load_job(e, up)?;
                if ancestor.state == JobState::Funded {
                    return credit_reserve(e, child_job_id, up, ancestor, amount);
                }
                job_id = up;
                job = ancestor;
            }
        }
    }
}

/// ADR-0011 D5: neither `provider` nor `agent_id` may already be the provider of a
/// job in the ancestor chain that starts at `parent`, the root included. Reads at
/// most `MAX_DEPTH` jobs.
fn require_no_cycle(
    e: &Env,
    parent: &Job,
    provider: &Address,
    agent_id: u32,
) -> Result<(), EscrowError> {
    let mut ancestor = parent.clone();
    loop {
        if ancestor.provider == *provider || ancestor.agent_id == agent_id {
            return Err(EscrowError::SubcontractCycle);
        }
        match ancestor.parent_job_id {
            None => return Ok(()),
            Some(up) => ancestor = load_job(e, up)?,
        }
    }
}

fn next_job_id(e: &Env) -> u64 {
    let id = EscrowContract::job_count(e) + 1;
    e.storage().instance().set(&DataKey::JobCount, &id);
    id
}

fn load_job(e: &Env, job_id: u64) -> Result<Job, EscrowError> {
    e.storage()
        .persistent()
        .get(&DataKey::Job(job_id))
        .ok_or(EscrowError::JobNotFound)
}

fn save_job(e: &Env, job_id: u64, job: &Job) {
    let key = DataKey::Job(job_id);
    e.storage().persistent().set(&key, job);
    extend_persistent(e, &key);
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
