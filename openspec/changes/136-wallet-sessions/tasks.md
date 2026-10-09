# Tasks: Wallet-authenticated sessions with SEP-10 (#136)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,600 authored (incl. tests): ~1,000 server+docs, ~600 Flutter. Generated Serverpod client/protocol excluded from the authored count, included in the diff |
| 400-line budget risk | High |
| Chained PRs recommended | No. Two PRs, each over 400, with `size:exception` |
| Suggested split | PR 1 server + docs (10 work-unit commits) → PR 2 Flutter (5 work-unit commits) |
| Delivery strategy | size:exception |
| Chain strategy | PR 2 targets PR 1's branch until PR 1 merges, then main. Flutter needs the generated `client.walletAuth` |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: PR 2 stacked on PR 1
400-line budget risk: High
size:exception: accepted (design delivery + the preference for few PRs with one work unit per commit)

Notes:
- Strict TDD: each GREEN task is preceded by its RED task. Tests land in the same commit as the behavior they verify.
- `puls3_domain` does not change (ADR-0001). SEP-10 stays in server and Flutter adapters.
- The spec prose still says `AuthEndpoint`. Design D1 renames it to `WalletAuthEndpoint` (`client.walletAuth`). Commit 10 amends the spec prose to that name. Behavior tasks follow D1 from the start.
- W18: a wrong-network client signature leaves the body unchanged, so it is not `tampered`. The server signature still verifies. The client signature does not. Pin the reason as `noClientSignature`. Commit 10 amends the W18 parenthetical to that reason.
- Endpoint name, parameter `signedChallengeXdr`, 15-minute expiry, and `WalletChallenge.networkPassphrase` follow the design. `api.md` is updated in commit 10 (W47).
- Gate, server (every PR 1 commit): `cd puls3_server && dart analyze --fatal-infos && dart test && dart format --set-exit-if-changed .` then `serverpod generate` and `git diff --exit-code -- puls3_server puls3_client` when models or endpoints changed.
- Gate, Flutter (every PR 2 commit): `cd puls3_flutter && flutter analyze --fatal-infos && flutter test && dart format --set-exit-if-changed .`
- Integration tests need Postgres and Redis (`docker compose` in `puls3_server`, tag `integration`).
- Commits: conventional, no Co-Authored-By or AI attribution.
- Out of scope: SEP-45, M accounts, `client_domain`, `stellar.toml`, Pollar, #116, expired-challenge cleanup.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Models, migration, AuthUser relation spike, change artifacts | PR 1 `feat/136-wallet-sessions-01-server` (base main) | `cd puls3_server && dart test test/unit/auth/wallet_models_test.dart` | `serverpod generate` then `git diff --exit-code` | Revert the commit (additive tables) |
| 2 | `WalletAuthConfig` and startup fail-closed | same | `dart test test/unit/auth/wallet_auth_config_test.dart` | N/A: config parsing, no running server | Revert the commit; models stay |
| 3 | `Sep10Codec` and the known vector | same | `dart test test/unit/auth/sep10_codec_test.dart` | N/A: pure codec, pinned bytes | Revert the commit; config stays |
| 4 | `authorityOf` and the account-entry RPC refactor | same | `dart test test/unit/ledger/account_authority_test.dart` | N/A: decode fixture, RPC client faked | Revert the commit; existing `accountSequence` callers stay green |
| 5 | `ChallengeStore` contract | same | `dart test test/unit/auth/challenge_store_test.dart test/integration/challenge_store_test.dart` | Integration: Postgres via `withServerpod` | Revert the commit; tables from unit 1 stay |
| 6 | `Sep10Verifier` | same | `dart test test/unit/auth/sep10_verifier_test.dart` | N/A: fakes for store, codec, chain | Revert the commit |
| 7 | `WalletIdp` find-or-create | same | `dart test test/integration/wallet_idp_test.dart` | Integration: Postgres, token manager | Revert the commit; no endpoint yet |
| 8 | Endpoint, service, rate limit | same | `dart test test/integration/wallet_auth_endpoint_test.dart` | Integration: `withServerpod`, rate limiter | Revert the commit; verifier stays usable |
| 9 | `WalletSessionWallet`, `requireLogin`, drop EmailIdp | same | `dart test test/integration/wallet_session_hire_test.dart` | Integration: sign-in → `createHire` → 401 after `signOutDevice` | Revert the commit; hire falls back to the test double |
| 10 | `api.md`, spec prose, `AppConfigRoute` | same | `rg "WalletAuthEndpoint|signedChallengeXdr|900" docs/architecture/api.md` | N/A: docs and a config route unit test | Revert the commit; server behavior stays |
| 11 | `AuthConfig` | PR 2 `feat/136-wallet-sessions-02-flutter` (base PR 1) | `cd puls3_flutter && flutter test test/auth_config_test.dart` | N/A: config parse | Revert the commit |
| 12 | Challenge check and `MockWallet` | same | `flutter test test/sep10_challenge_check_test.dart` | The `examples/sep10` vector passes `WebAuth.validateChallenge` | Revert the commit |
| 13 | `FreighterWallet.signChallenge` | same | `flutter test test/freighter_sign_challenge_test.dart` | N/A: bridge faked, no JS change | Revert the commit; `signTransaction` unchanged |
| 14 | Gateway and `WalletSession` | same | `flutter test test/wallet_session_test.dart` | N/A: fake gateway | Revert the commit |
| 15 | `main.dart` wiring and the Freighter evidence note | same | `flutter test` | Manual Freighter check (W46), recorded in the PR | Revert the commit; session class stays unused |

