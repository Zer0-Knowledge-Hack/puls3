import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { inspect } from 'node:util';

import { Keypair, TransactionBuilder, xdr } from '@stellar/stellar-base';

import {
  ChainSubmissionFailed,
  InvalidArgument,
  Puls3ApiError,
  Puls3ProtocolError,
  Puls3Timeout,
  SignerRequired,
  SigningRefused,
} from '../src/errors.js';
import type { ChainReader } from '../src/chain_reader.js';
import { KeySession } from '../src/key_session.js';
import { TESTNET, withNetwork } from '../src/network.js';
import { Puls3Sdk } from '../src/sdk.js';
import { keypairSigner, keypairSignerFromEnvironment } from '../src/signer.js';
import {
  agentWallet,
  builder,
  challenge,
  createJobCall,
  draft7,
  envelope,
  escrowCall,
  fundCall,
  giveFeedbackCall,
  invocation,
  addressAuth,
  registerFullCall,
  server,
  setAgentWalletCall,
  sourceAuth,
  transferCall,
  provider,
} from './chain.js';
import { agentJson, fakeTransport, hireJson, type Call } from './support.js';

/**
 * The chain as the SDK reads it itself: agent 30 is bound to [provider] on
 * the Identity Registry, and the latest ledger is 4,900 (the deploy's
 * authorization is prepared until 5,000).
 */
const chainJob = {
  client: builder.publicKey(),
  provider,
  evaluator: builder.publicKey(),
  agentId: 30,
  token: TESTNET.usdc,
  budget: 5_000_000n,
  deliverable: null as string | null,
};
/** What the agent's submit records: the SHA-256 of the result the hire shows. */
const delivered = createHash('sha256').update('Two findings.', 'utf8').digest('hex');
const fakeChain: ChainReader = {
  agentWallet: async (agentId) => (agentId === 30 ? provider : null),
  job: async (jobId) => {
    if (jobId !== 35n) throw new Error(`unexpected job ${jobId}`);
    return chainJob;
  },
  latestLedger: async () => 4_900,
};

const me = builder.publicKey();
const signer = keypairSigner(builder.secret());

/** Whether [signed] carries a valid signature of [key] over the testnet hash. */
function signedBy(signed: string, key: Keypair): boolean {
  const tx = TransactionBuilder.fromXDR(signed, TESTNET.passphrase);
  return tx.signatures.some((s) => key.verify(tx.hash(), s.signature()));
}

const preparedJson = (purpose: string, fields: Record<string, unknown>) => ({
  preparationId: `prep-${purpose}`,
  purpose,
  signer: me,
  networkPassphrase: TESTNET.passphrase,
  unsignedTransactionXdr: null,
  authorizationEntryXdr: null,
  transaction: null,
  signatureExpirationLedger: null,
  expiresAt: new Date(Date.now() + 600_000).toISOString(),
  ...fields,
});

const fundEnvelope = (budget = 5_000_000n) => {
  const call = fundCall(budget);
  return envelope(call, { auth: [sourceAuth(call, [invocation(transferCall(budget))])] });
};

interface Chain {
  status: string | null;
  last: { preparationId: string; purpose: string; state: string; errorCode: string | null } | null;
  feedback: { preparationId: string; state: string } | null;
}

/**
 * A server whose chain confirms each signed submission at once, unless
 * [options.outcome] says otherwise for a purpose.
 */
