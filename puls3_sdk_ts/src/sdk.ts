import { InvalidArgument, SessionRequired } from './errors.js';
import {
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
  /** For tests and other runtimes. Defaults to the global `fetch`. */
  fetch?: typeof fetch;
  /** Per request. Defaults to 20 seconds. */
  timeoutMs?: number;
}

/**
 * The puls3 API for TypeScript and JavaScript programs (#302), with the
 * calls, names and error codes of the Dart SDK `puls3_sdk`.
 *
 * It reads and prepares; this version never signs or submits a transaction
 * (signing is ADR-0010, a later release). Server errors reach the caller as
 * [Puls3ApiError] with the server's code (`HireNotFound`,
 * `InvalidHireTransition`, `AgentCatalogUnavailable`, ...).
 *
 * The catalog needs no session. Hire and Studio calls act for a wallet, so
 * they need its session: without one they throw [SessionRequired] and send
 * nothing. Arguments the server would refuse throw [InvalidArgument], also
 * without sending anything.
 */
export class Puls3Sdk {
  readonly #transport: Transport;
  readonly #hasSession: boolean;

  /**
   * An SDK over any [Transport], for tests and other runtimes.
   * [hasSession] says whether the transport authenticates as a wallet.
   */
  constructor(transport: Transport, options: { hasSession: boolean }) {
    this.#transport = transport;
    this.#hasSession = options.hasSession;
  }

  /**
   * Connects to the puls3 server at [apiUrl], for example
   * `https://puls3-hub-on-stellar.api.serverpod.space/`.
   *
   * Throws a `TypeError` unless [apiUrl] is an absolute `http` or `https`
   * URL with no query or fragment.
   */
  static connect(apiUrl: string, options: ConnectOptions = {}): Puls3Sdk {
    const transport = new HttpTransport(apiUrl, {
      ...(options.session === undefined ? {} : { auth: options.session }),
      ...(options.fetch === undefined ? {} : { fetch: options.fetch }),
      ...(options.timeoutMs === undefined ? {} : { timeoutMs: options.timeoutMs }),
    });
    return new Puls3Sdk(transport, { hasSession: options.session !== undefined });
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

  // --- Internals ----------------------------------------------------------

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
