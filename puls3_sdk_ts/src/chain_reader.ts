import {
  Account,
  Address,
  Contract,
  TransactionBuilder,
  nativeToScVal,
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
  /** The sequence of the latest closed ledger. */
  latestLedger(): Promise<number>;
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
  #id = 0;

  constructor(network: Puls3Network, source: string, fetchImpl: typeof fetch = fetch) {
    this.#network = network;
    this.#source = source;
    this.#fetch = fetchImpl;
  }

  async agentWallet(agentId: number): Promise<string | null> {
    const tx = new TransactionBuilder(new Account(this.#source, '0'), {
      fee: '100',
      networkPassphrase: this.#network.passphrase,
    })
      .addOperation(
        new Contract(this.#network.identityRegistry).call(
          'get_agent_wallet',
          nativeToScVal(agentId, { type: 'u32' }),
        ),
      )
      .setTimeout(30)
      .build();
    const result = (await this.#rpc('simulateTransaction', { transaction: tx.toXDR() })) as {
      error?: string;
      results?: { xdr?: string }[];
    };
    if (typeof result.error === 'string') {
      throw new Puls3ProtocolError(`The Identity Registry read failed: ${result.error}`);
    }
    const value = result.results?.[0]?.xdr;
    if (typeof value !== 'string') {
      throw new Puls3ProtocolError('The Identity Registry read returned no value');
    }
    const scVal = xdr.ScVal.fromXDR(value, 'base64');
    if (scVal.switch().name === 'scvVoid') return null;
    if (scVal.switch().name !== 'scvAddress') {
      throw new Puls3ProtocolError('The Identity Registry returned no address');
    }
    return Address.fromScVal(scVal).toString();
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
