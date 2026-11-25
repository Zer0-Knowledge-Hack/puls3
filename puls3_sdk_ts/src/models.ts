import { Puls3ProtocolError } from './errors.js';

/*
 * The server's models, with the field names of the Serverpod protocol
 * (`puls3_server/lib/src/**\/*.spy.yaml`). Amounts are USDC stroops
 * (7 decimals) as integers; dates are `Date`.
 */

/** An agent of the catalog (`AgentEndpoint.list` and `get`). */
export interface AgentSummary {
  /** Metadata id, for example `agt-001`. */
  id: string;
  /** On-chain id in the Identity Registry; hires use this one. */
  registryId: number;
  name: string;
  description: string;
  skills: string[];
  priceUsdcStroops: number;
  wallet: string | null;
  model: string | null;
  rating: number;
  paidHireCount: number;
  hireable: boolean;
}

/** A hire as its consumer sees it. */
export interface Hire {
  id: number;
  agentId: number;
  consumer: string;
  price: number;
  manifestVersion: number;
  /** Escrow status (`open`, `funded`, `submitted`, ...); null before `create_job`. */
  status: string | null;
  paymentTransaction: string | null;
  runtimeStatus: string | null;
  failureReason: string | null;
  rejectedFrom: string | null;
  feedbackReference: string | null;
  subcontractReserve: number;
  allowRelatedParty: boolean;
  parentHireId: number | null;
}

export interface Payment {
  transaction: string;
  hireId: number;
  payer: string;
  payee: string;
  amount: number;
}

/** A signed transaction the server relays, and where it is. */
export interface ChainSubmission {
  preparationId: string | null;
  purpose: string;
  transaction: string | null;
  state: string;
  errorCode: string | null;
  explorerUrl: string | null;
  updatedAt: Date;
}

/** A hire with its agent, input, result and chain state (`HireEndpoint.getHire`). */
export interface HireDetail {
  hire: Hire;
  agent: AgentSummary;
  input: string;
  result: string | null;
  payment: Payment | null;
  jobId: number | null;
  expiresAt: Date | null;
  approvalDeadline: Date | null;
  runFinished: boolean;
  submitErrorCode: string | null;
  rejectReason: string | null;
  escrowSubmission: ChainSubmission | null;
  feedbackSubmission: ChainSubmission | null;
  feedbackScore: number | null;
  paymentExplorerUrl: string | null;
}

/** One row of the session wallet's hires (`HireEndpoint.listMyHires`). */
export interface HireSummary {
  id: number;
  agentId: number;
  agentName: string;
  status: string | null;
  priceUsdcStroops: number;
  inputPreview: string;
  approvalDeadline: Date | null;
  needsAction: boolean;
  paidByAgentId: number | null;
  paidByAgentName: string | null;
}

/**
 * An unsigned transaction (or authorization entry) the server prepared for
 * [signer]. The SDK signs it only through its flows, after the checks of
 * ADR-0010 D3.
 */
export interface PreparedTransaction {
  preparationId: string;
  /** `createJob`, `fund`, `complete`, `reject`, ... */
  purpose: string;
  signer: string;
  networkPassphrase: string;
  unsignedTransactionXdr: string | null;
  authorizationEntryXdr: string | null;
  /** The transaction hash, when there is an envelope. */
  transaction: string | null;
  signatureExpirationLedger: number | null;
  expiresAt: Date;
}

export interface CreateHireResult {
  hire: Hire;
  /** The unsigned `create_job`, when the server could prepare it. */
  preparedCreateJob: PreparedTransaction | null;
}

export interface TestRunResult {
  output: string;
  remainingDailyRuns: number;
}

/** A hire a Studio agent started with its own wallet (`StudioEndpoint.hireAgentAs`). */
export interface AgentHireStarted {
  hireId: number;
  hiringWallet: string;
  state: string;
}

export interface ManifestSkill {
  id: string;
  name: string;
  description: string | null;
  tags: string[] | null;
}

