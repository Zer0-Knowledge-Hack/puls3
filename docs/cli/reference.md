# puls3 CLI reference

`puls3` is the command line for the puls3 API. It is a client of [`puls3_sdk`](../../puls3_sdk/) ([ADR-0007](../adr/0007-developer-sdk.md)), so it uses the same calls and the same errors as the SDK.

**It never signs or submits a transaction.** It reads the catalog today. The hire and Studio commands (`hire get`, `hire prepare-complete` and the rest) wait for the wallet session decision in ADR-0007 and for [#259](https://github.com/Zer0-Knowledge-Hack/puls3/issues/259). To deploy an agent, or to approve or reject a hire, use the app at [puls3.org](https://puls3.org/).

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

## Output and exit codes

A result goes to stdout. A failure writes one `error: <code>: <message>` line to stderr, plus the usage for a usage error, and nothing to stdout.

| Exit | Code on stderr | When |
|---|---|---|
| 0 | none | Success, or `--help`. |
| 1 | the server's `Puls3ApiException` code | The server answered with an error of its own. The catalog calls raise none today (an outage is `AgentCatalogUnavailable`, exit 69), so this is for the codes the API contract adds later. |
| 3 | `NotFound` | `catalog get` with an id the catalog does not have. |
| 64 | `Usage` | Unknown command, missing or extra argument, no server URL, or a URL that is not absolute `http`/`https`. Nothing is sent. |
| 69 | `Unreachable` | The server did not answer in 20 seconds, or the connection failed (DNS, TLS, socket). |
| 69 | `AgentCatalogUnavailable` | The server is up but cannot read the catalog. It is never shown as an empty list. |

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
