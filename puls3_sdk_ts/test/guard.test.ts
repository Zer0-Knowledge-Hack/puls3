import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { Address, FeeBumpTransaction, Networks, TransactionBuilder, xdr } from '@stellar/stellar-base';

import { SigningRefused } from '../src/errors.js';
import {
  checkChallenge,
  checkPreparedAuthorization,
  checkPreparedTransaction,
  type Expectation,
} from '../src/guard.js';
import { TESTNET, withNetwork } from '../src/network.js';
import {
  addressAuth,
  agentWallet,
  builder,
  challenge,
  createJobCall,
  escrowCall,
  envelope,
  fundCall,
  fundWithReserveCall,
  giveFeedbackCall,
  invocation,
  otherContract,
  prepared,
  provider,
  preparedTx,
  registerFullCall,
  server,
  setAgentWalletCall,
  sourceAuth,
  stranger,
  transferCall,
  reasonBytes,
  registration,
  rejectReason,
} from './chain.js';

const me = builder.publicKey();
const createJob: Expectation = { purpose: 'createJob', maxBudget: 5_000_000n, price: 5_000_000n, agentId: 30, provider };
const fund: Expectation = { purpose: 'fund', maxBudget: 5_000_000n, price: 5_000_000n, maxReserve: 0n, jobId: 35n };

function refused(rule: SigningRefused['rule'], run: () => unknown): void {
  assert.throws(run, (error: unknown) => {
    assert.ok(error instanceof SigningRefused, `expected SigningRefused, got ${String(error)}`);
    assert.equal(error.rule, rule, error.message);
    assert.equal(error.code, 'SigningRefused');
    return true;
  });
}

/** The expectation of complete or reject on job 35. */
const decision = (fn: 'complete' | 'reject'): Expectation =>
  fn === 'complete' ? { purpose: 'complete', jobId: 35n } : { purpose: 'reject', jobId: 35n, reason: rejectReason };

const check = (p: ReturnType<typeof prepared>, e: Expectation, network = TESTNET) =>
  checkPreparedTransaction(p, e, me, network);

describe('checkPreparedTransaction accepts what the server prepares', () => {
  it('create_job for the signer, judged by the signer, paid in USDC within the budget', () => {
    const p = preparedTx('createJob', createJobCall());
    assert.equal(check(p, createJob), p.unsignedTransactionXdr);
  });

  it('fund with the USDC transfer of exactly the budget to the escrow', () => {
    const call = fundCall();
    const p = preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(5_000_000n))])] });
    assert.equal(check(p, fund), p.unsignedTransactionXdr);
  });

  it('fund_with_reserve when the caller allowed the reserve', () => {
    const call = fundWithReserveCall(5_000_000n, 2_000_000n);
    const p = preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(7_000_000n))])] });
    assert.ok(check(p, { purpose: 'fund', maxBudget: 5_000_000n, price: 5_000_000n, maxReserve: 2_000_000n, jobId: 35n }));
  });

  for (const fn of ['complete', 'reject'] as const) {
    it(fn, () => {
      assert.ok(check(preparedTx(fn, escrowCall(fn)), decision(fn)));
    });
  }

  it('register_full on the Identity Registry', () => {
    assert.ok(check(preparedTx('registerFull', registerFullCall()), { purpose: 'registerFull', registration }));
  });

  it('give_feedback on the Reputation Registry', () => {
    assert.ok(check(preparedTx('giveFeedback', giveFeedbackCall()), { purpose: 'giveFeedback', agentId: 30 }));
  });

  it('a call with no authorization entries', () => {
    assert.ok(check(preparedTx('complete', escrowCall('complete'), { auth: [] }), { purpose: 'complete', jobId: 35n }));
  });
});

