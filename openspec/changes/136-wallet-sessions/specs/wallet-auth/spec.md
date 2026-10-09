# Wallet Auth Specification

## Purpose

A Stellar wallet proves control of its account with a SEP-10 (v3.4.1) challenge transaction. The server verifies it and issues a Serverpod `AuthSuccess` session bound to that wallet. `docs/architecture/api.md` is authoritative for error codes. Deviation from SEP-10, recorded: the response is Serverpod `AuthSuccess` (access + refresh), not the SEP-10 JWT.

> Scope: `WalletAuthEndpoint.createChallenge` / `verifyChallenge`, the `WalletIdp` identity provider, the `wallet_account` mapping, and the Flutter session lifecycle. Out of scope: contract accounts (SEP-45), M accounts, `client_domain`, `stellar.toml` publication, the Pollar adapter, web token hardening (#116).

## ADDED Requirements

### Requirement: Create a SEP-10 challenge

`WalletAuthEndpoint.createChallenge(wallet)` MUST validate `wallet` as a Stellar G-address (`InvalidStellarAddress` otherwise), apply the rate limit, build a SEP-10 challenge transaction signed by the server, persist a single-use challenge record, and return `WalletChallenge{challengeId, wallet, payload (challenge XDR), networkPassphrase, expiresAt}`. The transaction MUST have: source = the server signing key, sequence number 0, time bounds `min = now` and `max = now + 900` seconds, a first operation `manage_data` named `<home_domain> auth` sourced by `wallet` with a value of 48 random bytes base64-encoded (64 bytes), and a `manage_data` operation named `web_auth_domain` sourced by the server key. The server MUST sign it. `expiresAt` MUST equal the time-bounds end. The nonce MUST come from a cryptographically secure source and differ per challenge. The rate limit is 5 challenges per minute per wallet (`DatabaseRateLimiter`), exceeding it MUST raise `ChallengeRateLimited`. A missing signing key, home domain or auth configuration MUST raise `AuthenticationUnavailable` before persisting anything. The endpoint MUST NOT require a session (`@unauthenticatedClientCall`).

#### Scenario: W1 Challenge shape
- GIVEN a valid wallet `G...` and a configured server key, home domain and network
- WHEN `createChallenge(wallet)` is called
- THEN the decoded transaction has the server key as source, sequence 0, time bounds `[now, now + 900]`
- AND operation 1 is `manage_data` `<home_domain> auth` sourced by `wallet` with a 64-byte base64 value decoding to 48 bytes
- AND a later operation is `manage_data` `web_auth_domain` sourced by the server key with the web-auth domain value
- AND the server signature verifies over the hash for the configured network passphrase

#### Scenario: W2 Result and persistence
- GIVEN a successful `createChallenge`
- WHEN the result is inspected
- THEN `challengeId`, `wallet`, `payload`, `networkPassphrase` and `expiresAt` (= time-bounds max) are set
- AND one unconsumed challenge row exists for that id, wallet and transaction hash

#### Scenario: W3 Unique nonces
- GIVEN two `createChallenge` calls for the same wallet
- WHEN the results are compared
- THEN the challenge ids and the first-operation values differ

#### Scenario: W4 Invalid address
- GIVEN a `wallet` that is not a valid G-address (empty, wrong checksum, `M...`, `C...`)
- WHEN `createChallenge` is called
- THEN it fails with `InvalidStellarAddress` and persists nothing

#### Scenario: W5 Rate limited
- GIVEN 5 challenges already requested for a wallet within the last minute
- WHEN `createChallenge` is called for that wallet
- THEN it fails with `ChallengeRateLimited` and persists nothing
- AND another wallet is not limited

#### Scenario: W6 Authentication unavailable
- GIVEN the server signing key, home domain or web-auth domain is not configured
- WHEN `createChallenge` is called
- THEN it fails with `AuthenticationUnavailable` and persists nothing

#### Scenario: W7 Callable while signed in
- GIVEN the caller holds an access token for wallet A
- WHEN it calls `createChallenge` for wallet B
- THEN the call succeeds (no `SignInWhileAuthenticated`)

### Requirement: Verify a signed challenge

`WalletAuthEndpoint.verifyChallenge(challengeId, wallet, signedChallengeXdr)` MUST load the challenge and verify the signed transaction. Checks, with the first failure winning in this order:

1. Challenge exists (`ChallengeNotFound`), `wallet` equals the challenge wallet and is a valid address.
2. Not consumed (`ChallengeConsumed`), not expired by server time (`ChallengeExpired`).
3. Signed XDR parses as a transaction envelope for the configured network and its body is identical to the stored challenge body: source = server key, sequence 0, time bounds, first operation (type, source, name, value), extra operations (all `manage_data` sourced by the server key). Any other difference MUST raise `InvalidWalletSignature` with `details.reason` in `malformed`, `wrongNetwork`, `tampered`.
4. The server signature is present and valid (`InvalidWalletSignature`, `details.reason = serverSignature`).
5. Client signatures, with the server signature excluded:
   - If the account exists on chain: signatures MUST verify against the account's current signers (key, weight), and their combined weight MUST reach the account's **medium** threshold, otherwise `InvalidWalletSignature` with `details.reason = insufficientWeight` (or `noClientSignature` when none verifies).
   - If the account does not exist: there MUST be exactly one valid signature, by the wallet's master key (`details.reason = noClientSignature` or `invalidClientSignature` otherwise).
6. A signer lookup that fails because the chain cannot be read MUST raise `AuthenticationUnavailable`; it MUST NOT fall back to master-key-only.

On success the server MUST consume the challenge atomically and return `AuthSuccess` bound to `wallet`. Nothing is persisted or issued on any failure. The server MUST NOT log or return the signing key, nonce value, signed XDR or tokens in errors or logs.

#### Scenario: W8 Valid challenge, existing account, master key
- GIVEN an issued challenge for an existing account whose master key has weight at least its medium threshold
- WHEN the wallet signs it unchanged and `verifyChallenge` is called
- THEN the result is `AuthSuccess` (access and refresh token) bound to the wallet
- AND the challenge is consumed

#### Scenario: W9 Valid challenge, multisig account
- GIVEN an existing account with signers A (weight 1) and B (weight 1) and medium threshold 2
- WHEN the challenge is signed by A and B
- THEN `verifyChallenge` returns `AuthSuccess`

#### Scenario: W10 Insufficient signer weight
- GIVEN the same account signed only by A (weight 1 below medium threshold 2)
- WHEN `verifyChallenge` is called
- THEN it fails with `InvalidWalletSignature`, `details.reason = insufficientWeight`
- AND the challenge stays unconsumed

#### Scenario: W11 Signature by a non-signer
- GIVEN an existing account and a challenge signed only by an unrelated key
- WHEN `verifyChallenge` is called
- THEN it fails with `InvalidWalletSignature`

#### Scenario: W12 Server signature does not count toward weight
- GIVEN an existing account whose signer set (or a test configuration) includes the server key with enough weight
- WHEN the challenge carries only the server signature
- THEN it fails with `InvalidWalletSignature` (`noClientSignature`)

#### Scenario: W13 Unfunded account
- GIVEN a wallet that does not exist on chain and a challenge signed by its master key
- WHEN `verifyChallenge` is called
- THEN the result is `AuthSuccess`
- AND with two valid signatures, or a signature by another key, it fails with `InvalidWalletSignature`

#### Scenario: W14 Unknown challenge
- GIVEN a `challengeId` that does not exist
- WHEN `verifyChallenge` is called
- THEN it fails with `ChallengeNotFound`

#### Scenario: W15 Wrong wallet
- GIVEN a challenge issued for wallet A
- WHEN `verifyChallenge` is called with wallet B (valid address, even with a valid B signature)
- THEN it fails with `InvalidWalletSignature` (`details.reason = walletMismatch`) and the challenge stays unconsumed
- AND a malformed `wallet` fails with `InvalidStellarAddress`

#### Scenario: W16 Expired
- GIVEN a challenge whose time-bounds max has passed
- WHEN `verifyChallenge` is called with a valid signature
- THEN it fails with `ChallengeExpired`

#### Scenario: W17 Consumed
- GIVEN a challenge already used for a successful verification
- WHEN `verifyChallenge` is called again with the same valid signed XDR
- THEN it fails with `ChallengeConsumed` and issues no second session

#### Scenario: W18 Wrong network
- GIVEN a challenge signed by the client over a hash for another network passphrase
- WHEN `verifyChallenge` is called
- THEN it fails with `InvalidWalletSignature` (`details.reason = noClientSignature`) and the challenge stays unconsumed

#### Scenario: W19 Tampered body
- GIVEN a signed XDR whose transaction source, sequence, time bounds, first-operation name, source or value, or operation list differs from the stored challenge (including an added operation or a changed extra-operation source)
- WHEN `verifyChallenge` is called
- THEN each fails with `InvalidWalletSignature` (`details.reason = tampered`)

#### Scenario: W20 Missing or invalid server signature
- GIVEN a signed XDR with the server signature removed, replaced by a signature from another key, or corrupted
- WHEN `verifyChallenge` is called
- THEN it fails with `InvalidWalletSignature` (`details.reason = serverSignature`)

#### Scenario: W21 Malformed XDR
- GIVEN a signed XDR that is empty, not base64, truncated, has trailing bytes, or is a fee-bump envelope
- WHEN `verifyChallenge` is called
- THEN it fails with `InvalidWalletSignature` (`details.reason = malformed`)

#### Scenario: W22 Chain unreadable
- GIVEN the account signers/thresholds cannot be loaded because the chain is unavailable
- WHEN `verifyChallenge` is called
- THEN it fails with `AuthenticationUnavailable`, the challenge stays unconsumed, and no master-key fallback is applied

#### Scenario: W23 Failure persists nothing
- GIVEN any failure in W10 to W22
- WHEN `verifyChallenge` returns
- THEN no auth user, `wallet_account` row or token exists for the attempt

### Requirement: Challenge consumption is atomic and single-use

The challenge store MUST consume a challenge with a conditional update (consumed only if unconsumed and unexpired) in the same transaction that creates the wallet account and issues the tokens. At most one session MUST be issued per challenge. A failure while issuing the session MUST roll back the consumption.

#### Scenario: W24 Concurrent verifies
- GIVEN one valid signed challenge
- WHEN two `verifyChallenge` calls run concurrently
- THEN exactly one returns `AuthSuccess` and the other fails with `ChallengeConsumed`

#### Scenario: W25 Issuance failure rolls back
- GIVEN token issuance throws after verification
- WHEN `verifyChallenge` is called
- THEN the call fails, the challenge is unconsumed, and no `wallet_account` or auth user row is left behind

#### Scenario: W26 Store contract
- GIVEN the Postgres store and the in-memory fake
- WHEN the same contract tests run against both
- THEN they agree on insert, find, consume-once, expired-consume and unknown-id behaviors

### Requirement: Session is bound to one auth user per wallet

The `WalletIdp` MUST create a Serverpod auth user and a `wallet_account` row on a wallet's first successful sign-in, with `wallet` unique and the auth user unique. A later successful sign-in of the same wallet MUST reuse that auth user and MUST NOT create another. `AuthSuccess` MUST be issued through the Serverpod token manager (default 10-minute access, 14-day refresh). Wallet to user resolution MUST be possible in both directions.

#### Scenario: W27 First sign-in creates the mapping
- GIVEN a wallet never seen before
- WHEN `verifyChallenge` succeeds
- THEN one auth user and one `wallet_account` row (wallet, auth user) exist
- AND `AuthSuccess.authUserId` equals that auth user

#### Scenario: W28 Re-sign-in reuses the user
- GIVEN a wallet that already has a `wallet_account`
- WHEN a new challenge for it is verified
- THEN the same auth user id is returned, a fresh token pair is issued, and no second auth user or row exists

#### Scenario: W29 Two wallets, two users
- GIVEN wallets A and B each signing in
- WHEN both succeed
- THEN they have different auth users and A's token never resolves to B's wallet

#### Scenario: W30 Uniqueness enforced
- GIVEN a second `wallet_account` insert for an existing wallet or auth user
- WHEN it is attempted
- THEN the database rejects it and no partial state remains

#### Scenario: W31 Sign-in while holding another wallet's token
- GIVEN the caller holds an access token for wallet A
- WHEN it verifies a valid challenge for wallet B
- THEN the result is `AuthSuccess` for B's auth user (no `SignInWhileAuthenticated`)

### Requirement: Production SessionWallet resolves the wallet from the session

The production `SessionWallet` MUST resolve the wallet from `session.authenticated?.authUserId` through a `wallet_account` lookup. It MUST NOT trust any caller-supplied address. With no authenticated session, or an auth user without a `wallet_account`, it MUST fail closed. Server startup MUST fail closed when the JWT or wallet-signing secrets are missing in production. `FailClosedSessionWallet` MUST remain available as a test double only.

#### Scenario: W32 Resolves the bound wallet
- GIVEN a session authenticated as the auth user of wallet W
- WHEN `requireLogin` is called
- THEN it returns W

#### Scenario: W33 No session
- GIVEN a session with no authentication
- WHEN `requireLogin` is called
- THEN it raises the unauthenticated outcome

#### Scenario: W34 Auth user without wallet
- GIVEN an authenticated user with no `wallet_account`
- WHEN `requireLogin` is called
- THEN it fails closed and returns no wallet

#### Scenario: W35 Missing secrets in production
- GIVEN production mode with the server signing key or JWT secret absent
- WHEN the server starts
- THEN startup fails with a clear configuration error and the endpoints are not served

### Requirement: Secrets are never exposed

The server signing key MUST be read only from the Serverpod passwords (never an environment variable) and MUST NOT appear in logs, error `details`, or responses. Challenge nonces, signed XDRs and tokens MUST NOT be logged. `passwords.example.yaml` MUST document the new keys with placeholders only.

#### Scenario: W36 No secret leakage
- GIVEN any success or failure path of `createChallenge` and `verifyChallenge`
- WHEN responses, exception details and captured logs are inspected
- THEN none contains the signing key, a token, or the signed XDR

### Requirement: Template email identity provider is removed

The template EmailIdp endpoint, its configuration and generated client surface MUST be removed. Wallet challenge is the only sign-in method (`api.md` decision 10).

#### Scenario: W37 No email endpoint
- GIVEN the generated protocol after `serverpod generate`
- WHEN the endpoint list is inspected
- THEN no email sign-in or registration endpoint exists and `serverpod generate` leaves no diff

### Requirement: Flutter validates the challenge before the wallet prompt

`WalletPort.signChallenge(challenge)` MUST validate the challenge client-side before asking the wallet to sign, and MUST reject without prompting when any check fails: network passphrase equals the app's configured network; first operation is `manage_data` named `<expected home domain> auth` sourced by the connected account; a `web_auth_domain` operation matches the expected domain; every other operation is `manage_data` sourced by the server key; transaction source equals the configured server key; sequence is 0; time bounds are present and not expired by the client clock; the server signature verifies. The failure MUST be a typed rejection that never reaches `verifyChallenge`.

#### Scenario: W38 Valid challenge is signed
- GIVEN a well-formed challenge from the configured server
- WHEN `signChallenge` runs
- THEN the wallet prompt is shown once and the signed XDR is returned

#### Scenario: W39 Invalid challenges are rejected without a prompt
- GIVEN a challenge with a wrong network, wrong home domain, wrong server key, a non-`manage_data` or foreign-sourced extra operation, non-zero sequence, missing or expired time bounds, or an invalid server signature
- WHEN `signChallenge` runs
- THEN it fails with a typed error, the wallet prompt is never shown, and no call is made to `verifyChallenge`

#### Scenario: W40 User rejects the prompt
- GIVEN the wallet prompt is declined
- WHEN `signChallenge` runs
- THEN it fails with `WalletRejected` and no session is created

### Requirement: Flutter session lifecycle

Flutter MUST use `FlutterAuthSessionManager`, store the `AuthSuccess` after verification (`updateSignedInUser`), and rely on the standard refresh path. If refresh fails (refresh token expired, revoked or invalid), Flutter MUST discard the session and repeat the challenge flow before resuming the pending action. Disconnecting the wallet MUST call `signOutDevice`. `MockWallet` MUST sign with a real test key so the whole flow runs end to end without a browser extension.

#### Scenario: W41 Connect signs in
- GIVEN a connected `MockWallet`
- WHEN the wallet controller connects
- THEN it calls `createChallenge`, `signChallenge`, `verifyChallenge`, stores the session, and exposes the authenticated wallet

#### Scenario: W42 Expired access token refreshes
- GIVEN a stored session with an expired access token and a valid refresh token
- WHEN a protected call is made
- THEN the token is refreshed transparently and the call succeeds without a new challenge

#### Scenario: W43 Refresh failure repeats the challenge
- GIVEN refresh fails
- WHEN the session listenable reports signed-out
- THEN the controller starts a new challenge flow and resumes the pending action after success

#### Scenario: W44 Disconnect signs out
- GIVEN an authenticated session
- WHEN the user disconnects the wallet
- THEN `signOutDevice` is called, the stored session is cleared, and the controller state is disconnected

#### Scenario: W45 End-to-end with MockWallet against the real server logic
- GIVEN the `MockWallet` test key and an in-memory server wiring
- WHEN sign-in, a hire call and sign-out run in sequence
- THEN the hire call succeeds with the wallet's session and fails with 401 after sign-out

### Requirement: Freighter compatibility is evidenced

A known-vector unit test MUST cover a Freighter-signed SEP-10 challenge, and a manual check with real Freighter MUST be documented. `api.md` MUST be updated: lifecycle step 2 and the `verifyChallenge` parameter (`signedChallengeXdr`), expiry 15 minutes (replacing 5), and `WalletChallenge` (`payload` = challenge XDR, plus `networkPassphrase`).

#### Scenario: W46 Known vector verifies
- GIVEN a recorded Freighter-signed challenge
- WHEN the verification unit test runs
- THEN the client signature verifies and the body checks pass

#### Scenario: W47 Docs match behavior
- GIVEN `docs/architecture/api.md` after the change
- WHEN it is read
- THEN the lifecycle, `verifyChallenge` parameter, 15-minute expiry and `WalletChallenge` fields match this spec
