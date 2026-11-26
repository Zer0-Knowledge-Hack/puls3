import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { Address, Keypair, TransactionBuilder, nativeToScVal, xdr } from '@stellar/stellar-base';

import { SorobanRpcReader } from '../src/chain_reader.js';
import { Puls3NetworkError, Puls3ProtocolError } from '../src/errors.js';
import { TESTNET } from '../src/network.js';

const source = Keypair.random().publicKey();
const wallet = Keypair.random().publicKey();

/** A Soroban RPC that answers each JSON-RPC call with [result] and records it. */
function rpc(answer: (method: string) => unknown) {
  const requests: { url: string; method: string; params: Record<string, unknown> }[] = [];
  const fetchImpl = (async (url: string | URL, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body)) as { method: string; params: Record<string, unknown> };
    requests.push({ url: String(url), method: body.method, params: body.params });
    return new Response(JSON.stringify(answer(body.method)), { status: 200 });
  }) as typeof fetch;
  return { reader: new SorobanRpcReader(TESTNET, source, fetchImpl), requests };
}

const simulated = (value: xdr.ScVal) => ({ jsonrpc: '2.0', id: 1, result: { results: [{ xdr: value.toXDR('base64') }] } });

describe('SorobanRpcReader', () => {
  it("reads an agent's wallet from the Identity Registry with a simulation, nothing signed", async () => {
    const { reader, requests } = rpc(() => simulated(new Address(wallet).toScVal()));

    assert.equal(await reader.agentWallet(39), wallet);

    const [request] = requests;
    assert.equal(request!.url, TESTNET.rpcUrl);
    assert.equal(request!.method, 'simulateTransaction');
    const tx = TransactionBuilder.fromXDR(String(request!.params.transaction), TESTNET.passphrase);
    assert.equal(tx.signatures.length, 0);
    const op = (tx as unknown as { operations: { func: xdr.HostFunction }[] }).operations[0]!;
    const call = op.func.invokeContract();
    assert.equal(Address.fromScAddress(call.contractAddress()).toString(), TESTNET.identityRegistry);
    assert.equal(call.functionName().toString(), 'get_agent_wallet');
    assert.equal(call.args()[0]!.u32(), 39);
  });

  it('returns null for an agent with no wallet', async () => {
    const { reader } = rpc(() => simulated(xdr.ScVal.scvVoid()));
    assert.equal(await reader.agentWallet(39), null);
  });

  it('refuses a simulation error or an answer that is not an address', async () => {
    const failed = rpc(() => ({ jsonrpc: '2.0', id: 1, result: { error: 'HostError: contract not found' } }));
    await assert.rejects(failed.reader.agentWallet(39), Puls3ProtocolError);
    const number = rpc(() => simulated(xdr.ScVal.scvU32(5)));
    await assert.rejects(number.reader.agentWallet(39), Puls3ProtocolError);
    const refused = rpc(() => ({ jsonrpc: '2.0', id: 1, error: { code: -32600, message: 'bad request' } }));
    await assert.rejects(refused.reader.agentWallet(39), Puls3ProtocolError);
  });

  it('reads an escrow job by name, ignoring fields it does not check', async () => {
    const client = Keypair.random().publicKey();
    const provider = Keypair.random().publicKey();
    const entry = (key: string, val: xdr.ScVal) => new xdr.ScMapEntry({ key: xdr.ScVal.scvSymbol(key), val });
    const job = xdr.ScVal.scvMap([
      entry('agent_id', nativeToScVal(39, { type: 'u32' })),
      entry('budget', nativeToScVal(1_000_000n, { type: 'i128' })),
      entry('client', new Address(client).toScVal()),
      entry('deliverable', xdr.ScVal.scvBytes(Buffer.alloc(32, 0xab))),
      entry('evaluator', new Address(client).toScVal()),
      entry('provider', new Address(provider).toScVal()),
      entry('reserve', nativeToScVal(0n, { type: 'i128' })),
      entry('state', nativeToScVal(2, { type: 'u32' })),
      entry('token', new Address(TESTNET.usdc).toScVal()),
    ]);
    const { reader, requests } = rpc(() => simulated(job));

    assert.deepEqual(await reader.job(8n), {
      client,
      provider,
      evaluator: client,
      agentId: 39,
      token: TESTNET.usdc,
      budget: 1_000_000n,
      deliverable: 'ab'.repeat(32),
    });
    const tx = TransactionBuilder.fromXDR(String(requests[0]!.params.transaction), TESTNET.passphrase);
    const call = (tx as unknown as { operations: { func: xdr.HostFunction }[] }).operations[0]!.func.invokeContract();
    assert.equal(Address.fromScAddress(call.contractAddress()).toString(), TESTNET.escrow);
    assert.equal(call.functionName().toString(), 'get_job');
  });

  it('refuses a job the escrow does not return', async () => {
    const { reader } = rpc(() => ({ jsonrpc: '2.0', id: 1, result: { error: 'HostError: Error(Contract, #1)' } }));
    await assert.rejects(reader.job(999n), Puls3ProtocolError);
  });

  it('reads the latest ledger', async () => {
    const { reader, requests } = rpc(() => ({ jsonrpc: '2.0', id: 1, result: { sequence: 5_911_000 } }));
    assert.equal(await reader.latestLedger(), 5_911_000);
    assert.equal(requests[0]!.method, 'getLatestLedger');
  });

  it('reports an RPC it cannot reach', async () => {
    const down = new SorobanRpcReader(TESTNET, source, (async () => {
      throw new TypeError('fetch failed');
    }) as typeof fetch);
    await assert.rejects(down.latestLedger(), Puls3NetworkError);
  });

  it('gives up on an RPC that never answers, after its timeout (#424)', { timeout: 5_000 }, async () => {
    // A fetch that hangs until its request is aborted, as a hung RPC does.
    const hung = (async (_url: string | URL, init?: RequestInit) =>
      new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => reject(init.signal!.reason));
      })) as typeof fetch;
    const reader = new SorobanRpcReader(TESTNET, source, hung, { timeoutMs: 50 });
    // A real request holds a socket that keeps the process alive; this fake
    // holds nothing, and AbortSignal.timeout does not keep it alive itself.
    const alive = setTimeout(() => undefined, 5_000);
    try {
      await assert.rejects(reader.latestLedger(), Puls3NetworkError);
    } finally {
      clearTimeout(alive);
    }
  });

  it('gives up on an RPC whose body never ends, as a network error (#438, S2)', { timeout: 5_000 }, async () => {
    // The headers arrive, then the body hangs until the request is aborted.
    const hungBody = (async (_url: string | URL, init?: RequestInit) => {
      const body = new ReadableStream<Uint8Array>({
        start(controller) {
          init?.signal?.addEventListener('abort', () => controller.error(init.signal!.reason));
        },
      });
      return new Response(body, { status: 200, headers: { 'content-type': 'application/json' } });
    }) as typeof fetch;
    const reader = new SorobanRpcReader(TESTNET, source, hungBody, { timeoutMs: 50 });
    const alive = setTimeout(() => undefined, 5_000);
    try {
      await assert.rejects(reader.latestLedger(), (error: unknown) => {
        assert.ok(error instanceof Puls3NetworkError, `expected Puls3NetworkError, got ${String(error)}`);
        return true;
      });
    } finally {
      clearTimeout(alive);
    }
  });

  it('reports a body that is not JSON as a protocol error (#438, S2)', async () => {
    const html = (async () => new Response('<html>busy</html>', { status: 200 })) as typeof fetch;
    const reader = new SorobanRpcReader(TESTNET, source, html);
    await assert.rejects(reader.latestLedger(), Puls3ProtocolError);
  });

  for (const timeoutMs of [0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
    it(`refuses timeoutMs ${timeoutMs} when it is built (#438, S3)`, () => {
      assert.throws(
        () => new SorobanRpcReader(TESTNET, source, fetch, { timeoutMs }),
        (error: unknown) => error instanceof TypeError && /timeoutMs/.test(error.message),
      );
    });
  }

  it('accepts a positive timeoutMs (#438, S3)', () => {
    assert.ok(new SorobanRpcReader(TESTNET, source, fetch, { timeoutMs: 1 }));
  });
});
