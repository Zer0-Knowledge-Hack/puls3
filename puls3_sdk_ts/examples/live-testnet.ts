// A live run of the SDK on testnet (#302): it deploys an agent and hires and
// pays another one, then prints every step so the run can be posted as
// evidence. Run it from this folder:
//
//   npm ci
//   PULS3_SECRET_KEY='S…' npm run live
//
// The key must be a testnet key made for this, with XLM and at least 0.5
// Circle testnet USDC (issuer GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5).
// Optional: PULS3_API_URL (production by default), PULS3_AGENT_ID (30, Soroban
// Pre-Audit), PULS3_SKIP_DEPLOY=1 to only hire.

import { Puls3Sdk, formatUsdc, keypairSignerFromEnvironment } from '../src/index.js';

const api = process.env['PULS3_API_URL'] ?? 'https://puls3-hub-on-stellar.api.serverpod.space/';
const agentId = Number(process.env['PULS3_AGENT_ID'] ?? '30');
const signer = keypairSignerFromEnvironment();
if (signer === null) {
  console.error('Set PULS3_SECRET_KEY to a testnet key made for this run.');
  process.exit(64);
}
const sdk = Puls3Sdk.connect(api, { signer });
const tx = (hash: string | null | undefined) =>
  hash ? `https://stellar.expert/explorer/testnet/tx/${hash}` : '(no hash)';

console.log(`wallet ${sdk.wallet} on ${api}`);

if (process.env['PULS3_SKIP_DEPLOY'] !== '1') {
  const draft = await sdk.saveDraft({
    name: 'SDK release notes',
    description: 'Turns a list of merged changes into short release notes.',
    skills: [{ id: 'release-notes', name: 'Release notes', description: null, tags: ['docs'] }],
    model: { provider: 'workers-ai', id: '@cf/meta/llama-3.3-70b-instruct-fp8-fast' },
    systemPrompt: 'Write short, plain release notes for the changes you get.',
    inputType: 'text',
    inputMaxChars: 2000,
    outputType: 'text',
    outputMaxChars: 2000,
    price: { asset: 'USDC', amount: 1_000_000 },
  });
  console.log(`draft ${draft.draftId}`);
  console.log(`test run: ${(await sdk.testRun(draft.draftId, 'Fix login; add dark mode')).output}`);
  const agent = await sdk.deploy(draft.draftId, { onState: (s) => console.log(`deploy: ${s.state}`) });
  console.log(`agent ${agent.agentId}, wallet ${agent.agentWallet}`);
}

const target = (await sdk.listAgents()).find((a) => a.registryId === agentId);
if (target === undefined || !target.hireable) throw new Error(`agent ${agentId} is not hireable`);
console.log(`hiring ${target.name} for ${formatUsdc(target.priceUsdcStroops)} USDC`);

const hire = await sdk.hire(agentId, 'pub fn add(a: i128, b: i128) -> i128 { a + b }', {
  maxPrice: target.priceUsdcStroops,
});
const id = hire.hire.id;
console.log(`hire ${id}, job ${hire.jobId}, fund ${tx(hire.escrowSubmission?.transaction)}`);

const result = await sdk.waitForResult(id);
console.log(`status ${result.hire.status}\n${result.result ?? ''}`);
if (result.hire.status !== 'submitted') process.exit(1);

const approved = await sdk.approve(id);
console.log(`complete ${tx(approved.escrowSubmission?.transaction)}`);
const rated = await sdk.rate(id, 5, 'Run from @puls3_org/sdk.');
console.log(`give_feedback ${tx(rated.feedbackSubmission?.transaction)}`);
