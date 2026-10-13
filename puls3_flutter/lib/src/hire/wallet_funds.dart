import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../domain/usdc.dart';
import 'hire_gateway.dart';

/// Code of the USDC the escrow accepts (Circle testnet USDC, the asset of
/// the `PULS3_STELLAR_USDC_SAC` contract).
const String testnetUsdcCode = 'USDC';

/// Issuer of [testnetUsdcCode] on Stellar Testnet.
const String testnetUsdcIssuer =
    'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

/// What a wallet holds of the USDC the escrow accepts (api.md F5-2).
class WalletFunds {
  const WalletFunds({required this.accountExists, this.usdcStroops});

  /// The account is on the network (it has been funded with XLM).
  final bool accountExists;

  /// The USDC it can spend, in stroops; null when it has no USDC trustline.
  final int? usdcStroops;
}

/// Reads the [WalletFunds] of a `G…` account.
typedef ReadWalletFunds = Future<WalletFunds> Function(String account);

/// [ReadWalletFunds] over Horizon on Stellar Testnet.
Future<WalletFunds> readTestnetFunds(String account) async {
  final AccountResponse response;
  try {
    response = await StellarSDK.TESTNET.accounts.account(account);
  } on ErrorResponse catch (e) {
    if (e.code == 404) return const WalletFunds(accountExists: false);
    rethrow;
  }
  for (final balance in response.balances) {
    if (balance.assetCode == testnetUsdcCode &&
        balance.assetIssuer == testnetUsdcIssuer) {
      final selling = balance.sellingLiabilities;
      return WalletFunds(
        accountExists: true,
        usdcStroops:
            horizonAmountToStroops(balance.balance) -
            (selling == null ? 0 : horizonAmountToStroops(selling)),
      );
    }
  }
  return const WalletFunds(accountExists: true);
}

/// A Horizon amount such as `"12.5000000"` in stroops, with integer math
/// only (money is never a `double`).
int horizonAmountToStroops(String amount) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,7}))?$').firstMatch(amount.trim());
  if (match == null) {
    throw FormatException('Not a Stellar amount', amount);
  }
  final fraction = (match.group(2) ?? '').padRight(usdcDecimals, '0');
  return int.parse(match.group(1)!) * stroopsPerUsdc + int.parse(fraction);
}

/// Throws [HireInsufficientFunds] when [funds] cannot pay [priceUsdcStroops].
void requireFunds(WalletFunds funds, int priceUsdcStroops) {
  final price = formatUsdc(priceUsdcStroops);
  final usdc = funds.usdcStroops;
  if (!funds.accountExists) {
    throw HireInsufficientFunds(
      'Your wallet is not on Stellar Testnet yet. Fund it with testnet XLM '
      '(Friendbot), add a USDC trustline and get $price testnet USDC from '
      'faucet.circle.com, then try again. Nothing was signed.',
    );
  }
  if (usdc == null) {
    throw HireInsufficientFunds(
      'Your wallet has no USDC trustline. Add USDC (issuer '
      '$testnetUsdcIssuer) in your wallet and get $price testnet USDC from '
      'faucet.circle.com, then try again. Nothing was signed.',
    );
  }
  if (usdc < priceUsdcStroops) {
    throw HireInsufficientFunds(
      'This hire costs $price USDC and your wallet holds '
      '${formatUsdc(usdc)} USDC. Get testnet USDC from faucet.circle.com, '
      'then try again. Nothing was signed.',
    );
  }
}
