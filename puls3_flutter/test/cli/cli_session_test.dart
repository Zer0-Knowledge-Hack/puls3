import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart' as api;
import 'package:puls3_flutter/src/cli/cli_session_dialog.dart';
import 'package:puls3_flutter/src/cli/cli_session_issuer.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/ui/organisms/wallet_panel.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

const _token = 'sajrt:AAAA:BBBB:CCCC';
const _wallet = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

api.CliSessionGrant _grant() => api.CliSessionGrant(
  id: 'session-1',
  refreshToken: _token,
  expiresAt: DateTime.utc(2026, 11, 14, 12),
);

/// Opens the dialog from a button, as the wallet sheet does.
Future<void> _open(
  WidgetTester tester,
  Future<api.CliSessionGrant> Function() issue,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                unawaited(showCliSessionDialog(context, issue: issue)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('CliSessionDialog', () {
    late List<String?> clipboard;

    setUp(() {
      clipboard = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add((call.arguments as Map)['text'] as String?);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('shows the token once, with a warning and a copy button', (
      tester,
    ) async {
      var issued = 0;
      await _open(tester, () async {
        issued++;
        return _grant();
      });

      expect(issued, 1);
      expect(find.byKey(const ValueKey('cli-session-token')), findsOneWidget);
      expect(find.text(_token), findsOneWidget);
      expect(find.textContaining('Treat it like a password'), findsOneWidget);
      expect(find.textContaining('2026-11-14T12:00:00.000Z'), findsOneWidget);
      expect(find.textContaining('PULS3_REFRESH_TOKEN'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cli-session-copy')));
      await tester.pumpAndSettle();

      expect(clipboard, [_token]);
      expect(find.text('Copied'), findsOneWidget);
      // Rebuilds do not create a second session.
      expect(issued, 1);
    });

    testWidgets('closing forgets it: reopening issues a new one', (
      tester,
    ) async {
      var issued = 0;
      await _open(tester, () async {
        issued++;
        return _grant();
      });
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text(_token), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(issued, 2);
    });

    testWidgets('the token is never logged', (tester) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add('$message');
      try {
        await _open(tester, () async => _grant());
        await tester.tap(find.byKey(const ValueKey('cli-session-copy')));
        await tester.pumpAndSettle();
      } finally {
        // Restored inside the test: Flutter checks it before tearDown.
        debugPrint = original;
      }

      expect(logs.where((line) => line.contains(_token)), isEmpty);
    });

    testWidgets('a failure shows an error and no token', (tester) async {
      await _open(tester, () async => throw StateError('server down'));

      expect(find.byKey(const ValueKey('cli-session-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('cli-session-token')), findsNothing);
      expect(find.textContaining('server down'), findsNothing);
    });
  });

  group('WalletPanel', () {
    Future<void> pumpPanel(WidgetTester tester, VoidCallback? onCopy) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WalletPanel(
                status: WalletStatus.connected,
                walletName: 'Freighter',
                address: _wallet,
                onConnect: () {},
                onDisconnect: () {},
                onCopyCliSession: onCopy,
              ),
            ),
          ),
        );

    testWidgets('offers the CLI session when the app has a server session', (
      tester,
    ) async {
      var taps = 0;
      await pumpPanel(tester, () => taps++);

      await tester.tap(find.byKey(const ValueKey('wallet-copy-cli-session')));
      expect(taps, 1);
    });

    testWidgets('hides it otherwise', (tester) async {
      await pumpPanel(tester, null);

      expect(
        find.byKey(const ValueKey('wallet-copy-cli-session')),
        findsNothing,
      );
    });
  });

  group('ServerCliSessionIssuer', () {
    test('uses the existing session and never signs in again', () async {
      final store = InMemorySessionWalletStore();
      await store.write(_wallet);
      var challenges = 0;
      var created = 0;
      final issuer = ServerCliSessionIssuer(
        create: () async {
          created++;
          return _grant();
        },
        session: WalletSession(
          createChallenge: (wallet) async {
            challenges++;
            throw StateError('no sign-in expected');
          },
          verifyChallenge: (id, wallet, signed) async =>
              throw StateError('no sign-in expected'),
          isAuthenticated: () => true,
          storeSession: (_) async {},
          walletStore: store,
        ),
        wallet: MockWallet(),
      );

      final grant = await issuer.issue(_wallet);

      expect(grant.refreshToken, _token);
      expect(created, 1);
      expect(challenges, 0);
    });
  });
}
