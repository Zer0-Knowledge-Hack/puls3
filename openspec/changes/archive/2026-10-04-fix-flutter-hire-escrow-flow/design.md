# Design: Flutter Hire Escrow Flow

## Technical Approach

Enrich `HireSheet` and `HirePaymentView` to visually communicate on-chain Soroban escrow protection, provide direct verification links via StellarExpert testnet explorer, and handle wallet interaction errors gracefully with in-place retries.

## Architecture & Components

### 1. Stellar Explorer Helpers (`puls3_flutter/lib/src/domain/stellar_explorer.dart`)

Pure helper functions to construct canonical StellarExpert URLs for testnet:
```dart
const String defaultEscrowContractAddress =
    'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';

const String stellarExpertTestnetBase = 'https://stellar.expert/explorer/testnet';

String stellarExpertTxUrl(String hash) => '$stellarExpertTestnetBase/tx/$hash';

String stellarExpertContractUrl(String contractId) =>
    '$stellarExpertTestnetBase/contract/$contractId';
```

### 2. Enhanced `HirePhase` and Presentational View (`HirePaymentView`)

Add `HirePhase.error` to `HirePhase`:
```dart
enum HirePhase { review, signing, confirmed, error }
```

In `HirePaymentView`:
- Accept optional `escrowContractAddress` (defaulting to `defaultEscrowContractAddress`).
- Accept optional `errorMessage` for display in the error state.
- Accept optional `onOpenExplorer` callback `void Function(String url)?` to trigger URL opening (injectable for testability without requiring live browser launcher fakes).
- Accept optional `onRetry` callback `VoidCallback?`.
- Review phase renders:
  - Row for Price (USDC stroops).
  - Row for Asset: USDC.
  - Row for Network: Stellar.
  - Row for Destination: Agent wallet address badge.
  - Row for Escrow: Escrow contract address badge.
  - Explanatory copy: "Funds are locked in the Soroban Escrow contract and released upon approved delivery."
- Confirmed phase renders:
  - Tx hash display with a clickable explorer action / button to view on StellarExpert.
- Error phase renders:
  - Friendly error banner explaining why signing did not complete (e.g. signature rejected or network disconnect).
  - Primary button "Try again" calling `onRetry`.
  - Secondary button "Back to Marketplace".

### 3. Container State Machine (`HireSheet`)

Wrap the wallet signing call in a `try/catch`:
```dart
Future<void> _confirm() async {
  final wallet = AppScope.of(context).wallet;
  setState(() {
    _phase = HirePhase.signing;
    _errorMessage = null;
  });

  try {
    if (wallet.address == null) {
      await wallet.connect();
    }
    final hash = await wallet.signTransaction(
      'mock-usdc-payment:${widget.agent.stellarAddress}:${widget.agent.priceUsdcStroops}',
    );
    if (!mounted) return;
    setState(() {
      _txHash = hash;
      _phase = HirePhase.confirmed;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _phase = HirePhase.error;
      _errorMessage = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Payment could not be completed';
    });
  }
}
```

## File Changes Table

| File | Type | Purpose |
|------|------|---------|
| `puls3_flutter/lib/src/domain/stellar_explorer.dart` | New | Explorer URL generation & escrow contract constant |
| `puls3_flutter/lib/src/ui/organisms/hire_payment_view.dart` | Modified | Add escrow info, error view, interactive explorer button |
| `puls3_flutter/lib/src/screens/hire_sheet.dart` | Modified | Add error state handling, retry action, escrow injection |
| `puls3_flutter/test/domain/stellar_explorer_test.dart` | New | Unit tests for URL builders |
| `puls3_flutter/test/ui/hire_payment_view_test.dart` | New | Widget tests for all 4 phases (review, signing, confirmed, error) |
| `puls3_flutter/test/screens/hire_sheet_test.dart` | New | Widget tests for hire flow container & error recovery |

## Testing Strategy

- **Unit tests**: Pure tests for `stellarExpertTxUrl` and `stellarExpertContractUrl`.
- **Widget tests**:
  - `HirePaymentView` review state shows escrow badge and copy.
  - `HirePaymentView` confirmed state fires `onOpenExplorer` with the correct explorer URL.
  - `HirePaymentView` error state renders the error message and invokes `onRetry`.
  - `HireSheet` handles a failing wallet gracefully and recovers on retry.