## PR 1: Server and docs (~1,000 authored lines, `size:exception`)

Branch: `feat/136-wallet-sessions-01-server`, base `main`.

### Commit 1: Models, migration, relation spike

- [x] 1.1 Track `openspec/changes/136-wallet-sessions/` (exploration, proposal, specs, design, this tasks file) in the commit.
- [x] 1.2 RED: `wallet_models_test.dart` loads the generated `WalletChallenge` and asserts `challengeId`, `wallet`, `payload`, `networkPassphrase`, `expiresAt`. Assert `WalletChallengeRecord` and `WalletAccount` are server-only (absent from the client protocol). Done: failed with `Method not found: WalletChallenge`.
- [x] 1.3 GREEN: add `wallet_challenge.spy.yaml` (`WalletChallenge`, client model), `wallet_challenge_record.spy.yaml` (`serverOnly`, table `wallet_challenge`, unique `challengeId`, index on `wallet`, fields from the design), and `wallet_account.spy.yaml` (`serverOnly`, unique `wallet`, `authUser: module:serverpod_auth_core:AuthUser, relation(onDelete=Cascade)`, unique `authUserId`, `createdAt`). Run `serverpod generate`. The spike confirms the module nickname is the package name (no `modules` block in `generator.yaml`). Add the migration and its down migration. Done when 1.2 is green and a second generate leaves no diff. Done: nickname `serverpod_auth_core` resolves and the FK points at `serverpod_auth_core_user`. Serverpod 4.0.4 requires the relation object to be nullable (`AuthUser?`); `authUserId` is still `uuid NOT NULL` with a unique index. Migration `20261009114333724` plus `down.sql`. Tests green. A second generate changes no content (Windows rewrites line endings only; those files stay unstaged).

Commit: `feat(server): add wallet challenge and wallet account models`

### Commit 2: Config and secrets

- [x] 2.1 RED: `wallet_auth_config_test.dart`. Missing or blank `walletAuthSigningKey` throws in production and returns `AuthenticationUnavailable` in other modes (W6, W35). A non-secret key throws `ArgumentError` whose message does not contain the value. `toString` redacts the key. Home domain and web-auth domain come from `PULS3_AUTH_HOME_DOMAIN` and `PULS3_AUTH_WEB_AUTH_DOMAIN`; blank values are unavailable. Network passphrase comes from `StellarConfig`. Done: failed because `wallet_auth_config.dart` was missing.
- [x] 2.2 GREEN: `WalletAuthConfig` reads the Serverpod password `walletAuthSigningKey` (S… secret). It never reads that secret from the environment. Document the placeholder in `config/passwords.example.yaml` only. Wire the production startup check next to the existing JWT password check in `server.dart`: missing key throws before endpoints are served (W35). Other run modes defer the failure to the call (W6). Done: `ensureProduction` throws `StateError` only in production, before `pod.start()`. Other modes throw `AuthenticationUnavailable` from `fromEnvironment`. 8 tests green.

Commit: `feat(server): fail closed without the wallet auth signing key`

### Commit 3: SEP-10 codec and known vector

