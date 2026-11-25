import { randomUUID } from 'node:crypto';

import {
  ChainSubmissionFailed,
  InvalidArgument,
  Puls3ProtocolError,
  Puls3Timeout,
  SessionRequired,
  SignerRequired,
  SigningRefused,
} from './errors.js';
import {
  checkPreparedAuthorization,
  checkPreparedTransaction,
  type Expectation,
} from './guard.js';
import { SorobanRpcReader, type ChainReader } from './chain_reader.js';
import { KeySession } from './key_session.js';
import { TESTNET, type Puls3Network } from './network.js';
import type { Puls3Signer } from './signer.js';
import {
  decodeDeploySession,
  encodeAgentManifestDraft,
  type AgentManifestDraft,
  type DeploySession,
  decodeAgentHireStarted,
  decodeAgentSummaries,
  decodeAgentSummary,
  decodeCreateHireResult,
  decodeHireDetail,
  decodeHireSummaries,
  decodePreparedTransaction,
  decodeStudioDraft,
  decodeStudioDrafts,
  decodeTestRunResult,
  type AgentHireStarted,
  type AgentSummary,
  type CreateHireResult,
  type HireDetail,
  type HireSummary,
  type PreparedTransaction,
  type StudioDraft,
  type TestRunResult,
} from './models.js';
import { HttpTransport, type AuthProvider, type Transport } from './transport.js';

export interface ConnectOptions {
  /**
   * Authenticates the hire and Studio calls as the wallet that owns it, for
   * example a [CliSession]. Without it only the catalog works.
   */
  session?: AuthProvider;
  /**
   * Signs the wallet's transactions after checking each one (ADR-0010). With
   * a signer and no [session], the SDK signs in by itself (SEP-10).
   */
  signer?: Puls3Signer;
  /** The chain and contracts the SDK signs for. Defaults to [TESTNET]. */
  network?: Puls3Network;
  /** For tests and other runtimes. Defaults to the global `fetch`. */
  fetch?: typeof fetch;
  /** Per request. Defaults to 20 seconds. */
  timeoutMs?: number;
  /** How often a flow reads the chain state again. Defaults to 3 seconds. */
  pollIntervalMs?: number;
  /** How long a flow waits for one transaction. Defaults to 3 minutes. */
  stepTimeoutMs?: number;
  /**
   * Reads the chain for the checks that must not trust the server (an
   * agent's registered wallet, the latest ledger). Defaults to the
   * network's Soroban RPC ([Puls3Network.rpcUrl]).
   */
  chain?: ChainReader;
}

/** What [Puls3Sdk]'s constructor takes besides its transport. */
export interface SdkOptions {
  /** Whether the transport authenticates as a wallet. */
  hasSession: boolean;
  /** Signs after the checks of ADR-0010 D3. Without it the flows throw [SignerRequired]. */
  signer?: Puls3Signer;
  network?: Puls3Network;
  pollIntervalMs?: number;
  stepTimeoutMs?: number;
  /** For tests: the clock the checks and the waits use. */
  now?: () => Date;
  /** For tests: how a flow waits between two reads. */
  sleep?: (ms: number) => Promise<void>;
  /** See [ConnectOptions.chain]. Defaults to the network's Soroban RPC. */
  chain?: ChainReader;
}

/**
 * The puls3 API for TypeScript and JavaScript programs (#302), with the
 * calls, names and error codes of the Dart SDK `puls3_sdk`.
 *
 * Server errors reach the caller as [Puls3ApiError] with the server's code
 * (`HireNotFound`, `InvalidHireTransition`, `AgentCatalogUnavailable`, ...).
 *
 * The catalog needs no session. Hire and Studio calls act for a wallet, so
 * they need its session: without one they throw [SessionRequired] and send
 * nothing. Arguments the server would refuse throw [InvalidArgument], also
 * without sending anything.
 *
 * With a [Puls3Signer] the SDK also signs, as ADR-0010 decides: the flows
 * [deploy], [hire], [approve], [reject] and [rate] sign what the server
 * prepares, after checking each envelope, and submit it. Agent custody does
 * not change: the agent's own transactions and [hireAgentAs] are signed by
 * the server.
 */
