import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { FeeBumpTransaction, Networks, TransactionBuilder, xdr } from '@stellar/stellar-base';

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
  preparedTx,
  registerFullCall,
  server,
  setAgentWalletCall,
  sourceAuth,
  stranger,
  transferCall,
} from './chain.js';

const me = builder.publicKey();
const createJob: Expectation = { purpose: 'createJob', maxBudget: 5_000_000n };
const fund: Expectation = { purpose: 'fund', maxBudget: 5_000_000n, maxReserve: 0n };

function refused(rule: SigningRefused['rule'], run: () => unknown): void {
  assert.throws(run, (error: unknown) => {
    assert.ok(error instanceof SigningRefused, `expected SigningRefused, got ${String(error)}`);
    assert.equal(error.rule, rule, error.message);
    assert.equal(error.code, 'SigningRefused');
    return true;
  });
}

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
    assert.ok(check(p, { purpose: 'fund', maxBudget: 5_000_000n, maxReserve: 2_000_000n }));
  });

  for (const fn of ['complete', 'reject'] as const) {
    it(fn, () => {
      assert.ok(check(preparedTx(fn, escrowCall(fn)), { purpose: fn }));
    });
  }

  it('register_full on the Identity Registry', () => {
    assert.ok(check(preparedTx('registerFull', registerFullCall()), { purpose: 'registerFull' }));
  });

  it('give_feedback on the Reputation Registry', () => {
    assert.ok(check(preparedTx('giveFeedback', giveFeedbackCall()), { purpose: 'giveFeedback' }));
  });

  it('a call with no authorization entries', () => {
    assert.ok(check(preparedTx('complete', escrowCall('complete'), { auth: [] }), { purpose: 'complete' }));
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
      refused('signer', () => check(preparedTx('complete', escrowCall('complete', stranger.publicKey())), { purpose: 'complete' }));
    });

    it('an authorization another account has to give', () => {
      const call = escrowCall('complete');
      refused('signer', () =>
        check(preparedTx('complete', call, { auth: [addressAuth(stranger.publicKey(), call)] }), { purpose: 'complete' }),
      );
    });
  });

  describe('rule 3, purpose and call', () => {
    it('another purpose than asked', () => {
      refused('call', () => check(preparedTx('fund', fundCall()), createJob));
    });

    it('a call to a contract that is not the pinned escrow', () => {
      refused('call', () => check(preparedTx('complete', { ...escrowCall('complete'), contract: otherContract }), { purpose: 'complete' }));
    });

    it('another function on the right contract', () => {
      refused('call', () => check(preparedTx('complete', { ...escrowCall('complete'), fn: 'claim_refund' }), { purpose: 'complete' }));
    });

    it('complete dressed as reject', () => {
      refused('call', () => check(preparedTx('reject', escrowCall('complete')), { purpose: 'reject' }));
    });

    it('a second operation', () => {
      refused('call', () => check(preparedTx('complete', escrowCall('complete'), { extraOperation: true }), { purpose: 'complete' }));
    });

    it('an authorization for another call than the transaction makes', () => {
      const call = escrowCall('complete');
      const other = escrowCall('reject');
      refused('call', () => check(preparedTx('complete', call, { auth: [sourceAuth(other)] }), { purpose: 'complete' }));
    });

    it('a fee-bump envelope', () => {
      const inner = TransactionBuilder.fromXDR(envelope(escrowCall('complete')), TESTNET.passphrase);
      const bump = TransactionBuilder.buildFeeBumpTransaction(stranger, '200000', inner as never, TESTNET.passphrase);
      assert.ok(bump instanceof FeeBumpTransaction);
      refused('call', () => check(prepared('complete', { unsignedTransactionXdr: bump.toXDR() }), { purpose: 'complete' }));
    });

    it('a preparation with no transaction', () => {
      refused('call', () => check(prepared('complete'), { purpose: 'complete' }));
    });

    it('bytes that are not a transaction', () => {
      refused('call', () => check(prepared('complete', { unsignedTransactionXdr: 'bm90IHhkcg==' }), { purpose: 'complete' }));
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
        check(preparedTx('complete', call, { auth: [sourceAuth(call, [invocation(transferCall(1n))])] }), { purpose: 'complete' }),
      );
    });
  });

  describe('rule 5, bounds', () => {
    it('an expired preparation', () => {
      const p = preparedTx('complete', escrowCall('complete'));
      refused('bounds', () => check({ ...p, expiresAt: new Date(Date.now() - 1000) }, { purpose: 'complete' }));
    });

    it('a fee above the cap', () => {
      refused('bounds', () => check(preparedTx('complete', escrowCall('complete'), { fee: 60_000_000 }), { purpose: 'complete' }));
    });

    it('an envelope with no end time', () => {
      refused('bounds', () => check(preparedTx('complete', escrowCall('complete'), { timeoutSeconds: 0 }), { purpose: 'complete' }));
    });

    it('an envelope past its end time', () => {
      const p = preparedTx('complete', escrowCall('complete'), { timeoutSeconds: 60 });
      refused('bounds', () =>
        checkPreparedTransaction({ ...p, expiresAt: new Date(Date.now() + 3_600_000) }, { purpose: 'complete' }, me, TESTNET, new Date(Date.now() + 120_000)),
      );
    });
  });
});

