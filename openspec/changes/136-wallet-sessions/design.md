# Design: Wallet-authenticated sessions with SEP-10 (#136)

## Technical Approach

This design follows the proposal and the `wallet-auth`, `escrow-relay` and `hire-payment` specs. The server issues SEP-10 v3.4.1 challenges and verifies them. A custom Serverpod `IdentityProvider` (`WalletIdp`) then issues a standard `AuthSuccess`. This is the SIWE pattern (EIP-4361: nonce, domain, address, expiry, a single-use server record) built on Stellar's standard for it. Ports and adapters follow ADR-0001:

- **Ports**: the verification algorithm (`Sep10Verifier`) is plain Dart over ports.
- **Adapters**: crypto goes through `stellar_dart`, chain reads through `ChainAccounts` (Soroban RPC), persistence through Serverpod.
- **`puls3_domain`**: unchanged. SEP-10 is a protocol at the adapter level, and Flutter does not depend on `puls3_domain`, so a shared value object would serve nobody.

Serverpod 4.0.4 APIs relied on (pub cache, verified):

| API | Source |
|---|---|
| `IdentityProvider{method, mergeAuthUsers}` | `serverpod_auth_core_server-4.0.4/lib/src/common/integrations/identity_provider.dart:4-23` |
| `IdentityProviderBuilder<T>.build({tokenManager, authUsers, userProfiles})` | `.../integrations/provider_builder.dart:9-27` |
| `TokenManager.issueToken(session, {authUserId, method, scopes, transaction})`. Throws `SignInWhileAuthenticatedException` for another user's caller | `.../integrations/token_manager.dart:65-75` |
| `AuthUsers.create(session, {scopes, blocked, transaction})` | `.../auth_user/business/auth_users.dart:41` |
| `authUserId` extension | `.../auth_user/util/authentication_info_extension.dart:4-8` |
| `@unauthenticatedClientCall` precedent | `.../jwt/endpoints/jwt_tokens_endpoint.dart:40` |
| Login template: transaction, then create user, then insert account, then `issueToken` | `serverpod_auth_idp_server-4.0.4/lib/src/providers/anonymous/business/anonymous_idp.dart:47-95` |
| Cross-module relation `module:auth:AuthUser?` (the `auth` nickname is declared in that package's `config/generator.yaml:4-6`) | `.../anonymous/models/anonymous_account.spy.yaml:11` |
| `DatabaseRateLimiter.tryRecordAttempt` (advisory lock, admitted attempts survive rollback) and `RateLimiterConfig{domain, source, maxAttempts, timeframe}` | `.../common/rate_limited_request_attempt/rate_limiter.dart:56-153`, `rate_limiter_config.dart:33` |
| `NotAuthorizedException` → 401 | `serverpod-4.0.4/lib/src/server/endpoint_dispatch.dart:196,452`; `server.dart:250` |
| `Serverpod.getPassword` | `serverpod.dart:1162` |
| `JwtConfigFromPasswords` fails at startup without its secrets | `jwt_config.dart:233-238` |
| `FlutterAuthSessionManager.authInfoListenable` | `serverpod_auth_core_flutter-4.0.4/lib/src/session_manager.dart:15,68` |
| `updateSignedInUser`, `validateAuthentication`, `signOutDevice` | `serverpod_auth_core_client-4.0.4/lib/src/session_manager.dart:175,222,266` |
| `client.auth` is an extension getter | `serverpod_auth_core_client-4.0.4/lib/src/session_manager.dart:278-280` |

## Architecture Decisions

| # | Decision | Choice | Rejected | Rationale |
|---|---|---|---|---|
| D1 | Endpoint name | `WalletAuthEndpoint` (client: `client.walletAuth`). Update api.md | `AuthEndpoint` | Generated `Client.auth` would shadow the `auth` extension (core_client `session_manager.dart:278`). Instance members beat extensions, so `client.auth.updateSignedInUser` would break |
| D2 | Verification strategy | **Byte equality** of the signed body against the stored unsigned body, then signature checks | SEP-10 structural re-parse only | The server built the exact body. Equality covers source, seq 0, time bounds and every op in one check (`tampered`). The builder is still shape-tested against SEP-10 (W1) |
| D3 | Crypto port | `Sep10Codec`: `build(...)`, `parse(xdr)` (delegates to `StellarEnvelopeCodec.parse`, which already rejects empty, non-base64, fee-bump, truncated and trailing bytes), `verifies(key, sig, hash)`. Adapter `StellarSep10Codec` uses `stellar_dart` (`ManageDataOperation`, `StellarPrivateKey.sign`, `TransactionSignaturePayload`) | Building with stellar_flutter_sdk on the server | That SDK depends on Flutter (its pubspec). Reusing the codec keeps one parser |
| D4 | Signer source | Add `ChainAccounts.authorityOf(account) → AccountAuthority?` (`null` = not found). `SorobanRpcClient.accountEntry` returns the raw entry XDR, and `accountSequence` is refactored onto it. `RpcChainAccounts` decodes `AccountEntry.thresholds/signers` (`stellar_dart` `base.dart:228-243`) | A new RPC port | This is the binding. One `getLedgerEntries` path. `ChainUnavailable` → `AuthenticationUnavailable` in the auth service (W22). There is no master-only fallback |
| D5 | Weight rule | Client signatures exclude any signature by the server key. Each distinct signer counts once. Signers are ed25519 signers plus the master (weight = `thresholds[0]`). The sum must be ≥ `thresholds[2]` (medium). If that threshold is 0, the sum must be > 0. Account not found: exactly one signature, valid for the wallet master | Low threshold | Proposal/SEP-10. A hire moves funds |
| D6 | Response | Serverpod `AuthSuccess` via `TokenManager.issueToken` | SEP-10 JWT | A recorded deviation. Refresh and sign-out stay standard |
| D7 | Atomicity | Checks 1–6 run **outside** any database transaction, because of the RPC call. Then one transaction runs: conditional `UPDATE wallet_challenge SET consumed_at WHERE id AND consumed_at IS NULL AND expires_at > now`, then find-or-create of the `wallet_account` under `pg_advisory_xact_lock(fnv(wallet))`, then `issueToken`. If 0 rows are updated, the row is re-read to choose Consumed or Expired | Consume first, verify later | A row lock serializes concurrent verifies (W24). A rollback restores the challenge (W25). The advisory lock prevents a duplicate user for the same new wallet (the `DatabaseRateLimiter` pattern) |
| D8 | Challenge id | UUID v4. The row stores the unsigned server-signed XDR and the tx hash | Hash as id | The id is opaque and matches the api.md `challengeId` |
| D9 | Signing key | Serverpod password `walletAuthSigningKey` (S…), held in `WalletAuthConfig`. Its `toString` is redacted. It is never in env, logs or details. Production: missing → startup throws. Other modes: `AuthenticationUnavailable` per call | Env var | Proposal. W6/W35 |
| D10 | Public config | `PULS3_AUTH_HOME_DOMAIN` and `PULS3_AUTH_WEB_AUTH_DOMAIN` from env (the convention of the public `PULS3_STELLAR_*` values). The network comes from `StellarConfig.networkPassphrase` | Passwords | They are public values |
| D11 | How Flutter learns the expected values | `config.json` gets `auth{serverSigningKey, homeDomain, webAuthDomain, networkPassphrase}`. On the web, `AppConfigRoute` serves it. Native builds bundle it, with dart-define overrides. `WalletChallenge` carries `networkPassphrase` only for display and cross-checking | Server key in the `createChallenge` response | A response cannot vouch for its own signer. This is the closest analogue to SEP-10's `stellar.toml` `SIGNING_KEY` (out of scope). On web the trust is the same TLS origin, and native gets real pinning |
| D12 | Client validation | Use `stellar_flutter_sdk` `WebAuth(...).validateChallenge(xdr, account, null)` (`webauth.dart:148,468`) with an endpoint URI built from `webAuthDomain`. Also check that the network equals the configured network and `account` equals the connected one | A hand-written validator | This is the SDK's standard SEP-10 client check (seq, ops, home domain, web_auth_domain, time bounds, server signature) |
| D13 | Freighter path | New `FreighterWallet.signChallenge` reuses `bridge.signTransaction` with **no** JS change. It skips `_assertSourceBinding` only after D12 passes. Post-checks: body unchanged, and an added signature by the connected account verifies | Loosening `signTransaction` | The source exception exists only for validated challenges |
| D14 | Rate limit | `DatabaseRateLimiter(domain: 'puls3_wallet', source: 'challenge', maxAttempts: 5, timeframe: 1 min)`, key = wallet. Order: address, then config, then limit, then build and insert | A custom counter | Native, atomic. A failed config check costs no budget |
| D15 | Session wallet | `WalletSessionWallet`: `authenticated == null` → `NotAuthorizedException(unauthenticated)`. Then `wallet_account` by `authUserId`. If no row → the same 401 (fail closed, and the client re-challenges). `HireEndpoint.requireLogin => true`. The static setter seam stays. The default becomes `WalletSessionWallet`, and `FailClosedSessionWallet` moves to test support | `AuthenticationUnavailable` | A 401 drives the standard client re-auth. Without a lookup cache, one indexed read per call |
| D16 | Flutter session container | `WalletSession` (ChangeNotifier) composes `WalletController` and an `AuthGateway` port (adapter `ServerpodAuthGateway(Client)`). `WalletController` stays session-agnostic. `run(action)` retries once after re-sign-in on 401 or a null `authInfoListenable` | Logic inside `WalletController` | Container/presentational pattern. The controller doc says it knows no flows |
| D17 | Template removal | Delete `email_idp_endpoint.dart`, the `EmailIdpConfigFromPasswords` wiring, the code senders and `emailSecretHashPepper` | Keep it disabled | Decision 10, W37 |

## Interfaces / Contracts

```dart
// Server, lib/src/auth/
@unauthenticatedClientCall Future<WalletChallenge> createChallenge(Session s, String wallet);
@unauthenticatedClientCall Future<AuthSuccess> verifyChallenge(Session s, String challengeId, String wallet, String signedChallengeXdr);
abstract interface class Sep10Codec { BuiltChallenge build({required StellarAddress wallet, required List<int> nonce, required DateTime now});
  SignedEnvelope parse(String xdr); bool verifies(StellarAddress key, EnvelopeSignature sig, Uint8List hash); }
abstract interface class ChallengeStore { Future<void> insert(NewChallenge c); Future<StoredChallenge?> find(String id);
  Future<ConsumeOutcome> consume(String id, {Transaction? transaction}); } // consumed | alreadyConsumed | expired | notFound
final class AccountAuthority { final int masterWeight, mediumThreshold; final Map<StellarAddress, int> signers; }
// Flutter
Future<String> signChallenge(String challengeXdr, ChallengeExpectations expected); // WalletPort
```

The protocol model is `WalletChallenge{challengeId, wallet, payload (XDR), networkPassphrase, expiresAt}`.

**Tables** (with a migration and a down migration):

- `wallet_challenge`: `challengeId` (unique), `wallet`, `challengeXdr`, `transactionHash`, `expiresAt`, `createdAt`, `consumedAt?`. The class is `WalletChallengeRecord` and the table is `serverOnly`. Indexes: `challengeId` unique and `wallet`.
- `wallet_account`: `wallet` (unique), `authUser: module:serverpod_auth_core:AuthUser, relation(onDelete=Cascade)` with `authUserId` unique, and `createdAt`. Our `generator.yaml` declares no modules block, so the nickname defaults to the package name, as the generated `client.dart:415,486` confirms. Commit 1 spikes this.

## Verification steps → codes (api.md)

| # | Check | Failure |
|---|---|---|
| 0 | `wallet` parses as G | `InvalidStellarAddress` |
| 1 | Row exists / wallet equals the row's wallet | `ChallengeNotFound` / `InvalidWalletSignature{walletMismatch}` |
| 2 | `consumedAt` null / `now < expiresAt` | `ChallengeConsumed` / `ChallengeExpired` |
| 3 | `parse` / body bytes equal the stored body | `InvalidWalletSignature{malformed}` / `{tampered}` |
| 4 | Exactly one signature verifies with the server key | `{serverSignature}` |
| 5 | Load authority (failure: `AuthenticationUnavailable`), then D5 | `{noClientSignature}`, `{insufficientWeight}`, `{invalidClientSignature}` |
| 6 | D7 transaction (re-check 2 atomically) | `ChallengeConsumed` / `ChallengeExpired` |

A signature made for the wrong network fails step 4 or 5 as non-verifying (W18).

## Data Flow

    Flutter: createChallenge(w) -> WalletChallenge -> WebAuth.validateChallenge + network/account
          -> wallet.sign (prompt) -> verifyChallenge(id, w, xdr) -> client.auth.updateSignedInUser
    Server:  endpoint -> WalletAuthService -> [Sep10Codec | ChallengeStore | ChainAccounts | RateLimiter]
          -> tx{consume, WalletIdp.signIn(find-or-create, issueToken)} -> AuthSuccess
    Hire:    requireLogin(401) -> WalletSessionWallet(authUserId -> wallet_account) -> WalletMismatch check

## Observability and Security

- Each `createChallenge` and `verifyChallenge` outcome is logged with `challengeId`, the public wallet, and the code/reason, at `info` on success and `warning` on failure.
- The signing key, nonce, XDR and tokens are never logged.
- A W36 test captures logs and exceptions.

Threat Matrix: N/A. There is no routing, shell, subprocess, VCS automation or process boundary. The security risks (replay, tampering, server impersonation, multisig) are covered by W10–W24 and W39.

## File Changes

| File | Action |
|---|---|
| `puls3_server/lib/src/auth/{wallet_auth_config, sep10_codec, sep10_verifier, challenge_store, serverpod_challenge_store, wallet_idp, wallet_auth_service, wallet_auth_endpoint, wallet_session_wallet}.dart`, `{wallet_challenge_record, wallet_account, wallet_challenge}.spy.yaml` | Create |
| `puls3_server/lib/src/ledger/stellar_sep10_codec.dart` | Create |
| `puls3_server/lib/src/ledger/soroban_rpc_client.dart`, `hire/chain_accounts.dart`, `hire/hire_endpoint.dart`, `hire/session_wallet.dart`, `server.dart`, `web/routes/app_config_route.dart`, `config/passwords.example.yaml`, `migrations/*` | Modify |
| `puls3_server/lib/src/auth/email_idp_endpoint.dart` | Delete |
| `puls3_flutter/lib/src/auth/{auth_config, auth_gateway, serverpod_auth_gateway, wallet_session}.dart`, `wallet/sep10_challenge_check.dart` | Create |
| `puls3_flutter/lib/src/wallet/{wallet_port, mock_wallet, freighter/freighter_wallet}.dart`, `main.dart`, `assets/config.json` | Modify |
| `docs/architecture/api.md`, `docs/architecture/examples/sep10/*.json` (vectors) | Modify / Create |

## Testing Strategy (strict TDD)

| Layer | Covers |
|---|---|
| Unit: `StellarSep10Codec` | W1 shape, W3, W21; a **known vector** with a committed test-only server key, a fixed clock and nonce: the bytes and hash are pinned in `examples/sep10/` |
| Unit: `Sep10Verifier` (fakes) | Every row of the step table, W8–W22 (multisig, server-weight exclusion, unfunded) |
| Contract: `ChallengeStore` in memory vs Serverpod | W26 and expired consume |
| Integration (`withServerpod`) | W2, W5, W7, W17, W23–W25 (concurrent `Future.wait`), W27–W31, W33/W34 401, W36, W37; **sign-in → `createHire` → 401 after `signOutDevice`** |
| Flutter unit | D12 (W39 per field, no prompt counted), W38/W40, `WalletSession` W41–W44 with a fake gateway. The `examples/sep10` server vector must pass `WebAuth.validateChallenge` (cross-implementation interop) |
| Manual | A real Freighter signature is recorded as a vector; the server verifies it (W46) |

## Delivery (`size:exception`, 2 PRs, one work unit per commit)

**PR 1, server and docs (~1,000 authored lines, ~55% tests):**

1. Models, migration and the relation spike.
2. Config and secrets, with startup fail-closed.
3. `Sep10Codec` and its vector.
4. `authorityOf` and the RPC refactor.
5. `ChallengeStore` and its contracts.
6. Verifier.
7. `WalletIdp`.
8. Endpoint, service and rate limit.
9. `WalletSessionWallet`, `requireLogin`, and the EmailIdp removal.
10. api.md and `AppConfigRoute`.

**PR 2, Flutter (~600 lines):**

1. `AuthConfig`.
2. Challenge check and the `MockWallet` key.
3. `signChallenge` (Freighter).
4. Gateway and `WalletSession`.
5. `main.dart` wiring and the manual-evidence note.

## Migration / Rollout

The migration is additive (2 tables). Roll back by reverting PR 2, then PR 1. Production needs `walletAuthSigningKey`, the JWT secrets and the `PULS3_AUTH_*` values before deploy.

## Open Questions

- [ ] Cleaning up expired `wallet_challenge` rows. The rate limit is per wallet, so many distinct wallets can grow the table. A follow-up job is proposed.
- [ ] Does Freighter show a warning for a sequence-0 challenge? Answered by the manual check.
