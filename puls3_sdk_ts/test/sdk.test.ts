import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { InvalidArgument, Puls3ProtocolError, SessionRequired } from '../src/errors.js';
import { Puls3Sdk, formatUsdc } from '../src/sdk.js';
import {
  agentJson,
  fakeTransport,
  hireDetailJson,
  hireJson,
  preparedJson,
  wallet,
  type Call,
} from './support.js';

function sdkAnswering(answer: (call: Call) => unknown, hasSession = true) {
  const { transport, calls } = fakeTransport(answer);
  return { sdk: new Puls3Sdk(transport, { hasSession }), calls };
}

describe('the catalog', () => {
  it('lists agents anonymously, with typed fields', async () => {
    const { sdk, calls } = sdkAnswering(() => [agentJson], false);

    const [agent] = await sdk.listAgents();

    assert.deepEqual(calls, [{ endpoint: 'agent', method: 'list', args: {}, authenticated: false }]);
    assert.equal(agent!.registryId, 30);
    assert.equal(agent!.priceUsdcStroops, 5_000_000);
    assert.deepEqual(agent!.skills, ['security']);
  });

  it('applies the server defaults of fields an older server leaves out', async () => {
    const { rating: _r, paidHireCount: _p, hireable: _h, ...older } = agentJson;
    const { sdk } = sdkAnswering(() => [older], false);

    const [agent] = await sdk.listAgents();

    assert.equal(agent!.rating, 4.0);
    assert.equal(agent!.paidHireCount, 0);
    assert.equal(agent!.hireable, false);
  });

  it('gets one agent, and null for an unknown id', async () => {
    const { sdk, calls } = sdkAnswering((call) => (call.args['id'] === 'agt-001' ? agentJson : null), false);

    assert.equal((await sdk.getAgent('agt-001'))!.name, 'Soroban Pre-Audit');
    assert.equal(await sdk.getAgent('agt-999'), null);
    assert.equal(calls.every((c) => !c.authenticated), true);
  });

  it('refuses a blank id without calling the server', async () => {
    const { sdk, calls } = sdkAnswering(() => agentJson, false);

    await assert.rejects(sdk.getAgent('  '), InvalidArgument);
    assert.equal(calls.length, 0);
  });

  it('reports an answer it cannot read as Puls3ProtocolError', async () => {
    const { sdk } = sdkAnswering(() => [{ ...agentJson, registryId: 'thirty' }], false);

    await assert.rejects(sdk.listAgents(), Puls3ProtocolError);
  });
});

describe('without a session', () => {
  const { sdk, calls } = sdkAnswering(() => null, false);

  const sessionCalls: Array<[string, () => Promise<unknown>]> = [
    ['createHire', () => sdk.createHire(30, wallet, 'x', 'req-1')],
    ['getHire', () => sdk.getHire(1, wallet)],
    ['listMyHires', () => sdk.listMyHires()],
    ['prepareCreateJob', () => sdk.prepareCreateJob(1)],
    ['prepareFund', () => sdk.prepareFund(1)],
    ['prepareComplete', () => sdk.prepareComplete(1)],
    ['prepareReject', () => sdk.prepareReject(1, 'no')],
    ['listDrafts', () => sdk.listDrafts()],
    ['getDraft', () => sdk.getDraft(1)],
    ['testRun', () => sdk.testRun(1, 'hello')],
    ['hireAgentAs', () => sdk.hireAgentAs(28, 29, 'x', 1_000_000)],
    ['getAgentHire', () => sdk.getAgentHire(28, 1)],
  ];

  for (const [operation, call] of sessionCalls) {
    it(`${operation} throws SessionRequired and sends nothing`, async () => {
      await assert.rejects(call(), (error) => {
        assert.ok(error instanceof SessionRequired);
        assert.equal(error.operation, operation);
        assert.equal(error.code, 'SessionRequired');
        return true;
      });
      assert.equal(calls.length, 0);
    });
  }
});