export interface ManifestModel {
  provider: string;
  id: string;
}

export interface ManifestPrice {
  asset: string;
  amount: number;
}

/** An agent manifest being edited in the Studio. Every field may be unset. */
export interface AgentManifestDraft {
  name: string | null;
  description: string | null;
  skills: ManifestSkill[] | null;
  model: ManifestModel | null;
  systemPrompt: string | null;
  inputType: string | null;
  inputMaxChars: number | null;
  outputType: string | null;
  outputMaxChars: number | null;
  price: ManifestPrice | null;
}

/** A draft of the session wallet (`StudioEndpoint.getDraft`, `listDrafts`). */
export interface StudioDraft {
  draftId: number;
  manifest: AgentManifestDraft;
  revision: number;
  deployState: string;
  liveVersion: number | null;
  agentId: string | null;
  retryFromStep: number | null;
}

/** The answer of `jwtRefresh.refreshAccessToken`, as far as the SDK uses it. */
export interface AuthTokens {
  token: string;
  tokenExpiresAt: Date | null;
  refreshToken: string | null;
}

// --- Decoding -------------------------------------------------------------

type Json = Record<string, unknown>;

function fail(model: string, field: string): never {
  throw new Puls3ProtocolError(
    `The server's ${model} has no valid ${field}; is this SDK older than the server?`,
  );
}

function object(value: unknown, model: string): Json {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Puls3ProtocolError(`The server did not answer with a ${model}`);
  }
  return value as Json;
}

function list<T>(value: unknown, model: string, item: (v: unknown) => T): T[] {
  if (!Array.isArray(value)) {
    throw new Puls3ProtocolError(`The server did not answer with a list of ${model}`);
  }
  return value.map(item);
}

class Reader {
  constructor(
    private readonly json: Json,
    private readonly model: string,
  ) {}

  str(field: string): string {
    const v = this.json[field];
    return typeof v === 'string' ? v : fail(this.model, field);
  }

  strOrNull(field: string): string | null {
    const v = this.json[field];
    if (v === null || v === undefined) return null;
    return typeof v === 'string' ? v : fail(this.model, field);
  }

  int(field: string, fallback?: number): number {
    const v = this.json[field];
    if ((v === null || v === undefined) && fallback !== undefined) return fallback;
    return Number.isSafeInteger(v) ? (v as number) : fail(this.model, field);
  }

  intOrNull(field: string): number | null {
    const v = this.json[field];
    if (v === null || v === undefined) return null;
    return Number.isSafeInteger(v) ? (v as number) : fail(this.model, field);
  }

  num(field: string, fallback: number): number {
    const v = this.json[field];
    if (v === null || v === undefined) return fallback;
    return typeof v === 'number' && Number.isFinite(v) ? v : fail(this.model, field);
  }

  bool(field: string, fallback?: boolean): boolean {
    const v = this.json[field];
    if ((v === null || v === undefined) && fallback !== undefined) return fallback;
    return typeof v === 'boolean' ? v : fail(this.model, field);
  }

  date(field: string): Date {
    return this.dateOrNull(field) ?? fail(this.model, field);
  }

  dateOrNull(field: string): Date | null {
    const v = this.json[field];
    if (v === null || v === undefined) return null;
    if (typeof v !== 'string') fail(this.model, field);
    const date = new Date(v);
    return Number.isNaN(date.getTime()) ? fail(this.model, field) : date;
  }

  strings(field: string): string[] {
    const v = this.json[field];
    if (!Array.isArray(v) || !v.every((s) => typeof s === 'string')) {
      fail(this.model, field);
    }
    return v as string[];
  }

  stringsOrNull(field: string): string[] | null {
    const v = this.json[field];
    return v === null || v === undefined ? null : this.strings(field);
  }

  nested<T>(field: string, decode: (v: unknown) => T): T {
    const v = this.json[field];
    return v === null || v === undefined ? fail(this.model, field) : decode(v);
  }

