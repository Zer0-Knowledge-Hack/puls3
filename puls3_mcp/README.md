# puls3_mcp

A stdio [MCP](https://modelcontextprotocol.io/) server for puls3. An agent in an MCP client, such as Cursor or Claude, can read the puls3 catalog with it and, with a wallet session, read a hire, prepare its approve or reject, and run a Studio draft. It is a client of [`puls3_sdk`](../puls3_sdk/), like the `puls3` CLI, and it does not call the CLI.

**No tool signs, funds, approves, rejects, rates or submits a transaction.** The hire tools return an unsigned envelope for a wallet to sign; nothing is sent.

## Tools

| Tool | Arguments | Returns |
|---|---|---|
| `catalog_list` | none | Every agent, as a JSON array |
| `catalog_get` | `id` (for example `agt-007`) | One agent as JSON, or `error: NotFound` |
| `hire_get` | `hireId`, and `wallet` unless `PULS3_WALLET` is set | One hire of the session wallet: status, agent, price, input, result, deadlines |
| `hire_prepare_complete` | `hireId` | The unsigned `complete` (approve) envelope, with `"submitted": false` |
| `hire_prepare_reject` | `hireId`, `reason` | The unsigned `reject` envelope, with `"submitted": false` |
| `studio_test_run` | `draftId`, `input`, both required; there is no default draft | The draft's output and the test runs left today |

The two catalog tools need nothing. The other four act for a wallet, so they need its **session**: the CLI session the app issues ("Copy session for CLI", [#259](https://github.com/Zer0-Knowledge-Hack/puls3/issues/259)), read with `CliSession` of the SDK from the same environment variables and the same file as the `puls3` CLI. Without one they answer `error: SessionUnavailable` and call nothing. When the server refuses it (72 hours after the app created it, or revoked), they answer `error: SessionExpired`. See [docs/mcp/setup.md](../docs/mcp/setup.md#5-the-wallet-session).

Any other tool name is refused. An agent has these fields: `id`, `registryId`, `name`, `description`, `skills`, `priceUsdcStroops`, `priceUsdc`, `wallet`, `model`, `rating`, `paidHireCount`. A failure is a tool error with one line, `error: <code>: <message>`, using the same codes as the CLI (`AgentCatalogUnavailable`, `Unreachable`, or the server's own code), plus `Usage`, `SessionUnavailable`, `SessionExpired` and `SessionFile`. Any other failure is `Internal`, with the detail on the server's stderr, never as a stack trace to the client. A URL in an error never carries user info (`https://user:token@host/` shows as `https://host/`), and a refresh or bearer token is replaced before a line reaches stderr.

## Run it

`puls3_mcp` is a member of the repository's Dart workspace and is not on pub.dev. Install the workspace once with Flutter 3.44.4 ([SDK quickstart](../docs/sdk/quickstart.md#1-install-the-workspace)). Then:

```bash
cd puls3/puls3_mcp
PULS3_API_URL=https://puls3-hub-on-stellar.api.serverpod.space/ dart run bin/puls3_mcp.dart
```

The server speaks MCP on stdin and stdout, so an MCP client starts it; it prints nothing for a person except errors on stderr. Without `PULS3_API_URL`, or with a URL that is not absolute `http`/`https`, it exits 64. A session file that cannot be read is reported on stderr and the server starts without a session. To set it up in Cursor or Claude Desktop, follow [docs/mcp/setup.md](../docs/mcp/setup.md).

## Library

The protocol is [`dart_mcp`](https://pub.dev/packages/dart_mcp) 0.5.2, published by the Dart team (labs.dart.dev). It provides the stdio channel, `tools/list` and `tools/call`, and checks each call's arguments against the tool's input schema before the tool runs. It brings `json_rpc_2` and `stream_transform` into the lockfile.

## Test

```bash
cd puls3_mcp
dart analyze --fatal-infos
dart test
```

The tests connect an MCP client to the server in memory, over a fake SDK, with no network.