describe('hires', () => {
  it('createHire sends the request id exactly as given and trims the consumer', async () => {
    const { sdk, calls } = sdkAnswering(() => ({ hire: hireJson, preparedCreateJob: preparedJson('createJob') }));

    const result = await sdk.createHire(30, `  ${wallet}  `, '  the input  ', '  req-1  ');

    assert.deepEqual(calls[0], {
      endpoint: 'hire',
      method: 'createHire',
      authenticated: true,
      args: {
        agentId: 30,
        consumer: wallet,
        input: '  the input  ',
        requestId: '  req-1  ',
        subcontractReserve: null,
        allowRelatedParty: null,
      },
    });
    assert.equal(result.hire.id, 21);
    assert.equal(result.preparedCreateJob!.purpose, 'createJob');
    assert.ok(result.preparedCreateJob!.expiresAt instanceof Date);
    assert.equal(result.preparedCreateJob!.expiresAt.toISOString(), '2026-11-24T12:15:00.000Z');
  });

  it('createHire refuses what the server would refuse, without calling it', async () => {
    const { sdk, calls } = sdkAnswering(() => null);

    await assert.rejects(sdk.createHire(-1, wallet, 'x', 'r'), { argument: 'agentId' });
    await assert.rejects(sdk.createHire(1.5, wallet, 'x', 'r'), { argument: 'agentId' });
    await assert.rejects(sdk.createHire(30, ' ', 'x', 'r'), { argument: 'consumer' });
    await assert.rejects(sdk.createHire(30, wallet, '', 'r'), { argument: 'input' });
    await assert.rejects(sdk.createHire(30, wallet, 'x', '  '), { argument: 'requestId' });
    assert.equal(calls.length, 0);
  });

  it('getHire trims the consumer and decodes the detail', async () => {
    const { sdk, calls } = sdkAnswering(() => hireDetailJson);

    const detail = await sdk.getHire(21, ` ${wallet} `);

    assert.deepEqual(calls[0]!.args, { hireId: 21, consumer: wallet });
    assert.equal(detail.hire.status, 'submitted');
    assert.equal(detail.jobId, 35);
    assert.equal(detail.escrowSubmission!.updatedAt.toISOString(), '2026-11-24T12:01:00.000Z');
    assert.equal(detail.approvalDeadline, null);
  });

  it('the prepare calls send the hire id and return the unsigned envelope', async () => {
    const { sdk, calls } = sdkAnswering((call) => preparedJson(call.method));

    const prepared = [
      await sdk.prepareCreateJob(21),
      await sdk.prepareFund(21),
      await sdk.prepareComplete(21),
    ];

    assert.deepEqual(
      calls.map((c) => [c.endpoint, c.method, c.args]),
      [
        ['hire', 'prepareCreateJob', { hireId: 21 }],
        ['hire', 'prepareFund', { hireId: 21 }],
        ['hire', 'prepareComplete', { hireId: 21 }],
      ],
    );
    assert.equal(prepared.every((p) => p.unsignedTransactionXdr === 'AAAA'), true);
  });

  it('prepareReject trims the reason', async () => {
    const { sdk, calls } = sdkAnswering(() => preparedJson('reject'));

    await sdk.prepareReject(21, '  not needed any more  ');

    assert.deepEqual(calls[0]!.args, { hireId: 21, reason: 'not needed any more' });
  });

  it('hire ids below 1 are refused without calling the server', async () => {
    const { sdk, calls } = sdkAnswering(() => null);

    await assert.rejects(sdk.getHire(0, wallet), { argument: 'hireId' });
    await assert.rejects(sdk.prepareFund(0), { argument: 'hireId' });
    await assert.rejects(sdk.prepareReject(1, ' '), { argument: 'reason' });
    assert.equal(calls.length, 0);
  });

  it('listMyHires decodes each row', async () => {
    const { sdk } = sdkAnswering(() => [
      {
        id: 21,
        agentId: 30,
        agentName: 'Soroban Pre-Audit',
        status: 'completed',
        priceUsdcStroops: 5_000_000,
        inputPreview: 'Review…',
        approvalDeadline: null,
        needsAction: false,
        paidByAgentId: null,
        paidByAgentName: null,
      },
    ]);

    const [row] = await sdk.listMyHires();

    assert.equal(row!.agentName, 'Soroban Pre-Audit');
    assert.equal(row!.needsAction, false);
  });
});