describe('checkPreparedTransaction refuses (ADR-0010 D3)', () => {
  describe('rule 1, network', () => {
    it('a preparation for another network', () => {
      const p = preparedTx('createJob', createJobCall());
      refused('network', () => check({ ...p, networkPassphrase: Networks.FUTURENET }, createJob));
    });

    it('anything on the public network, even when configured', () => {
      const p = preparedTx('createJob', createJobCall());
      const pub = { ...TESTNET, passphrase: Networks.PUBLIC };
      refused('network', () => check({ ...p, networkPassphrase: Networks.PUBLIC }, createJob, pub));
    });

    it('an envelope whose signature would cover another network', () => {
      const p = preparedTx('createJob', createJobCall(), { passphrase: Networks.FUTURENET });
      // The envelope bytes carry no passphrase; the signature does. The SDK
      // always signs with the configured one, so the server cannot switch it.
      assert.ok(check(p, createJob));
    });
  });

  describe('rule 2, signer', () => {
    it('a preparation for another signer', () => {
      const p = preparedTx('createJob', createJobCall());
      refused('signer', () => check({ ...p, signer: stranger.publicKey() }, createJob));
    });

    it('an envelope from another source account', () => {
      refused('signer', () => check(preparedTx('createJob', createJobCall(), { source: stranger.publicKey() }), createJob));
    });

    it('a call made in the name of another account', () => {
      refused('signer', () => check(preparedTx('complete', escrowCall('complete', stranger.publicKey())), { purpose: 'complete', jobId: 35n }));
    });

    it('an authorization another account has to give', () => {
      const call = escrowCall('complete');
      refused('signer', () =>
        check(preparedTx('complete', call, { auth: [addressAuth(stranger.publicKey(), call)] }), { purpose: 'complete', jobId: 35n }),
      );
    });
  });

  describe('rule 3, purpose and call', () => {
    it('another purpose than asked', () => {
      refused('call', () => check(preparedTx('fund', fundCall()), createJob));
    });

    it('a call to a contract that is not the pinned escrow', () => {
      refused('call', () => check(preparedTx('complete', { ...escrowCall('complete'), contract: otherContract }), { purpose: 'complete', jobId: 35n }));
    });

    it('another function on the right contract', () => {
      refused('call', () => check(preparedTx('complete', { ...escrowCall('complete'), fn: 'claim_refund' }), { purpose: 'complete', jobId: 35n }));
    });

    it('complete dressed as reject', () => {
      refused('call', () => check(preparedTx('reject', escrowCall('complete')), { purpose: 'reject', jobId: 35n, reason: rejectReason }));
    });

    it('a second operation', () => {
      refused('call', () => check(preparedTx('complete', escrowCall('complete'), { extraOperation: true }), { purpose: 'complete', jobId: 35n }));
    });

    it('an authorization for another call than the transaction makes', () => {
      const call = escrowCall('complete');
      const other = escrowCall('reject');
      refused('call', () => check(preparedTx('complete', call, { auth: [sourceAuth(other)] }), { purpose: 'complete', jobId: 35n }));
    });

    it('a fee-bump envelope', () => {
      const inner = TransactionBuilder.fromXDR(envelope(escrowCall('complete')), TESTNET.passphrase);
      const bump = TransactionBuilder.buildFeeBumpTransaction(stranger, '200000', inner as never, TESTNET.passphrase);
      assert.ok(bump instanceof FeeBumpTransaction);
      refused('call', () => check(prepared('complete', { unsignedTransactionXdr: bump.toXDR() }), { purpose: 'complete', jobId: 35n }));
    });

    it('a preparation with no transaction', () => {
      refused('call', () => check(prepared('complete'), { purpose: 'complete', jobId: 35n }));
    });

    it('bytes that are not a transaction', () => {
      refused('call', () => check(prepared('complete', { unsignedTransactionXdr: 'bm90IHhkcg==' }), { purpose: 'complete', jobId: 35n }));
    });
  });

  describe('rule 4, money', () => {
    it('a job budget above the price the caller allowed', () => {
      refused('money', () => check(preparedTx('createJob', createJobCall({ budget: 5_000_001n })), createJob));
    });

    it('a job paid in another token', () => {
      refused('money', () => check(preparedTx('createJob', createJobCall({ token: otherContract })), createJob));
    });

    it('a job judged by another account, which could release the money itself', () => {
      refused('money', () => check(preparedTx('createJob', createJobCall({ evaluator: stranger.publicKey() })), createJob));
    });

    it('fund above the allowed budget', () => {
      const call = fundCall(9_000_000n);
      refused('money', () => check(preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(9_000_000n))])] }), fund));
    });

    it('a subcontract reserve the caller did not allow', () => {
      const call = fundWithReserveCall(5_000_000n, 1n);
      refused('money', () => check(preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(5_000_001n))])] }), fund));
    });

    it('a transfer of more than the budget', () => {
      const call = fundCall();
      refused('money', () => check(preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(50_000_000n))])] }), fund));
    });

    it('a transfer to another account than the escrow', () => {
      const call = fundCall();
      refused('money', () =>
        check(preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(5_000_000n, { to: stranger.publicKey() }))])] }), fund),
      );
    });

    it('a transfer of another token', () => {
      const call = fundCall();
      refused('money', () =>
        check(preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(5_000_000n, { token: otherContract }))])] }), fund),
      );
    });

    it('two nested transfers', () => {
      const call = fundCall();
      const t = invocation(transferCall(5_000_000n));
      refused('money', () => check(preparedTx('fund', call, { auth: [sourceAuth(call, [t, t])] }), fund));
    });

    it('any nested call on complete', () => {
      const call = escrowCall('complete');
      refused('money', () =>
        check(preparedTx('complete', call, { auth: [sourceAuth(call, [invocation(transferCall(1n))])] }), { purpose: 'complete', jobId: 35n }),
      );
    });
  });

  describe('rule 5, bounds', () => {
    it('an expired preparation', () => {
      const p = preparedTx('complete', escrowCall('complete'));
      refused('bounds', () => check({ ...p, expiresAt: new Date(Date.now() - 1000) }, { purpose: 'complete', jobId: 35n }));
    });

    it('a fee above the cap', () => {
      refused('bounds', () => check(preparedTx('complete', escrowCall('complete'), { fee: 60_000_000 }), { purpose: 'complete', jobId: 35n }));
    });

    it('an envelope with no end time', () => {
      refused('bounds', () => check(preparedTx('complete', escrowCall('complete'), { timeoutSeconds: 0 }), { purpose: 'complete', jobId: 35n }));
    });

    it('an envelope past its end time', () => {
      const p = preparedTx('complete', escrowCall('complete'), { timeoutSeconds: 60 });
      refused('bounds', () =>
        checkPreparedTransaction({ ...p, expiresAt: new Date(Date.now() + 3_600_000) }, { purpose: 'complete', jobId: 35n }, me, TESTNET, new Date(Date.now() + 120_000)),
      );
    });
  });
});

