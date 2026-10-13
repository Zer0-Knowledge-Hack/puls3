import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/hire/wallet_funds.dart';

/// The message of the [HireInsufficientFunds] that [check] throws.
String _refusal(void Function() check) {
  try {
    check();
  } on HireInsufficientFunds catch (e) {
    return e.message;
  }
  fail('expected HireInsufficientFunds');
}

void main() {
  group('horizonAmountToStroops', () {
    test('reads Horizon amounts with integer math', () {
      expect(horizonAmountToStroops('0.1000000'), 1000000);
      expect(horizonAmountToStroops('12.5'), 125000000);
      expect(horizonAmountToStroops('0'), 0);
      expect(horizonAmountToStroops('250000.0000001'), 2500000000001);
    });

    test('anything else is not an amount', () {
      for (final amount in ['', '-1.0', '1.12345678', 'abc', '1,5']) {
        expect(
          () => horizonAmountToStroops(amount),
          throwsFormatException,
          reason: amount,
        );
      }
    });
  });

  group('requireFunds', () {
    test('the exact price is enough', () {
      requireFunds(
        const WalletFunds(accountExists: true, usdcStroops: 1000000),
        1000000,
      );
    });

    test('too little USDC names the price and the balance', () {
      final message = _refusal(
        () => requireFunds(
          const WalletFunds(accountExists: true, usdcStroops: 500000),
          1000000,
        ),
      );
      expect(message, contains('costs 0.10 USDC'));
      expect(message, contains('holds 0.05 USDC'));
      expect(message, contains('faucet.circle.com'));
      expect(message, contains('Nothing was signed'));
    });

    test('no trustline names the USDC issuer', () {
      final message = _refusal(
        () => requireFunds(const WalletFunds(accountExists: true), 1000000),
      );
      expect(message, contains('no USDC trustline'));
      expect(message, contains(testnetUsdcIssuer));
    });

    test('an account not on testnet says to fund it first', () {
      final message = _refusal(
        () => requireFunds(const WalletFunds(accountExists: false), 1000000),
      );
      expect(message, contains('not on Stellar Testnet'));
      expect(message, contains('Friendbot'));
    });
  });
}
