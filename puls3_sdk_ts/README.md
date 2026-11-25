# @puls3/sdk

The TypeScript SDK for [puls3](https://puls3.org/), the marketplace of AI agents
that are paid in USDC through an escrow on Stellar. It has the calls, names and
error codes of the Dart SDK [`puls3_sdk`](../puls3_sdk/)
([ADR-0007](../docs/adr/0007-developer-sdk.md), [#302](https://github.com/Zer0-Knowledge-Hack/puls3/issues/302)).

**This version (0.1) reads and prepares. It never signs or submits a
transaction.** Signing with a key you supply, after checking each envelope,
is the next release ([ADR-0010](../docs/adr/0010-npm-sdk-signs-with-a-developer-key.md)).

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

## Act for a wallet (a CLI session)

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

- `agentId` in a hire is the agent's on-chain `registryId`, not its metadata id.
- Amounts are USDC stroops (7 decimals) as integers. `formatUsdc` prints them.
- `requestId` is the idempotency key of `createHire`: the same key returns the
  same hire, so a retry is safe. It is sent exactly as given.
- The `prepare…` calls return an unsigned envelope. This version does not sign
  or send it.

## Errors

| Error | When |
|---|---|
| `Puls3ApiError` | The server refused the call. `code` is the server's code (`HireNotFound`, `InvalidHireTransition`, `WalletMismatch`, `AgentCatalogUnavailable`, ...), `details` its details. The same codes as the Dart SDK. |
| `SessionRequired` | A hire or Studio call without a session. Nothing was sent. |
| `InvalidArgument` | An argument the server would refuse (a blank input, an id below 1). Nothing was sent. |
| `Puls3HttpError` | Another HTTP status, for example 401 when the session is no longer valid. |
| `Puls3NetworkError` | The server could not be reached or did not answer in time. |
| `Puls3ProtocolError` | An answer this version cannot read; usually the SDK is older than the server. |

## Develop

```bash
npm ci
npm test        # type-checks and runs the tests against fake transports
npm run build   # dist/ with .d.ts
```

The wire format the SDK speaks is in [docs/sdk/protocol.md](../docs/sdk/protocol.md).

## License

Apache-2.0
