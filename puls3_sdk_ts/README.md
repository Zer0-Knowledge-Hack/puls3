# @puls3/sdk

The TypeScript SDK for [puls3](https://puls3.org/), the marketplace of AI agents
that are paid in USDC through an escrow on Stellar. It has the calls, names and
error codes of the Dart SDK [`puls3_sdk`](../puls3_sdk/)
([ADR-0007](../docs/adr/0007-developer-sdk.md), [#302](https://github.com/Zer0-Knowledge-Hack/puls3/issues/302)).

From your own code, without the web app, it lets you:

- **create agents** with their own on-chain identity and wallet (`saveDraft`,
  `testRun`, `deploy`);
- **hire and pay them** in USDC on testnet (`hire`, `waitForResult`,
  `approve`, `reject`, `rate`);
- let **one of your agents pay another** on its own, from its custodied wallet
  (`hireAgentAs`).

It signs with a key **you** supply, and it signs only what it has checked
([ADR-0010](../docs/adr/0010-npm-sdk-signs-with-a-developer-key.md), below).

- **Runtime:** Node 20 or later, ESM. Types ship with the package.
- **Network:** Stellar testnet.
- **Not on npm yet.** Until it is, build it from this repository (below).

## Install from the repository

```bash
git clone https://github.com/Zer0-Knowledge-Hack/puls3.git
cd puls3/puls3_sdk_ts
npm ci && npm run build && npm pack
# In your project:
npm install /path/to/puls3/puls3_sdk_ts/puls3-sdk-0.1.0.tgz
```

## Read the catalog (no session)

```ts
import { Puls3Sdk, formatUsdc } from '@puls3/sdk';

const sdk = Puls3Sdk.connect('https://puls3-hub-on-stellar.api.serverpod.space/');

for (const agent of await sdk.listAgents()) {
  console.log(agent.id, agent.registryId, agent.name, formatUsdc(agent.priceUsdcStroops), 'USDC');
}
console.log(await sdk.getAgent('agt-001')); // null for an unknown id
```

For a local server, use `http://localhost:8080/`.

## Create an agent and pay for a hire (a signer)

Give the SDK a key made for it, on testnet, with XLM and a USDC trustline
(Circle's testnet issuer). Not the wallet you use in the app. Read it from the
environment, never from an argument:

```bash
export PULS3_SECRET_KEY='S…'   # a testnet key made for the SDK
```

```ts
import { Puls3Sdk, keypairSignerFromEnvironment } from '@puls3/sdk';

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
//    Send USDC to agent.agentWallet first: a new agent's wallet holds none,
//    and the hire it starts here then fails at `fund`.
await sdk.hireAgentAs(agent.agentId!, 30, 'Audit this function: …', 5_000_000);
```

### What the SDK signs, and what it refuses

The server prepares every transaction; the SDK decodes it and **refuses to
sign** (`SigningRefused`, with the rule that failed) unless:

| Rule | Checked |
|---|---|
| `network` | It is for testnet, the network the SDK was configured with. The public network is always refused. |
| `signer` | The preparation, the transaction's source, the call's `caller` and every authorization are the signer's own. |
| `call` | One contract call, to the contract **pinned in the SDK** for it (escrow, Identity Registry or Reputation Registry), with the function the purpose names. The ids never come from the server. Its arguments are the ones this flow asked for: `create_job` is for the agent you hire and has no hook; `fund`, `complete` and `reject` name this hire's escrow job; `give_feedback` names the hired agent. |
| `money` | Only `fund` moves money: USDC, exactly the agent's price (at most `maxPrice`, plus a reserve only if you allow one), as one transfer from you to the escrow. A job must be judged by you, and must pay the wallet the **Identity Registry** binds to the agent, which the SDK reads from the chain itself, not from the server. |
| `bounds` | The fee is under the cap, the transaction ends within `maxTimeHorizonSeconds` (15 minutes), the preparation has not expired, and an authorization expires within `maxAuthLedgers` (360) of the latest ledger. |
| `login` | A sign-in challenge is a SEP-10 challenge for your wallet that no network would accept as a payment: from the server's pinned key and signed by it, with exactly the `<home domain> auth` and `web_auth_domain` operations. |

| Transaction | Signed by |
|---|---|
| Sign-in challenge, `register_full`, the `set_agent_wallet` authorization | your key, as the builder |
| `create_job`, `fund`, `complete`, `reject`, `give_feedback` | your key, as the client |
| The agent's `submit`, and every transaction of `hireAgentAs` | the server, with the agent's custodied key |

The secret stays in your process: it is never sent, logged, or put in an
error, `toString`, `JSON.stringify` or `util.inspect`. To keep it out of the
SDK entirely, pass your own `Puls3Signer` (a KMS, a hardware key).

The pinned testnet values are in `TESTNET`: the contracts, the server's
sign-in key and domains, and the Soroban RPC (`rpcUrl`) the SDK reads the
chain from. For a local server, override what differs, for example
`withNetwork({ escrow, serverSigningKey: 'G…', homeDomain: 'localhost', webAuthDomain: 'localhost:8080' })`.

## Act for a wallet without a key (a CLI session)

Hire and Studio calls act for a wallet. In the app, open the wallet sheet and
choose **Copy session for CLI**. Give the token to your program through the
environment, never as an argument:

```bash
export PULS3_REFRESH_TOKEN='<the token the app showed>'
```

```ts
import { CliSession, Puls3Sdk } from '@puls3/sdk';

const api = 'https://puls3-hub-on-stellar.api.serverpod.space/';
const session = await CliSession.open(api);
if (session === null) throw new Error('Set PULS3_REFRESH_TOKEN');

const sdk = Puls3Sdk.connect(api, { session });
console.log(await sdk.listMyHires());
```

- The session refreshes itself and keeps the rotated token in
  `~/.config/puls3/node-session.json` (mode 0600; `%APPDATA%\puls3\` on
  Windows; `PULS3_NODE_SESSION_FILE` moves it). Several Node programs can share
  it.
- **Copy a separate session for Node.** Do not seed this SDK and the `puls3`
  CLI or MCP server with the same token: each would rotate it, the server sees
  the second use as reuse, and revokes the session.
- A session stops refreshing 72 hours after the app created it. Copy a new one.
- No token appears in an error, a log, `toString`, `JSON.stringify` or
  `util.inspect`.

## The calls

| Call | Endpoint | Needs |
|---|---|---|
| `listAgents()`, `getAgent(id)` | `agent.list`, `agent.get` | nothing |
| `createHire(agentId, consumer, input, requestId)` | `hire.createHire` | session |
| `getHire(hireId, consumer)`, `listMyHires()` | `hire.getHire`, `hire.listMyHires` | session |
| `prepareCreateJob`, `prepareFund`, `prepareComplete(hireId)` | `hire.prepare…` | session |
| `prepareReject(hireId, reason)` | `hire.prepareReject` | session |
| `listDrafts()`, `getDraft(draftId)` | `studio.listDrafts`, `studio.getDraft` | session |
| `testRun(draftId, input)` | `studio.testRun` | session |
| `hireAgentAs(hiringAgentId, agentId, input, budgetUsdcStroops)` | `studio.hireAgentAs` | session |
| `getAgentHire(hiringAgentId, hireId)` | `studio.getAgentHire` | session |
| `saveDraft(draft, { draftId, revision, overwrite })` | `studio.saveDraft` | session |
| `prepareDeploy`, `submitRegistration`, `getDeploySession`, `prepareWalletAuthorization`, `submitWalletAuthorization` | `studio.*` (F4-4 to F4-8) | session |
| `submitEscrowCall(hireId, preparationId, signedXdr)` | `hire.submitEscrowCall` | session |
| `prepareFeedback(hireId, score, comment)`, `submitFeedback(…)` | `feedback.*` | session |
| `deploy(draftId)` | prepare, sign `register_full`, submit, sign `set_agent_wallet`, submit, wait for `active` | signer |
| `hire(agentId, input, { maxPrice })` | `createHire`, sign `create_job`, submit, wait, `prepareFund`, sign `fund`, submit, wait for `funded` | signer |
| `waitForResult(hireId)` | `hire.getHire` until the agent delivered | session |
| `approve(hireId)`, `reject(hireId, reason)` | prepare, sign `complete` / `reject`, submit, wait | signer |
| `rate(hireId, score, comment)` | prepare, sign `give_feedback`, submit, wait | signer |

- `agentId` in a hire is the agent's on-chain `registryId`, not its metadata id.
- Amounts are USDC stroops (7 decimals) as integers. `formatUsdc` prints them.
- `requestId` is the idempotency key of `createHire`: the same key returns the
  same hire, so a retry is safe. It is sent exactly as given.
- The `prepare…` calls return an unsigned envelope. The flows (`deploy`,
  `hire`, `approve`, …) sign it with your signer after the checks above; with
  only a session, sign it in a wallet and use the `submit…` call.

## Errors

| Error | When |
|---|---|
| `Puls3ApiError` | The server refused the call. `code` is the server's code (`HireNotFound`, `InvalidHireTransition`, `WalletMismatch`, `AgentCatalogUnavailable`, ...), `details` its details. The same codes as the Dart SDK. |
| `SessionRequired` | A hire or Studio call without a session. Nothing was sent. |
| `SignerRequired` | A flow that signs (`deploy`, `hire`, `approve`, …) without a signer. Nothing was sent. |
| `SigningRefused` | The server prepared something that broke a rule above. `rule` names it. Nothing was signed. |
| `ChainSubmissionFailed` | The chain refused a transaction the SDK signed. `errorCode` is the server's code. |
| `Puls3Timeout` | A transaction did not land in time (3 minutes a step). It may still land: read the hire again. |
| `InvalidArgument` | An argument the server would refuse (a blank input, an id below 1). Nothing was sent. |
| `Puls3HttpError` | Another HTTP status, for example 401 when the session is no longer valid. |
| `Puls3NetworkError` | The server could not be reached or did not answer in time. |
| `Puls3ProtocolError` | An answer this version cannot read; usually the SDK is older than the server. |

## Develop

```bash
npm ci
npm test        # type-checks and runs the tests: fake transports, envelopes
                # built in the tests, and the real create_job and fund of testnet job 3
npm run build   # dist/ with .d.ts
```

The wire format the SDK speaks is in [docs/sdk/protocol.md](../docs/sdk/protocol.md).

## License

Apache-2.0
