import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/l10n/locale_controller.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/screens/hire_detail_screen.dart';
import 'package:puls3_flutter/src/screens/rate_hire_sheet.dart';
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

final _now = DateTime.utc(2026, 10, 26, 12);
const _decisionHash =
    'dec1510000000000000000000000000000000000000000000000000000000001';
const _feedbackHash =
    'fee0000000000000000000000000000000000000000000000000000000000001';

HireProgress _hire({
  String? status = 'funded',
  String? runtimeStatus,
  String? result,
  String? failureReason,
  String? rejectedFrom,
  String? paymentTransaction = _fundHash,
  String? paymentExplorerUrl,
  DateTime? approvalDeadline,
  String? decisionTransaction,
  String? decisionExplorerUrl,
  String? feedbackTransaction,
  String? feedbackState,
  String? feedbackErrorCode,
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
  approvalDeadline: approvalDeadline,
  decisionTransaction: decisionTransaction,
  decisionExplorerUrl: decisionExplorerUrl,
  feedbackTransaction: feedbackTransaction,
  feedbackState: feedbackState,
  feedbackErrorCode: feedbackErrorCode,
);

/// Answers `getHire` from a script: each read takes the next answer, and
/// the last one repeats. An answer is a [HireProgress] or an exception.
class _ProgressGateway implements HireGateway {
  _ProgressGateway(this.answers, {this.isDemo = false, this.failSubmit});

  final List<Object> answers;
  final reads = <(int, String)>[];
  final signIns = <String>[];
  final prepared = <(String, String)>[];
  final submitted = <(int, String, String)>[];
  HireGatewayException? failSubmit;

  /// `prepareFeedback` calls: hire, score, comment.
  final ratings = <(int, int, String)>[];

  /// `submitFeedback` calls: hire, signed envelope.
  final relayedRatings = <(int, String)>[];

  /// When set, the next `prepareFeedback` fails with it once.
  HireGatewayException? failFeedback;

  @override
  final bool isDemo;

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
  Future<void> checkFunds(String consumer, int priceUsdcStroops) async {}

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
  Future<EscrowPreparation> prepareComplete(int hireId) async {
    prepared.add(('complete', ''));
    return EscrowPreparation(
      preparationId: 'prep-complete',
      purpose: 'complete',
      unsignedTransaction: 'AAAA-complete',
    );
  }

  @override
  Future<EscrowPreparation> prepareReject(int hireId, String reason) async {
    prepared.add(('reject', reason));
    return EscrowPreparation(
      preparationId: 'prep-reject',
      purpose: 'reject',
      unsignedTransaction: 'AAAA-reject',
    );
  }

  @override
  Future<EscrowPreparation> prepareFeedback(
    int hireId,
    int score,
    String comment,
  ) async {
    final failure = failFeedback;
    if (failure != null) {
      failFeedback = null;
      throw failure;
    }
    ratings.add((hireId, score, comment));
    return const EscrowPreparation(
      preparationId: 'prep-feedback',
      purpose: 'giveFeedback',
      unsignedTransaction: 'AAAA-feedback',
    );
  }

  @override
  Future<EscrowSubmission> submitFeedback(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) async {
    relayedRatings.add((hireId, signedTransaction));
    return const EscrowSubmission(
      transactionHash: _feedbackHash,
      state: 'submitted',
    );
  }

  @override
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) async {
    final failure = failSubmit;
    if (failure != null) {
      failSubmit = null;
      throw failure;
    }
    submitted.add((hireId, preparation.purpose, signedTransaction));
    return EscrowSubmission(
      transactionHash:
          'dec1510000000000000000000000000000000000000000000000000000000001',
      state: 'submitted',
      explorerUrl:
          'https://stellar.expert/explorer/testnet/tx/dec1510000000000000000000000000000000000000000000000000000000001',
    );
  }
}

final _opened = <Uri>[];
final _copied = <String>[];