function hireServer(options: {
  createJobBudget?: bigint;
  price?: number;
  outcome?: Record<string, 'failed' | 'pending'>;
  /** createHire answers as for a retried requestId: create_job already sent. */
  createJobAlreadySent?: boolean;
  /** With [createJobAlreadySent]: that earlier create_job fails on chain instead of landing. */
  earlierCreateJobFails?: boolean;
  /** The hire status a confirmed submission moves to, instead of the usual one. */
  lands?: Record<string, string>;
  /** The chain the SDK reads itself. Defaults to [fakeChain]. */
  chainReader?: ChainReader;
} = {}) {
  const chain: Chain = { status: null, last: null, feedback: null };
  let reads = 0;
  const submitted: { purpose: string; signed: string }[] = [];
  const next: Record<string, string> = {
    createJob: 'open',
    fund: 'funded',
    complete: 'completed',
    reject: 'rejected',
    ...options.lands,
  };
  const detail = () => ({
    hire: { ...hireJson, consumer: me, price: options.price ?? 5_000_000, status: chain.status },
    agent: agentJson,
    input: 'Review this contract.',
    result: chain.status === 'submitted' ? 'Two findings.' : null,
    payment: null,
    jobId: chain.status === null ? null : 35,
    expiresAt: null,
    approvalDeadline: null,
    runFinished: false,
    submitErrorCode: null,
    rejectReason: null,
    escrowSubmission:
      chain.last && {
        ...chain.last,
        transaction: null,
        explorerUrl: null,
        updatedAt: new Date().toISOString(),
      },
    feedbackSubmission:
      chain.feedback && {
        ...chain.feedback,
        purpose: 'giveFeedback',
        transaction: null,
        errorCode: null,
        explorerUrl: null,
        updatedAt: new Date().toISOString(),
      },
    feedbackScore: null,
    paymentExplorerUrl: null,
  });
  const submit = (purpose: string, call: Call) => {
    const signed = call.args['signedTransactionXdr'] as string;
    submitted.push({ purpose, signed });
    const outcome = options.outcome?.[purpose];
    const state = outcome ?? 'confirmed';
    chain.last = {
      preparationId: call.args['preparationId'] as string,
      purpose,
      state,
      errorCode: outcome === 'failed' ? 'TransactionFailed' : null,
    };
    if (state === 'confirmed' && next[purpose]) chain.status = next[purpose]!;
  };
  const { transport, calls } = fakeTransport((call) => {
    switch (`${call.endpoint}.${call.method}`) {
      case 'hire.createHire':
        return {
          hire: { ...hireJson, consumer: me, price: options.price ?? 5_000_000 },
          preparedCreateJob: options.createJobAlreadySent ? null : preparedJson('createJob', {
            unsignedTransactionXdr: envelope(createJobCall({ budget: options.createJobBudget ?? 5_000_000n })),
          }),
        };
      case 'hire.prepareFund':
        return preparedJson('fund', { unsignedTransactionXdr: fundEnvelope() });
      case 'hire.prepareComplete':
        return preparedJson('complete', { unsignedTransactionXdr: envelope(escrowCall('complete')) });
      case 'hire.prepareReject':
        return preparedJson('reject', { unsignedTransactionXdr: envelope(escrowCall('reject')) });
      case 'hire.submitEscrowCall': {
        const purpose = String(call.args['preparationId']).replace('prep-', '');
        submit(purpose, call);
        return detail();
      }
      case 'feedback.prepareFeedback':
        return preparedJson('giveFeedback', { unsignedTransactionXdr: envelope(giveFeedbackCall()) });
      case 'feedback.submitFeedback':
        submitted.push({ purpose: 'giveFeedback', signed: call.args['signedTransactionXdr'] as string });
        chain.feedback = { preparationId: call.args['preparationId'] as string, state: 'confirmed' };
        return detail();
      case 'hire.getHire':
        // The create_job sent before the retry lands (or fails) on the second read.
        if (options.createJobAlreadySent && chain.status === null && ++reads === 2) {
          if (options.earlierCreateJobFails) {
            chain.last = { preparationId: 'prep-earlier', purpose: 'createJob', state: 'failed', errorCode: 'TransactionFailed' };
          } else {
            chain.status = 'open';
          }
        }
        return detail();
      default:
        throw new Error(`unexpected call ${call.endpoint}.${call.method}`);
    }
  });
  let clock = Date.now();
  const sdk = new Puls3Sdk(transport, {
    hasSession: true,
    signer,
    chain: options.chainReader ?? {
      ...fakeChain,
      // The job carries the delivery once the agent submitted, as on chain.
      job: async (jobId) => ({
        ...(await fakeChain.job(jobId)),
        deliverable: chain.status === 'submitted' ? delivered : null,
      }),
    },
    pollIntervalMs: 1_000,
    stepTimeoutMs: 10_000,
    now: () => new Date(clock),
    sleep: async (ms) => {
      clock += ms;
    },
  });
  return { sdk, calls, submitted, chain };
}