- [x] 3.1 Add `docs/architecture/examples/sep10/` with a committed test-only server secret, a fixed clock, a fixed 48-byte nonce, the expected XDR and the expected transaction hash. The secret is a test vector, not a credential. Done: `challenge.json` uses 32 bytes of `0x07`, clock `2026-10-09T12:00:00Z`, nonce bytes 1..48.
- [x] 3.2 RED: `sep10_codec_test.dart`. `build` matches the vector bytes and hash (W1 shape: source, sequence 0, time bounds `[now, now+900]`, first op `<home_domain> auth` sourced by the wallet with 48 decoded bytes, `web_auth_domain` sourced by the server key). Two builds with different nonces differ (W3). `parse` rejects empty, non-base64, truncated, trailing bytes and fee-bump as the existing envelope codec does (W21). `verifies` accepts the vector's server signature and rejects a corrupted one. Done: failed because `stellar_sep10_codec.dart` and the vector file were missing.
- [x] 3.3 GREEN: `Sep10Codec` port and `StellarSep10Codec` on `stellar_dart` (`ManageDataOperation`, `StellarPrivateKey.sign`). `parse` delegates to `StellarEnvelopeCodec.parse`. Done: 5 tests green. A corrupted signature that is not a valid ed25519 scalar returns false instead of throwing.

Commit: `feat(server): build and parse SEP-10 challenge transactions`

### Commit 4: Account authority

- [x] 4.1 RED: `account_authority_test.dart`. A fixture account entry decodes master weight (`thresholds[0]`), medium threshold (`thresholds[2]`) and ed25519 signers. A missing account is `null`. `accountSequence` still returns the sequence after the refactor. An RPC failure surfaces as `ChainUnavailable`. Done: failed because `authorityOf` was missing.
- [x] 4.2 GREEN: `SorobanRpcClient.accountEntry` returns the raw entry XDR. Refactor `accountSequence` onto it. `ChainAccounts.authorityOf` → `AccountAuthority?`. `RpcChainAccounts` decodes `AccountEntry` thresholds and signers. Existing sequence callers stay green. Done: 4 tests green, plus the recorded `accountSequence` and `sequenceOf` suites. A pre-auth signer is omitted.

Commit: `feat(server): read account signer thresholds for SEP-10`

### Commit 5: Challenge store

- [x] 5.1 RED: one contract, two adapters (`challenge_store_test.dart` in-memory, `test/integration/challenge_store_test.dart` Postgres). Insert, find, consume-once, expired consume, unknown id (W26). A consume inside a transaction that throws leaves the row unconsumed. Done: failed because `challenge_store.dart` and the in-memory store were missing.
- [x] 5.2 GREEN: `ChallengeStore` port, in-memory fake, and `ServerpodChallengeStore`. `consume` is a conditional update (`consumedAt` null and `expiresAt > now`) and accepts an optional transaction. Outcomes: consumed, alreadyConsumed, expired, notFound. Done: the same 5 tests pass on both adapters. `expiresAt == now` is expired. A thrown transaction rolls the consume back.

Commit: `feat(server): store single-use wallet challenges`

### Commit 6: Verifier

- [x] 6.1 RED: `sep10_verifier_test.dart` with fakes. First failure wins, in order: unknown id (`ChallengeNotFound`, W14), malformed wallet (`InvalidStellarAddress`, W15), wallet mismatch (`walletMismatch`, W15), consumed (W17), expired (W16), malformed XDR (`malformed`, W21), body mismatch (`tampered`, W19: source, sequence, time bounds, first op, extra op), bad server signature (`serverSignature`, W20), chain unavailable (`AuthenticationUnavailable`, no master-key fallback, W22), no verifying client signature (`noClientSignature`, W11, W12), weight below medium (`insufficientWeight`, W10), unfunded account with exactly one master signature passes (W13) and a second signature or a foreign key fails (`invalidClientSignature`). Wrong-network client signature, body unchanged, is `noClientSignature` (W18). A passing master-key account returns the verified challenge and does not consume it (W8 shape at this layer). Server weight is excluded (W12). Medium threshold 0 requires weight > 0 (D5). Done: failed because `sep10_verifier.dart` was missing.
- [x] 6.2 GREEN: `Sep10Verifier` implements that order over `Sep10Codec`, `ChallengeStore` and `ChainAccounts`. It does not open a database transaction and does not issue tokens. Done: 17 tests green. A pass returns the row with `consumedAt` null. `ChainUnavailable` becomes `AuthenticationUnavailable` and does not fall back to the master key.

Commit: `feat(server): verify SEP-10 challenges against account weight`

### Commit 7: Wallet identity provider

- [ ] 7.1 RED: `wallet_idp_test.dart` (integration). First sign-in creates one auth user and one `wallet_account` (W27). Second sign-in of the same wallet reuses the user and issues a new token pair (W28). Two wallets create two users (W29). A second insert of the same wallet or auth user is rejected with no partial row (W30). Concurrent first sign-ins for one new wallet, under the advisory lock, leave one user (D7). Done when it fails.
- [ ] 7.2 GREEN: `WalletIdp` follows the anonymous-idp transaction shape: find-or-create under `pg_advisory_xact_lock` of the wallet, then `TokenManager.issueToken`. `mergeAuthUsers` is unused. Done when 7.1 is green.

