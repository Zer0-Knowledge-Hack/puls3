import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart' as api;
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';
import 'package:puls3_flutter/src/cli/cli_session_dialog.dart';
import 'package:puls3_flutter/src/cli/cli_session_issuer.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/hire/fake_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/l10n/locale_controller.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';
import 'package:puls3_flutter/src/screens/wallet_sheet.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/organisms/wallet_panel.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

const _token = 'sajrt:AAAA:BBBB:CCCC';
const _wallet = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _otherWallet = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

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

api.CliSession _cliSession(
  String id, {
  int createdHour = 10,
  int usedHour = 11,
  int expiresHour = 13,
}) => api.CliSession(
  id: id,
  createdAt: DateTime.utc(2026, 11, 17, createdHour),
  lastUsedAt: DateTime.utc(2026, 11, 17, usedHour),
  expiresAt: DateTime.utc(2026, 11, 20, expiresHour),
);

final class _FakeCliSessions implements CliSessionIssuer {
  _FakeCliSessions(this.sessions);

  final List<api.CliSession> sessions;
  final revoked = <String>[];
  Object? listFailure;
  Object? revokeFailure;

  @override
  Future<api.CliSessionGrant> issue(String wallet) async => _grant();

  @override
  Future<List<api.CliSession>> list(String wallet) async {
    final failure = listFailure;
    if (failure != null) throw failure;
    return List.of(sessions);
  }

  @override
  Future<bool> revoke(String wallet, String id) async {
    final failure = revokeFailure;
    if (failure != null) throw failure;
    revoked.add(id);
    sessions.removeWhere((session) => session.id == id);
    return true;
  }
}

final class _DelayedCliSessions implements CliSessionIssuer {
  final _list = Completer<List<api.CliSession>>();

  @override
  Future<api.CliSessionGrant> issue(String wallet) async => _grant();

  @override
  Future<List<api.CliSession>> list(String wallet) => _list.future;

  @override
  Future<bool> revoke(String wallet, String id) async => false;

  void complete(List<api.CliSession> sessions) => _list.complete(sessions);
}

