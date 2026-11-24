# puls3 MCP setup (Cursor and Claude Desktop)

> **This server cannot sign, fund or submit a transaction.**
> Its tools read the puls3 catalog and, with a wallet session, read a hire, run a Studio draft and prepare unsigned envelopes. Nothing it returns is sent to Stellar. To approve or reject a hire, or to deploy an agent, use the app at [puls3.org](https://puls3.org/), where your wallet signs.

`puls3_mcp` is a stdio [MCP](https://modelcontextprotocol.io/) server over [`puls3_sdk`](../../puls3_sdk/) ([ADR-0007](../adr/0007-developer-sdk.md)). Your MCP client starts it as a local process. It is not a hosted endpoint. The package and its tests are in [`puls3_mcp/`](../../puls3_mcp/).

## 1. Install the workspace

You need Flutter 3.44.4 and a clone of this repository, as in the [SDK quickstart](../sdk/quickstart.md#1-install-the-workspace):

```bash
git clone https://github.com/Zer0-Knowledge-Hack/puls3.git
cd puls3
flutter pub get --enforce-lockfile
```

The client needs two absolute paths:

| Value | How to find it | Example |
|---|---|---|
| The `dart` binary | `which dart` (macOS, Linux) or `where dart` (Windows) | `/Users/you/flutter/bin/dart` |
| The server script | `<your clone>/puls3_mcp/bin/puls3_mcp.dart` | `/Users/you/code/puls3/puls3_mcp/bin/puls3_mcp.dart` |

Use the absolute path to `dart`: a desktop app may not see the `PATH` of your shell. On Windows, write the paths with forward slashes or doubled backslashes in JSON (`C:/code/puls3/...` or `C:\\code\\puls3\\...`).

The server reads the API URL from `PULS3_API_URL`. The public testnet server is `https://puls3-hub-on-stellar.api.serverpod.space/`; a local one is `http://localhost:8080/`. For the catalog the server needs no key, token or wallet, so this config holds no secret. The hire and Studio tools need a wallet session, added in [step 5](#5-the-wallet-session).

## 2. Cursor

Add the server to `.cursor/mcp.json` in a project, or to `~/.cursor/mcp.json` for every project:

```json
{
  "mcpServers": {
    "puls3": {
      "command": "/Users/you/flutter/bin/dart",
      "args": ["run", "/Users/you/code/puls3/puls3_mcp/bin/puls3_mcp.dart"],
      "env": {
        "PULS3_API_URL": "https://puls3-hub-on-stellar.api.serverpod.space/"
      }
    }
  }
}
```

Restart Cursor, or turn the server off and on in the MCP section of Cursor's settings. The server shows as `puls3` with six tools.

## 3. Claude Desktop

Open **Settings → Developer → Edit Config**. That is `claude_desktop_config.json`, in `~/Library/Application Support/Claude/` on macOS and `%APPDATA%\Claude\` on Windows. Add the same block:

```json
{
  "mcpServers": {
    "puls3": {
      "command": "/Users/you/flutter/bin/dart",
      "args": ["run", "/Users/you/code/puls3/puls3_mcp/bin/puls3_mcp.dart"],
      "env": {
        "PULS3_API_URL": "https://puls3-hub-on-stellar.api.serverpod.space/"
      }
    }
  }
}
```

If the file already has `mcpServers`, add only the `"puls3": { ... }` entry inside it. Quit and reopen Claude Desktop. The tools appear under `puls3` in the tools menu.

## 4. Try it

Ask the client something like *"List the puls3 agents and their prices"*. It calls `catalog_list` and gets the catalog as JSON. On 2026-11-10 the testnet catalog had ten agents (`agt-001` to `agt-008`, `studio-1`, `studio-3`).

## 5. The wallet session

The catalog tools work as soon as the server starts. The other four act for your wallet, so they need a **CLI session**: a separate session that the app issues for your wallet. It can read your hires, run your drafts and prepare envelopes. It cannot move funds, because nothing here signs.

1. In the app at [puls3.org](https://puls3.org/), connect your wallet, open the wallet sheet and choose **Copy session for CLI**. The app shows the token once.
2. Give it to the server **once**, as `PULS3_REFRESH_TOKEN`, and tell it your wallet's public address:

   ```json
   "env": {
     "PULS3_API_URL": "https://puls3-hub-on-stellar.api.serverpod.space/",
     "PULS3_WALLET": "G...your wallet's public address",
     "PULS3_REFRESH_TOKEN": "paste the token here"
   }
   ```

3. Restart the client and call a hire tool. The server saves the session in a file only you can read (`~/.config/puls3/session.json`, or `%APPDATA%\puls3\session.json` on Windows; `PULS3_SESSION_FILE` moves it).
4. **Remove `PULS3_REFRESH_TOKEN` from the config** and restart once more. The token rotates on every refresh, so the one you pasted is already used up, and the saved file is what the server reads from then on.

Things to know:

- **The token is a secret while it is in the config.** Anyone who reads it before step 4 can act as your CLI session. Do not commit that file and do not paste the token into a chat with the agent.
- **`PULS3_WALLET` is not a secret.** It is your public address, and `hire_get` needs it. You can also pass `wallet` in the call.
- **The session ends 72 hours after the app created it.** The tools then answer `error: SessionExpired`: copy a new session and repeat the steps.
- **It is separate from the app's session.** Ending one does not end the other. To end a CLI session early, revoke it in the wallet sheet ([Revoke a CLI session](#revoke-a-cli-session)); otherwise it ends at 72 hours.
- **The `puls3` CLI uses the same file.** If you already seeded the CLI, the server finds the session with no token in its config: set only `PULS3_WALLET`.
- **More on CLI sessions,** including how an automated test gets one without the app: [CLI sessions outside the app](../sdk/sessions.md).

## Tools

| Tool | Arguments | What it does |
|---|---|---|
| `catalog_list` | none | Returns every agent in the catalog: id, registry id, name, skills, price, wallet, model and rating. |
| `catalog_get` | `id` | Returns one agent by its catalog id, for example `agt-007`, or `NotFound`. |
| `hire_get` | `hireId`, `wallet` (optional with `PULS3_WALLET`) | Returns one hire of your wallet: status, agent, price, input, result and deadlines. |
| `hire_prepare_complete` | `hireId` | Prepares the unsigned escrow `complete` (approve) of a hire for your wallet to sign. It does not send it. |
| `hire_prepare_reject` | `hireId`, `reason` | Prepares the unsigned escrow `reject` of a hire for your wallet to sign. It does not send it. |
| `studio_test_run` | `draftId`, `input` | Runs one of your Studio drafts on an input and returns its output. It uses one of your daily test runs. Both arguments are required. |

The two prepare tools return the envelope with `"submitted": false`. To approve or reject, open the hire in the app, where your wallet signs. You can check on [stellar.expert](https://stellar.expert/explorer/testnet) that calling them sent no transaction.

## Revoke a CLI session

The app creates CLI sessions from the wallet sheet (**Copy session for CLI**). The same sheet lists the wallet's live sessions under that action: each shows when it was created, last used and when it ends, with a **Revoke** button. Revoking one never signs out the app. A revoked session can still answer for up to 10 minutes, because access tokens are checked without a database read until they expire.

## When something fails

Every failure is a tool error with one line, `error: <code>: <message>`:

| Code | Meaning | What to do |
|---|---|---|
| `Unreachable` | The server did not answer in 20 seconds, or the connection failed. | An idle testnet server can take that long to wake up. Call the tool once more. |
| `AgentCatalogUnavailable` | The server is up but cannot read the catalog. | Try again later. The tool never shows that as an empty list. |
| `NotFound` | `catalog_get` with an id the catalog does not have. | Check the id with `catalog_list`. |
| `SessionUnavailable` | A hire or Studio tool, and the server has no session. | Follow [step 5](#5-the-wallet-session). |
| `SessionExpired` | The server refused the session: 72 hours passed, or it was revoked. | Copy a new session in the app and repeat step 5. |
| `SessionFile` | The session file could not be read or written. | Check the path in the message and its permissions, or set `PULS3_SESSION_FILE`. |
| `Usage` | An argument is missing or not valid, for example `hire_get` with no wallet. | Fix the argument the message names. |
| `InvalidHireTransition` and other server codes | The server refused the call, for example approving a hire that is not `submitted`. | The message says why. |
| `Internal` | Something unexpected failed inside the server. | The detail is in the client's MCP log for `puls3` (the server's stderr). Report it with that line. |

If the client shows no tools at all, the process did not start. Run the same command in a terminal:

```bash
PULS3_API_URL=https://puls3-hub-on-stellar.api.serverpod.space/ /Users/you/flutter/bin/dart run /Users/you/code/puls3/puls3_mcp/bin/puls3_mcp.dart
```

If `PULS3_API_URL` is missing or invalid, it prints `error: Usage: ...` to stderr and exits 64. Otherwise it starts and then waits silently on stdin (stop it with Ctrl+C), because stdout carries only the protocol. A wrong path to `dart` or to the script fails here with the shell's own error.