describe('Puls3Sdk.hire', () => {
  it('signs create_job and then fund, and returns the funded hire', async () => {
    const { sdk, calls, submitted } = hireServer();
    const detail = await sdk.hire(30, 'Review this contract.', { maxPrice: 5_000_000, requestId: 'req-1' });
    assert.equal(detail.hire.status, 'funded');
    assert.deepEqual(
      submitted.map((s) => s.purpose),
      ['createJob', 'fund'],
    );
    for (const s of submitted) assert.ok(signedBy(s.signed, builder), `${s.purpose} is signed by the signer`);
    const create = calls.find((c) => c.method === 'createHire')!;
    assert.equal(create.args['consumer'], me);
    assert.equal(create.args['requestId'], 'req-1');
  });

  it('makes a request id when none is given', async () => {
    const { sdk, calls } = hireServer();
    await sdk.hire(30, 'x', { maxPrice: 5_000_000 });
    assert.match(String(calls.find((c) => c.method === 'createHire')!.args['requestId']), /^sdk-[0-9a-f-]{36}$/);
  });

  it('on a retry, waits for the create_job already sent instead of signing another', async () => {
    const { sdk, submitted } = hireServer({ createJobAlreadySent: true });
    const detail = await sdk.hire(30, 'x', { maxPrice: 5_000_000, requestId: 'req-1' });
    assert.equal(detail.hire.status, 'funded');
    assert.deepEqual(
      submitted.map((s) => s.purpose),
      ['fund'],
    );
  });

  it('refuses before preparing anything when the agent costs more than maxPrice', async () => {
    const { sdk, submitted } = hireServer({ price: 9_000_000 });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000 }), SigningRefused);
    assert.equal(submitted.length, 0);
  });

  it('signs nothing when the server prepares a bigger budget than it reported', async () => {
    const { sdk, submitted } = hireServer({ createJobBudget: 50_000_000n });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000 }), (e: unknown) => {
      assert.ok(e instanceof SigningRefused);
      assert.equal(e.rule, 'money');
      return true;
    });
    assert.equal(submitted.length, 0);
  });

  it("signs nothing when the job would pay another wallet than the agent's on the registry", async () => {
    // The server names [provider]; the Identity Registry binds agent 30 to a stranger.
    const stranger = Keypair.random().publicKey();
    const { sdk, submitted } = hireServer({
      chainReader: { ...fakeChain, agentWallet: async () => stranger },
    });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000 }), (e: unknown) => {
      assert.ok(e instanceof SigningRefused);
      assert.equal(e.rule, 'money');
      return true;
    });
    assert.equal(submitted.length, 0);
  });

  it('signs nothing when the agent has no wallet on the registry', async () => {
    const { sdk, submitted } = hireServer({
      chainReader: { ...fakeChain, agentWallet: async () => null },
    });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000 }), SigningRefused);
    assert.equal(submitted.length, 0);
  });

  it('reports a fund that failed on chain', async () => {
    const { sdk } = hireServer({ outcome: { fund: 'failed' } });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000 }), (e: unknown) => {
      assert.ok(e instanceof ChainSubmissionFailed);
      assert.equal(e.purpose, 'fund');
      assert.equal(e.errorCode, 'TransactionFailed');
      return true;
    });
  });

  it('times out when create_job never lands', async () => {
    const { sdk } = hireServer({ outcome: { createJob: 'pending' } });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000 }), Puls3Timeout);
  });

  it('on a retry, reports the create_job already sent when it failed on chain (#424)', async () => {
    const { sdk, submitted } = hireServer({ createJobAlreadySent: true, earlierCreateJobFails: true });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000, requestId: 'req-1' }), (e: unknown) => {
      assert.ok(e instanceof ChainSubmissionFailed, `expected ChainSubmissionFailed, got ${String(e)}`);
      assert.equal(e.purpose, 'createJob');
      assert.equal(e.errorCode, 'TransactionFailed');
      return true;
    });
    assert.equal(submitted.length, 0);
  });

  it('refuses to return a hire that fund left unfunded (#424)', async () => {
    const { sdk } = hireServer({ lands: { fund: 'expired' } });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000 }), (e: unknown) => {
      assert.ok(e instanceof Puls3ProtocolError, `expected Puls3ProtocolError, got ${String(e)}`);
      assert.match(e.message, /expired/);
      return true;
    });
  });

  it('accepts a hire the agent already moved past funded (#424)', async () => {
    const { sdk } = hireServer({ lands: { fund: 'submitted' } });
    const detail = await sdk.hire(30, 'x', { maxPrice: 5_000_000 });
    assert.equal(detail.hire.status, 'submitted');
  });

  it('sends maxReserve to createHire as the subcontract reserve, and none without it (#424)', async () => {
    const reserved = hireServer();
    await reserved.sdk.hire(30, 'x', { maxPrice: 5_000_000, maxReserve: 2_000_000 });
    assert.equal(reserved.calls.find((c) => c.method === 'createHire')!.args['subcontractReserve'], 2_000_000);
    const plain = hireServer();
    await plain.sdk.hire(30, 'x', { maxPrice: 5_000_000 });
    assert.equal(plain.calls.find((c) => c.method === 'createHire')!.args['subcontractReserve'], null);
  });

  it('a retry of a hire that was already rejected is not returned as funded (#424)', async () => {
    const { sdk, chain } = hireServer();
    chain.status = 'rejected';
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 5_000_000, requestId: 'req-1' }), (e: unknown) => {
      assert.ok(e instanceof Puls3ProtocolError);
      assert.match(e.message, /is rejected, not funded/);
      return true;
    });
  });

  it('createHire refuses a reserve that is negative, too large or not an integer, sending nothing (#424)', async () => {
    for (const subcontractReserve of [-1, 2n ** 60n, 0.5]) {
      const { sdk, calls } = hireServer();
      await assert.rejects(sdk.createHire(30, me, 'x', 'req-1', { subcontractReserve }), (e: unknown) => {
        assert.ok(e instanceof InvalidArgument, `${String(subcontractReserve)}: got ${String(e)}`);
        assert.equal(e.argument, 'subcontractReserve');
        return true;
      });
      assert.equal(calls.length, 0);
    }
  });

  it('refuses a maxPrice or maxReserve that is not an integer with InvalidArgument, sending nothing (#424)', async () => {
    for (const options of [{ maxPrice: 1.5 }, { maxPrice: 5_000_000, maxReserve: 0.5 }, { maxPrice: Number.NaN }]) {
      const { sdk, calls } = hireServer();
      await assert.rejects(sdk.hire(30, 'x', options), InvalidArgument);
      assert.equal(calls.length, 0);
    }
  });

  it('needs a signer, and sends nothing without one', async () => {
    const { transport, calls } = fakeTransport(() => null);
    const sdk = new Puls3Sdk(transport, { hasSession: true });
    await assert.rejects(sdk.hire(30, 'x', { maxPrice: 1 }), SignerRequired);
    await assert.rejects(sdk.deploy(1), SignerRequired);
    await assert.rejects(sdk.approve(21, { result: 'Two findings.' }), SignerRequired);
    assert.equal(calls.length, 0);
  });
});

