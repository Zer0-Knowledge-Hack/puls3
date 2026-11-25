# The puls3 wire protocol

How a client calls the puls3 server over HTTP, for a client that is not the
generated Dart one (`puls3_client`). The TypeScript SDK
([`puls3_sdk_ts/`](../../puls3_sdk_ts/), #302) follows this page. It
describes Serverpod 4.0.4, the version the server runs; the source of truth is
`serverpod_client` (`serverpod_client_shared.dart`, `serverpod_client_io.dart`)
and `serverpod` (`server.dart`, `_toErrorResponse`).

Checked against the production server on 2026-11-24: `agent.list` and
`agent.get` without a session, a typed error from `walletAuth.createChallenge`,
and a 401 from `hire.listMyHires` without a session.

## A call

Every endpoint method is one HTTP request:

```
POST <apiUrl><endpoint>/<method>
Content-Type: application/json; charset=utf-8
Authorization: Bearer <access token>        (omitted for an anonymous call)

{"hireId": 21, "consumer": "G…"}
```

- `<apiUrl>` ends in `/`, for example
  `https://puls3-hub-on-stellar.api.serverpod.space/`. `<endpoint>` and
  `<method>` are the names in `puls3_client/lib/src/protocol/client.dart`:
  `agent/list`, `hire/getHire`, `studio/testRun`, `jwtRefresh/refreshAccessToken`.
- The body is a JSON object of the method's arguments, by name. Optional
  arguments the caller leaves out are sent as `null` (the Dart client does).
  A method without arguments takes `{}`.
- A call is anonymous when the generated client marks it
  `authenticated: false`: `walletAuth.*` and `jwtRefresh.refreshAccessToken`.
  The catalog (`agent.list`, `agent.get`) accepts both.

## Values

| Dart type | JSON |
|---|---|
| `int`, `double`, `bool`, `String` | number, number, boolean, string. Amounts are USDC stroops (7 decimals) as integers, all well within 2^53 |
| `DateTime` | ISO 8601 string in UTC, for example `"2026-11-24T12:15:00.000Z"` |
| `List<T>` | array |
| `Map<String, T>` | object |
| A model (`AgentSummary`, `HireDetail`, ...) | object with the fields of its `.spy.yaml`, by name. A nullable field may be `null` or absent. Server-only fields never appear |

The models are in `puls3_server/lib/src/**/*.spy.yaml`. A field with a
default (`rating: double, default=4.0`) may be absent from an older server;
read it as the default.

## The answer

| Status | Body | Meaning |
|---|---|---|
| 200 | the JSON of the return value; `null` for a null result (`agent.get` of an unknown id); empty for `void` | success |
| 400 | `{"className": "<name>", "data": {...}}` | a typed exception, below |
| 400 | plain text | the server could not read the arguments (missing, wrong type), or an invalid `Authorization` header |
| 401 | empty | no valid session for a method that needs one |
| 403 | empty | the session lacks a scope the method needs |
| 404 | text | no such endpoint or method |
| 500 | empty | an unexpected server error |

### Typed exceptions

A typed exception is `{"className": ..., "data": ...}`. `className` is
the exception's name, prefixed with its module for the auth modules
(`serverpod_auth_core.RefreshTokenExpiredException`). `data` holds its
fields.

- **`Puls3ApiException`** is the API's error (ADR-0007 D3). `data` is
  `{"code": "...", "message": "..." | null, "details": {"k": "v"} | null}`.
  `code` is the contract: `HireNotFound`, `HireNotOwned`, `WalletMismatch`,
  `InvalidHireTransition`, `IdempotencyKeyReused`, `DraftNotFound`,
  `TestQuotaExceeded`, `InvalidStellarAddress`, ... ([api.md](../architecture/api.md)).
  `details` is a string map, for example
  `{"status": "open", "purpose": "complete"}` on `InvalidHireTransition`.
- **Other exceptions** keep their own class: `AgentCatalogUnavailable`
  (`message`), `AgentUnavailable` and `AgentCannotDeliver` (`agentId`),
  `HireRequestInvalid` and `HireLedgerUnavailable` (`message`),
  `HireConfigurationMissing` (`setting`), and the refresh-token exceptions of
  `serverpod_auth_core`. The TypeScript SDK reports them with the class name,
  without its module, as the code.

## Sessions

A session is a pair of tokens from the `serverpod_auth_core` JWT strategy.

- **Sign-in** (SEP-10, two anonymous calls): `walletAuth/createChallenge`
  `{"wallet"}` returns a `WalletChallenge` (`challengeId`, `payload`: the
  challenge transaction XDR, `networkPassphrase`, `expiresAt`). The wallet signs
  `payload` and sends it to `walletAuth/verifyChallenge`
  `{"challengeId", "wallet", "signedChallengeXdr"}`. The answer is an
  `AuthSuccess`.
- **A CLI session** (#259) skips the sign-in: the app's wallet sheet creates one
  (`cliSession/create`) and shows its refresh token once. A program starts by
  refreshing it.
- **`AuthSuccess`** carries `token` (the access token, sent as
  `Authorization: Bearer <token>`), `tokenExpiresAt`, `refreshToken`,
  `authStrategy`, `authUserId` and `scopeNames`.
- **Refresh:** `jwtRefresh/refreshAccessToken` `{"refreshToken"}`, anonymous,
  returns a new `AuthSuccess` and **rotates** the refresh token: the old one
  stops working, and presenting it again revokes the session
  (`RefreshTokenInvalidSecretException`). A client must therefore refresh one
  at a time and store the new refresh token before using it. A refused
  refresh (`RefreshTokenExpiredException`, `RefreshTokenNotFoundException`,
  `RefreshTokenMalformedException`, `RefreshTokenInvalidSecretException`) ends
  the session.
- **On 401** with a session, the Dart client refreshes once and retries the
  call. The TypeScript SDK does the same.

## What a second client keeps in step

- **Names:** the endpoint, method and argument names, and the model fields. A
  rename in a `.spy.yaml` or an endpoint is a breaking change for every client.
- **Error codes:** the `Puls3ApiException` codes are shared. The TypeScript
  SDK passes them through unchanged, as the Dart SDK does.
- **How:** the TypeScript SDK's tests pin this format with fakes
  (`puls3_sdk_ts/test/`), and the server's contract tests
  (`puls3_server/test/integration/sdk_contract_test.dart`) pin what the server
  stores. A server change that alters this page updates it and the TypeScript
  SDK in the same pull request.
