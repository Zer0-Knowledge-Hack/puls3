# Delta for Escrow Relay

Only the session parts change. Real wallet sessions (#136) replace the injectable-seam scope note. All other requirements are unchanged.

## MODIFIED Requirements

### Requirement: Ownership and session enforcement

Every `HireEndpoint` method MUST require a session: `HireEndpoint.requireLogin` MUST be `true`, so a request without a valid access token is rejected by Serverpod with HTTP 401 before the method runs. Each method MUST then resolve the wallet through the production `SessionWallet` (wallet bound to the session's auth user, see `wallet-auth`) before doing any work. Where a wallet address parameter exists it MUST equal the session wallet, otherwise `WalletMismatch`. A hire not owned by the session wallet MUST raise `HireNotOwned`. A `preparationId` that is unknown, belongs to another hire, or belongs to another wallet MUST raise `PreparationNotFound`. `SessionWallet` stays injectable so tests can substitute a fake.

(Previously: the wallet came from the injectable `SessionWallet` seam, which failed closed until #25; the endpoint had no `requireLogin`.)

#### Scenario: W48 No token gives HTTP 401
- GIVEN a request to any `HireEndpoint` method with no access token
- WHEN the call is made through the real endpoint stack
- THEN the response is HTTP 401 and no store or chain call is made

#### Scenario: W49 Expired or invalid token gives HTTP 401
- GIVEN an expired, revoked or malformed access token
- WHEN any `HireEndpoint` method is called
- THEN the response is HTTP 401

#### Scenario: W50 Valid session reaches the method
- GIVEN an access token issued by `verifyChallenge` for wallet W
- WHEN `createHire` is called with `consumer = W`
- THEN the method runs with W as the session wallet and the hire belongs to W

#### Scenario: W51 Wallet parameter differs from the session
- GIVEN a valid session for wallet W
- WHEN `createHire` (or `getHire`, `listHires`) is called with `consumer` = another valid address
- THEN it fails with `WalletMismatch` and no hire is persisted

#### Scenario: W52 Every method enforces the seam
- GIVEN a fake `SessionWallet` that records calls
- WHEN each hire method is invoked in turn
- THEN `requireLogin` is called by each of them before any store or chain access

#### Scenario: W53 Hire not owned
- GIVEN a hire whose consumer is not the session wallet
- WHEN any prepare method or `submitEscrowCall` is called for it
- THEN it fails with `HireNotOwned` and nothing is persisted

#### Scenario: W54 Unknown or foreign preparation
- GIVEN a `preparationId` that does not exist, or belongs to another hire or wallet
- WHEN `submitEscrowCall` is called
- THEN it fails with `PreparationNotFound`

#### Scenario: W55 Invalid or unknown hire
- GIVEN a non-positive hire id, or an id that names no hire
- WHEN a prepare method or `submitEscrowCall` is called
- THEN it fails with `InvalidHireId` or `HireNotFound` respectively

#### Scenario: W56 Production wiring is not fail-closed
- GIVEN the production server wiring
- WHEN `HireEndpoint` is constructed
- THEN its `SessionWallet` is the session-backed implementation, not `FailClosedSessionWallet`