Future<void> _pumpDetail(
  WidgetTester tester, {
  required HireGateway gateway,
  WalletPort? wallet,
  String id = '3',
  DateTime Function()? now,
  Widget Function()? page,
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
          body:
              page?.call() ??
              HireDetailScreen(
                hireId: state.pathParameters['id']!,
                pollInterval: _poll,
                openUrl: (url) async => _opened.add(url),
                copyText: (text) async => _copied.add(text),
                now: now ?? () => _now,
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
      studioGateway: FakeStudioGateway(),
      hireGateway: gateway,
      hireFlowStore: MemoryHireFlowStore(),
      locale: LocaleController(
        store: MemoryLocaleStore(),
        initial: const Locale('en'),
      ),
      child: MaterialApp.router(
        theme: Puls3Theme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    expect(find.byKey(const ValueKey('hire-detail-reject')), findsOneWidget);

    // A failed run keeps polling until the client rejects.
    await tester.pump(_poll);
    await tester.pump();
    expect(gateway.reads, hasLength(5));
    await tester.pumpWidget(const SizedBox());
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

  testWidgets('submitted hire: Approve signs complete and shows Completed', (
    tester,
  ) async {
    final wallet = TestWallet(initialAddress: _consumer);
    final gateway = _ProgressGateway([
      _hire(
        status: 'submitted',
        result: 'Ticket 42 answered.',
        approvalDeadline: _now.add(const Duration(hours: 1)),
      ),
      _hire(
        status: 'completed',
        result: 'Ticket 42 answered.',
        decisionTransaction: _decisionHash,
      ),
    ]);
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);

    expect(_status('Submitted'), findsOneWidget);
    expect(find.byKey(const ValueKey('hire-detail-approve')), findsOneWidget);
    expect(find.byKey(const ValueKey('hire-detail-reject')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hire-detail-approve')));
    await tester.pump();
    await tester.pump();

    expect(wallet.signed, ['AAAA-complete']);
    expect(gateway.prepared, [('complete', '')]);
    expect(gateway.submitted.single.$2, 'complete');
    expect(gateway.submitted.single.$3, 'signed:AAAA-complete');
    expect(_status('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('hire-detail-approve')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('hire-detail-decision')));
    await tester.pump();
    expect(_opened.single.toString(), endsWith('/tx/$_decisionHash'));
  });

  testWidgets('Reject and refund on submitted shows Rejected with the tx', (
    tester,
  ) async {
    final wallet = TestWallet(initialAddress: _consumer);
    final gateway = _ProgressGateway([
      _hire(
        status: 'submitted',
        result: 'Ticket 42 answered.',
        approvalDeadline: _now.add(const Duration(hours: 1)),
      ),
      _hire(
        status: 'rejected',
        rejectedFrom: 'submitted',
        result: 'Ticket 42 answered.',
        decisionTransaction: _decisionHash,
      ),
    ]);
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);

    await tester.enterText(
      find.byKey(const ValueKey('hire-detail-reject-reason')),
      'Not what I asked',
    );
    await tester.tap(find.byKey(const ValueKey('hire-detail-reject')));
    await tester.pump();
    await tester.pump();

    expect(gateway.prepared, [('reject', 'Not what I asked')]);
    expect(wallet.signed, ['AAAA-reject']);
    expect(_status('Rejected'), findsOneWidget);
    expect(
      find.text('This hire was rejected. The escrow returned the USDC to you.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed run offers Reject and refund', (tester) async {
    final wallet = TestWallet(initialAddress: _consumer);
    final gateway = _ProgressGateway([
      _hire(runtimeStatus: 'failed', failureReason: 'The model timed out.'),
      _hire(
        status: 'rejected',
        rejectedFrom: 'funded',
        failureReason: 'The model timed out.',
      ),
    ]);
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);

    expect(find.byKey(const ValueKey('hire-detail-approve')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hire-detail-reject')));
    await tester.pump();
    await tester.pump();
    expect(gateway.prepared, [('reject', '')]);
    expect(_status('Rejected'), findsOneWidget);
  });

  testWidgets('after the approval deadline Reject is hidden', (tester) async {
    await _pumpDetail(
      tester,
      gateway: _ProgressGateway([
        _hire(
          status: 'submitted',
          result: 'done',
          approvalDeadline: _now.subtract(const Duration(minutes: 1)),
        ),
      ]),
    );
    expect(find.byKey(const ValueKey('hire-detail-approve')), findsNothing);
    expect(find.byKey(const ValueKey('hire-detail-reject')), findsNothing);
    expect(
      find.byKey(const ValueKey('hire-detail-deadline-passed')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a declined wallet signature stays on the hire', (tester) async {
    final wallet = TestWallet(initialAddress: _consumer)
      ..failNextSignature = const WalletSignatureRejected();
    final gateway = _ProgressGateway([
      _hire(
        status: 'submitted',
        result: 'done',
        approvalDeadline: _now.add(const Duration(hours: 1)),
      ),
    ]);
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);

    await tester.tap(find.byKey(const ValueKey('hire-detail-approve')));
    await tester.pump();
    expect(
      find.text(
        'You cancelled the signature in your wallet. Nothing was sent.',
      ),
      findsOneWidget,
    );
    expect(_status('Submitted'), findsOneWidget);
    expect(gateway.submitted, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a relay error keeps the hire and can be retried', (
    tester,
  ) async {
    final wallet = TestWallet(initialAddress: _consumer);
    final gateway = _ProgressGateway(
      [
        _hire(
          status: 'submitted',
          result: 'done',
          approvalDeadline: _now.add(const Duration(hours: 1)),
        ),
      ],
      failSubmit: const HireBackendUnavailable(
        'Stellar Testnet could not be reached.',
      ),
    );
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);

    await tester.tap(find.byKey(const ValueKey('hire-detail-approve')));
    await tester.pump();
    expect(find.text('Stellar Testnet could not be reached.'), findsOneWidget);
    expect(_status('Submitted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a demo hire labels the flow and has no explorer link', (
    tester,
  ) async {
    final wallet = TestWallet(initialAddress: _consumer);
    final gateway = _ProgressGateway([
      _hire(
        status: 'submitted',
        result: 'Demo result. No funds moved.',
        approvalDeadline: _now.add(const Duration(hours: 1)),
      ),
      _hire(
        status: 'completed',
        result: 'Demo result. No funds moved.',
      ),
    ], isDemo: true);
    await _pumpDetail(tester, gateway: gateway, wallet: wallet);

    expect(find.byKey(const ValueKey('hire-detail-demo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hire-detail-approve')));
    await tester.pump();
    await tester.pump();
    expect(_status('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('hire-detail-decision')), findsNothing);
  });

  group('F7 rate a completed hire', () {
    final rate = find.byKey(const ValueKey('hire-detail-rate'));
    final send = find.byKey(const ValueKey('rate-send'));
    final comment = find.byKey(const ValueKey('rate-comment'));
    final sheetError = find.byKey(const ValueKey('rate-error'));

    bool sendEnabled(WidgetTester tester) =>
        tester
            .widget<TextButton>(
              find.descendant(of: send, matching: find.byType(TextButton)),
            )
            .onPressed !=
        null;

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(rate);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> pickScore(WidgetTester tester, int score) async {
      await tester.tap(find.byKey(ValueKey('score-star-$score')));
      await tester.pump();
    }

    testWidgets('Rate shows only on a completed hire with no rating', (
      tester,
    ) async {
      final cases = {
        _hire(runtimeStatus: 'running'): false,
        _hire(
          status: 'submitted',
          result: 'done',
          approvalDeadline: _now.add(const Duration(hours: 1)),
        ): false,
        _hire(status: 'rejected', rejectedFrom: 'submitted'): false,
        _hire(status: 'expired'): false,
        _hire(
          status: 'completed',
          feedbackTransaction: _feedbackHash,
          feedbackState: 'confirmed',
        ): false,
        _hire(status: 'completed'): true,
        // A failed rating can be sent again.
        _hire(status: 'completed', feedbackState: 'failed'): true,
        // Unless its outcome is unknown: the relay refuses a new one.
        _hire(
          status: 'completed',
          feedbackState: 'failed',
          feedbackErrorCode: 'OutcomeUnknown',
        ): false,
      };
      for (final MapEntry(key: hire, value: shown) in cases.entries) {
        await _pumpDetail(tester, gateway: _ProgressGateway([hire]));
        expect(
          rate,
          shown ? findsOneWidget : findsNothing,
          reason: '${hire.status} ${hire.feedbackState}',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('pick a score, comment, sign: S06 shows the rating once the '
        'tracker confirms it, then stops polling', (tester) async {
      final wallet = TestWallet(initialAddress: _consumer);
      final gateway = _ProgressGateway([
        _hire(status: 'completed', result: 'done'),
        _hire(
          status: 'completed',
          result: 'done',
          feedbackTransaction: _feedbackHash,
          feedbackState: 'submitted',
        ),
        _hire(
          status: 'completed',
          result: 'done',
          feedbackTransaction: _feedbackHash,
          feedbackState: 'confirmed',
        ),
      ]);
      await _pumpDetail(tester, gateway: gateway, wallet: wallet);
      await openSheet(tester);

      expect(find.text('Rate Support Relay'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);

      await pickScore(tester, 5);
      await tester.enterText(comment, '  Fast and right.  ');
      await tester.pump();
      expect(sendEnabled(tester), isTrue);

      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(gateway.ratings, [(3, 5, 'Fast and right.')]);
      expect(wallet.signed, ['AAAA-feedback']);
      expect(gateway.relayedRatings, [(3, 'signed:AAAA-feedback')]);
      expect(send, findsNothing);
      expect(rate, findsNothing);
      expect(
        find.text('Rating sent. Waiting for Stellar to confirm it.'),
        findsOneWidget,
      );

      await tester.pump(_poll);
      await tester.pump();
      expect(find.text('Rating saved'), findsOneWidget);
      expect(find.byKey(const ValueKey('hire-detail-score')), findsOneWidget);
      final reads = gateway.reads.length;

      // Completed and confirmed: nothing left to poll.
      await tester.pump(_poll * 3);
      expect(gateway.reads, hasLength(reads));

      await tester.tap(find.byKey(const ValueKey('hire-detail-feedback')));
      await tester.pump();
      expect(_opened.single.toString(), endsWith('/tx/$_feedbackHash'));
    });

    testWidgets('a rating that fails on chain says so, and Rate is offered '
        'again', (tester) async {
      final gateway = _ProgressGateway([
        _hire(
          status: 'completed',
          result: 'done',
          feedbackTransaction: _feedbackHash,
          feedbackState: 'submitted',
        ),
        _hire(
          status: 'completed',
          result: 'done',
          feedbackState: 'failed',
          feedbackErrorCode: 'TransactionFailed',
        ),
      ]);
      await _pumpDetail(tester, gateway: gateway);
      expect(
        find.text('Rating sent. Waiting for Stellar to confirm it.'),
        findsOneWidget,
      );
      expect(rate, findsNothing);

      await tester.pump(_poll);
      await tester.pump();

      expect(
        find.text(
          'Your rating did not go through (TransactionFailed). '
          'Try again.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Rating sent. Waiting for Stellar to confirm it.'),
        findsNothing,
      );
      expect(rate, findsOneWidget);
    });

    testWidgets('a rating whose outcome is unknown pauses Rate and says why', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        gateway: _ProgressGateway([
          _hire(
            status: 'completed',
            result: 'done',
            feedbackState: 'failed',
            feedbackErrorCode: 'OutcomeUnknown',
          ),
        ]),
      );

      expect(
        find.byKey(const ValueKey('hire-detail-rating-failed')),
        findsOneWidget,
      );
      expect(
        find.textContaining('could not confirm whether your rating'),
        findsOneWidget,
      );
      expect(rate, findsNothing);
    });

    testWidgets('the server refusing a rating shows translated copy, not the '
        'raw server text', (tester) async {
      final cases = <HireGatewayException, String>{
        const HireOwnerCannotRate(): 'The owner of this agent cannot rate it.',
        const HireNotRatable(): 'Only a completed hire can be rated.',
        const HireInvalidRating():
            'Pick a score from 1 to 5 and keep the comment to 500 characters.',
        const HireRatingInProgress():
            'A rating for this hire is still being confirmed. Check back in a '
            'moment.',
      };
      for (final MapEntry(key: failure, value: copy) in cases.entries) {
        final wallet = TestWallet(initialAddress: _consumer);
        final gateway = _ProgressGateway([_hire(status: 'completed')])
          ..failFeedback = failure;
        await _pumpDetail(tester, gateway: gateway, wallet: wallet);
        await openSheet(tester);
        await pickScore(tester, 4);
        await tester.tap(send);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(sheetError, findsOneWidget, reason: '$failure');
        expect(find.text(copy), findsOneWidget, reason: '$failure');
        expect(wallet.signed, isEmpty);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the limit and the counter use the trimmed text in the '
        "server's unit", (tester) async {
      final counter = find.byKey(const ValueKey('rate-comment-counter'));
      await _pumpDetail(
        tester,
        gateway: _ProgressGateway([_hire(status: 'completed')]),
      );
      await openSheet(tester);
      await pickScore(tester, 4);

      // 500 characters plus surrounding spaces: the server gets 500.
      await tester.enterText(comment, '   ${'x' * 500}   ');
      await tester.pump();
      expect(find.text('Keep the comment to 500 characters.'), findsNothing);
      expect(tester.widget<Text>(counter).data, '500/500');
      expect(sendEnabled(tester), isTrue);

      // An emoji is two UTF-16 code units, as the server counts it: the
      // counter and the error agree.
      await tester.enterText(comment, '😀' * 251);
      await tester.pump();
      expect(tester.widget<Text>(counter).data, '502/500');
      expect(find.text('Keep the comment to 500 characters.'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('a comment over 500 characters shows an inline error and '
        'disables Send', (tester) async {
      await _pumpDetail(
        tester,
        gateway: _ProgressGateway([_hire(status: 'completed')]),
      );
      await openSheet(tester);
      await pickScore(tester, 4);

      await tester.enterText(comment, 'x' * 501);
      await tester.pump();
      expect(
        find.text('Keep the comment to 500 characters.'),
        findsOneWidget,
      );
      expect(sendEnabled(tester), isFalse);

      await tester.enterText(comment, 'x' * 500);
      await tester.pump();
      expect(find.text('Keep the comment to 500 characters.'), findsNothing);
      expect(sendEnabled(tester), isTrue);
    });

    testWidgets('a declined signature stays on the sheet: "Rating not sent"', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: _consumer)
        ..failNextSignature = const WalletSignatureRejected();
      final gateway = _ProgressGateway([_hire(status: 'completed')]);
      await _pumpDetail(tester, gateway: gateway, wallet: wallet);
      await openSheet(tester);
      await pickScore(tester, 3);

      await tester.tap(send);
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Rating not sent: you cancelled the signature in your wallet.',
        ),
        findsOneWidget,
      );
      expect(send, findsOneWidget);
      expect(gateway.relayedRatings, isEmpty);

      // The same sheet can try again.
      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(gateway.relayedRatings, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an already rated hire stays on the sheet with the F7 copy', (
      tester,
    ) async {
      final gateway = _ProgressGateway([_hire(status: 'completed')])
        ..failFeedback = const HireAlreadyRated();
      await _pumpDetail(tester, gateway: gateway);
      await openSheet(tester);
      await pickScore(tester, 5);

      await tester.tap(send);
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<Text>(sheetError).data,
        'You already rated this hire.',
      );
      expect(send, findsOneWidget);
    });

    testWidgets('the server refusing the wallet asks for the one that hired', (
      tester,
    ) async {
      final gateway = _ProgressGateway([_hire(status: 'completed')])
        ..failFeedback = const HireWrongWallet();
      await _pumpDetail(tester, gateway: gateway);
      await openSheet(tester);
      await pickScore(tester, 2);

      await tester.tap(send);
      await tester.pump();
      await tester.pump();

      expect(find.text('Rate with the wallet that hired.'), findsOneWidget);
      expect(send, findsOneWidget);
    });

    testWidgets('another connected wallet cannot sign: "Rate with the wallet '
        'that hired"', (tester) async {
      final wallet = TestWallet(initialAddress: 'GSOMEONEELSE');
      final gateway = _ProgressGateway([_hire(status: 'completed')]);
      await _pumpDetail(
        tester,
        gateway: gateway,
        wallet: wallet,
        page: () => RateHireSheet(
          hire: _hire(status: 'completed'),
          consumer: _consumer,
        ),
      );
      await tester.pump();
      await pickScore(tester, 5);

      await tester.tap(send);
      await tester.pump();

      expect(find.text('Rate with the wallet that hired.'), findsOneWidget);
      expect(wallet.signed, isEmpty);
      expect(gateway.ratings, isEmpty);
      expect(gateway.signIns, isEmpty);
    });

    testWidgets('a hire rated before this visit says so, with its tx', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        gateway: _ProgressGateway([
          _hire(
            status: 'completed',
            feedbackTransaction: _feedbackHash,
            feedbackState: 'confirmed',
          ),
        ]),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('hire-detail-rating')))
            .data,
        'You already rated this hire.',
      );
      expect(find.byKey(const ValueKey('hire-detail-score')), findsNothing);
      expect(rate, findsNothing);

      await tester.tap(find.byKey(const ValueKey('hire-detail-feedback')));
      await tester.pump();
      expect(_opened.single.toString(), endsWith('/tx/$_feedbackHash'));
    });
  });
}
