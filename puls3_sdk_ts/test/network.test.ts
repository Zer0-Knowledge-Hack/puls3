import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';

import { TESTNET } from '../src/network.js';

/**
 * The SDK refuses to sign a call to any contract but these (ADR-0010 D3,
 * rule 3), so they must follow the deployment record. When the escrow
 * rotates (#421), this test fails until [TESTNET] names the new one.
 */
describe('TESTNET', () => {
  const deployment = JSON.parse(
    readFileSync(join(process.cwd(), '..', 'contracts', 'deployments', 'testnet.json'), 'utf8'),
  ) as {
    network: string;
    escrow: { contract_id: string };
    identity_registry: { contract_id: string };
    reputation_registry: { contract_id: string };
    direct_payment: { sac_id: string };
  };

  it('is the network of contracts/deployments/testnet.json', () => {
    assert.equal(deployment.network, 'testnet');
  });

  it('pins the contracts that contracts/deployments/testnet.json records', () => {
    assert.deepEqual(
      {
        escrow: TESTNET.escrow,
        identityRegistry: TESTNET.identityRegistry,
        reputationRegistry: TESTNET.reputationRegistry,
        usdc: TESTNET.usdc,
      },
      {
        escrow: deployment.escrow.contract_id,
        identityRegistry: deployment.identity_registry.contract_id,
        reputationRegistry: deployment.reputation_registry.contract_id,
        usdc: deployment.direct_payment.sac_id,
      },
    );
  });
});