export class Puls3Sdk {
  readonly #transport: Transport;
  readonly #hasSession: boolean;
  readonly #signer: Puls3Signer | null;
  readonly #network: Puls3Network;
  readonly #pollMs: number;
  readonly #stepMs: number;
  readonly #now: () => Date;
  readonly #sleep: (ms: number) => Promise<void>;
  readonly #chain: ChainReader | null;

  /** An SDK over any [Transport], for tests and other runtimes. */
  constructor(transport: Transport, options: SdkOptions) {
    this.#transport = transport;
    this.#hasSession = options.hasSession;
    this.#signer = options.signer ?? null;
    this.#network = options.network ?? TESTNET;
    this.#pollMs = options.pollIntervalMs ?? 3_000;
    this.#stepMs = options.stepTimeoutMs ?? 180_000;
    this.#now = options.now ?? (() => new Date());
    this.#sleep = options.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
    const signer = this.#signer;
    this.#chain =
      options.chain ??
      (signer === null ? null : new SorobanRpcReader(this.#network, signer.publicKey()));
  }

  /**
   * Connects to the puls3 server at [apiUrl], for example
   * `https://puls3-hub-on-stellar.api.serverpod.space/`.
   *
   * With a [ConnectOptions.signer] and no [ConnectOptions.session], the SDK
   * signs in as the signer's wallet on the first call that needs it.
   *
   * Throws a `TypeError` unless [apiUrl] is an absolute `http` or `https`
   * URL with no query or fragment.
   */
  static connect(apiUrl: string, options: ConnectOptions = {}): Puls3Sdk {
    const network = options.network ?? TESTNET;
    const base = {
      ...(options.fetch === undefined ? {} : { fetch: options.fetch }),
      ...(options.timeoutMs === undefined ? {} : { timeoutMs: options.timeoutMs }),
    };
    let auth = options.session;
    if (auth === undefined && options.signer !== undefined) {
      auth = new KeySession(new HttpTransport(apiUrl, base), options.signer, network);
    }
    const transport = new HttpTransport(apiUrl, {
      ...base,
      ...(auth === undefined ? {} : { auth }),
    });
    return new Puls3Sdk(transport, {
      hasSession: auth !== undefined,
      network,
      ...(options.signer === undefined ? {} : { signer: options.signer }),
      ...(options.pollIntervalMs === undefined ? {} : { pollIntervalMs: options.pollIntervalMs }),
      ...(options.stepTimeoutMs === undefined ? {} : { stepTimeoutMs: options.stepTimeoutMs }),
      ...(options.chain === undefined ? {} : { chain: options.chain }),
    });
  }

  /** The signer's wallet, or null without a signer. */
  get wallet(): string | null {
    return this.#signer?.publicKey() ?? null;
  }

  /** Whether the hire and Studio calls have a session to use. */
  get hasSession(): boolean {
    return this.#hasSession;
  }

  // --- Catalog (no session) ----------------------------------------------

  /** Every agent in the catalog (`agent.list`). */
  async listAgents(): Promise<AgentSummary[]> {
    return decodeAgentSummaries(
      await this.#transport.call('agent', 'list', {}, { authenticated: false }),
    );
  }

  /**
   * One agent by its metadata id, for example `agt-001` (`agent.get`).
   * Null for an unknown id.
   */
  async getAgent(id: string): Promise<AgentSummary | null> {
    requireText('id', id);
    const value = await this.#transport.call('agent', 'get', { id }, { authenticated: false });
    return value === null ? null : decodeAgentSummary(value);
  }

  // --- Hires (session) ----------------------------------------------------

  /**
   * Starts a hire of [agentId] (the agent's `registryId`) for [consumer]
   * with [input] (`hire.createHire`). Returns the persisted hire and, when
   * available, its unsigned `create_job`.
   *
   * [requestId] is the idempotency key: repeating it for the same
   * [consumer] returns the same hire, so a retry is safe. It is opaque and
   * sent exactly as given, so `" req-1 "` and `"req-1"` are two keys.
   * [consumer] must be the session wallet's address; it is trimmed.
   */
  async createHire(
    agentId: number,
    consumer: string,
    input: string,
    requestId: string,
  ): Promise<CreateHireResult> {
    requireInt('agentId', agentId, 0);
    requireText('consumer', consumer);
    requireText('input', input);
    requireText('requestId', requestId);
    return decodeCreateHireResult(
      await this.#call('createHire', 'hire', 'createHire', {
        agentId,
        consumer: consumer.trim(),
        input,
        requestId,
        subcontractReserve: null,
        allowRelatedParty: null,
      }),
    );
  }