Commit: `feat(server): bind one auth user to each wallet`

### Commit 8: Endpoint, service, rate limit

- [ ] 8.1 RED: `wallet_auth_endpoint_test.dart` (integration). `createChallenge` persists one row and returns `WalletChallenge` with `expiresAt` at now+900 (W2). Two calls differ in id and nonce (W3). A bad address persists nothing (W4). The 6th call for one wallet in a minute is `ChallengeRateLimited` and persists nothing; another wallet is not limited (W5). Missing config is `AuthenticationUnavailable` and persists nothing (W6). A signed-in caller can `createChallenge` for another wallet (W7). `verifyChallenge` of a valid signed challenge returns `AuthSuccess` and consumes the row (W8, W9 through the real codec with a fake chain). Failures W10–W22 persist no auth user, no `wallet_account` and no token (W23). Two concurrent verifies: one `AuthSuccess`, one `ChallengeConsumed` (W24). A token-manager throw rolls the consume back (W25). Verifying wallet B while holding wallet A's token returns B's user (W31). Logs and exception details for one success and one failure contain neither the signing key, nor a token, nor the signed XDR (W36). Done when it fails.
- [ ] 8.2 GREEN: `WalletAuthService` and `WalletAuthEndpoint` (`@unauthenticatedClientCall`). Order for create: parse address, then config, then `DatabaseRateLimiter` (`puls3_wallet` / `challenge`, 5 per minute, key = wallet), then build and insert. Verify runs the verifier outside a transaction, then one transaction: consume, `WalletIdp.signIn`, `issueToken`. Zero updated rows are re-read to choose consumed or expired. Log `challengeId`, wallet and code only. Done when 8.1 is green and `serverpod generate` leaves no diff.

Commit: `feat(server): issue wallet sessions from SEP-10 challenges`

### Commit 9: Session wallet and hire enforcement

- [ ] 9.1 RED: `wallet_session_hire_test.dart`. `WalletSessionWallet` returns the bound wallet (W32). No session and an auth user without a row raise `NotAuthorizedException` (401), not `AuthenticationUnavailable` (W33, W34). `HireEndpoint.requireLogin` is true. Production construction uses `WalletSessionWallet`, not `FailClosedSessionWallet` (W56). Each hire method calls `requireLogin` before store or chain access (W52, W57). No token on any hire method is HTTP 401 and persists nothing (W48, W58). A token from `verifyChallenge` makes `createHire` belong to that wallet (W50, W59). Another `consumer` is `WalletMismatch` and persists nothing (W51, W60). Wallet V cannot prepare or read wallet W's hire (`HireNotOwned` or `WalletMismatch`, W53, W61). Unknown or foreign `preparationId` is `PreparationNotFound` (W54). A bad hire id is `InvalidHireId` or `HireNotFound` (W55). Sign-in, `createHire`, `signOutDevice`, then the same call is 401 (design integration row, W45's server half). The generated protocol has no email sign-in endpoint (W37). Done when it fails.
- [ ] 9.2 GREEN: `WalletSessionWallet` looks up `wallet_account` by `authUserId`. Keep the setter seam. Default it to `WalletSessionWallet`. Move `FailClosedSessionWallet` to test support. Set `HireEndpoint.requireLogin => true`. Delete `email_idp_endpoint.dart`, the `EmailIdpConfigFromPasswords` wiring, the code senders and `emailSecretHashPepper`. Regenerate. Done when 9.1 is green and generate leaves no diff.

Commit: `feat(server): require a wallet session on every hire method`

### Commit 10: Docs and app config

- [ ] 10.1 Amend `specs/wallet-auth/spec.md` prose: `WalletAuthEndpoint` (D1) and W18 reason `noClientSignature`. Leave scenario ids unchanged.
- [ ] 10.2 Update `docs/architecture/api.md`: lifecycle step 2, `verifyChallenge(challengeId, wallet, signedChallengeXdr)`, expiry 15 minutes, `WalletChallenge` fields, the endpoint name `walletAuth` (W47).
- [ ] 10.3 RED then GREEN: `AppConfigRoute` includes `auth.serverSigningKey`, `auth.homeDomain`, `auth.webAuthDomain` and `auth.networkPassphrase` from public config. The signing key in that payload is the public address (G…), never the S… secret. A test reads the route output and asserts the secret is absent.
- [ ] 10.4 Run the server gate. Confirm the PR body carries `size:exception` and the work-unit list.

