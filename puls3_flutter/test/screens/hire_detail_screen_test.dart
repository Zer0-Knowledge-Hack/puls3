import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/screens/hire_detail_screen.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

import '../helpers.dart';
import 'hire_sheet_test.dart' show TestWallet;

const _consumer = 'GUSER123';
const _poll = Duration(seconds: 1);
const _fundHash =
    'fa11ce0000000000000000000000000000000000000000000000000000000001';

HireProgress _hire({
  String? status = 'funded',
  String? runtimeStatus,
  String? result,
  String? failureReason,
  String? rejectedFrom,
  String? paymentTransaction = _fundHash,
  String? paymentExplorerUrl,
}) => HireProgress(
  hireId: 3,
  agentName: 'Support Relay',
  priceUsdcStroops: 10000000,
  input: 'Answer ticket 42',
  status: status,
  runtimeStatus: runtimeStatus,
  result: result,
  failureReason: failureReason,
  rejectedFrom: rejectedFrom,
  paymentTransaction: paymentTransaction,
  paymentExplorerUrl: paymentExplorerUrl,
);

/// Answers `getHire` from a script: each read takes the next answer, and
/// the last one repeats. An answer is a [HireProgress] or an exception.
class _ProgressGateway implements HireGateway {
  _ProgressGateway(this.answers);

  final List<Object> answers;
  final reads = <(int, String)>[];
  final signIns = <String>[];

  @override
  bool get isDemo => false;

  @override
  Future<HireProgress> getHire(int hireId, String consumer) async {
    reads.add((hireId, consumer));
    final next = answers.length > 1 ? answers.removeAt(0) : answers.first;
    if (next is Exception) throw next;
    return next as HireProgress;
  }

  @override
  Future<void> ensureSignedIn(String wallet, ChallengeSigner sign) async {
    await sign(
      const SignInChallenge(
        transactionXdr: 'challenge',
        networkPassphrase: stellarTestnetPassphrase,
      ),
    );
    signIns.add(wallet);
  }

  @override
  Future<void> forgetSession() async {}

  @override
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) => throw UnimplementedError();

  @override
  Future<EscrowPreparation> prepareCreateJob(int hireId) =>
      throw UnimplementedError();

  @override
  Future<EscrowPreparation> prepareFund(int hireId) =>
      throw UnimplementedError();

  @override
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) => throw UnimplementedError();
}

final _opened = <Uri>[];
final _copied = <String>[];