describe('checkPreparedAuthorization (set_agent_wallet, F4-7)', () => {
  const entry = (e: xdr.SorobanAuthorizationEntry, ledger: number | null = 1_000) =>
    prepared('setAgentWallet', { authorizationEntryXdr: e.toXDR('base64'), signatureExpirationLedger: ledger });
  const expectation = { agentId: 31, agentWallet };

  it('accepts the builder binding the deploy wallet to its agent', () => {
    const result = checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall())), expectation, me, TESTNET, 900);
    assert.equal(result.validUntilLedger, 1_000);
  });

  it('refuses another agent id', () => {
    refused('call', () => checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall(99))), expectation, me, TESTNET, 900));
  });

  it('refuses another wallet than the deploy created', () => {
    refused('call', () =>
      checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall(31, stranger.publicKey()))), expectation, me, TESTNET, 900),
    );
  });

  it('refuses an entry for another account', () => {
    refused('signer', () =>
      checkPreparedAuthorization(entry(addressAuth(stranger.publicKey(), setAgentWalletCall())), expectation, me, TESTNET, 900),
    );
  });

  it('refuses source-account credentials, which would sign a whole transaction', () => {
    refused('signer', () => checkPreparedAuthorization(entry(sourceAuth(setAgentWalletCall())), expectation, me, TESTNET, 900));
  });

  it('refuses another function', () => {
    refused('call', () => checkPreparedAuthorization(entry(addressAuth(me, registerFullCall())), expectation, me, TESTNET, 900));
  });

  it('refuses a nested call', () => {
    refused('money', () =>
      checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall(), [invocation(transferCall(1n))])), expectation, me, TESTNET, 900),
    );
  });

  it('refuses an entry with no expiration ledger', () => {
    refused('bounds', () => checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall()), null), expectation, me, TESTNET, 900));
  });
});

