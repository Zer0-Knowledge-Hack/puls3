import {
  Account,
  Address,
  Contract,
  TransactionBuilder,
  nativeToScVal,
  scValToNative,
  xdr,
} from '@stellar/stellar-base';

import { Puls3NetworkError, Puls3ProtocolError } from './errors.js';
import type { Puls3Network } from './network.js';

/**
 * What the SDK reads from the chain itself, not from the puls3 server, so a
 * server that lies cannot make it sign for someone else (ADR-0010 D3 rule 4).
 */
export interface ChainReader {
  /** The wallet the Identity Registry binds to [agentId], or null. */
  agentWallet(agentId: number): Promise<string | null>;
  /** Escrow job [jobId] as the escrow stores it (`get_job`). */
  job(jobId: bigint): Promise<EscrowJob>;
  /** The sequence of the latest closed ledger. */
  latestLedger(): Promise<number>;
}

/** The fields of an escrow job the SDK checks before it signs a call on it. */
export interface EscrowJob {
  client: string;
  provider: string;
  evaluator: string;
  agentId: number;
  token: string;
  budget: bigint;
  /** The SHA-256 the agent's `submit` recorded (hex), or null before it. */
  deliverable: string | null;
}

/**
 * [ChainReader] over the network's Soroban RPC ([Puls3Network.rpcUrl]). A
 * read is a simulation: nothing is signed or sent. [source] is the account
 * the simulation runs as, which must exist: the signer's own wallet.
 */
export class SorobanRpcReader implements ChainReader {
  readonly #network: Puls3Network;
  readonly #source: string;
  readonly #fetch: typeof fetch;
  readonly #timeoutMs: number;
  #id = 0;

  /**
   * [options.timeoutMs] bounds each RPC request (20 seconds by default, as
   * the server calls): a hung RPC ends as `Puls3NetworkError` instead of
   * hanging `hire` and `deploy` past their step timeout.
   */
  constructor(
    network: Puls3Network,
    source: string,
    fetchImpl: typeof fetch = fetch,
    options: { timeoutMs?: number } = {},
  ) {
    this.#network = network;
    this.#source = source;
    this.#fetch = fetchImpl;
    this.#timeoutMs = options.timeoutMs ?? 20_000;
  }

  async agentWallet(agentId: number): Promise<string | null> {
    const scVal = await this.#read(
      this.#network.identityRegistry,
      'get_agent_wallet',
      nativeToScVal(agentId, { type: 'u32' }),
      'The Identity Registry read',
    );
    if (scVal.switch().name === 'scvVoid') return null;
    if (scVal.switch().name !== 'scvAddress') {
      throw new Puls3ProtocolError('The Identity Registry returned no address');
    }
    return Address.fromScVal(scVal).toString();
  }

  async job(jobId: bigint): Promise<EscrowJob> {
    const scVal = await this.#read(
      this.#network.escrow,
      'get_job',
      nativeToScVal(jobId, { type: 'u64' }),
      `The escrow read of job ${jobId}`,
    );
    if (scVal.switch().name !== 'scvMap') {
      throw new Puls3ProtocolError(`The escrow returned no job ${jobId}`);
    }
    const fields = new Map<string, xdr.ScVal>();
    for (const e of scVal.map()!) {
      if (e.key().switch().name !== 'scvSymbol') {
        throw new Puls3ProtocolError(`The escrow returned job ${jobId} with a non-symbol field`);
      }
      fields.set(e.key().sym().toString(), e.val());
    }
    const address = (name: string) => {
      const value = fields.get(name);
      if (value === undefined || value.switch().name !== 'scvAddress') {
        throw new Puls3ProtocolError(`Job ${jobId} has no ${name}`);
      }
      return Address.fromScVal(value).toString();
    };
    const integer = (name: string) => {
      const value = fields.get(name);
      if (value === undefined) throw new Puls3ProtocolError(`Job ${jobId} has no ${name}`);
      return BigInt(scValToNative(value) as number | bigint);
    };
    return {
      client: address('client'),
      provider: address('provider'),
      evaluator: address('evaluator'),
      agentId: Number(integer('agent_id')),
      token: address('token'),
      budget: integer('budget'),
      deliverable: deliverable(fields.get('deliverable'), jobId),
    };
  }

  /** Simulates one read-only contract call and returns its value. */
  async #read(contract: string, fn: string, arg: xdr.ScVal, label: string): Promise<xdr.ScVal> {
    const tx = new TransactionBuilder(new Account(this.#source, '0'), {
      fee: '100',
      networkPassphrase: this.#network.passphrase,
    })
      .addOperation(new Contract(contract).call(fn, arg))
      .setTimeout(30)
      .build();
    const result = (await this.#rpc('simulateTransaction', { transaction: tx.toXDR() })) as {
      error?: string;
      results?: { xdr?: string }[];
    };
    if (typeof result.error === 'string') {
      throw new Puls3ProtocolError(`${label} failed: ${result.error}`);
    }
    const value = result.results?.[0]?.xdr;
    if (typeof value !== 'string') throw new Puls3ProtocolError(`${label} returned no value`);
    return xdr.ScVal.fromXDR(value, 'base64');
  }

  async latestLedger(): Promise<number> {
    const result = (await this.#rpc('getLatestLedger', {})) as { sequence?: unknown };
    if (typeof result.sequence !== 'number') {
      throw new Puls3ProtocolError('The RPC returned no latest ledger');
    }
    return result.sequence;
  }

  async #rpc(method: string, params: object): Promise<unknown> {
    let response: Response;
    try {
      response = await this.#fetch(this.#network.rpcUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', id: ++this.#id, method, params }),
        signal: AbortSignal.timeout(this.#timeoutMs),
      });
    } catch (e) {
      throw new Puls3NetworkError(`The Soroban RPC did not answer: ${(e as Error).message}`);
    }
    let body: { result?: unknown; error?: { message?: string } };
    try {
      body = (await response.json()) as typeof body;
    } catch {
      throw new Puls3ProtocolError(`The Soroban RPC answered ${response.status} with no JSON`);
    }
    if (body.error !== undefined || body.result === undefined) {
      throw new Puls3ProtocolError(`The Soroban RPC refused ${method}: ${body.error?.message ?? 'no result'}`);
    }
    return body.result;
  }
}

/** `Option<BytesN<32>>`: void before the agent submits, 32 bytes after. */
function deliverable(value: xdr.ScVal | undefined, jobId: bigint): string | null {
  if (value === undefined || value.switch().name === 'scvVoid') return null;
  if (value.switch().name !== 'scvBytes' || value.bytes().length !== 32) {
    throw new Puls3ProtocolError(`Job ${jobId} has a deliverable that is not 32 bytes`);
  }
  return Buffer.from(value.bytes()).toString('hex');
}