describe('Puls3Sdk.approve, reject, rate', () => {
  it('approve signs complete and waits until the hire is completed', async () => {
    const { sdk, submitted, chain } = hireServer();
    chain.status = 'submitted';
    const detail = await sdk.approve(21, { trustServer: true });
    assert.equal(detail.hire.status, 'completed');
    assert.equal(submitted[0]!.purpose, 'complete');
    assert.ok(signedBy(submitted[0]!.signed, builder));
  });

  it('reject signs reject and waits until the hire is rejected', async () => {
    const { sdk, chain } = hireServer();
    chain.status = 'funded';
    assert.equal((await sdk.reject(21, 'Not usable.', { trustServer: true })).hire.status, 'rejected');
  });

  // ADR-0010 D3 rule 4: the job id comes from the server, so the job is read
  // from the escrow. A server that answers approve(hire A) with the complete
  // of another of the signer's jobs is refused, and nothing is signed.
  for (const [label, job] of [
    ['another agent', { ...chainJob, deliverable: delivered, agentId: 31 }],
    ['another price', { ...chainJob, deliverable: delivered, budget: 9_000_000n }],
    ["another client's job", { ...chainJob, deliverable: delivered, client: Keypair.random().publicKey() }],
    // The server is consistent about the agent and the price: only the
    // delivery recorded on chain tells the two jobs apart.
    ['the same agent and price but another delivery', {
      ...chainJob,
      deliverable: createHash('sha256').update('Other work.', 'utf8').digest('hex'),
    }],
  ] as const) {
    it(`approve and reject sign nothing when the server points at a job for ${label}`, async () => {
      for (const decide of ['approve', 'reject'] as const) {
        const { sdk, submitted, chain } = hireServer({ chainReader: { ...fakeChain, job: async () => job } });
        chain.status = 'submitted';
        await assert.rejects(
          decide === 'approve' ? sdk.approve(21, { trustServer: true }) : sdk.reject(21, 'Not usable.', { trustServer: true }),
          SigningRefused,
        );
        assert.equal(submitted.length, 0, decide);
      }
    });
  }

  // The B1 probe: the server is consistent about every field it returns, and
  // describes another job with that job's own result. Only the result the
  // caller reviewed tells them apart.
  for (const decide of ['approve', 'reject'] as const) {
    it(`${decide} with the reviewed result signs nothing when the server shows another job's result`, async () => {
      const { sdk, submitted, chain } = hireServer();
      chain.status = 'submitted';
      const reviewed = { result: 'What I reviewed.' };
      await assert.rejects(
        decide === 'approve' ? sdk.approve(21, reviewed) : sdk.reject(21, 'Not usable.', reviewed),
        (e: unknown) => {
          assert.ok(e instanceof SigningRefused);
          assert.equal(e.rule, 'call');
          return true;
        },
      );
      assert.equal(submitted.length, 0);
    });
  }

  it('approve with the reviewed result signs when it is the delivery on chain', async () => {
    const { sdk, submitted, chain } = hireServer();
    chain.status = 'submitted';
    assert.equal((await sdk.approve(21, { result: 'Two findings.' })).hire.status, 'completed');
    assert.equal(submitted.length, 1);
  });

  it('approve accepts a job whose agent has since bound another wallet', async () => {
    // The escrow pays the provider it stored, so a later rebind is no reason to refuse.
    const { sdk, submitted, chain } = hireServer({
      chainReader: {
        ...fakeChain,
        agentWallet: async () => Keypair.random().publicKey(),
        job: async () => ({ ...chainJob, deliverable: delivered }),
      },
    });
    chain.status = 'submitted';
    assert.equal((await sdk.approve(21, { trustServer: true })).hire.status, 'completed');
    assert.equal(submitted.length, 1);
  });

  it('reject of a funded hire refuses a job that already has a delivery', async () => {
    const { sdk, submitted, chain } = hireServer({
      chainReader: { ...fakeChain, job: async () => ({ ...chainJob, deliverable: delivered }) },
    });
    chain.status = 'funded';
    await assert.rejects(sdk.reject(21, 'Not usable.', { trustServer: true }), SigningRefused);
    assert.equal(submitted.length, 0);
  });

  // #424: the reviewed result is required, and trusting the server is an
  // explicit choice. Typed loosely, as a JavaScript caller would call it.
  type Loose = {
    approve(hireId: number, options?: unknown): Promise<unknown>;
    reject(hireId: number, reason: string, options?: unknown): Promise<unknown>;
  };
  for (const [label, options] of [
    ['no options', undefined],
    ['empty options', {}],
    ['a result and trustServer together', { result: 'Two findings.', trustServer: true }],
    ['trustServer other than true', { trustServer: false }],
    // From the #424 verifier's probes.
    ['null options', null],
    ['a bare string', 'Two findings.'],
    ['an array', ['Two findings.']],
    ['a result that is not a string', { result: 5 }],
    ['trustServer as a string', { trustServer: 'true' }],
    ['trustServer as 1', { trustServer: 1 }],
    ['a result with trustServer false', { result: 'Two findings.', trustServer: false }],
  ] as const) {
    it(`approve and reject refuse ${label} with InvalidArgument, sending nothing (#424)`, async () => {
      for (const decide of ['approve', 'reject'] as const) {
        const { sdk, calls, chain } = hireServer();
        chain.status = 'submitted';
        const loose = sdk as unknown as Loose;
        await assert.rejects(
          decide === 'approve' ? loose.approve(21, options) : loose.reject(21, 'Not usable.', options),
          (e: unknown) => {
            assert.ok(e instanceof InvalidArgument, `${decide}: expected InvalidArgument, got ${String(e)}`);
            assert.equal(e.argument, 'result');
            return true;
          },
        );
        assert.equal(calls.length, 0, decide);
      }
    });
  }

  it('approve ignores a trustServer inherited from Object.prototype (#424)', async () => {
    const { sdk, calls, chain } = hireServer();
    chain.status = 'submitted';
    const loose = sdk as unknown as Loose;
    (Object.prototype as Record<string, unknown>)['trustServer'] = true;
    try {
      await assert.rejects(loose.approve(21, {}), InvalidArgument);
    } finally {
      delete (Object.prototype as Record<string, unknown>)['trustServer'];
    }
    assert.equal(calls.length, 0);
  });

  it('approve refuses { result: null }: there is nothing to approve (#424)', async () => {
    const { sdk, calls, chain } = hireServer();
    chain.status = 'submitted';
    const loose = sdk as unknown as Loose;
    await assert.rejects(loose.approve(21, { result: null }), InvalidArgument);
    assert.equal(calls.length, 0);
  });

  it('reject with result null signs for a funded hire with no delivery (#424)', async () => {
    const { sdk, submitted, chain } = hireServer();
    chain.status = 'funded';
    const loose = sdk as unknown as Loose;
    await loose.reject(21, 'Not usable.', { result: null });
    assert.equal(submitted.length, 1);
  });

  it('reject with result null refuses a job that has a delivery (#424)', async () => {
    const { sdk, submitted, chain } = hireServer({
      chainReader: { ...fakeChain, job: async () => ({ ...chainJob, deliverable: delivered }) },
    });
    chain.status = 'funded';
    const loose = sdk as unknown as Loose;
    await assert.rejects(loose.reject(21, 'Not usable.', { result: null }), SigningRefused);
    assert.equal(submitted.length, 0);
  });

  it('rate signs give_feedback and waits for it on chain', async () => {
    const { sdk, submitted, chain } = hireServer();
    chain.status = 'completed';
    const detail = await sdk.rate(21, 5, 'Clear findings.');
    assert.equal(detail.feedbackSubmission?.state, 'confirmed');
    assert.ok(signedBy(submitted[0]!.signed, builder));
  });

  it('waitForResult returns once the agent delivered', async () => {
    const { sdk, chain } = hireServer();
    chain.status = 'funded';
    let reads = 0;
    const original = sdk.getHire.bind(sdk);
    sdk.getHire = async (id, consumer) => {
      if (++reads === 3) chain.status = 'submitted';
      return original(id, consumer);
    };
    assert.equal((await sdk.waitForResult(21)).hire.status, 'submitted');
  });
});

