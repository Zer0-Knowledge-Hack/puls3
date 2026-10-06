# Flutter Hire Escrow Flow Specification

## Purpose

The Flutter hire flow MUST inform the user of the Soroban Escrow protection, provide direct links to StellarExpert testnet explorer for verification, and handle wallet signing failures gracefully with clear error feedback and retry capability.

> **Status:** the flow is a UI demo until the server relay exists (#96, #97). Signing mock XDR creates no hire and sends no payment, so `HirePhase.confirmed` shows "Demo signature only" with no tx hash and no explorer link, and the requirements below about a confirmation hash and explorer link are superseded. The explorer URL helpers stay for the real flow.

## ADDED Requirements

### Requirement: StellarExpert explorer URL generation

A pure module `stellar_explorer.dart` MUST provide helper functions to format testnet StellarExpert URLs for transactions and contracts.

#### Scenario: Transaction explorer URL

- GIVEN a 64-character transaction hash `43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437`
- WHEN `stellarExpertTxUrl` is called
- THEN it returns `https://stellar.expert/explorer/testnet/tx/43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437`

#### Scenario: Contract explorer URL

- GIVEN a 56-character contract ID `CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`
- WHEN `stellarExpertContractUrl` is called
- THEN it returns `https://stellar.expert/explorer/testnet/contract/CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`

### Requirement: Escrow payment review details

In `HirePaymentView`, the `review` phase MUST display:
1. The price in USDC.
2. The agent destination wallet address.
3. The escrow contract address holding funds in custody (`CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2` by default).
4. Explanatory text indicating funds are locked in Escrow and released upon satisfactory completion.

#### Scenario: Review phase displays escrow contract

- GIVEN a `HirePaymentView` in `HirePhase.review` with default escrow contract address
- WHEN it is built
- THEN it displays the escrow contract label and address badge
- AND displays the agent destination address
- AND displays the "Confirm & sign" action button

### Requirement: Interactive explorer link on confirmation

When in `HirePhase.confirmed`, `HirePaymentView` MUST display the transaction hash as an interactive link or action that triggers opening the StellarExpert testnet explorer URL for that hash.

#### Scenario: Confirmed phase displays transaction explorer action

- GIVEN a `HirePaymentView` in `HirePhase.confirmed` with txHash `43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437`
- WHEN it is built
- THEN it renders the shortened tx hash
- AND provides a visible button or link to view on StellarExpert

#### Scenario: Opening explorer URL

- GIVEN an onOpenExplorer callback injected into `HirePaymentView`
- WHEN the user taps the explorer link or button
- THEN the callback is invoked with the full StellarExpert testnet URL

### Requirement: Resilient error phase and retry

`HirePhase` MUST include an `error` state. When wallet signing fails or throws:
1. `HireSheet` MUST transition to `HirePhase.error` with a descriptive message instead of throwing unhandled exceptions.
2. `HirePaymentView` MUST render the error message and a "Retry" button.
3. Tapping "Retry" MUST transition back to signing/review and allow the user to attempt signing again.

#### Scenario: Wallet rejection shows error state

- GIVEN a wallet that throws `Exception("User rejected signature")` during `signTransaction`
- WHEN the user confirms the payment in `HireSheet`
- THEN `HireSheet` transitions to `HirePhase.error`
- AND displays the error message without closing the sheet
- AND shows a "Try again" button

#### Scenario: Retry recovers to signing

- GIVEN a `HireSheet` in `HirePhase.error`
- WHEN the user taps "Try again"
- THEN signing is re-attempted
