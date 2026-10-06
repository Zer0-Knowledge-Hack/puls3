# Exploration: fix-flutter-hire-escrow-flow

Full analysis: engram `sdd/fix-flutter-hire-escrow-flow/explore`.

## Current state

- `puls3_flutter/lib/src/screens/hire_sheet.dart` owns the hire lifecycle (`HirePhase`: `review`, `signing`, `confirmed`).
- `HirePaymentView` (`puls3_flutter/lib/src/ui/organisms/hire_payment_view.dart`) renders the payment summary and success confirmation.
- The confirm action calls `wallet.signTransaction('mock-usdc-payment:${widget.agent.stellarAddress}:${widget.agent.priceUsdcStroops}')`.
- The escrow contract (`CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2`) is live on Stellar testnet (PR #84). The UI needs to reflect escrow protection (locking funds on-chain, release on validated completion, refund guarantee on expiry).
- Clicking the tx hash or contract id should open the StellarExpert testnet explorer (`https://stellar.expert/explorer/testnet/tx/<hash>`).
- If wallet signing fails or is rejected, the sheet currently remains in `signing` or uncaught exception state without user-facing remediation.
- Wallet connection: if disconnected, the flow must trigger connection before signing.

## Approaches

| Approach | Verdict |
|---|---|
| A. Enrich `HireSheet` and `HirePaymentView` with Escrow guarantee context, StellarExpert explorer links via `url_launcher`, and resilient error recovery | Recommended: keeps the clean presentational/container seam, zero breaking changes to existing routes, fully testable with widget tests |
| B. Rewrite entire app navigation to a dedicated multi-step page | Higher complexity, breaks existing bottom sheet modal UX, out of review budget |
| C. Hardcode direct payments without escrow references | Does not leverage the live on-chain escrow evidence deployed in PR #84 |

## Defaults chosen

- Default Escrow contract address: `CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2` (from `contracts/deployments/testnet.json`).
- Stellar testnet explorer base: `https://stellar.expert/explorer/testnet`.
- Add an error state (`HirePhase.error` / error message) so users can retry on failure without closing the modal.
- Tx hash in `HirePaymentView` rendered as an interactive link with launch capability.
- Display "Escrow Contract" in the payment review breakdown alongside agent destination.
- Strict TDD covering widget rendering across all phases (review, signing, confirmed, error).

## Risks

- `url_launcher` in unit test environments requires fake/mocking or testing the callback/URL builder seam.
- Review budget: aim for ~250 lines of focused UI, widgets, and tests.
