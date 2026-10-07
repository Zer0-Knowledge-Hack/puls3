import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/organisms/wallet_panel.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../helpers.dart';

Finder _state(String name) => find.byKey(ValueKey('wallet-state-$name'));

/// Opens the wallet sheet from the top bar chip.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Connect wallet'));
  await advance(tester, const Duration(milliseconds: 400));
}

void main() {
  group('wallet sheet states (MockWallet)', () {
    testWidgets('disconnected: a clear connect action', (tester) async {
      await pumpApp(tester, location: '/market');
      await _openSheet(tester);

      expect(_state('disconnected'), findsOneWidget);
      expect(find.text('Connect a wallet'), findsOneWidget);
      expect(find.text('Connect Demo wallet'), findsOneWidget);
    });

    testWidgets('connecting, then connected with a short address, Testnet '
        'and Disconnect', (tester) async {
      final wallet = MockWallet();
      await pumpApp(tester, location: '/market', wallet: wallet);
      await _openSheet(tester);

      await tester.tap(find.text('Connect Demo wallet'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_state('connecting'), findsOneWidget);
      expect(find.text('Waiting for Demo wallet…'), findsOneWidget);

      await advance(tester, const Duration(milliseconds: 600));
      expect(_state('connected'), findsOneWidget);
      expect(find.text('Testnet'), findsOneWidget);
      final address = wallet.address!;
      final short =
          '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
      // In the sheet and in the app bar chip.
      expect(find.text(short), findsNWidgets(2));

      await tester.tap(find.text('Disconnect'));
      await advance(tester, const Duration(milliseconds: 300));
      expect(_state('disconnected'), findsOneWidget);
      expect(wallet.address, isNull);
      expect(find.text('Connect wallet'), findsOneWidget);
    });

    testWidgets('rejected: recoverable, no crash', (tester) async {
      final wallet = MockWallet()..rejectConnection = true;
      await pumpApp(tester, location: '/market', wallet: wallet);
      await _openSheet(tester);

      await tester.tap(find.text('Connect Demo wallet'));
      await advance(tester, const Duration(milliseconds: 700));
      expect(_state('rejected'), findsOneWidget);
      expect(find.text('Connection cancelled'), findsOneWidget);
      expect(tester.takeException(), isNull);

      wallet.rejectConnection = false;
      await tester.tap(find.text('Try again'));
      await advance(tester, const Duration(milliseconds: 700));
      expect(_state('connected'), findsOneWidget);
    });

    testWidgets('wrong network: a clear error, then recovery', (tester) async {
      final wallet = MockWallet()
        ..walletNetwork = Network.PUBLIC.networkPassphrase;
      await pumpApp(tester, location: '/market', wallet: wallet);
      await _openSheet(tester);

      await tester.tap(find.text('Connect Demo wallet'));
      await advance(tester, const Duration(milliseconds: 700));
      expect(_state('wrong-network'), findsOneWidget);
      expect(find.text('Switch your wallet to Testnet'), findsOneWidget);
      // Never shown as connected on the wrong network.
      expect(wallet.address, isNull);

      wallet.walletNetwork = stellarTestnetPassphrase;
      await tester.tap(find.text('Try again'));
      await advance(tester, const Duration(milliseconds: 700));
      expect(_state('connected'), findsOneWidget);
    });

    testWidgets('not installed: says so and offers to install', (
      tester,
    ) async {
      final wallet = MockWallet()..failure = const WalletNotInstalled();
      await pumpApp(tester, location: '/market', wallet: wallet);
      await _openSheet(tester);

      await tester.tap(find.text('Connect Demo wallet'));
      await advance(tester, const Duration(milliseconds: 700));
      expect(_state('not-installed'), findsOneWidget);
      expect(find.text('Demo wallet not found'), findsOneWidget);
    });

    testWidgets('a connected chip opens the sheet to disconnect', (
      tester,
    ) async {
      final wallet = MockWallet();
      await pumpApp(tester, location: '/market', wallet: wallet);
      await _openSheet(tester);
      await tester.tap(find.text('Connect Demo wallet'));
      await advance(tester, const Duration(milliseconds: 700));
      Navigator.of(tester.element(_state('connected'))).pop();
      await advance(tester, const Duration(milliseconds: 400));

      final address = wallet.address!;
      await tester.tap(
        find.text(
          '${address.substring(0, 4)}…${address.substring(address.length - 4)}',
        ),
      );
      await advance(tester, const Duration(milliseconds: 400));
      expect(_state('connected'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('on a phone the sheet fits without overflow', (tester) async {
      await pumpApp(tester, location: '/market', size: const Size(360, 800));
      await tester.tap(find.text('Connect'));
      await advance(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Connect Demo wallet'));
      await advance(tester, const Duration(milliseconds: 700));
      expect(_state('connected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('WalletPanel (presentational)', () {
    Future<void> pumpPanel(WidgetTester tester, WalletPanel panel) async {
      Puls3Fonts.useGoogleFonts = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: Puls3Theme.dark(),
          home: Scaffold(body: panel),
        ),
      );
    }

    testWidgets('not installed shows an install action when there is a page', (
      tester,
    ) async {
      var installs = 0;
      await pumpPanel(
        tester,
        WalletPanel(
          status: WalletStatus.error,
          walletName: 'Freighter',
          error: const WalletNotInstalled(),
          onConnect: () {},
          onDisconnect: () {},
          onInstall: () => installs++,
        ),
      );
      expect(find.text('Freighter not found'), findsOneWidget);
      await tester.tap(find.text('Install Freighter'));
      expect(installs, 1);
    });

    testWidgets('a locked wallet asks to unlock', (tester) async {
      await pumpPanel(
        tester,
        WalletPanel(
          status: WalletStatus.error,
          walletName: 'Freighter',
          error: const WalletUnavailable(),
          onConnect: () {},
          onDisconnect: () {},
        ),
      );
      expect(find.text('Freighter is locked'), findsOneWidget);
    });
  });

  group('WalletController', () {
    test('tryConnect keeps a failure as state instead of throwing', () async {
      final controller = WalletController(
        MockWallet(connectDelay: Duration.zero)..rejectConnection = true,
      );
      expect(await controller.tryConnect(), isFalse);
      expect(controller.status, WalletStatus.error);
      expect(controller.lastError, isA<WalletSignatureRejected>());
    });

    test('connect still throws for flows that map errors themselves', () {
      final controller = WalletController(
        MockWallet(connectDelay: Duration.zero)
          ..walletNetwork = Network.PUBLIC.networkPassphrase,
      );
      expect(controller.connect(), throwsA(isA<WalletWrongNetwork>()));
    });
  });
}