  /** Hire [hireId] of [consumer], the session wallet's address (`hire.getHire`). */
  async getHire(hireId: number, consumer: string): Promise<HireDetail> {
    requireInt('hireId', hireId, 1);
    requireText('consumer', consumer);
    return decodeHireDetail(
      await this.#call('getHire', 'hire', 'getHire', { hireId, consumer: consumer.trim() }),
    );
  }

  /**
   * The session wallet's hires, newest first, including those its Studio
   * agents paid for (`hire.listMyHires`).
   */
  async listMyHires(): Promise<HireSummary[]> {
    return decodeHireSummaries(await this.#call('listMyHires', 'hire', 'listMyHires', {}));
  }

  /** A fresh unsigned `create_job` for [hireId] (`hire.prepareCreateJob`). */
  async prepareCreateJob(hireId: number): Promise<PreparedTransaction> {
    return this.#prepare('prepareCreateJob', hireId);
  }

  /** The unsigned `fund` of hire [hireId] (`hire.prepareFund`). */
  async prepareFund(hireId: number): Promise<PreparedTransaction> {
    return this.#prepare('prepareFund', hireId);
  }

  /** The unsigned `complete` of hire [hireId] (`hire.prepareComplete`). */
  async prepareComplete(hireId: number): Promise<PreparedTransaction> {
    return this.#prepare('prepareComplete', hireId);
  }

  /** The unsigned `reject` of hire [hireId] with [reason], trimmed (`hire.prepareReject`). */
  async prepareReject(hireId: number, reason: string): Promise<PreparedTransaction> {
    requireInt('hireId', hireId, 1);
    requireText('reason', reason);
    return decodePreparedTransaction(
      await this.#call('prepareReject', 'hire', 'prepareReject', {
        hireId,
        reason: reason.trim(),
      }),
    );
  }

  // --- Studio (session) ---------------------------------------------------

  /** The session wallet's drafts (`studio.listDrafts`). */
  async listDrafts(): Promise<StudioDraft[]> {
    return decodeStudioDrafts(await this.#call('listDrafts', 'studio', 'listDrafts', {}));
  }

  /** The session wallet's draft [draftId] (`studio.getDraft`). */
  async getDraft(draftId: number): Promise<StudioDraft> {
    requireInt('draftId', draftId, 1);
    return decodeStudioDraft(await this.#call('getDraft', 'studio', 'getDraft', { draftId }));
  }

  /**
   * Runs the session wallet's saved draft [draftId] once on [input], exactly
   * as given (`studio.testRun`). No hire and no payment.
   */
  async testRun(draftId: number, input: string): Promise<TestRunResult> {
    requireInt('draftId', draftId, 1);
    requireText('input', input);
    return decodeTestRunResult(
      await this.#call('testRun', 'studio', 'testRun', { draftId, input }),
    );
  }

  /**
   * Makes the session wallet's live Studio agent [hiringAgentId] hire
   * [agentId] on [input], paying at most [budgetUsdcStroops] from the
   * agent's custodied wallet (`studio.hireAgentAs`, #312). The server signs
   * the agent's transactions; this SDK signs nothing. Returns once the hire
   * exists.
   */
  async hireAgentAs(
    hiringAgentId: number,
    agentId: number,
    input: string,
    budgetUsdcStroops: number,
  ): Promise<AgentHireStarted> {
    requireInt('hiringAgentId', hiringAgentId, 0);
    requireInt('agentId', agentId, 0);
    requireText('input', input);
    requireInt('budgetUsdcStroops', budgetUsdcStroops, 1);
    return decodeAgentHireStarted(
      await this.#call('hireAgentAs', 'studio', 'hireAgentAs', {
        hiringAgentId,
        agentId,
        input,
        budgetUsdcStroops,
      }),
    );
  }

  /** Hire [hireId] that the session wallet's agent [hiringAgentId] made (`studio.getAgentHire`). */
  async getAgentHire(hiringAgentId: number, hireId: number): Promise<HireDetail> {
    requireInt('hiringAgentId', hiringAgentId, 0);
    requireInt('hireId', hireId, 1);
    return decodeHireDetail(
      await this.#call('getAgentHire', 'studio', 'getAgentHire', { hiringAgentId, hireId }),
    );
  }

  // --- Studio drafts and deploy (session) ---------------------------------

  /**
   * Creates a draft, or saves a new revision of [options.draftId]
   * (`studio.saveDraft`). [options.revision] must be the revision last read,
   * unless [options.overwrite] is true. The server validates the manifest
   * and answers `InvalidManifest` with the problems in `details`.
   */
  async saveDraft(
    draft: Partial<AgentManifestDraft>,
    options: { draftId?: number; revision?: number; overwrite?: boolean } = {},
  ): Promise<StudioDraft> {
    if (options.draftId !== undefined) requireInt('draftId', options.draftId, 1);
    if (options.revision !== undefined) requireInt('revision', options.revision, 0);
    return decodeStudioDraft(
      await this.#call('saveDraft', 'studio', 'saveDraft', {
        draft: encodeAgentManifestDraft(draft),
        draftId: options.draftId ?? null,
        revision: options.revision ?? null,
        overwrite: options.overwrite ?? null,
      }),
    );
  }

  /**
   * Starts or resumes the deploy of [draftId] for [builder], the session
   * wallet (`studio.prepareDeploy`, F4-4 to F4-6). It creates the agent's
   * custodied wallet and prepares `register_full`.
   */
  async prepareDeploy(draftId: number, builder: string): Promise<DeploySession> {
    requireInt('draftId', draftId, 1);
    requireText('builder', builder);
    return decodeDeploySession(
      await this.#call('prepareDeploy', 'studio', 'prepareDeploy', { draftId, builder: builder.trim() }),
    );
  }

  /** Submits the builder-signed `register_full` (`studio.submitRegistration`). */
  async submitRegistration(
    draftId: number,
    preparationId: string,
    signedTransactionXdr: string,
  ): Promise<DeploySession> {
    requireInt('draftId', draftId, 1);
    requireText('preparationId', preparationId);
    requireText('signedTransactionXdr', signedTransactionXdr);
    return decodeDeploySession(
      await this.#call('submitRegistration', 'studio', 'submitRegistration', {
        draftId,
        preparationId,
        signedTransactionXdr,
      }),
    );
  }

  /** The current deploy of [draftId] (`studio.getDeploySession`). */
  async getDeploySession(draftId: number): Promise<DeploySession> {
    requireInt('draftId', draftId, 1);
    return decodeDeploySession(
      await this.#call('getDeploySession', 'studio', 'getDeploySession', { draftId }),
    );
  }

  /** Prepares the builder's `set_agent_wallet` entry (`studio.prepareWalletAuthorization`, F4-7). */
  async prepareWalletAuthorization(draftId: number): Promise<DeploySession> {
    requireInt('draftId', draftId, 1);
    return decodeDeploySession(
      await this.#call('prepareWalletAuthorization', 'studio', 'prepareWalletAuthorization', {
        draftId,
      }),
    );
  }

  /** Submits the signed `set_agent_wallet` entry (`studio.submitWalletAuthorization`). */
  async submitWalletAuthorization(
    draftId: number,
    preparationId: string,
    signedAuthorizationEntryXdr: string,
  ): Promise<DeploySession> {
    requireInt('draftId', draftId, 1);
    requireText('preparationId', preparationId);
    requireText('signedAuthorizationEntryXdr', signedAuthorizationEntryXdr);
    return decodeDeploySession(
      await this.#call('submitWalletAuthorization', 'studio', 'submitWalletAuthorization', {
        draftId,
        preparationId,
        signedAuthorizationEntryXdr,
      }),
    );
  }

  // --- Signed submissions (session) ---------------------------------------

  /** Submits a wallet-signed escrow call of [hireId] (`hire.submitEscrowCall`). */
  async submitEscrowCall(
    hireId: number,
    preparationId: string,
    signedTransactionXdr: string,
  ): Promise<HireDetail> {
    requireInt('hireId', hireId, 1);
    requireText('preparationId', preparationId);
    requireText('signedTransactionXdr', signedTransactionXdr);
    return decodeHireDetail(
      await this.#call('submitEscrowCall', 'hire', 'submitEscrowCall', {
        hireId,
        preparationId,
        signedTransactionXdr,
      }),
    );
  }

  /** Prepares the client's `give_feedback` of [hireId], [score] 1 to 5 (`feedback.prepareFeedback`). */
  async prepareFeedback(hireId: number, score: number, comment: string): Promise<PreparedTransaction> {
    requireInt('hireId', hireId, 1);
    if (!Number.isSafeInteger(score) || score < 1 || score > 5) {
      throw new InvalidArgument('score', 'must be an integer from 1 to 5');
    }
    return decodePreparedTransaction(
      await this.#call('prepareFeedback', 'feedback', 'prepareFeedback', { hireId, score, comment }),
    );
  }

  /** Submits the signed `give_feedback` (`feedback.submitFeedback`). */
  async submitFeedback(
    hireId: number,
    preparationId: string,
    signedTransactionXdr: string,
  ): Promise<HireDetail> {
    requireInt('hireId', hireId, 1);
    requireText('preparationId', preparationId);
    requireText('signedTransactionXdr', signedTransactionXdr);
    return decodeHireDetail(
      await this.#call('submitFeedback', 'feedback', 'submitFeedback', {
        hireId,
        preparationId,
        signedTransactionXdr,
      }),
    );
  }

  // --- Flows that sign (signer, ADR-0010) ----------------------------------

  /**
   * Deploys the session wallet's draft [draftId] as an agent with its own
   * on-chain identity and wallet (F4-4 to F4-8): the server creates the
   * custodied agent wallet, the signer signs `register_full` and the
   * `set_agent_wallet` entry, and the server publishes the agent.
   *
   * Resumes a deploy that stopped halfway. Returns the `active` session,
   * with [DeploySession.agentId] and [DeploySession.agentWallet]. Throws
   * [ChainSubmissionFailed] when the deploy ends `failed`.
   */
  async deploy(
    draftId: number,
    options: { onState?: (session: DeploySession) => void } = {},
  ): Promise<DeploySession> {
    const signer = this.#requireSigner('deploy');
    const wallet = signer.publicKey();
    let session = await this.prepareDeploy(draftId, wallet);
    let deadline = this.#deadline();
    for (;;) {
      options.onState?.(session);
      switch (session.state) {
        case 'active':
          return session;
        case 'failed':
          throw new ChainSubmissionFailed('deploy', session.failureCode);
        case 'awaitingRegistrationSignature': {
          const prepared = session.preparation;
          if (prepared === null || prepared.expiresAt.getTime() <= this.#now().getTime()) {
            await this.#wait(deadline, 'a fresh register_full');
            session = await this.prepareDeploy(draftId, wallet);
            continue;
          }
          const envelope = checkPreparedTransaction(
            prepared,
            { purpose: 'registerFull' },
            wallet,
            this.#network,
            this.#now(),
          );
          const signed = await signer.signTransaction(envelope, this.#network.passphrase);
          session = await this.submitRegistration(draftId, prepared.preparationId, signed);
          deadline = this.#deadline();
          continue;
        }
        case 'awaitingWalletAuthorization': {
          const authorizing = await this.prepareWalletAuthorization(draftId);
          const prepared = authorizing.preparation;
          const agentId = authorizing.agentId ?? session.agentId;
          const agentWallet = authorizing.agentWallet ?? session.agentWallet;
          if (prepared === null || agentId === null || agentWallet === null) {
            throw new Puls3ProtocolError(
              'The server prepared no wallet authorization, or no agent id and wallet',
            );
          }
          const { entryXdr, validUntilLedger } = checkPreparedAuthorization(
            prepared,
            { agentId, agentWallet },
            wallet,
            this.#network,
            await this.#requireChain().latestLedger(),
            this.#now(),
          );
          const signed = await signer.signAuthEntry(entryXdr, validUntilLedger, this.#network.passphrase);
          session = await this.submitWalletAuthorization(draftId, prepared.preparationId, signed);
          deadline = this.#deadline();
          continue;
        }
        default:
          // registrationSubmitted, walletAuthorizationSubmitted, publishing.
          await this.#wait(deadline, `the deploy (${session.state})`);
          session = await this.getDeploySession(draftId);
      }
    }
  }

  /**
   * Hires [agentId] (its `registryId`) on [input] and pays it: the signer
   * signs `create_job` and then `fund`, each after checking it moves at most
   * [options.maxPrice] USDC stroops into the escrow, and the SDK waits for
   * each on chain. Returns the hire once it is `funded`; the agent then
   * works on it ([waitForResult]).
   *
   * [options.requestId] is the idempotency key, so a retry with the same one
   * resumes the same hire. A new one is made when it is left out.
   */
  async hire(
    agentId: number,
    input: string,
    options: { maxPrice: number | bigint; requestId?: string; maxReserve?: number | bigint },
  ): Promise<HireDetail> {
    const signer = this.#requireSigner('hire');
    const wallet = signer.publicKey();
    const maxBudget = BigInt(options.maxPrice);
    if (maxBudget <= 0n) throw new InvalidArgument('maxPrice', 'must be above 0');
    const maxReserve = BigInt(options.maxReserve ?? 0);
    if (maxReserve < 0n) throw new InvalidArgument('maxReserve', 'must not be negative');
    const started = await this.createHire(
      agentId,
      wallet,
      input,
      options.requestId ?? `sdk-${randomUUID()}`,
    );
    const hireId = started.hire.id;
    const price = BigInt(started.hire.price);
    if (price > maxBudget) {
      throw new SigningRefused(
        'money',
        `the agent's price ${started.hire.price} is above the allowed ${maxBudget}`,
      );
    }

    let detail = await this.getHire(hireId, wallet);
    if (detail.hire.status === null) {
      // createHire returns no create_job when one was already submitted (a
      // retried requestId): wait for that one instead of preparing another.
      const createJob = started.preparedCreateJob;
      if (createJob !== null) {
        // The job must pay the wallet the Identity Registry binds to the
        // agent, read from the chain: never the one the server names.
        const provider = await this.#requireChain().agentWallet(agentId);
        if (provider === null) {
          throw new SigningRefused('money', `agent ${agentId} has no wallet on the Identity Registry`);
        }
        await this.#signEscrowCall(hireId, createJob, {
          purpose: 'createJob',
          maxBudget,
          price,
          agentId,
          provider,
        });
      }
      detail = await this.#waitHire(hireId, wallet, createJob, (d) => d.hire.status !== null, 'create_job');
    }
    if (detail.hire.status === 'open') {
      const fund = await this.prepareFund(hireId);
      await this.#signEscrowCall(hireId, fund, {
        purpose: 'fund',
        maxBudget,
        price,
        maxReserve,
        jobId: requireJobId(detail),
      });
      detail = await this.#waitHire(hireId, wallet, fund, (d) => d.hire.status !== 'open', 'fund');
    }
    return detail;
  }

  /**
   * Waits until the agent delivered on hire [hireId] (`submitted`) or the
   * hire ended (`completed`, `rejected`, `expired`), and returns it. Agents
   * can take minutes, so the wait is [options.timeoutMs], 10 minutes by
   * default. [consumer] defaults to the signer's wallet.
   */
  async waitForResult(
    hireId: number,
    options: { consumer?: string; timeoutMs?: number } = {},
  ): Promise<HireDetail> {
    const consumer = options.consumer ?? this.#requireSigner('waitForResult').publicKey();
    const deadline = this.#now().getTime() + (options.timeoutMs ?? 600_000);
    for (;;) {
      const detail = await this.getHire(hireId, consumer);
      const status = detail.hire.status;
      if (status !== null && ['submitted', 'completed', 'rejected', 'expired'].includes(status)) {
        return detail;
      }
      await this.#wait(deadline, `the result of hire ${hireId}`);
    }
  }

  /**
   * Approves the delivered hire [hireId]: signs `complete`, which releases
   * the escrow to the agent, and waits until the hire is `completed`.
   */
  async approve(hireId: number): Promise<HireDetail> {
    const wallet = this.#requireSigner('approve').publicKey();
    const jobId = requireJobId(await this.getHire(hireId, wallet));
    const prepared = await this.prepareComplete(hireId);
    await this.#signEscrowCall(hireId, prepared, { purpose: 'complete', jobId });
    return this.#waitHire(hireId, wallet, prepared, (d) => d.hire.status === 'completed', 'complete');
  }

  /**
   * Rejects hire [hireId] for [reason]: signs `reject`, which refunds the
   * escrow to the signer, and waits until the hire is `rejected`.
   */
  async reject(hireId: number, reason: string): Promise<HireDetail> {
    const wallet = this.#requireSigner('reject').publicKey();
    const jobId = requireJobId(await this.getHire(hireId, wallet));
    const prepared = await this.prepareReject(hireId, reason);
    await this.#signEscrowCall(hireId, prepared, { purpose: 'reject', jobId });
    return this.#waitHire(hireId, wallet, prepared, (d) => d.hire.status === 'rejected', 'reject');
  }

  /**
   * Rates the completed hire [hireId] with [score] (1 to 5) and [comment]:
   * signs `give_feedback` on the Reputation Registry and waits for it.
   */
  async rate(hireId: number, score: number, comment: string): Promise<HireDetail> {
    const signer = this.#requireSigner('rate');
    const wallet = signer.publicKey();
    const { agentId } = (await this.getHire(hireId, wallet)).hire;
    const prepared = await this.prepareFeedback(hireId, score, comment);
    const envelope = checkPreparedTransaction(
      prepared,
      { purpose: 'giveFeedback', agentId },
      wallet,
      this.#network,
      this.#now(),
    );
    const signed = await signer.signTransaction(envelope, this.#network.passphrase);
    await this.submitFeedback(hireId, prepared.preparationId, signed);
    const deadline = this.#deadline();
    for (;;) {
      const detail = await this.getHire(hireId, wallet);
      const submission = detail.feedbackSubmission;
      if (submission?.preparationId === prepared.preparationId) {
        if (submission.state === 'failed') {
          throw new ChainSubmissionFailed('giveFeedback', submission.errorCode);
        }
        if (submission.state === 'confirmed') return detail;
      }
      await this.#wait(deadline, 'give_feedback');
    }
  }

  // --- Internals ----------------------------------------------------------

  #requireChain(): ChainReader {
    // A signer always comes with a reader (the RPC by default).
    if (this.#chain === null) throw new SignerRequired('reading the chain');
    return this.#chain;
  }

  #requireSigner(operation: string): Puls3Signer {
    if (this.#signer === null) throw new SignerRequired(operation);
    if (!this.#hasSession) throw new SessionRequired(operation);
    return this.#signer;
  }

  /** Checks [prepared] (ADR-0010 D3), signs it and submits it. */
  async #signEscrowCall(
    hireId: number,
    prepared: PreparedTransaction,
    expectation: Expectation,
  ): Promise<HireDetail> {
    const signer = this.#requireSigner(expectation.purpose);
    const envelope = checkPreparedTransaction(
      prepared,
      expectation,
      signer.publicKey(),
      this.#network,
      this.#now(),
    );
    const signed = await signer.signTransaction(envelope, this.#network.passphrase);
    return this.submitEscrowCall(hireId, prepared.preparationId, signed);
  }

  /**
   * Reads hire [hireId] until [done], or until the submission of [prepared]
   * failed on chain ([ChainSubmissionFailed]) or the step timed out.
   */
  async #waitHire(
    hireId: number,
    consumer: string,
    prepared: PreparedTransaction | null,
    done: (detail: HireDetail) => boolean,
    step: string,
  ): Promise<HireDetail> {
    const deadline = this.#deadline();
    for (;;) {
      const detail = await this.getHire(hireId, consumer);
      const submission = detail.escrowSubmission;
      if (
        prepared !== null &&
        submission?.preparationId === prepared.preparationId &&
        submission.state === 'failed'
      ) {
        throw new ChainSubmissionFailed(prepared.purpose, submission.errorCode);
      }
      if (done(detail)) return detail;
      await this.#wait(deadline, step);
    }
  }

  #deadline(): number {
    return this.#now().getTime() + this.#stepMs;
  }

  async #wait(deadline: number, step: string): Promise<void> {
    if (this.#now().getTime() >= deadline) throw new Puls3Timeout(step);
    await this.#sleep(this.#pollMs);
  }


  async #prepare(method: string, hireId: number): Promise<PreparedTransaction> {
    requireInt('hireId', hireId, 1);
    return decodePreparedTransaction(await this.#call(method, 'hire', method, { hireId }));
  }

  #call(
    operation: string,
    endpoint: string,
    method: string,
    args: Record<string, unknown>,
  ): Promise<unknown> {
    if (!this.#hasSession) throw new SessionRequired(operation);
    return this.#transport.call(endpoint, method, args);
  }
}

function requireText(argument: string, value: string): void {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new InvalidArgument(argument, 'must not be blank');
  }
}

function requireInt(argument: string, value: number, min: number): void {
  if (!Number.isSafeInteger(value) || value < min) {
    throw new InvalidArgument(argument, `must be an integer of ${min} or more`);
  }
}

/**
 * [stroops] (7 decimals) as a USDC amount, with integer arithmetic only: at
 * least 2 decimals, trailing zeros past them dropped. `5000000` is `0.50`,
 * `12345678` is `1.2345678`.
 */
export function formatUsdc(stroops: number | bigint): string {
  const value = BigInt(stroops);
  const sign = value < 0n ? '-' : '';
  const abs = value < 0n ? -value : value;
  const whole = abs / 10_000_000n;
  let fraction = (abs % 10_000_000n).toString().padStart(7, '0');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.slice(0, -1);
  }
  return `${sign}${whole}.${fraction}`;
}

/** The escrow job of [detail], which the escrow calls must name. */
function requireJobId(detail: HireDetail): bigint {
  if (detail.jobId === null) {
    throw new Puls3ProtocolError(`Hire ${detail.hire.id} has no escrow job yet`);
  }
  return BigInt(detail.jobId);
}
