# Exploration: wallet-authenticated sessions (#136)

## Current state

- `docs/architecture/api.md` defines `Auth` (wallet-bound Serverpod session, 401/403, `WalletMismatch`), `AuthEndpoint.createChallenge(wallet)` / `verifyChallenge(challengeId, wallet, signature)` (lines 38-39), the session lifecycle (lines 202-209, step 2 "Unverified" for `signMessage`) and `WalletChallenge {challengeId, wallet, payload, expiresAt}` (line 274). Auth error codes already exist.
- Server: `puls3_server/lib/src/hire/session_wallet.dart` holds the `SessionWallet` seam and `FailClosedSessionWallet`; `HireEndpoint` injects it with a static setter. `server.dart` already calls `initializeAuthServices` with `JwtConfigFromPasswords()` plus a template Email IdP; `jwt_refresh_endpoint.dart` exists; JWT secrets are in `passwords.example.yaml`.
- Flutter: `main.dart` builds the `Client` with no auth session manager. `WalletPort` has no `signMessage`. The Freighter bridge loads `@stellar/freighter-api@6.0.1` and does not import `signMessage`.

## Serverpod 4.0.4 auth

- Packages `serverpod_auth_core_*` and `serverpod_auth_idp_*` 4.0.4 are in the workspace.
- A custom `IdentityProvider` plus `IdentityProviderBuilder`, registered in `initializeAuthServices(identityProviderBuilders: [...])`, can mirror `AnonymousIdp.login`: in one transaction create the auth user, insert the provider account row, and call `tokenManager.issueToken(...)`.
- `AuthEndpoint` methods need `@unauthenticatedClientCall` (otherwise `SignInWhileAuthenticatedException` on re-challenge with another wallet's token).
- Defaults: 10-minute access token, 14-day refresh token.
- The authenticated user is `session.authenticated?.authUserId`; mapping to a wallet needs a `wallet_account` table (wallet unique, auth user unique).
- A missing login is HTTP 401 only with `requireLogin => true` on the endpoint.
- `DatabaseRateLimiter` can back `ChallengeRateLimited`.
- Flutter: `client.authSessionManager = FlutterAuthSessionManager()`, `client.auth.updateSignedInUser(authSuccess)`, `signOutDevice()`; a failed refresh signs out and nulls `authInfoListenable`, which is the re-challenge trigger.

## Freighter and SEP-53

- Freighter `signMessage(message, {address})` returns `{signedMessage, signerAddress, error?}` and follows SEP-53 (docs.freighter.app). `signedMessage` is a `Buffer` in one API version and a base64 `string` in another; the runtime shape of 6.0.1 is unproven, so the bridge must normalize both.
- SEP-53 preimage: `UTF8("Stellar Signed Message:\n") || messageBytes`, SHA-256, ed25519 over the 32-byte hash. The spec carries no domain, nonce or network, so the message text must.
- Server verification can reuse `StellarPublicKey.verify` as in `stellar_envelope_codec.dart`.

## Alternatives

| | Approach | Pros | Cons |
|---|---|---|---|
| A | Custom `WalletIdp` + SEP-53 SIWE-style challenge | Standard Serverpod JWT, no server signing key, human-readable prompt | `signMessage` runtime shape to prove; narrower wallet support than SEP-10 |
| B | SEP-10 challenge transaction | Broadest wallet support | Server signing key, home domain, adapter changes, opaque prompt |

SEP-45 applies only to contract accounts. bnbagent-sdk has no user login (serving surfaces are out of the SDK); the closest idiom is EIP-4361 SIWE, and SEP-53 plus a SIWE-style message is its Stellar equivalent.

## Risks

- Freighter `signMessage` return shape; the displayed text must be checked manually.
- Cross-module `AuthUser` relation syntax in our `spy.yaml` is unverified.
- Flutter web token storage and XSS (see #116).
- Contract accounts cannot use SEP-53.
- Estimated 1.3-1.6k authored lines: over the 400-line budget.
