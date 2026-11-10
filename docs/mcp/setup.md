# puls3 MCP setup (Cursor and Claude Desktop)

> **This server cannot sign, fund or submit a transaction.**
> Its tools read the puls3 catalog and, once the SDK has a wallet session, prepare unsigned envelopes. Nothing it returns is sent to Stellar. To approve or reject a hire, or to deploy an agent, use the app at [puls3.org](https://puls3.org/), where your wallet signs.

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

The server reads the API URL from `PULS3_API_URL`. The public testnet server is `https://puls3-hub-on-stellar.api.serverpod.space/`; a local one is `http://localhost:8080/`. The server needs no key, token or wallet, so the config holds no secret.

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

Ask the client something like *"List the puls3 agents and their prices"*. It calls `catalog_list` and gets the catalog as JSON, ten agents on testnet today (`agt-001` to `agt-008`, `studio-1`, `studio-3`).

## Tools

| Tool | Arguments | What it does |
|---|---|---|
| `catalog_list` | none | Returns every agent in the catalog: id, registry id, name, skills, price, wallet, model and rating. |
| `catalog_get` | `id` | Returns one agent by its catalog id, for example `agt-007`, or `NotFound`. |
| `hire_get` | `hireId` | Will return one hire of the signed-in wallet. |
| `hire_prepare_complete` | `hireId` | Will prepare the unsigned escrow `complete` (approve) of a hire for your wallet to sign. It does not send it. |
| `hire_prepare_reject` | `hireId`, `reason` | Will prepare the unsigned escrow `reject` of a hire for your wallet to sign. It does not send it. |
| `studio_test_run` | `draftId`, `input` | Will run one of your Studio drafts on an input. Both arguments are required. |

**Today only the two catalog tools work.** The other four need a wallet session that the SDK does not have yet ([ADR-0007](../adr/0007-developer-sdk.md#open-decisions), [#259](https://github.com/Zer0-Knowledge-Hack/puls3/issues/259)). Until then they answer `error: SessionUnavailable` and call nothing. This page will say how to pass the session when #259 lands.

## When something fails

Every failure is a tool error with one line, `error: <code>: <message>`:

| Code | Meaning | What to do |
|---|---|---|
| `Unreachable` | The server did not answer in 20 seconds, or the connection failed. | An idle testnet server can take that long to wake up. Call the tool once more. |
| `AgentCatalogUnavailable` | The server is up but cannot read the catalog. | Try again later. The tool never shows that as an empty list. |
| `NotFound` | `catalog_get` with an id the catalog does not have. | Check the id with `catalog_list`. |
| `SessionUnavailable` | A hire or Studio tool, before #259. | Use [puls3.org](https://puls3.org/). |

If the client shows no tools at all, the process did not start. Run the same command in a terminal:

```bash
PULS3_API_URL=https://puls3-hub-on-stellar.api.serverpod.space/ /Users/you/flutter/bin/dart run /Users/you/code/puls3/puls3_mcp/bin/puls3_mcp.dart
```

If `PULS3_API_URL` is missing or invalid, it prints `error: Usage: ...` to stderr and exits 64. Otherwise it starts and then waits silently on stdin (stop it with Ctrl+C), because stdout carries only the protocol. A wrong path to `dart` or to the script fails here with the shell's own error.
