# Tasks: Flutter Hire Escrow Flow

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~250-350 lines (UI + domain helpers + widget tests) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR, commit-sized work units 0-5 |
| Delivery strategy | single-pr |
| Chain strategy | standard |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: standard
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 0 | Record baseline | PR 1 | `flutter test` | N/A | None |
| 1 | Stellar explorer helpers | PR 1 | `flutter test test/domain/stellar_explorer_test.dart` | N/A: pure functions | `stellar_explorer.dart` |
| 2 | `HirePaymentView` Escrow & Error support | PR 1 | `flutter test test/ui/hire_payment_view_test.dart` | Widget tests | `hire_payment_view.dart` |
| 3 | `HireSheet` container error resilience | PR 1 | `flutter test test/screens/hire_sheet_test.dart` | Widget tests | `hire_sheet.dart` |
| 4 | Verification & Gates | PR 1 | `flutter analyze --fatal-infos && flutter test` | Full suite | Clean git tree |

## Phase 0: Baseline (unit 0)

- [ ] 0.1 Confirm baseline: run `flutter analyze --fatal-infos` and `flutter test` in `puls3_flutter` (66 tests baseline).

## Phase 1: Stellar explorer helpers (unit 1, spec: StellarExpert explorer URL generation)

- [ ] 1.1 RED: create `puls3_flutter/test/domain/stellar_explorer_test.dart` asserting `stellarExpertTxUrl` and `stellarExpertContractUrl` format correct testnet URLs and default escrow contract ID is exported.
- [ ] 1.2 GREEN: create `puls3_flutter/lib/src/domain/stellar_explorer.dart`.

## Phase 2: Escrow details and Error phase in HirePaymentView (unit 2, spec: Escrow payment review details, Interactive explorer link on confirmation, Resilient error phase and retry)

- [ ] 2.1 RED: create `puls3_flutter/test/ui/hire_payment_view_test.dart`:
  - Review phase renders price, agent destination, escrow contract AddressBadge, and escrow lock explanatory text.
  - Confirmed phase renders shortened tx hash and calls `onOpenExplorer` when tapped.
  - Error phase renders error message, "Try again" button calling `onRetry`, and "Back to Marketplace" button.
- [ ] 2.2 GREEN: update `puls3_flutter/lib/src/ui/organisms/hire_payment_view.dart` with `HirePhase.error`, `escrowContractAddress`, `errorMessage`, `onOpenExplorer`, `onRetry`, and corresponding UI widgets.

## Phase 3: Container error handling in HireSheet (unit 3, spec: Resilient error phase and retry)

- [ ] 3.1 RED: create `puls3_flutter/test/screens/hire_sheet_test.dart`:
  - Successful signing transitions to confirmed phase with tx hash and explorer link.
  - Failing wallet (throws Exception) transitions to error phase and displays message without crashing.
  - Tapping "Try again" calls confirm again.
- [ ] 3.2 GREEN: update `puls3_flutter/lib/src/screens/hire_sheet.dart` to handle exceptions in `_confirm`, set `HirePhase.error` and `_errorMessage`, and pass `onRetry` and `onOpenExplorer`.

## Phase 4: Gates & Cleanup (unit 4)

- [ ] 4.1 Run `flutter analyze --fatal-infos` and ensure 0 issues.
- [ ] 4.2 Run `flutter test` and ensure all tests pass.
- [ ] 4.3 Restore any Flutter platform side-effect artifacts (`git checkout HEAD -- pubspec.lock puls3_flutter/linux puls3_flutter/macos puls3_flutter/windows`).
