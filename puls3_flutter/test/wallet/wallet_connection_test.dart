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
      expect(find.text('Wrong network'), findsOneWidget);
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

    testWidgets('a connector that failed to load never asks to install', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        WalletPanel(
          status: WalletStatus.error,
          walletName: 'Freighter',
          error: const WalletConnectorUnavailable(),
          onConnect: () {},
          onDisconnect: () {},
          onInstall: () {},
        ),
      );
      expect(find.text('Could not load the wallet connector'), findsOneWidget);
      expect(find.textContaining('ad blocker'), findsOneWidget);
      expect(find.text('Install Freighter'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
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
      expect(controller.status, WalletStatus.rejected);
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

  group('signing (WalletController + MockWallet)', () {
    const unsignedXdr = 'AAAA-server-prepared-envelope';

    Future<WalletController> connected(MockWallet wallet) async {
      final controller = WalletController(wallet);
      expect(await controller.tryConnect(), isTrue);
      expect(controller.status, WalletStatus.connected);
      return controller;
    }

    MockWallet fastWallet() => MockWallet(
      connectDelay: Duration.zero,
      signDelay: const Duration(milliseconds: 10),
    );

    test(
      'signing, then signed: the XDR reaches the wallet unchanged',
      () async {
        final controller = await connected(fastWallet());
        final signing = controller.signTransaction(unsignedXdr);
        expect(controller.status, WalletStatus.signing);

        final signed = await signing;
        // MockWallet marks exactly what it was given.
        expect(signed, '${MockWallet.signedPrefix}$unsignedXdr');
        expect(controller.status, WalletStatus.signed);
      },
    );

    test('a rejected signature is recoverable', () async {
      final wallet = fastWallet();
      final controller = await connected(wallet);
      wallet.rejectSignatures = true;

      await expectLater(
        controller.signTransaction(unsignedXdr),
        throwsA(isA<WalletSignatureRejected>()),
      );
      expect(controller.status, WalletStatus.rejected);
      // Still connected: dismissing returns to the account.
      expect(await controller.tryConnect(), isTrue);
      expect(controller.status, WalletStatus.connected);
    });

    test('a signing error is a typed error state', () async {
      final wallet = fastWallet();
      final controller = await connected(wallet);
      wallet.failure = const WalletUnavailable();

      await expectLater(
        controller.signTransaction(unsignedXdr),
        throwsA(isA<WalletUnavailable>()),
      );
      expect(controller.status, WalletStatus.error);
    });

    test('a wrong network blocks signing before any prompt', () async {
      final wallet = fastWallet();
      final controller = await connected(wallet);
      wallet.walletNetwork = Network.PUBLIC.networkPassphrase;

      await expectLater(
        controller.signTransaction(unsignedXdr),
        throwsA(isA<WalletWrongNetwork>()),
      );
      expect(controller.status, WalletStatus.wrongNetwork);
      // The session is forgotten: the user must reconnect on Testnet.
      expect(controller.address, isNull);
    });

    test('disconnect returns to disconnected', () async {
      final controller = await connected(fastWallet());
      await controller.signTransaction(unsignedXdr);
      await controller.disconnect();
      expect(controller.status, WalletStatus.disconnected);
      expect(controller.address, isNull);
    });
  });

  group('WalletPanel signing states', () {
    Future<void> pumpPanel(WidgetTester tester, WalletPanel panel) async {
      Puls3Fonts.useGoogleFonts = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: Puls3Theme.dark(),
          home: Scaffold(body: panel),
        ),
      );
    }

    const address = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

    testWidgets('signing waits for the wallet', (tester) async {
      await pumpPanel(
        tester,
        WalletPanel(
          status: WalletStatus.signing,
          walletName: 'Freighter',
          address: address,
          onConnect: () {},
          onDisconnect: () {},
        ),
      );
      expect(_state('signing'), findsOneWidget);
      expect(find.text('Waiting for wallet confirmation…'), findsOneWidget);
    });

    testWidgets('signed keeps the account and says it was signed', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        WalletPanel(
          status: WalletStatus.signed,
          walletName: 'Freighter',
          address: address,
          onConnect: () {},
          onDisconnect: () {},
        ),
      );
      expect(_state('signed'), findsOneWidget);
      expect(find.text('Transaction signed'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('a rejected signature says so and offers a retry', (
      tester,
    ) async {
      var retries = 0;
      await pumpPanel(
        tester,
        WalletPanel(
          status: WalletStatus.rejected,
          walletName: 'Freighter',
          address: address,
          error: const WalletSignatureRejected(),
          onConnect: () => retries++,
          onDisconnect: () {},
        ),
      );
      expect(find.text('Signature rejected'), findsOneWidget);
      expect(
        find.text(
          'You rejected the transaction in Freighter. Nothing was sent.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('any other failure is a recoverable error', (tester) async {
      await pumpPanel(
        tester,
        WalletPanel(
          status: WalletStatus.error,
          walletName: 'Freighter',
          error: const WalletAccountChanged(),
          onConnect: () {},
          onDisconnect: () {},
        ),
      );
      expect(find.text('Account changed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('wallet prompts that never settle (#113 review)', () {
    test('a connect that never answers times out instead of hanging', () async {
      // The prompt answers after 1 s; the limit is 20 ms.
      final controller = WalletController(
        MockWallet(connectDelay: const Duration(seconds: 1)),
        connectTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(controller.connect(), throwsA(isA<WalletTimedOut>()));
      expect(controller.status, WalletStatus.error);
      expect(controller.isConnecting, isFalse);
    });

    test('disconnecting during a pending connect stays disconnected', () async {
      final wallet = MockWallet(
        connectDelay: const Duration(milliseconds: 20),
      );
      final controller = WalletController(wallet);
      final connecting = controller.connect();
      expect(controller.status, WalletStatus.connecting);

      await controller.disconnect();
      await expectLater(connecting, throwsA(isA<WalletException>()));
      expect(wallet.address, isNull);
      expect(controller.status, WalletStatus.disconnected);
    });

    test('an account switch while signing forgets the session', () async {
      final wallet = MockWallet(
        connectDelay: Duration.zero,
        signDelay: Duration.zero,
      );
      final controller = WalletController(wallet);
      await controller.connect();
      wallet.failure = const WalletAccountChanged();

      await expectLater(
        controller.signTransaction('AAAA-unsigned'),
        throwsA(isA<WalletAccountChanged>()),
      );
      expect(controller.status, WalletStatus.error);
      expect(controller.lastError, isA<WalletAccountChanged>());
      // The next attempt must connect again.
      expect(controller.address, isNull);
    });

    testWidgets('a timed-out prompt says so and offers a retry', (
      tester,
    ) async {
      Puls3Fonts.useGoogleFonts = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: Puls3Theme.dark(),
          home: Scaffold(
            body: WalletPanel(
              status: WalletStatus.error,
              walletName: 'Freighter',
              error: const WalletTimedOut(),
              onConnect: () {},
              onDisconnect: () {},
            ),
          ),
        ),
      );
      expect(_state('timed-out'), findsOneWidget);
      expect(find.text('No answer from Freighter'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