describe('checkPreparedAuthorization (set_agent_wallet, F4-7)', () => {
  const entry = (e: xdr.SorobanAuthorizationEntry, ledger: number | null = 1_000) =>
    prepared('setAgentWallet', { authorizationEntryXdr: e.toXDR('base64'), signatureExpirationLedger: ledger });
  const expectation = { agentId: 31, agentWallet };

  it('accepts the builder binding the deploy wallet to its agent', () => {
    const result = checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall())), expectation, me, TESTNET);
    assert.equal(result.validUntilLedger, 1_000);
  });

  it('refuses another agent id', () => {
    refused('call', () => checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall(99))), expectation, me, TESTNET));
  });

  it('refuses another wallet than the deploy created', () => {
    refused('call', () =>
      checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall(31, stranger.publicKey()))), expectation, me, TESTNET),
    );
  });

  it('refuses an entry for another account', () => {
    refused('signer', () =>
      checkPreparedAuthorization(entry(addressAuth(stranger.publicKey(), setAgentWalletCall())), expectation, me, TESTNET),
    );
  });

  it('refuses source-account credentials, which would sign a whole transaction', () => {
    refused('signer', () => checkPreparedAuthorization(entry(sourceAuth(setAgentWalletCall())), expectation, me, TESTNET));
  });

  it('refuses another function', () => {
    refused('call', () => checkPreparedAuthorization(entry(addressAuth(me, registerFullCall())), expectation, me, TESTNET));
  });

  it('refuses a nested call', () => {
    refused('money', () =>
      checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall(), [invocation(transferCall(1n))])), expectation, me, TESTNET),
    );
  });

  it('refuses an entry with no expiration ledger', () => {
    refused('bounds', () => checkPreparedAuthorization(entry(addressAuth(me, setAgentWalletCall()), null), expectation, me, TESTNET));
  });
});

describe('checkChallenge (rule 6, login)', () => {
  const pinned = withNetwork({ serverSigningKey: server.publicKey(), homeDomain: 'puls3.example' });

  it('accepts a challenge from the pinned server key, for the signer', () => {
    const c = challenge();
    assert.equal(checkChallenge(c, me, pinned), c.payload);
  });

  it('accepts any server when no key is pinned', () => {
    assert.ok(checkChallenge(challenge({ from: stranger }), me, TESTNET));
  });

  it('refuses a challenge from another server key', () => {
    refused('login', () => checkChallenge(challenge({ from: stranger }), me, pinned));
  });

  it('refuses a challenge the server did not sign', () => {
    refused('login', () => checkChallenge(challenge({ sign: false }), me, pinned));
  });

  it('refuses a transaction with a sequence number, which a network could accept', () => {
    refused('login', () => checkChallenge(challenge({ sequence: '7' }), me, TESTNET));
  });

  it('refuses a "challenge" from the signer\'s own account', () => {
    refused('login', () => checkChallenge(challenge({ from: builder }), me, TESTNET));
  });

  it('refuses a payment dressed as a challenge', () => {
    refused('login', () => checkChallenge(challenge({ payment: true }), me, TESTNET));
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
    refused('login', () => checkChallenge(challenge({ timeoutSeconds: 60 }), me, TESTNET, new Date(Date.now() + 120_000)));
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