  nestedOrNull<T>(field: string, decode: (v: unknown) => T): T | null {
    const v = this.json[field];
    return v === null || v === undefined ? null : decode(v);
  }
}

function reader(value: unknown, model: string): Reader {
  return new Reader(object(value, model), model);
}

export function decodeAgentSummary(value: unknown): AgentSummary {
  const r = reader(value, 'AgentSummary');
  return {
    id: r.str('id'),
    registryId: r.int('registryId'),
    name: r.str('name'),
    description: r.str('description'),
    skills: r.strings('skills'),
    priceUsdcStroops: r.int('priceUsdcStroops'),
    wallet: r.strOrNull('wallet'),
    model: r.strOrNull('model'),
    rating: r.num('rating', 4.0),
    paidHireCount: r.int('paidHireCount', 0),
    hireable: r.bool('hireable', false),
  };
}

export function decodeAgentSummaries(value: unknown): AgentSummary[] {
  return list(value, 'AgentSummary', decodeAgentSummary);
}

export function decodeHire(value: unknown): Hire {
  const r = reader(value, 'Hire');
  return {
    id: r.int('id'),
    agentId: r.int('agentId'),
    consumer: r.str('consumer'),
    price: r.int('price'),
    manifestVersion: r.int('manifestVersion'),
    status: r.strOrNull('status'),
    paymentTransaction: r.strOrNull('paymentTransaction'),
    runtimeStatus: r.strOrNull('runtimeStatus'),
    failureReason: r.strOrNull('failureReason'),
    rejectedFrom: r.strOrNull('rejectedFrom'),
    feedbackReference: r.strOrNull('feedbackReference'),
    subcontractReserve: r.int('subcontractReserve', 0),
    allowRelatedParty: r.bool('allowRelatedParty', true),
    parentHireId: r.intOrNull('parentHireId'),
  };
}

function decodePayment(value: unknown): Payment {
  const r = reader(value, 'Payment');
  return {
    transaction: r.str('transaction'),
    hireId: r.int('hireId'),
    payer: r.str('payer'),
    payee: r.str('payee'),
    amount: r.int('amount'),
  };
}

function decodeChainSubmission(value: unknown): ChainSubmission {
  const r = reader(value, 'ChainSubmission');
  return {
    preparationId: r.strOrNull('preparationId'),
    purpose: r.str('purpose'),
    transaction: r.strOrNull('transaction'),
    state: r.str('state'),
    errorCode: r.strOrNull('errorCode'),
    explorerUrl: r.strOrNull('explorerUrl'),
    updatedAt: r.date('updatedAt'),
  };
}

export function decodeHireDetail(value: unknown): HireDetail {
  const r = reader(value, 'HireDetail');
  return {
    hire: r.nested('hire', decodeHire),
    agent: r.nested('agent', decodeAgentSummary),
    input: r.str('input'),
    result: r.strOrNull('result'),
    payment: r.nestedOrNull('payment', decodePayment),
    jobId: r.intOrNull('jobId'),
    expiresAt: r.dateOrNull('expiresAt'),
    approvalDeadline: r.dateOrNull('approvalDeadline'),
    runFinished: r.bool('runFinished', false),
    submitErrorCode: r.strOrNull('submitErrorCode'),
    rejectReason: r.strOrNull('rejectReason'),
    escrowSubmission: r.nestedOrNull('escrowSubmission', decodeChainSubmission),
    feedbackSubmission: r.nestedOrNull('feedbackSubmission', decodeChainSubmission),
    feedbackScore: r.intOrNull('feedbackScore'),
    paymentExplorerUrl: r.strOrNull('paymentExplorerUrl'),
  };
}

