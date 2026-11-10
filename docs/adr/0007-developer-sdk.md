# ADR-0007: Developer SDK (`puls3_sdk`)

- **Status:** Proposed. The catalog part is implemented (#229); the session decision ([Open decision 1](#open-decisions)) and the session-bound operations are [#259](https://github.com/Zer0-Knowledge-Hack/puls3/issues/259).
- **Date:** 2026-11-05
- **Issue:** #222 (week 2 of the developer platform)
- **Clients of this package:** the `puls3` CLI (#224), the MCP server (#226)
- **Guides:** SDK quickstart (#223), CLI reference (#225), [MCP setup](../mcp/setup.md) (#227)
- **Related:** [API contract](../architecture/api.md) · [ADR-0001](0001-system-architecture.md) · [secrets](../infra/secrets.md)

## Context

A developer who wants to use puls3 today has to copy the Flutter app or call the generated Serverpod client (`puls3_client`) from inside this repo. The CLI and the MCP server need one library with a stable surface, so that neither grows its own client and the three stay in step with the server.

The server endpoints already exist. This ADR decides the shape of the library over them. It adds no endpoint.

## Decision

### D1. One Dart package, no Flutter, no signing

- The SDK is the Dart package `puls3_sdk`, a workspace member that depends on `puls3_client`.
- It does not import Flutter, `puls3_server` or `puls3_domain`.
- **It never signs or submits a transaction.** Each `prepare*` call returns the server's unsigned envelope (`PreparedTransaction`). Signing stays in the wallet: the app today, and anything later only by a new decision.
- A TypeScript SDK is out of this milestone.

### D2. Public operations

The SDK names follow `docs/architecture/api.md`. Where the generated endpoint method has another name, the SDK maps it.

| Area | SDK operation | Server endpoint | Session |
|---|---|---|---|
| Catalog | `listAgents` | `AgentEndpoint.list` | No |
| Catalog | `getAgent(id)` | `AgentEndpoint.get` | No |
| Hire | `createHire` | `HireEndpoint.createHire` | Yes |
| Hire | `getHire` | `HireEndpoint.getHire` | Yes |
| Hire | `prepareCreateJob`, `prepareFund`, `prepareComplete`, `prepareReject` | `HireEndpoint.*` | Yes |
| Feedback | `prepareFeedback` | `FeedbackEndpoint.prepareFeedback` | Yes |
| Studio | `saveDraft`, `testRun`, `saveProviderCredential` | `StudioEndpoint.*` | Yes |

`createHire` is not in the #222 issue text. It is added because without it there is no hire id, so the `prepare*` calls cannot start a hire. It creates the hire row and signs nothing.

### D3. Errors pass through

The SDK adds no error vocabulary. A caller sees exactly what the server sends:

- `Puls3ApiException` and its stable `code` (contract rule 7);
- `AgentCatalogUnavailable` for a catalog outage (the documented exception to rule 7);
- for a session the server rejects before the endpoint runs, the client's HTTP `401` or `403` exception, as rule 7 describes.
- for a server that cannot be reached, times out or answers with another HTTP error, the generated client's `ServerpodClientException` (the SDK re-exports the type so callers can catch it).

Arguments the SDK can reject locally, such as a blank agent id or a non-HTTP API URL, raise `ArgumentError` without a network call.

### D4. The CLI and the MCP server are clients of this package

`puls3_cli` and `puls3_mcp` depend on `puls3_sdk` and call only its public API. They do not construct `puls3_client` themselves and they do not shell out to each other.

## Open decisions

1. **How a program without the app gets a wallet session.** `HireEndpoint`, `StudioEndpoint` and `FeedbackEndpoint` require login. The only way to log in is the SEP-10 challenge, which the wallet signs (`WalletAuthEndpoint.createChallenge` / `verifyChallenge`). So every row marked "Session" above needs a session, and D1 says the SDK does not sign.

   **Token rotation rules out the simplest option.** The server uses the `serverpod_auth_core_server` 4.0.4 defaults (`JwtConfigFromPasswords()`, nothing overridden): an access token lives **10 minutes**, a refresh token **14 days**, and **every refresh rotates the refresh token**. The old one then fails with `RefreshTokenInvalidSecretException` (`jwt_config.dart`, `jwt.dart`). Found on #222 (Pericena).

   | Option | What it means | Trade-off |
   |---|---|---|
   | A. Tokens from the environment | The SDK takes an access token and a refresh token (`PULS3_ACCESS_TOKEN`, `PULS3_REFRESH_TOKEN`) copied from the app. | **Does not work as written.** The first refresh, at most 10 minutes later, rotates the refresh token, so the environment value is dead from then on. If the app's own token is copied, whichever side refreshes first signs the other out. |
   | **A′. A separate CLI session, persisted** (recommended) | The signed-in app asks the server for a **second session** for the same wallet. The developer passes its refresh token once (`PULS3_REFRESH_TOKEN`); the SDK's session provider stores the rotated tokens in a user-only file (for example `~/.config/puls3/session.json`, mode 0600) and refreshes from there. | Keeps "no wallet key outside the wallet" and survives rotation without touching the app's session. Costs one `requireLogin` server endpoint that issues a session for the caller's own `authUserId`, the app's "copy session for CLI" action, and the session file. A stolen CLI token reaches only that wallet's hires and drafts, cannot move funds (every `prepare*` is unsigned), and can be revoked on its own. |
   | B. Sign only the login challenge | The CLI and the MCP server read a wallet key file (never an argument) and sign the SEP-10 challenge, and nothing else. | No rotation problem, but it puts a wallet key on the developer's machine, and the rule becomes "signs only the login challenge". |
   | C. Catalog only | Ship `listAgents` / `getAgent` with no session; the session rows wait. | No new secret at all, but the CLI and MCP milestones lose most of their commands. The fallback if A′ cannot take a server change in time. |

   Asked on #222; the operations and the session provider are #259. Until it is decided, the package ships the catalog only.

## Consequences

- The CLI and the MCP server cannot drift from the server: they use the same operations and the same errors.
- Nothing in the SDK can move funds. A prepared envelope still has to be signed in a wallet.
- Changing a server endpoint changes the SDK in the same PR, or the SDK's tests against the generated client fail to compile.
- The [quickstart](../sdk/quickstart.md) (#223) and the CLI and MCP guides document the session variables once Open decision 1 is settled.
