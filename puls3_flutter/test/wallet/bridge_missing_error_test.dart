import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/hire/hire_flow_controller.dart';
import 'package:puls3_flutter/src/wallet/freighter/freighter_bridge.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

void main() {
  test('a bridge that failed to load is a connector error, not "install"', () {
    expect(
      bridgeMissingError(bridgeFailedToLoad: true),
      isA<WalletConnectorUnavailable>(),
    );
  });

  test('a bridge with no wallet behind it still means not installed', () {
    expect(
      bridgeMissingError(bridgeFailedToLoad: false),
      isA<WalletNotInstalled>(),
    );
  });

  test('the hire flow never tells the user to install Freighter for it', () {
    final message = walletErrorMessage(const WalletConnectorUnavailable());
    expect(message, contains('could not load'));
    expect(message, isNot(contains('Install')));
    expect(message, contains('No funds moved'));
  });
}