Commit: `docs: describe SEP-10 wallet sessions and publish the auth config`

## PR 2: Flutter (~600 authored lines, `size:exception`)

Branch: `feat/136-wallet-sessions-02-flutter`, base PR 1. Opens only after PR 1's generated client exists. Depends on `client.walletAuth`.

### Commit 1: Auth config

- [ ] 11.1 RED: `auth_config_test.dart`. `config.json` `auth` block parses server signing key, home domain, web-auth domain and network passphrase. A missing block fails closed. Dart-define overrides win over the bundled file. Done when it fails.
- [ ] 11.2 GREEN: `AuthConfig` and the `assets/config.json` `auth` block (public G… key only). Done when 11.1 is green.

Commit: `feat(app): load the SEP-10 auth config`

### Commit 2: Challenge check and MockWallet

- [ ] 12.1 RED: `sep10_challenge_check_test.dart`. The server vector in `docs/architecture/examples/sep10/` passes `WebAuth.validateChallenge`. W39: wrong network, wrong home domain, wrong server key, a non-`manage_data` or foreign-sourced extra operation, non-zero sequence, missing or expired time bounds, and a bad server signature each throw a typed error and the prompt counter stays 0. W38: a valid challenge asks the prompt once. W40: a declined prompt is `WalletRejected`. Done when it fails.
- [ ] 12.2 GREEN: `sep10_challenge_check.dart` uses `stellar_flutter_sdk` `WebAuth.validateChallenge` (D12) plus the network and connected-account checks. `MockWallet.signChallenge` signs with a real test key after the check. `WalletPort.signChallenge` grows the method. Done when 12.1 is green.

Commit: `feat(app): validate a SEP-10 challenge before the wallet prompt`

### Commit 3: Freighter signChallenge

- [ ] 13.1 RED: `freighter_sign_challenge_test.dart`. After the check passes, `signChallenge` calls `bridge.signTransaction` and skips the source-account binding. A changed body or a signature that is not from the connected account is rejected. A failed check never calls the bridge (W39). No change to `freighter_bridge.js`. Done when it fails.
- [ ] 13.2 GREEN: `FreighterWallet.signChallenge` (D13). Done when 13.1 is green.

Commit: `feat(app): sign a validated SEP-10 challenge with Freighter`

### Commit 4: Session container

- [ ] 14.1 RED: `wallet_session_test.dart` with a fake `AuthGateway`. Connect calls create, sign, verify, stores the session and exposes the wallet (W41). An expired access token refreshes and the pending call succeeds without a new challenge (W42). A failed refresh runs one new challenge and then resumes the pending action (W43). Disconnect calls `signOutDevice` and clears the session (W44). `WalletController` gains no session knowledge. Done when it fails.
- [ ] 14.2 GREEN: `AuthGateway`, `ServerpodAuthGateway` (`client.walletAuth`, `updateSignedInUser`, `signOutDevice`) and `WalletSession`. `run` retries once after re-sign-in on 401 or a null `authInfoListenable`. Done when 14.1 is green.

Commit: `feat(app): keep a wallet session across hire calls`

### Commit 5: Wiring and Freighter evidence

- [ ] 15.1 Wire `WalletSession` from `main.dart`. The hire flow uses `WalletSession.run`.
- [ ] 15.2 W46: document the manual Freighter check in the PR body (sequence-0 warning, signed XDR, server verification). When a real signature is captured, add it under `docs/architecture/examples/sep10/` and a server test that verifies it. Until that capture exists, the interop proof is the commit-2 vector through `WebAuth.validateChallenge`.
- [ ] 15.3 Run the Flutter gate. PR body carries `size:exception`, the dependency diagram marking this PR, and the manual-check note.

Commit: `feat(app): sign in with the wallet before hiring`

## Risks

- The `AuthUser` relation nickname is a spike in commit 1. If `serverpod generate` rejects `module:serverpod_auth_core`, stop and adjust the yaml before later commits.
- PR 1's integration tests need the test Postgres. A red integration test blocks the commit.
- W46 needs a person with Freighter. The PR can open with the manual steps written and the vector test following the capture.
- Removing EmailIdp touches generated client code. Commit 9 must include that generated diff.

## Rollback

Revert PR 2, then PR 1. `HireEndpoint` returns to a test double and, once PR 1 is gone, to `FailClosedSessionWallet`. The two tables are additive.