describe('the Studio', () => {
  it('testRun sends the input exactly as given', async () => {
    const { sdk, calls } = sdkAnswering(() => ({ output: 'ok', remainingDailyRuns: 9 }));

    const result = await sdk.testRun(4, '  A long note.  ');

    assert.deepEqual(calls[0], {
      endpoint: 'studio',
      method: 'testRun',
      args: { draftId: 4, input: '  A long note.  ' },
      authenticated: true,
    });
    assert.equal(result.remainingDailyRuns, 9);
  });

  it('hireAgentAs sends the budget and returns the started hire', async () => {
    const { sdk, calls } = sdkAnswering(() => ({ hireId: 40, hiringWallet: wallet, state: 'funded' }));

    const started = await sdk.hireAgentAs(28, 29, 'Summarize.', 1_000_000);

    assert.deepEqual(calls[0]!.args, {
      hiringAgentId: 28,
      agentId: 29,
      input: 'Summarize.',
      budgetUsdcStroops: 1_000_000,
    });
    assert.equal(started.hireId, 40);
  });

  it('hireAgentAs refuses a budget below 1 stroop', async () => {
    const { sdk, calls } = sdkAnswering(() => null);

    await assert.rejects(sdk.hireAgentAs(28, 29, 'x', 0), { argument: 'budgetUsdcStroops' });
    assert.equal(calls.length, 0);
  });

  it('getDraft and listDrafts decode the manifest', async () => {
    const draft = {
      draftId: 4,
      manifest: {
        name: 'Summarizer',
        description: null,
        skills: [{ id: 'summarize', name: 'Summarize', description: null, tags: ['text'] }],
        model: { provider: 'workers-ai', id: '@cf/meta/llama-3.3-70b-instruct-fp8-fast' },
        systemPrompt: 'Summarize the text in five short bullet points.',
        inputType: 'text',
        inputMaxChars: 4000,
        outputType: 'text',
        outputMaxChars: 2000,
        price: { asset: 'USDC', amount: 1_000_000 },
      },
      revision: 3,
      deployState: 'draft',
      liveVersion: null,
      agentId: null,
      retryFromStep: null,
    };
    const { sdk } = sdkAnswering((call) => (call.method === 'getDraft' ? draft : [draft]));

    assert.equal((await sdk.getDraft(4)).manifest.skills![0]!.tags![0], 'text');
    assert.equal((await sdk.listDrafts())[0]!.manifest.price!.amount, 1_000_000);
  });
});

describe('formatUsdc', () => {
  it('keeps at least two decimals and drops trailing zeros past them', () => {
    assert.equal(formatUsdc(5_000_000), '0.50');
    assert.equal(formatUsdc(12_345_678), '1.2345678');
    assert.equal(formatUsdc(0), '0.00');
    assert.equal(formatUsdc(-1_000_000), '-0.10');
    assert.equal(formatUsdc(90_071_992_547_409_910n), '9007199254.740991');
  });
});

describe('Puls3Sdk.connect', () => {
  it('refuses an API URL that is not absolute http or https', () => {
    assert.throws(() => Puls3Sdk.connect('localhost:8080'), TypeError);
  });

  it('has a session only when one is given', () => {
    assert.equal(Puls3Sdk.connect('http://localhost:8080/').hasSession, false);
  });
});