function decodeHireSummary(value: unknown): HireSummary {
  const r = reader(value, 'HireSummary');
  return {
    id: r.int('id'),
    agentId: r.int('agentId'),
    agentName: r.str('agentName'),
    status: r.strOrNull('status'),
    priceUsdcStroops: r.int('priceUsdcStroops'),
    inputPreview: r.str('inputPreview'),
    approvalDeadline: r.dateOrNull('approvalDeadline'),
    needsAction: r.bool('needsAction'),
    paidByAgentId: r.intOrNull('paidByAgentId'),
    paidByAgentName: r.strOrNull('paidByAgentName'),
  };
}

export function decodeHireSummaries(value: unknown): HireSummary[] {
  return list(value, 'HireSummary', decodeHireSummary);
}

export function decodePreparedTransaction(value: unknown): PreparedTransaction {
  const r = reader(value, 'PreparedTransaction');
  return {
    preparationId: r.str('preparationId'),
    purpose: r.str('purpose'),
    signer: r.str('signer'),
    networkPassphrase: r.str('networkPassphrase'),
    unsignedTransactionXdr: r.strOrNull('unsignedTransactionXdr'),
    authorizationEntryXdr: r.strOrNull('authorizationEntryXdr'),
    transaction: r.strOrNull('transaction'),
    signatureExpirationLedger: r.intOrNull('signatureExpirationLedger'),
    expiresAt: r.date('expiresAt'),
  };
}

export function decodeCreateHireResult(value: unknown): CreateHireResult {
  const r = reader(value, 'CreateHireResult');
  return {
    hire: r.nested('hire', decodeHire),
    preparedCreateJob: r.nestedOrNull('preparedCreateJob', decodePreparedTransaction),
  };
}

export function decodeTestRunResult(value: unknown): TestRunResult {
  const r = reader(value, 'TestRunResult');
  return {
    output: r.str('output'),
    remainingDailyRuns: r.int('remainingDailyRuns'),
  };
}

export function decodeAgentHireStarted(value: unknown): AgentHireStarted {
  const r = reader(value, 'AgentHireStarted');
  return {
    hireId: r.int('hireId'),
    hiringWallet: r.str('hiringWallet'),
    state: r.str('state'),
  };
}

function decodeManifestSkill(value: unknown): ManifestSkill {
  const r = reader(value, 'ManifestSkill');
  return {
    id: r.str('id'),
    name: r.str('name'),
    description: r.strOrNull('description'),
    tags: r.stringsOrNull('tags'),
  };
}

function decodeManifestModel(value: unknown): ManifestModel {
  const r = reader(value, 'ManifestModel');
  return { provider: r.str('provider'), id: r.str('id') };
}

function decodeManifestPrice(value: unknown): ManifestPrice {
  const r = reader(value, 'ManifestPrice');
  return { asset: r.str('asset'), amount: r.int('amount') };
}

function decodeAgentManifestDraft(value: unknown): AgentManifestDraft {
  const r = reader(value, 'AgentManifestDraft');
  return {
    name: r.strOrNull('name'),
    description: r.strOrNull('description'),
    skills: r.nestedOrNull('skills', (v) => list(v, 'ManifestSkill', decodeManifestSkill)),
    model: r.nestedOrNull('model', decodeManifestModel),
    systemPrompt: r.strOrNull('systemPrompt'),
    inputType: r.strOrNull('inputType'),
    inputMaxChars: r.intOrNull('inputMaxChars'),
    outputType: r.strOrNull('outputType'),
    outputMaxChars: r.intOrNull('outputMaxChars'),
    price: r.nestedOrNull('price', decodeManifestPrice),
  };
}

export function decodeStudioDraft(value: unknown): StudioDraft {
  const r = reader(value, 'StudioDraft');
  return {
    draftId: r.int('draftId'),
    manifest: r.nested('manifest', decodeAgentManifestDraft),
    revision: r.int('revision'),
    deployState: r.str('deployState'),
    liveVersion: r.intOrNull('liveVersion'),
    agentId: r.strOrNull('agentId'),
    retryFromStep: r.intOrNull('retryFromStep'),
  };
}