Future<void> _pumpDetail(
  WidgetTester tester, {
  required HireGateway gateway,
  WalletPort? wallet,
  String id = '3',
}) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _opened.clear();
  _copied.clear();
  final router = GoRouter(
    initialLocation: '/hires/$id',
    routes: [
      GoRoute(
        path: '/hires/:id',
        builder: (_, state) => Scaffold(
          body: HireDetailScreen(
            hireId: state.pathParameters['id']!,
            pollInterval: _poll,
            openUrl: (url) async => _opened.add(url),
            copyText: (text) async => _copied.add(text),
          ),
        ),
      ),
      GoRoute(
        path: '/market',
        builder: (_, _) => const Scaffold(body: Text('market')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppScope(
      catalog: AgentCatalog(const InMemoryAgentRepository(testAgents)),
      wallet: WalletController(
        wallet ?? TestWallet(initialAddress: _consumer),
      ),
      deployGateway: FakeDeployGateway(),
      hireGateway: gateway,
      hireFlowStore: MemoryHireFlowStore(),
      child: MaterialApp.router(
        theme: Puls3Theme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder _status(String label) => find.descendant(
  of: find.byKey(const ValueKey('hire-detail-status')),
  matching: find.text(label),
);

void main() {
  testWidgets('follows a funded hire from queued to the result, then stops '
      'polling', (tester) async {
    final gateway = _ProgressGateway([
      _hire(runtimeStatus: 'queued'),
      _hire(runtimeStatus: 'running'),
      _hire(runtimeStatus: 'running', result: 'Ticket 42 answered.'),
      _hire(runtimeStatus: 'failed', failureReason: 'must not be read'),
    ]);
    await _pumpDetail(tester, gateway: gateway);

    expect(gateway.reads.first, (3, _consumer));
    expect(find.text('Hire #3'), findsOneWidget);
    expect(_status('Funded · Queued'), findsOneWidget);
    expect(find.text('Queued: the agent starts shortly.'), findsOneWidget);
    expect(find.text('Answer ticket 42'), findsOneWidget);
    expect(find.text('Held in escrow'), findsOneWidget);
    expect(find.byKey(const ValueKey('hire-detail-result')), findsNothing);

    await tester.pump(_poll);
    await tester.pump();
    expect(_status('Funded · Running'), findsOneWidget);
    expect(find.text('The agent is working on your task.'), findsOneWidget);

    await tester.pump(_poll);
    await tester.pump();
    expect(_status('Funded · Result ready'), findsOneWidget);
    expect(find.text('Ticket 42 answered.'), findsOneWidget);
    expect(gateway.reads, hasLength(3));

    // Still waiting for the agent's submit: it keeps polling.
    await tester.pump(_poll);
    await tester.pump();
    expect(gateway.reads, hasLength(4));
    expect(_status('Funded · Run failed'), findsOneWidget);

    // A failed run is final: no more reads.
    await tester.pump(_poll * 5);
    expect(gateway.reads, hasLength(4));
  });

  testWidgets('Copy copies the result; the payment opens on StellarExpert', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      gateway: _ProgressGateway([
        _hire(status: 'completed', result: 'Ticket 42 answered.'),
      ]),
    );

    await tester.tap(find.byKey(const ValueKey('hire-detail-copy')));
    await tester.pump();
    expect(_copied, ['Ticket 42 answered.']);
    expect(find.text('Result copied'), findsOneWidget);

    await tester.tap(find.text('View payment on StellarExpert'));
    await tester.pump();
    expect(_opened.single.toString(), endsWith('/tx/$_fundHash'));
  });

  testWidgets('prefers the explorer link the server built', (tester) async {
    await _pumpDetail(
      tester,
      gateway: _ProgressGateway([
        _hire(
          status: 'completed',
          paymentExplorerUrl: 'https://example.test/tx/1',
        ),
      ]),
    );
    await tester.tap(find.text('View payment on StellarExpert'));
    await tester.pump();
    expect(_opened.single.toString(), 'https://example.test/tx/1');
  });

  testWidgets('a failed run shows its reason and says the funds stay in the '
      'escrow', (tester) async {
    await _pumpDetail(
      tester,
      gateway: _ProgressGateway([
        _hire(runtimeStatus: 'failed', failureReason: 'The model timed out.'),
      ]),
    );
    expect(_status('Funded · Run failed'), findsOneWidget);
    expect(find.text('The model timed out.'), findsOneWidget);
    expect(
      find.textContaining('Your USDC stays in the escrow'),
      findsOneWidget,
    );
  });

  testWidgets('closed hires use the #10 names and stop polling', (
    tester,
  ) async {
    final cases = {
      _hire(status: 'completed'): 'Completed',
      _hire(status: 'submitted', result: 'done'): 'Submitted',
      _hire(status: 'rejected', rejectedFrom: 'funded'): 'Rejected',
      _hire(
        status: 'rejected',
        rejectedFrom: 'open',
        paymentTransaction: null,
      ): 'Cancelled',
      _hire(status: 'expired'): 'Expired',
      _hire(status: null, paymentTransaction: null): 'Awaiting payment',
    };
    for (final MapEntry(key: hire, value: label) in cases.entries) {
      final gateway = _ProgressGateway([hire]);
      await _pumpDetail(tester, gateway: gateway);
      expect(_status(label), findsOneWidget, reason: label);
      await tester.pump(_poll);
      await tester.pump();
      final polls = hire.stage.isFinal ? 1 : 2;
      expect(gateway.reads, hasLength(polls), reason: label);
    }
    // Unmount the last screen so its poll timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no payment yet: no explorer button, nothing held', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      gateway: _ProgressGateway([
        _hire(status: 'open', paymentTransaction: null),
      ]),
    );
    expect(find.text('View payment on StellarExpert'), findsNothing);
    expect(find.text('Held in escrow'), findsNothing);
    expect(
      find.text('Waiting for the payment to confirm on Stellar.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unknown or foreign hire is "Hire not found"', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      gateway: _ProgressGateway([const HireNotFound()]),
    );
    expect(find.text('Hire not found'), findsOneWidget);

    await tester.tap(find.text('Back to Marketplace'));
    await tester.pumpAndSettle();
    expect(find.text('market'), findsOneWidget);
  });

  testWidgets('an id that is not a hire id asks nothing', (tester) async {
    final gateway = _ProgressGateway([_hire()]);
    await _pumpDetail(tester, gateway: gateway, id: 'abc');
    expect(find.text('Hire not found'), findsOneWidget);
    expect(gateway.reads, isEmpty);
  });

  testWidgets('without a wallet it asks to connect, then loads the hire', (
    tester,
  ) async {
    final gateway = _ProgressGateway([_hire(status: 'completed')]);
    await _pumpDetail(tester, gateway: gateway, wallet: TestWallet());
    expect(find.text('Connect your wallet'), findsOneWidget);
    expect(gateway.reads, isEmpty);

    await tester.tap(find.text('Connect wallet'));
    await tester.pump();
    await tester.pump();
    expect(gateway.reads.single.$2, 'GTESTUSERWALLET1234567890');
    expect(_status('Completed'), findsOneWidget);
  });

  testWidgets('no session: the wallet signs in, then the hire loads', (
    tester,
  ) async {
    final wallet = TestWallet(initialAddress: _consumer);
    final gateway = _ProgressGateway([
      const HireNotSignedIn(),
      _hire(status: 'completed'),
    ]);
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);
    expect(find.text('Sign in to see this hire'), findsOneWidget);

    await tester.tap(find.text('Sign in with wallet'));
    await tester.pump();
    await tester.pump();

    expect(wallet.challenges, ['challenge']);
    expect(gateway.signIns, [_consumer]);
    expect(_status('Completed'), findsOneWidget);
  });

  testWidgets('a declined sign-in says so and can be retried', (tester) async {
    final wallet = TestWallet(initialAddress: _consumer)
      ..failNextChallenge = const WalletSignatureRejected();
    final gateway = _ProgressGateway([
      const HireNotSignedIn(),
      _hire(status: 'completed'),
    ]);
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);

    await tester.tap(find.text('Sign in with wallet'));
    await tester.pump();
    expect(
      find.text('You cancelled the sign-in in your wallet.'),
      findsOneWidget,
    );
    expect(gateway.signIns, isEmpty);

    await tester.tap(find.text('Sign in with wallet'));
    await tester.pump();
    await tester.pump();
    expect(_status('Completed'), findsOneWidget);
  });

  testWidgets('a failed first load shows Retry', (tester) async {
    final gateway = _ProgressGateway([
      const HireBackendUnavailable('Stellar Testnet could not be reached.'),
      _hire(status: 'completed'),
    ]);
    await _pumpDetail(tester, gateway: gateway);
    expect(find.text('Could not load this hire'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(_status('Completed'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the last status with a Retry banner', (
    tester,
  ) async {
    final gateway = _ProgressGateway([
      _hire(runtimeStatus: 'running'),
      const HireBackendUnavailable('Stellar Testnet could not be reached.'),
      _hire(runtimeStatus: 'running', result: 'Ticket 42 answered.'),
    ]);
    await _pumpDetail(tester, gateway: gateway);

    await tester.pump(_poll);
    await tester.pump();
    expect(_status('Funded · Running'), findsOneWidget);
    expect(find.text('Showing the last known status'), findsOneWidget);

    // A failed refresh stops polling until Retry.
    await tester.pump(_poll * 3);
    expect(gateway.reads, hasLength(2));

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Showing the last known status'), findsNothing);
    expect(find.text('Ticket 42 answered.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the app routes /hires/:id to the hire detail', (tester) async {
    await pumpApp(tester, location: '/hires/3');
    // The default wallet is not connected yet.
    expect(find.text('Connect your wallet'), findsOneWidget);
  });
}