Future<WalletController> _pumpWalletSheet(
  WidgetTester tester, {
  required CliSessionIssuer? cli,
  bool connected = true,
}) async {
  final wallet = MockWallet(signDelay: Duration.zero);
  if (connected) wallet.switchAccount();
  final controller = WalletController(wallet);
  await tester.pumpWidget(
    AppScope(
      catalog: AgentCatalog(const InMemoryAgentRepository([])),
      wallet: controller,
      deployGateway: FakeDeployGateway(),
      studioGateway: FakeStudioGateway(),
      hireGateway: FakeHireGateway(delay: Duration.zero),
      hireFlowStore: MemoryHireFlowStore(),
      locale: LocaleController(
        store: MemoryLocaleStore(),
        initial: const Locale('en'),
      ),
      cliSessions: cli,
      child: MaterialApp(
        theme: Puls3Theme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: WalletSheet()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return controller;
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
        list: () async => [],
        revoke: (_) async => false,
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

    test('list and revoke refuse a session of another wallet', () async {
      final store = InMemorySessionWalletStore();
      await store.write(_wallet);
      var lists = 0;
      var revokes = 0;
      final issuer = ServerCliSessionIssuer(
        create: () async => _grant(),
        list: () async {
          lists++;
          return [_cliSession('cli-1')];
        },
        revoke: (_) async {
          revokes++;
          return true;
        },
        session: WalletSession(
          createChallenge: (wallet) async =>
              throw StateError('no sign-in expected'),
          verifyChallenge: (id, wallet, signed) async =>
              throw StateError('no sign-in expected'),
          isAuthenticated: () => true,
          storeSession: (_) async {},
          walletStore: store,
        ),
        wallet: MockWallet(),
      );

      expect(await issuer.list(_otherWallet), isEmpty);
      expect(await issuer.revoke(_otherWallet, 'cli-1'), isFalse);
      expect(lists, 0);
      expect(revokes, 0);
    });
  });

  group('WalletSheet CLI sessions (#344)', () {
    testWidgets('lists sessions with their dates, without ids or tokens', (
      tester,
    ) async {
      final cli = _FakeCliSessions([
        _cliSession('cli-1'),
        _cliSession('cli-2', createdHour: 12, usedHour: 12, expiresHour: 15),
      ]);
      await _pumpWalletSheet(tester, cli: cli);

      expect(find.text('CLI sessions'), findsOneWidget);
      expect(find.textContaining('Created 2026-11-17 10:00'), findsOneWidget);
      expect(find.textContaining('10:00 UTC'), findsOneWidget);
      expect(
        find.textContaining('Last used 2026-11-17 11:00'),
        findsOneWidget,
      );
      expect(find.textContaining('Ends 2026-11-20 13:00'), findsOneWidget);
      expect(find.text('Revoke'), findsNWidgets(2));
      expect(find.textContaining('10 minutes'), findsOneWidget);

      expect(find.text('cli-1'), findsNothing);
      expect(find.text('cli-2'), findsNothing);
      expect(find.textContaining('sajrt:'), findsNothing);
    });

    testWidgets('revoking asks for confirmation and keeps the app signed in', (
      tester,
    ) async {
      final cli = _FakeCliSessions([
        _cliSession('cli-1'),
        _cliSession('cli-2'),
      ]);
      final controller = await _pumpWalletSheet(tester, cli: cli);
      await tester.runAsync(() => controller.signTransaction('AAAA'));
      await tester.pump();
      expect(controller.status, WalletStatus.signed);

      final revoke = find.byKey(
        const ValueKey('cli-session-revoke-cli-1'),
      );
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pumpAndSettle();

      expect(find.text('Revoke CLI session?'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('cli-session-revoke-confirm')),
      );
      await tester.pumpAndSettle();

      expect(cli.revoked, ['cli-1']);
      expect(find.byKey(const ValueKey('cli-session-cli-1')), findsNothing);
      expect(find.byKey(const ValueKey('cli-session-cli-2')), findsOneWidget);
      expect(controller.status, WalletStatus.signed);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('a session of another wallet shows no sessions', (
      tester,
    ) async {
      final store = InMemorySessionWalletStore();
      await store.write(_otherWallet);
      var lists = 0;
      var revokes = 0;
      final issuer = ServerCliSessionIssuer(
        create: () async => _grant(),
        list: () async {
          lists++;
          return [_cliSession('cli-1')];
        },
        revoke: (_) async {
          revokes++;
          return true;
        },
        session: WalletSession(
          createChallenge: (wallet) async =>
              throw StateError('no sign-in expected'),
          verifyChallenge: (id, wallet, signed) async =>
              throw StateError('no sign-in expected'),
          isAuthenticated: () => true,
          storeSession: (_) async {},
          walletStore: store,
        ),
        wallet: MockWallet(),
      );

      await _pumpWalletSheet(tester, cli: issuer);

      expect(lists, 0);
      expect(revokes, 0);
      expect(find.text('CLI sessions'), findsNothing);
      expect(
        find.byKey(const ValueKey('wallet-copy-cli-session')),
        findsOneWidget,
      );
    });

    testWidgets('with no sessions it shows only the copy action', (
      tester,
    ) async {
      final cli = _FakeCliSessions([]);
      await _pumpWalletSheet(tester, cli: cli);

      expect(
        find.byKey(const ValueKey('wallet-copy-cli-session')),
        findsOneWidget,
      );
      expect(find.text('CLI sessions'), findsNothing);
    });

    testWidgets('a disconnected wallet shows neither', (tester) async {
      final cli = _FakeCliSessions([_cliSession('cli-1')]);
      await _pumpWalletSheet(tester, cli: cli, connected: false);

      expect(
        find.byKey(const ValueKey('wallet-copy-cli-session')),
        findsNothing,
      );
      expect(find.text('CLI sessions'), findsNothing);
      expect(
        find.byKey(const ValueKey('wallet-state-disconnected')),
        findsOneWidget,
      );
    });

    testWidgets('an unreachable server keeps the copy action and says so', (
      tester,
    ) async {
      final cli = _FakeCliSessions([])..listFailure = StateError('down');
      await _pumpWalletSheet(tester, cli: cli);

      expect(
        find.byKey(const ValueKey('wallet-copy-cli-session')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cli-sessions-error')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Could not load CLI sessions'),
        findsOneWidget,
      );
    });

    testWidgets('a list from the old address never lands', (tester) async {
      final cli = _DelayedCliSessions();
      final controller = await _pumpWalletSheet(tester, cli: cli);

      await controller.disconnect();
      await tester.pump();
      cli.complete([_cliSession('cli-old')]);
      await tester.pump();

      expect(find.text('CLI sessions'), findsNothing);
      expect(find.byKey(const ValueKey('cli-session-cli-old')), findsNothing);
    });

    testWidgets('a 401 on revoke asks for a new session', (tester) async {
      final cli = _FakeCliSessions([_cliSession('cli-1')])
        ..revokeFailure = api.ServerpodClientUnauthorized();
      await _pumpWalletSheet(tester, cli: cli);

      final revoke = find.byKey(
        const ValueKey('cli-session-revoke-cli-1'),
      );
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('cli-session-revoke-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Your app session ended'), findsOneWidget);
      expect(find.textContaining('server did not answer'), findsNothing);
    });
  });
}
