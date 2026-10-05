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

const CONTRACT_VERSION: &str = "0.1.0";

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

    /// Admin only. The treasury is read at settlement time.
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

    /// Admin only. Only `create_job` consults the registry, so in-flight jobs are unaffected.
    pub fn set_identity_registry(
        e: &Env,
        caller: Address,
        registry: Address,
    ) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        e.storage()
            .instance()
            .set(&DataKey::IdentityRegistry, &registry);
        RegistryUpdated { registry }.publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Admin only. The admin configures the contract and has no power over job funds.
    pub fn set_admin(e: &Env, caller: Address, new_admin: Address) -> Result<(), EscrowError> {
        require_admin(e, &caller)?;
        e.storage().instance().set(&DataKey::Admin, &new_admin);
        AdminChanged {
            old_admin: caller,
            new_admin,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
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
        let fee_bps = Self::fee_bps(e);
        if fee_bps > max_fee_bps {
            return Err(EscrowError::FeeExceedsMax);
        }
        require_token_allowed(e, &job.token)?;
        job.fee_bps = fee_bps;
        job.state = JobState::Funded;
        save_job(e, job_id, &job);
        TokenClient::new(e, &job.token).transfer(
            &job.client,
            e.current_contract_address(),
            &job.budget,
        );
        JobFunded {
            job_id,
            client: job.client,
            amount: job.budget,
            fee_bps: job.fee_bps,
        }
        .publish(e);
        extend_instance(e);
        Ok(())
    }

    /// Provider only. Starts the approval window; it must close before the job expires.
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
        save_job(e, job_id, &job);
        if refunded > 0 {
            refund_client(e, &job);
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
        save_job(e, job_id, &job);
        refund_client(e, &job);
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
fn validate_limits(max_expiry: u64, approval_window: u64) -> Result<(), EscrowError> {
    if max_expiry == 0 || approval_window == 0 || approval_window >= max_expiry {
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
    let treasury = if fee > 0 {
        Some(EscrowContract::treasury(e).ok_or(EscrowError::TreasuryNotSet)?)
    } else {
        None
    };
    job.state = JobState::Completed;
    save_job(e, job_id, &job);
    if payout > 0 {
        pay_or_defer(e, job_id, &job.token, &job.provider, payout)?;
    }
    if let Some(treasury) = treasury {
        pay_or_defer(e, job_id, &job.token, &treasury, fee)?;
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
fn pay_or_defer(
    e: &Env,
    job_id: u64,
    token: &Address,
    recipient: &Address,
    amount: i128,
) -> Result<(), EscrowError> {
    let sent =
        TokenClient::new(e, token).try_transfer(&e.current_contract_address(), recipient, &amount);
    if matches!(sent, Ok(Ok(()))) {
        return Ok(());
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
    Ok(())
}

/// Returns the full budget to the stored client, never to the caller. No fee.
fn refund_client(e: &Env, job: &Job) {
    TokenClient::new(e, &job.token).transfer(
        &e.current_contract_address(),
        &job.client,
        &job.budget,
    );
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