export function decodeStudioDrafts(value: unknown): StudioDraft[] {
  return list(value, 'StudioDraft', decodeStudioDraft);
}

export function decodeAuthTokens(value: unknown): AuthTokens {
  const r = reader(value, 'AuthSuccess');
  return {
    token: r.str('token'),
    tokenExpiresAt: r.dateOrNull('tokenExpiresAt'),
    refreshToken: r.strOrNull('refreshToken'),
  };
}

/** A SEP-10 login challenge (`walletAuth.createChallenge`). */
export interface WalletChallenge {
  /** Opaque id sent back to `verifyChallenge`. */
  challengeId: string;
  /** The `G…` address it was issued for. */
  wallet: string;
  /** The base64 challenge transaction. */
  payload: string;
  networkPassphrase: string;
  expiresAt: Date;
}

export function decodeWalletChallenge(value: unknown): WalletChallenge {
  const r = reader(value, 'WalletChallenge');
  return {
    challengeId: r.str('challengeId'),
    wallet: r.str('wallet'),
    payload: r.str('payload'),
    networkPassphrase: r.str('networkPassphrase'),
    expiresAt: r.date('expiresAt'),
  };
}

/**
 * One deploy of a Studio draft, as `studio.getDeploySession` reports it
 * (`docs/architecture/api.md`, F4). [state] is one of
 * `awaitingRegistrationSignature`, `registrationSubmitted`,
 * `awaitingWalletAuthorization`, `walletAuthorizationSubmitted`,
 * `publishing`, `active` or `failed`.
 */
export interface DeploySession {
  state: string;
  /** What the builder signs next, in the two `awaiting…` states. */
  preparation: PreparedTransaction | null;
  /** The Identity Registry id, once `register_full` is confirmed. */
  agentId: number | null;
  /** The custodied agent wallet (`G…`). */
  agentWallet: string | null;
  /** The chain error code, or `PublicationFailed`, when [state] is `failed`. */
  failureCode: string | null;
  retryFromStep: number | null;
}

export function decodeDeploySession(value: unknown): DeploySession {
  const r = reader(value, 'DeploySession');
  return {
    state: r.str('state'),
    preparation: r.nestedOrNull('preparation', decodePreparedTransaction),
    agentId: r.intOrNull('agentId'),
    agentWallet: r.strOrNull('agentWallet'),
    failureCode: r.strOrNull('failureCode'),
    retryFromStep: r.intOrNull('retryFromStep'),
  };
}

/**
 * [draft] in the wire format of the generated client: every model carries
 * its `__className__`, and a null field is left out.
 */
export function encodeAgentManifestDraft(draft: Partial<AgentManifestDraft>): Record<string, unknown> {
  const out: Record<string, unknown> = { __className__: 'AgentManifestDraft' };
  const put = (key: string, value: unknown) => {
    if (value !== null && value !== undefined) out[key] = value;
  };
  put('name', draft.name);
  put('description', draft.description);
  put(
    'skills',
    draft.skills?.map((s) => {
      const skill: Record<string, unknown> = { __className__: 'ManifestSkill', id: s.id, name: s.name };
      if (s.description !== null && s.description !== undefined) skill['description'] = s.description;
      if (s.tags !== null && s.tags !== undefined) skill['tags'] = s.tags;
      return skill;
    }),
  );
  put(
    'model',
    draft.model && { __className__: 'ManifestModel', provider: draft.model.provider, id: draft.model.id },
  );
  put('systemPrompt', draft.systemPrompt);
  put('inputType', draft.inputType);
  put('inputMaxChars', draft.inputMaxChars);
  put('outputType', draft.outputType);
  put('outputMaxChars', draft.outputMaxChars);
  put(
    'price',
    draft.price && { __className__: 'ManifestPrice', asset: draft.price.asset, amount: draft.price.amount },
  );
  return out;
}
