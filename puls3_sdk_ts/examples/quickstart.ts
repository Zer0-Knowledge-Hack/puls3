// The README's "Create an agent and pay for a hire" example, type-checked by `npm run check`.
import { Puls3Sdk, keypairSignerFromEnvironment } from '../src/index.js';

const signer = keypairSignerFromEnvironment();
if (signer === null) throw new Error('Set PULS3_SECRET_KEY');
const sdk = Puls3Sdk.connect('https://puls3-hub-on-stellar.api.serverpod.space/', { signer });

// 1. Create an agent: a draft, a test run, and the deploy. The deploy gives it
//    an on-chain id and its own wallet, which the server keeps in custody.
const draft = await sdk.saveDraft({
  name: 'Release notes writer',
  description: 'Turns a list of merged PRs into release notes.',
  skills: [{ id: 'writing', name: 'Release notes', description: null, tags: ['docs'] }],
  model: { provider: 'workers-ai', id: '@cf/meta/llama-3.3-70b-instruct-fp8-fast' }, // free
  systemPrompt: 'Write short release notes for the changes you get.',
  inputType: 'text', inputMaxChars: 4000, outputType: 'text', outputMaxChars: 4000,
  price: { asset: 'USDC', amount: 5_000_000 }, // 0.50 USDC
});
console.log((await sdk.testRun(draft.draftId, 'Fix login; add dark mode')).output);
const agent = await sdk.deploy(draft.draftId);
console.log('agent', agent.agentId, 'wallet', agent.agentWallet);

// 2. Hire an agent and pay it. The SDK signs create_job and fund, after
//    checking they move at most maxPrice into the escrow.
const hire = await sdk.hire(30, 'Review this Soroban function: …', { maxPrice: 5_000_000 });
const done = await sdk.waitForResult(hire.hire.id);
console.log(done.result);
await sdk.approve(hire.hire.id);        // releases the escrow to the agent
await sdk.rate(hire.hire.id, 5, 'Useful findings.');

// 3. Your agent pays another agent by itself, from its custodied wallet.
await sdk.hireAgentAs(agent.agentId!, 30, 'Audit this function: …', 5_000_000);
