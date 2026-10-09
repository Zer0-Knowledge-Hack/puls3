# Delta for Hire Payment

Only the session seam requirement changes. All other requirements are unchanged.

## MODIFIED Requirements

### Requirement: Every hire method requires the session wallet

Every `HireEndpoint` method (`createHire`, `prepareCreateJob`, `prepareFund`, `prepareComplete`, `prepareReject`, `submitEscrowCall`) MUST be protected by `requireLogin` (HTTP 401 without a valid session) and MUST obtain the wallet from the production `SessionWallet`, which resolves it from the authenticated session through the `wallet_account` mapping (see `wallet-auth`). The resolved wallet MUST be used for ownership and MUST equal any caller-supplied `consumer` (`WalletMismatch` otherwise).

(Previously: "Real session binding replaces the seam in #25; until then ownership is proven only against a fake.")

#### Scenario: W57 Seam enforced on every method
- GIVEN a fake `SessionWallet` that records invocations
- WHEN each hire method is called
- THEN each calls `requireLogin` exactly once before touching a store or the chain

#### Scenario: W58 Unauthenticated createHire
- GIVEN no access token
- WHEN `createHire` is called through the endpoint stack
- THEN the response is HTTP 401 and no hire is persisted

#### Scenario: W59 Hire bound to the signed-in wallet
- GIVEN wallet W signed in through `verifyChallenge`
- WHEN `createHire(agentId, W, input, requestId)` is called with W's token
- THEN the hire's consumer is W

#### Scenario: W60 Another wallet's address is rejected
- GIVEN wallet W signed in
- WHEN `createHire` is called with W's token and `consumer` = wallet V
- THEN it fails with `WalletMismatch` and no hire is persisted

#### Scenario: W61 A token never acts for another wallet
- GIVEN wallets W and V each signed in, and a hire owned by W
- WHEN V's token calls `getHire` or `prepareFund` for W's hire
- THEN it fails with `HireNotOwned` (or `WalletMismatch` when V passes W's address)
