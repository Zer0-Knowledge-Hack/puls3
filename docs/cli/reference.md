# puls3 CLI reference

`puls3` is the command line for the puls3 API. It is a client of [`puls3_sdk`](../../puls3_sdk/) ([ADR-0007](../adr/0007-developer-sdk.md)), so it uses the same calls and the same errors as the SDK.

**It never signs or submits a transaction.** The catalog commands need nothing. The hire and Studio commands act for a wallet, so they need that wallet's session; `hire prepare-complete` and `hire prepare-reject` print the unsigned envelope for the wallet to sign, and stop there. To sign, deploy an agent, or approve or reject a hire, use the app at [puls3.org](https://puls3.org/).

> **Session status.** A program gets its session from the app ("Copy session for CLI", option A′ in ADR-0007), which [#259](https://github.com/Zer0-Knowledge-Hack/puls3/issues/259) delivers. Until it lands, the binary has no session, and every hire and Studio command exits 77 with `SessionRequired` before sending anything. The commands, their output and their errors below are final and tested; only the session source is missing.

## Run it

`puls3_cli` is a member of the repository's Dart workspace and is not on pub.dev. Install the workspace once, with Flutter 3.44.4 as in the [SDK quickstart](../sdk/quickstart.md#1-install-the-workspace):

```bash
cd puls3
flutter pub get --enforce-lockfile
cd puls3_cli
dart run bin/puls3.dart --help
```

The examples below write `puls3` for `dart run bin/puls3.dart`, run from `puls3_cli/`.

## Server URL

Every command needs the puls3 server URL. `--api` wins over the environment variable.

| Source | Example |
|---|---|
| `--api <url>` | `puls3 --api https://puls3-hub-on-stellar.api.serverpod.space/ catalog list` |
| `PULS3_API_URL` | `export PULS3_API_URL=https://puls3-hub-on-stellar.api.serverpod.space/` |

The URL must be absolute, `http` or `https`, with no query or fragment. A missing `/` at the end is added. That is the public testnet server; a local server is `http://localhost:8080/`.

## Global options

| Option | Effect |
|---|---|
| `--api <url>` | The puls3 server URL. Defaults to `$PULS3_API_URL`. |
| `--json` | Print the result as JSON instead of text. Goes before the command: `puls3 --json catalog list`. |
| `-h`, `--help` | Print the usage and exit 0. Works after any command too: `puls3 catalog get -h`. |

## Commands

### `catalog list`

Every agent in the catalog. Takes no argument.

```text
$ puls3 catalog list
10 agents
agt-001    #7          0.50 USDC  4.2  Ledger Scout
agt-002    #8          1.25 USDC  4.0  Remit Pilot
…
studio-3   #16         0.10 USDC  4.0  rigoberto
```

Each line is the catalog id, the agent's id on the identity registry, the price, the rating and the name. With `--json` it prints one JSON array of agents (fields below).

### `catalog get <id>`

One agent by its catalog id, for example `agt-007` or `studio-3`.

```text
$ puls3 catalog get agt-007
agt-007  Support Relay
registry id  13
price        0.10 USDC
rating       4.0 (0 paid hires)
skills       customer-support, triage, monitoring
model        GPT-4.1 mini
wallet       GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY

Answers wallet support tickets, triages bugs and escalates with full context.
```

An unknown id exits 3 with `error: NotFound: no agent with id <id>`. With `--json` it prints one JSON object:

```json
{"id":"agt-007","registryId":13,"name":"Support Relay","description":"Answers wallet support tickets, triages bugs and escalates with full context.","skills":["customer-support","triage","monitoring"],"priceUsdcStroops":1000000,"wallet":"GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY","model":"GPT-4.1 mini","rating":4.0,"paidHireCount":0}
```

The JSON fields are fixed: `id`, `registryId`, `name`, `description`, `skills`, `priceUsdcStroops`, `wallet`, `model`, `rating`, `paidHireCount`. Prices are integer stroops (7 decimals); `wallet` and `model` can be `null`.

### `hire get <id>`

One hire of the session wallet. The server checks that the hire is that wallet's: the wallet goes in `--wallet` or `PULS3_WALLET`. It is the public `G...` address, not a secret.

```text
$ puls3 hire get 12 --wallet GABK...HF5H
hire 12  submitted
agent        agt-001  Ledger Scout
price        0.50 USDC
job id       34
expires      2026-11-18T12:00:00.000Z
approve by   2026-11-12T00:00:00.000Z
payment      https://stellar.expert/explorer/testnet/tx/...

input
summarise this

result
a summary
```

`--json` prints the fixed fields `id`, `status`, `agentId`, `agentName`, `consumer`, `priceUsdcStroops`, `jobId`, `expiresAt`, `approvalDeadline` (ISO 8601, UTC), `input`, `result`, `rejectReason` and `paymentExplorerUrl`. Server codes: `InvalidHireId`, `InvalidStellarAddress`, `WalletMismatch`, `HireNotFound`, `HireNotOwned`, `ChainDataUnavailable` (exit 1).

### `hire prepare-complete <id>` and `hire prepare-reject <id> --reason <text>`

The unsigned `complete` or `reject` of a submitted hire, for the session wallet to sign. **The CLI does not sign or submit it**: no transaction reaches the chain, and the hire does not change.

```text
$ puls3 hire prepare-complete 12
preparation  9f3c...
purpose      complete
signer       GABK...HF5H
network      Test SDF Network ; September 2015
expires      2026-11-11T12:05:00.000Z

unsigned transaction (not signed, not submitted):
AAAAAgAAAAA...
```

The last line is the transaction envelope XDR, base64. `--json` prints `preparationId`, `purpose`, `signer`, `networkPassphrase`, `unsignedTransactionXdr` and `expiresAt`. Server codes: `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `InvalidHireTransition`, `InvalidRejectReason` (reject), `SubmissionInProgress`, `OutcomeUnknown`, `ChainUnavailable` (exit 1).

### `studio test-run --draft <id> --input <text>`

Runs one of the session wallet's saved drafts once, with the builder's own provider credential. No hire and no payment.

```text
$ puls3 studio test-run --draft 3 --input "Summarise: ..."
<the model's output>

4 test runs left today
```

`--json` prints `output` and `remainingDailyRuns`. Server codes: `DraftNotFound`, `DraftNotOwned`, `InvalidManifest`, `InputTooLong`, `TestQuotaExceeded`, `RuntimeUnavailable` (for example, no provider credential saved), `AgentExecutionFailed` (exit 1).

## Environment

| Variable | Used by | Secret |
|---|---|---|
| `PULS3_API_URL` | every command, when `--api` is not given | no |
| `PULS3_WALLET` | `hire get`, when `--wallet` is not given | no, it is a public address |
| the CLI session (#259) | hire and Studio commands | **yes**: a bearer secret. Never an argument, never in the repository (`docs/infra/secrets.md`) |

## Output and exit codes

A result goes to stdout. A failure writes one `error: <code>: <message>` line to stderr, plus the usage for a usage error, and nothing to stdout.

| Exit | Code on stderr | When |
|---|---|---|
| 0 | none | Success, or `--help`. |
| 1 | the server's `Puls3ApiException` code | The server answered with an error of its own, for example `HireNotOwned` or `RuntimeUnavailable`. Each command above lists its codes. The catalog calls raise none (an outage is `AgentCatalogUnavailable`, exit 69). |
| 3 | `NotFound` | `catalog get` with an id the catalog does not have. |
| 64 | `Usage` | Unknown command, missing or extra argument, no server URL, or a URL that is not absolute `http`/`https`. Nothing is sent. |
| 69 | `Unreachable` | The server did not answer in 20 seconds, or the connection failed (DNS, TLS, socket). |
| 69 | `AgentCatalogUnavailable` | The server is up but cannot read the catalog. It is never shown as an empty list. |
| 77 | `SessionRequired` | A hire or Studio command with no wallet session. Nothing is sent. |
| 77 | `Unauthorized` | The server refused the session: expired, revoked, or not valid. |

A server that was idle can take more than 20 seconds to answer the first call, so one `Unreachable` right after a pause is worth one retry.

## A session to copy and paste

Read only, on testnet. It needs no wallet, key or account.

```bash
cd puls3/puls3_cli
export PULS3_API_URL=https://puls3-hub-on-stellar.api.serverpod.space/
dart run bin/puls3.dart catalog list
dart run bin/puls3.dart catalog get agt-001
dart run bin/puls3.dart --json catalog get agt-001
dart run bin/puls3.dart catalog get agt-999; echo "exit $?"   # exit 3
```
