# Proposal: Wallet-authenticated sessions with SEP-10 (issue #136)

## Intent

- Every `Auth: Yes` method fails closed today (`FailClosedSessionWallet` raises `AuthenticationUnavailable`), so no user can hire. #136 binds a Serverpod session to a proven Stellar wallet.
- Decision: **SEP-10** challenge transactions, not SEP-53 `signMessage`. SEP-10 is the ecosystem standard (anchors, Pollar) and works with any wallet that can sign a transaction.

## Scope

### In Scope
- `AuthEndpoint.createChallenge(wallet)` returns a SEP-10 challenge signed by the server: source = server signing key, sequence 0, timebounds, first op `manage_data "<home_domain> auth"` (source = client, 48 random bytes, base64), plus a `web_auth_domain` op.
- `verifyChallenge(challengeId, wallet, signedChallenge)` checks the server signature, the client signature, ops, timebounds, network and home domain. It consumes the challenge atomically, once.
- A custom `WalletIdp` `IdentityProvider` returns Serverpod `AuthSuccess`. A `wallet_account` table maps one auth user to each wallet. A production `SessionWallet` resolves the wallet with a DB lookup.
- `HireEndpoint.requireLogin => true` (real 401s). Remove the template EmailIdp endpoint and its config.
- Flutter: `WalletPort.signChallenge` checks the challenge before the prompt. `MockWallet` signs with a real test key. `FlutterAuthSessionManager` stores and refreshes the session. A failed refresh repeats the challenge; disconnect calls `signOutDevice`.
- Docs: `api.md` (lifecycle, `verifyChallenge` parameter, expiry, `WalletChallenge`).

### Out of Scope
- Contract accounts (SEP-45), M accounts, `client_domain`.
- Publishing `SIGNING_KEY`/`WEB_AUTH_ENDPOINT` in `stellar.toml`. Only our own app consumes the endpoint, and it gets the server key from `NetworkConfig` over the same TLS origin. Revisit with Pollar.
- Pollar adapter (phase 2; `WalletPort` stays open). Web token hardening (#116).

## Proposed defaults (adjustable at review)

| Topic | Default |
|---|---|
| Response | Serverpod `AuthSuccess` (JWT access + refresh) instead of the SEP-10 JWT. This is a recorded deviation, so refresh and sign-out stay standard |
| Signer check | Follow SEP-10 (decided at review). If the client account exists, load its signers and thresholds over Soroban RPC (extend `ChainAccounts`), exclude the server signature, and require the valid client signatures' combined weight to reach the account's **medium** threshold (SEP-10: medium = authority to move funds, which is what a hire does). If the account does not exist, require exactly one valid master-key signature. Possession of the master key alone is not assumed to be possession of the account |
| Expiry | 15-minute timebounds (SEP-10 v3.4.1 recommendation, verified against the spec). The single-use nonce limits replay; the server issues at most one session per challenge, as SEP-10 requires. `api.md` five minutes → 15 |
| Tokens | Serverpod defaults (10 min / 14 days) |
| Rate limit | `DatabaseRateLimiter`, 5 challenges per minute per wallet |
| Secrets | Server signing key as a Serverpod password, never in env or logs. Home and web-auth domain from config |
| Freighter proof | Known-vector unit test plus a documented manual check with real Freighter |

## Capabilities

### New Capabilities
- `wallet-auth`: SEP-10 challenge and verification, the wallet identity provider, wallet-to-user mapping, rate limit, client session lifecycle.

### Modified Capabilities
- `escrow-relay`: session enforcement becomes real (HTTP 401 via `requireLogin`, production `SessionWallet`).
- `hire-payment`: the "until #25" seam requirement is replaced by the real session binding.

## Approach

The server reuses the decode and verify code in `stellar_envelope_codec.dart`. The challenge store copies the pattern of the escrow preparation store: a conditional `UPDATE` for the atomic consume, an in-memory fake and contract tests. `AuthEndpoint` methods use `@unauthenticatedClientCall`. Crypto and Serverpod code stay in adapters, so the ADR-0001 domain boundary is not crossed.

## Affected Areas

| Area | Impact |
|---|---|
| `puls3_server/lib/server.dart`, `lib/src/auth/*` | Modified/New/Removed (EmailIdp) |
| `puls3_server/lib/src/hire/session_wallet.dart`, `hire_endpoint.dart` | Modified |
| `puls3_server/lib/src/**/*.spy.yaml`, migrations, `passwords.example.yaml` | New |
| `puls3_flutter/lib/src/wallet/*`, `state/wallet_controller.dart`, `web/freighter_bridge.js`, `main.dart` | Modified |
| `docs/architecture/api.md` | Modified |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Freighter shows an opaque sequence-0 tx or warns about it | Med | Client-side checks, manual evidence, UX copy |
| Cross-module `AuthUser` relation syntax in `spy.yaml` | Med | Spike in the first commit |
| A missing `@unauthenticatedClientCall` causes `SignInWhileAuthenticated` | Low | Test re-challenge while signed in |
| JWT and signing secrets missing in production | Med | Startup fails closed, documented in `passwords.example.yaml` |
| Web token storage and XSS | Med | Tracked in #116 |

## Rollback Plan

Revert PR 2, then PR 1. `HireEndpoint` falls back to `FailClosedSessionWallet`. The new tables are additive, so the migration can stay or be rolled back with a down migration.

## Delivery

About 1.3-1.6k authored lines, over the 400-line budget. Proposal: 2 PRs with a justified `size:exception` and one clear unit per commit: (1) server + docs, (2) Flutter.

## Success Criteria (issue #136)

- [ ] A valid SEP-10 signature returns `AuthSuccess` bound to the wallet. Expired, consumed, unknown, wrong-network or forged challenges return their `api.md` codes.
- [ ] `HireEndpoint` returns 401 without a session and `WalletMismatch` for another wallet.
- [ ] Refresh works. A failed refresh repeats the challenge; disconnect signs out.
- [ ] The Freighter known-vector test and the manual check are recorded.
- [ ] Analyze and tests pass for server and Flutter, and `serverpod generate` leaves no diff.

## Proposal question round

The binding decisions above came before this phase. Resolved at review: 15-minute expiry (verified against SEP-10 v3.4.1) and a SEP-10 signer/threshold check at the medium threshold instead of master-key-only. Still open for design: whether `NetworkConfig` carries the server key and home domain.