describe('Puls3Sdk.deploy', () => {
  function deployServer(options: { agentWallet?: string } = {}) {
    let state = 'awaitingRegistrationSignature';
    let reads = 0;
    const signedEntries: string[] = [];
    const session = () => ({
      state,
      preparation:
        state === 'awaitingRegistrationSignature'
          ? preparedJson('registerFull', { unsignedTransactionXdr: envelope(registerFullCall()) })
          : null,
      agentId: state === 'awaitingRegistrationSignature' || state === 'registrationSubmitted' ? null : 31,
      agentWallet,
      failureCode: null,
      retryFromStep: null,
    });
    const { transport, calls } = fakeTransport((call) => {
      switch (call.method) {
        case 'getDraft':
          assert.equal(call.args['draftId'], 7);
          return draft7;
        case 'prepareDeploy':
          assert.equal(call.args['builder'], me);
          return session();
        case 'submitRegistration':
          assert.ok(signedBy(call.args['signedTransactionXdr'] as string, builder));
          state = 'registrationSubmitted';
          return session();
        case 'getDeploySession':
          reads++;
          if (state === 'registrationSubmitted') state = 'awaitingWalletAuthorization';
          else if (state === 'walletAuthorizationSubmitted') state = 'publishing';
          else if (state === 'publishing') state = 'active';
          return session();
        case 'prepareWalletAuthorization':
          return {
            ...session(),
            preparation: preparedJson('setAgentWallet', {
              authorizationEntryXdr: addressAuth(
                me,
                setAgentWalletCall(31, options.agentWallet ?? agentWallet),
              ).toXDR('base64'),
              signatureExpirationLedger: 5_000,
            }),
          };
        case 'submitWalletAuthorization':
          signedEntries.push(call.args['signedAuthorizationEntryXdr'] as string);
          state = 'walletAuthorizationSubmitted';
          return session();
        default:
          throw new Error(`unexpected ${call.method}`);
      }
    });
    let clock = Date.now();
    const sdk = new Puls3Sdk(transport, {
      hasSession: true,
      signer,
      chain: fakeChain,
      pollIntervalMs: 1_000,
      stepTimeoutMs: 10_000,
      now: () => new Date(clock),
      sleep: async (ms) => {
        clock += ms;
      },
    });
    return { sdk, calls, signedEntries, reads: () => reads };
  }

  it('signs register_full and the wallet authorization, and returns the active agent', async () => {
    const { sdk, signedEntries } = deployServer();
    const states: string[] = [];
    const result = await sdk.deploy(7, { onState: (s) => states.push(s.state) });
    assert.equal(result.state, 'active');
    assert.equal(result.agentId, 31);
    assert.equal(result.agentWallet, agentWallet);
    assert.deepEqual(states, [
      'awaitingRegistrationSignature',
      'registrationSubmitted',
      'awaitingWalletAuthorization',
      'walletAuthorizationSubmitted',
      'publishing',
      'active',
    ]);
    const entry = xdr.SorobanAuthorizationEntry.fromXDR(signedEntries[0]!, 'base64');
    const credentials = entry.credentials().address();
    assert.equal(credentials.signatureExpirationLedger(), 5_000);
    assert.notEqual(credentials.signature().switch().name, 'scvVoid', 'the entry carries a signature');
  });

  it('refuses a wallet authorization that binds another wallet', async () => {
    const { sdk, signedEntries } = deployServer({ agentWallet: Keypair.random().publicKey() });
    await assert.rejects(sdk.deploy(7), SigningRefused);
    assert.equal(signedEntries.length, 0);
  });
});

