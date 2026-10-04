# Proposal: Flutter Hire Escrow Flow

## Intent

The hire flow in `HireSheet` and `HirePaymentView` currently shows a generic payment summary, signs a mock string, and displays an unclickable tx hash on confirmation, with no visual evidence of the Soroban escrow contract or resilient error recovery. Connect the hire experience to the live on-chain escrow contract (`CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`), provide direct links to StellarExpert testnet explorer, and support error recovery when wallet signing fails.

## Scope

### In Scope
- **Escrow-aware Payment Review**: `HirePaymentView` displays the Escrow protection details (Custody contract, Release on completion / Refund guarantee) alongside agent wallet and USDC amount.
- **Interactive Explorer Links**: Transaction hash and Escrow contract address rendered as interactive links that open StellarExpert testnet (`https://stellar.expert/explorer/testnet/tx/<hash>` and `.../contract/<address>`).
- **Resilient Error Recovery**: Introduction of `HirePhase.error` in the hire lifecycle with human-friendly error messages and a "Retry" button so rejected signatures or wallet disconnects do not freeze the UI.
- **Wallet Connection Seam**: Ensure `HireSheet` confirms wallet connection before attempting to sign.
- **Widget & Unit Tests**: Full TDD coverage of the review, signing, confirmed, and error states.

### Out of Scope
- Rust escrow contract changes (already deployed and verified in PR #84).
- Server backend changes (already verified in PR #86 and #88).
- Multi-party arbitration or disputes.

## Capabilities

### New Capabilities
- `flutter-hire-escrow-flow`: Escrow-backed hire payment view, StellarExpert link formatting and launching, error state with retry mechanics.

### Modified Capabilities
- None

## Approach

Keep the existing container/presentational split:
- `HireSheet` manages state (`review` -> `signing` -> `confirmed` / `error`), talks to `WalletPort`, and catches exceptions.
- `HirePaymentView` receives the state and callbacks, rendering the escrow breakdown, signing spinner, success panel with StellarExpert explorer link, or error banner with retry option.
- Helper `stellarExpertTxUrl(hash)` and `stellarExpertContractUrl(contractId)` for testnet URL generation.
- Default escrow contract constant sourced from `testnet.json`.

## Affected Areas

| Component | Area | Impact |
|-----------|------|--------|
| app | `puls3_flutter/lib/src/ui/organisms/hire_payment_view.dart` | Enhanced phases, escrow details, clickable explorer link |
| app | `puls3_flutter/lib/src/screens/hire_sheet.dart` | Error handling, retry logic, escrow contract injection |
| app | `puls3_flutter/lib/src/domain/stellar_explorer.dart` | Testnet explorer URL helpers |
| app | `puls3_flutter/test/` | Widget tests covering review, signing, confirmed, error & retry |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| URL launcher throws in non-web unit test environments | Low | Inject url launcher callback or use test-safe url launcher seams |
| Layout overflow on small screens with extra escrow info | Low | Use compact KeyValueRow and Responsive layout in HirePaymentView |

## Rollback Plan

Revert the PR; existing `HireSheet` and `HirePaymentView` code is self-contained.

## Dependencies

- Deployed Escrow contract on testnet (`contracts/deployments/testnet.json`).
- `url_launcher` package (already present in `puls3_flutter/pubspec.yaml`).

## Review Workload

~200-250 changed lines including widget tests; single PR within the 400-line review budget.

## Success Criteria

- [ ] `HirePaymentView` displays Escrow contract custody alongside agent wallet and USDC stroop price.
- [ ] Successful hire confirmation presents the tx hash with a functional link to StellarExpert testnet.
- [ ] Wallet signing errors transition to an error phase with a clear message and a retry button.
- [ ] `flutter analyze --fatal-infos` and `flutter test` pass with 100% clean results.