describe('checkChallenge (rule 6, login)', () => {
  const pinned = withNetwork({
    serverSigningKey: server.publicKey(),
    homeDomain: 'puls3.example',
    webAuthDomain: 'puls3.example',
  });
  const unpinned = withNetwork({ serverSigningKey: null, homeDomain: null, webAuthDomain: null });

  it('accepts a challenge from the pinned server key, for the signer', () => {
    const c = challenge();
    assert.equal(checkChallenge(c, me, pinned), c.payload);
  });

  it('accepts any server only when the developer unpins the key', () => {
    assert.ok(checkChallenge(challenge({ from: stranger }), me, unpinned));
  });

  it('refuses a challenge from another key with the default network, which pins the server', () => {
    refused('login', () => checkChallenge(challenge(), me, TESTNET));
  });

  it('refuses a third operation', () => {
    refused('login', () => checkChallenge(challenge({ extraOperation: true }), me, pinned));
  });

  it('refuses another web_auth_domain', () => {
    refused('login', () => checkChallenge(challenge({ webAuthDomain: 'evil.example' }), me, pinned));
  });

  it('refuses a challenge from another server key', () => {
    refused('login', () => checkChallenge(challenge({ from: stranger }), me, pinned));
  });

  it('refuses a challenge the server did not sign', () => {
    refused('login', () => checkChallenge(challenge({ sign: false }), me, pinned));
  });

  it('refuses a transaction with a sequence number, which a network could accept', () => {
    refused('login', () => checkChallenge(challenge({ sequence: '7' }), me, pinned));
  });

  it('refuses a "challenge" from the signer\'s own account', () => {
    refused('login', () => checkChallenge(challenge({ from: builder }), me, pinned));
  });

  it('refuses a payment dressed as a challenge', () => {
    refused('login', () => checkChallenge(challenge({ payment: true }), me, pinned));
  });

  it('refuses a first operation for another account', () => {
    refused('login', () => checkChallenge(challenge({ firstSource: stranger.publicKey() }), me, TESTNET));
  });

  it('refuses another home domain than the pinned one', () => {
    refused('login', () => checkChallenge(challenge({ name: 'evil.example auth' }), me, pinned));
  });

  it('refuses a challenge for another wallet', () => {
    refused('login', () => checkChallenge(challenge({ wallet: stranger.publicKey() }), me, TESTNET));
  });

  it('refuses an expired challenge', () => {
    refused('login', () => checkChallenge(challenge({ timeoutSeconds: 60 }), me, pinned, new Date(Date.now() + 120_000)));
  });
});

describe('withNetwork', () => {
  it('refuses the public network', () => {
    assert.throws(() => withNetwork({ passphrase: Networks.PUBLIC }), TypeError);
  });

  it('refuses a contract id that is not one', () => {
    assert.throws(() => withNetwork({ escrow: 'GABC' }), TypeError);
  });

  it('keeps the pinned testnet ids unless overridden', () => {
    const local = withNetwork({ escrow: otherContract });
    assert.equal(local.escrow, otherContract);
    assert.equal(local.usdc, TESTNET.usdc);
  });
});