describe('KeySession', () => {
  function authServer(options: { challenge?: ReturnType<typeof challenge>; refreshFails?: boolean } = {}) {
    let logins = 0;
    const { transport, calls } = fakeTransport((call) => {
      switch (`${call.endpoint}.${call.method}`) {
        case 'walletAuth.createChallenge':
          return { ...(options.challenge ?? challenge()), expiresAt: new Date(Date.now() + 900_000).toISOString() };
        case 'walletAuth.verifyChallenge':
          assert.ok(signedBy(call.args['signedChallengeXdr'] as string, builder));
          logins++;
          return { token: `access-${logins}`, tokenExpiresAt: new Date(Date.now() + 600_000).toISOString(), refreshToken: `refresh-${logins}` };
        case 'jwtRefresh.refreshAccessToken':
          if (options.refreshFails) throw new Puls3ApiError('RefreshTokenExpired', null, null);
          return { token: 'access-r', tokenExpiresAt: new Date(Date.now() + 600_000).toISOString(), refreshToken: 'refresh-r' };
        default:
          throw new Error('unexpected');
      }
    });
    return { transport, calls, logins: () => logins };
  }

  const network = withNetwork({
    serverSigningKey: server.publicKey(),
    homeDomain: 'puls3.example',
    webAuthDomain: 'puls3.example',
  });

  it('signs in with the signer and gives a bearer header', async () => {
    const { transport, calls } = authServer();
    const session = new KeySession(transport, signer, network);
    assert.equal(await session.authorization(), 'Bearer access-1');
    assert.ok(calls.every((c) => !c.authenticated), 'the auth calls are anonymous');
  });

  it('refreshes with the rotated token, and signs in again when it is refused', async () => {
    const ok = authServer();
    const session = new KeySession(ok.transport, signer, network);
    await session.login();
    assert.equal(await session.refresh(true), 'success');
    assert.equal(await session.authorization(), 'Bearer access-r');

    const refused = authServer({ refreshFails: true });
    const again = new KeySession(refused.transport, signer, network);
    await again.login();
    assert.equal(await again.refresh(true), 'success');
    assert.equal(refused.logins(), 2);
  });

  it('refuses a challenge that is not one, and never sends a signature', async () => {
    const { transport, calls } = authServer({ challenge: challenge({ sequence: '9' }) });
    await assert.rejects(new KeySession(transport, signer, network).login(), SigningRefused);
    assert.ok(!calls.some((c) => c.method === 'verifyChallenge'));
  });

  it('reports a signer that fails during sign-in, instead of sending the call without a session (#424)', async () => {
    const { transport, calls } = authServer();
    const broken = {
      publicKey: () => signer.publicKey(),
      signTransaction: async () => {
        throw new Error('the hardware key is unplugged');
      },
      signAuthEntry: (entry: string, until: number, passphrase: string) => signer.signAuthEntry(entry, until, passphrase),
    };
    const session = new KeySession(transport, broken, network);
    await assert.rejects(session.authorization(), /the hardware key is unplugged/);
    assert.ok(!calls.some((c) => c.method === 'verifyChallenge'));
  });

  it('reports a sign-in answer it cannot read as Puls3ProtocolError (#424)', async () => {
    const { transport } = fakeTransport((call) => {
      if (call.method === 'createChallenge') return { unexpected: true };
      throw new Error(`unexpected ${call.method}`);
    });
    const session = new KeySession(transport, signer, network);
    await assert.rejects(session.authorization(), Puls3ProtocolError);
  });

  it('never shows a token', async () => {
    const { transport } = authServer();
    const session = new KeySession(transport, signer, network);
    await session.login();
    for (const text of [String(session), JSON.stringify(session), inspect(session)]) {
      assert.ok(!text.includes('access-1') && !text.includes('refresh-1'), text);
    }
  });
});

describe('keypairSigner', () => {
  it('never shows the secret', () => {
    const secret = builder.secret();
    for (const text of [String(signer), JSON.stringify(signer), inspect(signer), inspect(signer, { showHidden: true })]) {
      assert.ok(!text.includes(secret), text);
      assert.ok(text.includes(me));
    }
  });

  it('does not echo a malformed secret', () => {
    const bad = `S${'B'.repeat(55)}`;
    assert.throws(() => keypairSigner(bad), (e: unknown) => e instanceof TypeError && !e.message.includes(bad));
  });

  it('reads PULS3_SECRET_KEY, and is null without it', () => {
    assert.equal(keypairSignerFromEnvironment({ PULS3_SECRET_KEY: builder.secret() })?.publicKey(), me);
    assert.equal(keypairSignerFromEnvironment({}), null);
  });

  it('signs a transaction with the network it is given', async () => {
    const signed = await signer.signTransaction(envelope(escrowCall('complete')), TESTNET.passphrase);
    assert.ok(signedBy(signed, builder));
  });
});
