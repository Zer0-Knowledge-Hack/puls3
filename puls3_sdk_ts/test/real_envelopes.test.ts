import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';

import { Transaction, TransactionBuilder } from '@stellar/stellar-base';

import { SigningRefused } from '../src/errors.js';
import { checkPreparedTransaction, type Expectation } from '../src/guard.js';
import type { PreparedTransaction } from '../src/models.js';
import { TESTNET } from '../src/network.js';

/**
 * The checks of ADR-0010 D3 on the real `create_job` and `fund` of testnet
 * escrow job 3 (the fixtures the server's relay tests use), so the SDK is
 * known to accept the calls the escrow actually takes, not only envelopes
 * built in these tests.
 */
const fixtures = join(process.cwd(), '..', 'puls3_server', 'test', 'fixtures', 'escrow_relay');

function real(name: string): Transaction {
  const json = JSON.parse(readFileSync(join(fixtures, `${name}.json`), 'utf8')) as {
    envelopeXdr: string;
    networkPassphrase: string;
  };
  assert.equal(json.networkPassphrase, TESTNET.passphrase);
  return TransactionBuilder.fromXDR(json.envelopeXdr, json.networkPassphrase) as Transaction;
}

function prepare(purpose: string, tx: Transaction): PreparedTransaction {
  return {
    preparationId: 'real',
    purpose,
    signer: tx.source,
    networkPassphrase: TESTNET.passphrase,
    unsignedTransactionXdr: tx.toXDR(),
    authorizationEntryXdr: null,
    transaction: null,
    signatureExpirationLedger: null,
    expiresAt: new Date(Date.now() + 60_000),
  };
}

/**
 * Job 3 was created from the Stellar CLI, which sets no end time. The
 * server's relay always does (`maxTime`, `escrow_relay_service.dart`), so
 * the same operation is put in an envelope with one, as the relay builds it.
 */
function withEndTime(tx: Transaction): Transaction {
  return TransactionBuilder.cloneFrom(tx, {
    fee: tx.fee,
    timebounds: { minTime: 0, maxTime: Math.floor(Date.now() / 1000) + 300 },
  }).build();
}

const cases: [string, Expectation][] = [
  // Job 3's provider and agent id, as `get_job 3` returns them on chain.
  [
    'get_transaction_create_job_3_xdr',
    {
      purpose: 'createJob',
      maxBudget: 5_000_000n,
      price: 5_000_000n,
      agentId: 7,
      provider: 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
    },
  ],
  ['get_transaction_fund_job_3_xdr', { purpose: 'fund', maxBudget: 5_000_000n, price: 5_000_000n, maxReserve: 0n, jobId: 3n }],
];

describe('the checks on real testnet envelopes (escrow job 3)', () => {
  for (const [name, expectation] of cases) {
    const tx = real(name);

    it(`accepts the real ${expectation.purpose}`, () => {
      const bounded = withEndTime(tx);
      assert.equal(
        checkPreparedTransaction(prepare(expectation.purpose, bounded), expectation, tx.source, TESTNET),
        bounded.toXDR(),
      );
    });

    it(`refuses the real ${expectation.purpose} with a lower maxPrice`, () => {
      const lower = { ...expectation, maxBudget: 4_999_999n } as Expectation;
      assert.throws(
        () => checkPreparedTransaction(prepare(expectation.purpose, withEndTime(tx)), lower, tx.source, TESTNET),
        (e: unknown) => e instanceof SigningRefused && e.rule === 'money',
      );
    });

    it(`refuses the real ${expectation.purpose} as sent from the CLI, with no end time`, () => {
      assert.throws(
        () => checkPreparedTransaction(prepare(expectation.purpose, tx), expectation, tx.source, TESTNET),
        (e: unknown) => e instanceof SigningRefused && e.rule === 'bounds',
      );
    });
  }
});