describe('ADR-0010 D3 rules 4, 6 and 8: what the server cannot change', () => {
  it('create_job must pay the wallet the Identity Registry binds to the agent', () => {
    refused('money', () => check(preparedTx('createJob', createJobCall({ provider: stranger.publicKey() })), createJob));
  });

  it('create_job must have no hook', () => {
    const hook = new Address(otherContract).toScVal();
    refused('call', () => check(preparedTx('createJob', createJobCall({ hook })), createJob));
  });

  it('create_job must be for the requested agent', () => {
    refused('call', () => check(preparedTx('createJob', createJobCall({ agentId: 31 })), createJob));
  });

  it("create_job's budget must be the agent's price, not merely under maxPrice", () => {
    refused('money', () => check(preparedTx('createJob', createJobCall({ budget: 4_000_000n })), createJob));
  });

  it("fund must be for this hire's job", () => {
    const call = fundCall(5_000_000n, 36n);
    const p = preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(5_000_000n))])] });
    refused('call', () => check(p, fund));
  });

  it("fund must pull the agent's price", () => {
    const call = fundCall(4_000_000n);
    const p = preparedTx('fund', call, { auth: [sourceAuth(call, [invocation(transferCall(4_000_000n))])] });
    refused('money', () => check(p, fund));
  });

  for (const fn of ['complete', 'reject'] as const) {
    it(`${fn} must be for this hire's job, not another job of the signer`, () => {
      refused('call', () => check(preparedTx(fn, escrowCall(fn, me, 36n)), decision(fn)));
    });
  }

  it('give_feedback must be for the hired agent', () => {
    refused('call', () => check(preparedTx('giveFeedback', giveFeedbackCall(31)), { purpose: 'giveFeedback', agentId: 30 }));
  });

  it('a transaction valid for longer than the horizon is refused', () => {
    const p = preparedTx('complete', escrowCall('complete'), { timeoutSeconds: 3_600 });
    refused('bounds', () => check(p, { purpose: 'complete', jobId: 35n }));
  });

  it('an authorization valid too many ledgers ahead is refused', () => {
    const p = prepared('setAgentWallet', {
      authorizationEntryXdr: addressAuth(me, setAgentWalletCall()).toXDR('base64'),
      signatureExpirationLedger: 900 + TESTNET.maxAuthLedgers + 1,
    });
    refused('bounds', () => checkPreparedAuthorization(p, { agentId: 31, agentWallet }, me, TESTNET, 900));
  });

  it('an authorization that already expired on chain is refused', () => {
    const p = prepared('setAgentWallet', {
      authorizationEntryXdr: addressAuth(me, setAgentWalletCall()).toXDR('base64'),
      signatureExpirationLedger: 900,
    });
    refused('bounds', () => checkPreparedAuthorization(p, { agentId: 31, agentWallet }, me, TESTNET, 900));
  });
});

describe('TESTNET pins the server', () => {
  it("ships the server's SEP-10 key and domains", () => {
    assert.equal(TESTNET.serverSigningKey, 'GBEELNIKCJBWCVR4KYEP4LTLXWGD5MOSLRF32CHFULLMPGNTKBBKHOEG');
    assert.equal(TESTNET.homeDomain, 'puls3-hub-on-stellar.api.serverpod.space');
    assert.equal(TESTNET.webAuthDomain, 'puls3-hub-on-stellar.api.serverpod.space');
  });

  it('withNetwork refuses an RPC that is not a URL, and bounds that are not positive', () => {
    assert.throws(() => withNetwork({ rpcUrl: 'not a url' }), TypeError);
    assert.throws(() => withNetwork({ maxTimeHorizonSeconds: 0 }), TypeError);
    assert.throws(() => withNetwork({ maxAuthLedgers: -1 }), TypeError);
  });
});

describe("ADR-0010 D3 rule 4: the reason and the registration are the caller's", () => {
  it('complete must carry no reason (32 zero bytes)', () => {
    const p = preparedTx('complete', escrowCall('complete', me, 35n, reasonBytes('reject')));
    refused('call', () => check(p, decision('complete')));
  });

  it("reject must carry the SHA-256 of the caller's reason", () => {
    const p = preparedTx('reject', escrowCall('reject', me, 35n, reasonBytes('reject', 'Something else.')));
    refused('call', () => check(p, decision('reject')));
  });

  const register = (call: ReturnType<typeof registerFullCall>) =>
    check(preparedTx('registerFull', call), { purpose: 'registerFull', registration });

  it("register_full is accepted when it registers the draft's metadata", () => {
    assert.ok(register(registerFullCall()));
  });

  for (const [label, call] of [
    ['another catalog id', registerFullCall({ fields: { id: 'studio-8' } })],
    ['another name', registerFullCall({ fields: { name: 'Impostor' } })],
    ['another description', registerFullCall({ fields: { description: 'Something else.' } })],
    ['other skills', registerFullCall({ fields: { skills: JSON.stringify(['summarize', 'trade']) } })],
    ['another price', registerFullCall({ fields: { priceUsdcStroops: '9000000' } })],
    ['another model', registerFullCall({ fields: { model: 'claude-opus' } })],
    ['an extra metadata entry', registerFullCall({ extra: ['payout', 'GABC'] })],
    ['no manifest hash', registerFullCall({ drop: 'manifestHash' })],
    ['a URI for another manifest', registerFullCall({ uri: `https://puls3.example/registry/${'0'.repeat(64)}` })],
    ['a URI that is not a registration file', registerFullCall({ uri: 'https://evil.example/agent.json' })],
  ] as const) {
    it(`register_full with ${label} is refused`, () => {
      refused('call', () => register(call));
    });
  }
});
