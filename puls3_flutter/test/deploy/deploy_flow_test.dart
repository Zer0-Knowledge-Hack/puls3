import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/deploy/deploy_flow.dart';
import 'package:puls3_flutter/src/deploy/deploy_flow_controller.dart';
import 'package:puls3_flutter/src/deploy/deploy_gateway.dart';
import 'package:puls3_flutter/src/domain/agent_draft.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/molecules/progress_step_row.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

const _draft = AgentDraft(
  name: 'Visa Scout with a rather long agent name for small phones',
  description: 'Checks visa rules.',
  model: 'Claude Sonnet',
  systemPrompt: 'You check visa rules.',
  skills: ['Travel'],
  priceUsdcStroops: 5000000,
);

const _txHash =
    'aa11bb22cc33dd44ee55ff6600112233445566778899aabbccddeeff00112233';
const _agentWallet = 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ';

/// A fake client whose every call waits until the test completes it.
class ScriptedGateway implements DeployGateway {
  @override
  bool isDemo = false;

  final prepares = <Completer<PreparedDeploy>>[];
  final builders = <String>[];
  final submissions = <Completer<Registration>>[];
  final activations = <Completer<String>>[];
  final signedPayloads = <String>[];

  @override
  Future<PreparedDeploy> prepare(AgentDraft draft, {required String builder}) {
    builders.add(builder);
    final call = Completer<PreparedDeploy>();
    prepares.add(call);
    return call.future;
  }

  @override
  Future<Registration> submitRegistration(
    PreparedDeploy prepared,
    String signedTransaction,
  ) {
    signedPayloads.add(signedTransaction);
    final call = Completer<Registration>();
    submissions.add(call);
    return call.future;
  }

  @override
  Future<String> activate(Registration registration) {
    final call = Completer<String>();
    activations.add(call);
    return call.future;
  }

  static const prepared = PreparedDeploy(
    preparationId: 'prep-1',
    unsignedTransaction: 'AAAA-unsigned',
  );
  static const registration = Registration(
    agentId: 42,
    transactionHash: _txHash,
  );
}

class _Harness {
  _Harness(
    this.tester, {
    this.stepTimeout,
    this.signatureTimeout,
    MockWallet? wallet,
  }) : wallet =
           wallet ??
           MockWallet(
             connectDelay: Duration.zero,
             signDelay: const Duration(seconds: 1),
           );

  final WidgetTester tester;
  final Duration? stepTimeout;
  final Duration? signatureTimeout;
  bool mounted = true;
  final gateway = ScriptedGateway();
  final MockWallet wallet;
  final opened = <Uri>[];
  final viewed = <DeployResult>[];
  final live = <DeployResult>[];
  final clipboard = <String>[];
  var closed = 0;

  Future<void> pump({Size size = const Size(390, 844)}) async {
    Puls3Fonts.useGoogleFonts = false;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final controller = WalletController(wallet);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: Puls3Theme.dark(),
        home: Scaffold(
          body: SafeArea(
            // The same frame the Studio sheet gives the flow on a phone.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Puls3Spacing.md),
              child: DeployFlow(
                draft: _draft,
                gateway: gateway,
                wallet: controller,
                stepTimeout: stepTimeout,
                signatureTimeout: signatureTimeout,
                onLive: live.add,
                onViewAgent: viewed.add,
                onClose: () => closed++,
                openUrl: (url) async => opened.add(url),
              ),
            ),
          ),
        ),
      ),
    );
    await settle();
  }

  /// Lets futures and frames run without waiting on endless animations.
  Future<void> settle([
    Duration time = const Duration(milliseconds: 50),
  ]) async {
    await tester.pump();
    await tester.pump(time);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> completePrepare() async {
    gateway.prepares.last.complete(ScriptedGateway.prepared);
    await settle();
  }

  /// Waits out the mock wallet's signature delay.
  Future<void> sign() => settle(const Duration(milliseconds: 1000));

  Future<void> completeRegistration() async {
    gateway.submissions.last.complete(ScriptedGateway.registration);
    await settle();
  }

  Future<void> completeActivation() async {
    gateway.activations.last.complete(_agentWallet);
    await settle();
  }

  Future<void> goLive() async {
    await completePrepare();
    await sign();
    await completeRegistration();
    await completeActivation();
  }

  StepStatus statusOf(DeployStep step) => tester
      .widget<ProgressStepRow>(find.byKey(ValueKey('deploy-step-${step.name}')))
      .status;

  Finder errorPanel(DeployErrorKind kind) =>
      find.byKey(ValueKey('deploy-error-${kind.name}'));

  Finder phase(DeployStep step) =>
      find.byKey(ValueKey('deploy-phase-${step.name}'));
}

void main() {
  group('progress', () {
    testWidgets('preparing: card, active step, skeletons, no close button', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();

      expect(h.phase(DeployStep.preparing), findsOneWidget);
      expect(find.text('Preparing deployment'), findsOneWidget);
      expect(h.statusOf(DeployStep.preparing), StepStatus.active);
      expect(h.statusOf(DeployStep.awaitingSignature), StepStatus.pending);
      // Values are unknown yet: skeletons, nothing to copy.
      expect(find.byTooltip('Copy agent ID'), findsNothing);
      // A deploy in flight cannot be closed by accident.
      expect(find.byTooltip('Close'), findsNothing);
      expect(h.gateway.prepares, hasLength(1));
    });

    testWidgets('waiting for signature tells the user to act in the wallet', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();

      expect(h.phase(DeployStep.awaitingSignature), findsOneWidget);
      expect(find.text('Wallet signature'), findsOneWidget);
      expect(
        find.text('Confirm the transaction in your wallet.'),
        findsOneWidget,
      );
      expect(find.text('Waiting for confirmation…'), findsOneWidget);
      expect(h.statusOf(DeployStep.preparing), StepStatus.done);
      expect(h.statusOf(DeployStep.awaitingSignature), StepStatus.active);
      expect(h.gateway.submissions, isEmpty);
      await h.sign(); // let the mock wallet's timer finish
    });

    testWidgets('registering sends the signed transaction once', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      await h.sign();

      expect(h.phase(DeployStep.registering), findsOneWidget);
      expect(find.text('Registering agent'), findsOneWidget);
      expect(h.statusOf(DeployStep.awaitingSignature), StepStatus.done);
      expect(h.statusOf(DeployStep.registering), StepStatus.active);
      expect(h.gateway.signedPayloads, hasLength(1));
      // The builder that signs is the one the transaction was prepared for.
      expect(h.gateway.builders.single, h.wallet.address);
    });

    testWidgets('activating shows the confirmed id and transaction', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      await h.sign();
      await h.completeRegistration();

      expect(h.phase(DeployStep.activating), findsOneWidget);
      expect(find.text('Almost there…'), findsOneWidget);
      expect(h.statusOf(DeployStep.registering), StepStatus.done);
      expect(h.statusOf(DeployStep.activating), StepStatus.active);
      // The skeletons were replaced by the confirmed values.
      expect(find.text('#42'), findsOneWidget);
      expect(find.text('aa11bb22…00112233'), findsOneWidget);
    });

    testWidgets('live: id, transaction, copy, explorer and open agent', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.goLive();

      expect(find.byKey(const ValueKey('deploy-success')), findsOneWidget);
      expect(find.text('Agent deployed'), findsOneWidget);
      expect(find.text('#42'), findsOneWidget);
      expect(h.live.single.agentId, 42);

      await tester.tap(find.byTooltip('Copy agent ID'));
      await tester.tap(find.byTooltip('Copy transaction'));
      await tester.pump();
      expect(h.clipboard, ['42', _txHash]);
      expect(find.byTooltip('Copied'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('deploy-explorer-link')));
      expect(
        h.opened.single.toString(),
        'https://stellar.expert/explorer/testnet/tx/$_txHash',
      );

      await tester.tap(find.text('Open agent'));
      expect(h.viewed.single.agentId, 42);

      await tester.tap(find.text('Done'));
      expect(h.closed, 1);
    });
  });

  group('errors and recovery', () {
    testWidgets('signature rejected: try again reuses the preparation', (
      tester,
    ) async {
      final h = _Harness(tester);
      h.wallet.rejectSignatures = true;
      await h.pump();
      await h.completePrepare();
      await h.sign();

      expect(h.errorPanel(DeployErrorKind.signatureRejected), findsOneWidget);
      expect(find.text('Signature rejected'), findsOneWidget);
      expect(h.statusOf(DeployStep.awaitingSignature), StepStatus.failed);
      expect(h.gateway.submissions, isEmpty);
      // Nothing technical to show for a user decision.
      expect(find.text('Show details'), findsNothing);

      h.wallet.rejectSignatures = false;
      await tester.tap(find.text('Try again'));
      await h.sign();
      await h.completeRegistration();
      await h.completeActivation();

      expect(find.text('Agent deployed'), findsOneWidget);
      expect(h.gateway.prepares, hasLength(1));
    });

    testWidgets('transaction failed: details on request, then Preparing, '
        'signature and registration run again', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      await h.sign();
      h.gateway.submissions.last.completeError(
        const DeployTransactionFailed('tx_bad_seq', transactionHash: _txHash),
      );
      await h.settle();

      expect(h.errorPanel(DeployErrorKind.transactionFailed), findsOneWidget);
      expect(find.text('Deployment failed'), findsOneWidget);
      expect(h.statusOf(DeployStep.registering), StepStatus.failed);
      expect(find.text('tx_bad_seq'), findsNothing);

      await tester.tap(find.text('Show details'));
      await tester.pump();
      expect(find.text('tx_bad_seq'), findsOneWidget);
      expect(find.textContaining('Code: transactionFailed'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await h.settle();
      expect(h.statusOf(DeployStep.preparing), StepStatus.active);
      expect(h.gateway.prepares, hasLength(2));

      await h.goLive();
      expect(find.text('Agent deployed'), findsOneWidget);
      expect(h.gateway.signedPayloads, hasLength(2));
    });

    testWidgets('backend error: retry repeats only the failed step', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      await h.sign();
      await h.completeRegistration();
      h.gateway.activations.last.completeError(
        const DeployBackendError('Publication failed'),
      );
      await h.settle();

      expect(h.errorPanel(DeployErrorKind.backendError), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(h.statusOf(DeployStep.activating), StepStatus.failed);
      // A stopped deploy can be left.
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await h.settle();
      await h.completeActivation();

      expect(find.text('Agent deployed'), findsOneWidget);
      expect(h.gateway.signedPayloads, hasLength(1));
      expect(h.gateway.submissions, hasLength(1));
      expect(h.gateway.activations, hasLength(2));
    });

    testWidgets('a double tap on retry starts a single run', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      h.gateway.prepares.last.completeError(const DeployBackendError('Down'));
      await h.settle();

      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Retry'), warnIfMissed: false);
      await h.settle();

      expect(h.gateway.prepares, hasLength(2));
    });

    testWidgets('wallet unavailable: retry connects again', (tester) async {
      final h = _Harness(tester);
      h.wallet.failure = const WalletUnavailable();
      await h.pump();

      expect(h.errorPanel(DeployErrorKind.walletUnavailable), findsOneWidget);
      expect(find.text('Wallet not available'), findsOneWidget);
      expect(h.gateway.prepares, isEmpty);

      h.wallet.failure = null;
      await tester.tap(find.text('Try again'));
      await h.settle();
      expect(h.gateway.prepares, hasLength(1));
    });

    testWidgets('wrong network: retry signs the same transaction', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      h.wallet.failure = const WalletWrongNetwork();
      await h.sign();

      expect(h.errorPanel(DeployErrorKind.wrongNetwork), findsOneWidget);
      expect(h.statusOf(DeployStep.awaitingSignature), StepStatus.failed);

      h.wallet.failure = null;
      await tester.tap(find.text('Try again'));
      // The wallet forgot the wrong-network session: it reconnects first,
      // with the same account, then signs the same transaction.
      await h.settle(const Duration(milliseconds: 600));
      await h.sign();
      expect(h.statusOf(DeployStep.registering), StepStatus.active);
      expect(h.gateway.prepares, hasLength(1));
    });

    testWidgets('account changed: never signs the old account transaction, '
        'prepares a new one for the current account', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      final firstBuilder = h.gateway.builders.single;
      h.wallet.switchAccount();
      await h.completePrepare();

      expect(h.errorPanel(DeployErrorKind.accountChanged), findsOneWidget);
      expect(h.gateway.submissions, isEmpty);

      await tester.tap(find.text('Use current account'));
      await h.settle();
      expect(h.gateway.prepares, hasLength(2));
      expect(h.gateway.builders.last, isNot(firstBuilder));
      expect(h.gateway.builders.last, h.wallet.address);

      await h.goLive();
      expect(find.text('Agent deployed'), findsOneWidget);
    });

    testWidgets('timeout: reported as a lost connection, retry recovers', (
      tester,
    ) async {
      final h = _Harness(tester, stepTimeout: const Duration(seconds: 5));
      await h.pump();
      await tester.pump(const Duration(seconds: 6));
      await h.settle();

      expect(h.errorPanel(DeployErrorKind.connection), findsOneWidget);
      expect(find.text('Connection lost'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await h.settle();
      await h.goLive();
      expect(find.text('Agent deployed'), findsOneWidget);
    });

    testWidgets('invalid response: an unverifiable hash is never shown', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      await h.sign();
      h.gateway.submissions.last.complete(
        const Registration(agentId: 42, transactionHash: 'not-a-hash'),
      );
      await h.settle();

      expect(h.errorPanel(DeployErrorKind.invalidResponse), findsOneWidget);
      expect(find.text('#42'), findsNothing);
      expect(find.textContaining('not-a-hash'), findsNothing);

      await tester.tap(find.text('Retry'));
      await h.settle();
      await h.completeRegistration();
      await h.completeActivation();
      expect(find.text('Agent deployed'), findsOneWidget);
    });

    testWidgets('cancel after an error leaves the flow', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      h.gateway.prepares.last.completeError(const DeployBackendError('Down'));
      await h.settle();

      await tester.tap(find.text('Cancel'));
      expect(h.closed, 1);
    });
  });

  group('review fixes (#109)', () {
    testWidgets('a demo gateway is labelled as a demo, never as live', (
      tester,
    ) async {
      final h = _Harness(tester);
      h.gateway.isDemo = true;
      await h.pump();
      expect(find.byKey(const ValueKey('deploy-demo-banner')), findsOneWidget);

      await h.goLive();
      expect(find.byKey(const ValueKey('deploy-demo-result')), findsOneWidget);
      expect(find.text('Demo deploy only'), findsOneWidget);
      expect(find.text('Agent deployed'), findsNothing);
      expect(find.textContaining('live on Stellar'), findsNothing);
      // No explorer link or agent page for made-up values.
      expect(find.byKey(const Key('deploy-explorer-link')), findsNothing);
      expect(find.text('Open agent'), findsNothing);
      expect(find.text(_txHash), findsNothing);
      expect(h.live.single.isDemo, isTrue);
      expect(h.live.single.explorerUrl, isNull);

      await tester.tap(find.text('Back to Studio'));
      expect(h.closed, 1);
    });

    testWidgets('the wallet returns a signed envelope, not a hash', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      await h.sign();

      expect(
        h.gateway.signedPayloads.single,
        '${MockWallet.signedPrefix}${ScriptedGateway.prepared.unsignedTransaction}',
      );
      await h.completeRegistration();
      await h.completeActivation();
    });

    testWidgets('an expired preparation is prepared again, not resent', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      await h.completePrepare();
      await h.sign();
      h.gateway.submissions.last.completeError(
        const DeployPreparationExpired('timeBounds'),
      );
      await h.settle();

      expect(h.errorPanel(DeployErrorKind.preparationExpired), findsOneWidget);
      await tester.tap(find.text('Prepare again'));
      await h.settle();
      expect(h.gateway.prepares, hasLength(2));

      await h.goLive();
      expect(find.text('Agent deployed'), findsOneWidget);
      expect(h.gateway.signedPayloads, hasLength(2));
    });

    testWidgets('a wallet that never answers times out and can be retried', (
      tester,
    ) async {
      // The mock wallet answers after 1 s; the limit is 0.5 s.
      final h = _Harness(
        tester,
        signatureTimeout: const Duration(milliseconds: 500),
      );
      await h.pump();
      await h.completePrepare();
      expect(h.statusOf(DeployStep.awaitingSignature), StepStatus.active);
      // While the wallet prompt is open, the user can still leave.
      expect(find.byTooltip('Close'), findsOneWidget);

      await h.settle(const Duration(milliseconds: 600));
      expect(h.errorPanel(DeployErrorKind.walletTimeout), findsOneWidget);
      expect(find.text('No answer from your wallet'), findsOneWidget);
      expect(h.gateway.submissions, isEmpty);

      await tester.tap(find.text('Try again'));
      await h.settle();
      expect(h.statusOf(DeployStep.awaitingSignature), StepStatus.active);
      // Let the pending mock timers finish.
      await h.settle(const Duration(seconds: 2));
      expect(h.gateway.prepares, hasLength(1));
    });

    testWidgets('a wallet connection that never answers times out and the '
        'user can leave', (tester) async {
      // The connect prompt never answers in practice: 10 minutes against a
      // 0.5 s limit.
      final h = _Harness(
        tester,
        signatureTimeout: const Duration(milliseconds: 500),
        wallet: MockWallet(connectDelay: const Duration(minutes: 10)),
      );
      await h.pump();
      expect(h.statusOf(DeployStep.preparing), StepStatus.active);
      expect(h.gateway.prepares, isEmpty);
      // While the connect prompt is open, the user can still leave.
      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      expect(h.closed, 1);

      await h.settle(const Duration(milliseconds: 600));
      expect(h.errorPanel(DeployErrorKind.walletTimeout), findsOneWidget);
      expect(find.text('No answer from your wallet'), findsOneWidget);
      expect(h.gateway.prepares, isEmpty);
      // Let the pending mock timer finish.
      await h.settle(const Duration(minutes: 10));
    });

    testWidgets('a closed flow stops instead of running the next steps', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump();
      final prepare = h.gateway.prepares.single;
      // The host removes the flow (e.g. the sheet is closed).
      await tester.pumpWidget(const SizedBox());
      prepare.complete(ScriptedGateway.prepared);
      await tester.pump(const Duration(seconds: 2));

      expect(h.gateway.submissions, isEmpty);
      expect(h.gateway.signedPayloads, isEmpty);
    });
  });

  group('responsive: no overflow', () {
    const sizes = {
      '320 × 568': Size(320, 568),
      '360 × 800': Size(360, 800),
      '390 × 844': Size(390, 844),
      '414 × 896': Size(414, 896),
      'landscape 844 × 390': Size(844, 390),
      'desktop 1280 × 800': Size(1280, 800),
    };

    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets('$name: every state lays out', (tester) async {
        // Signature step.
        final h = _Harness(tester);
        await h.pump(size: size);
        await h.completePrepare();
        expect(find.text('Waiting for confirmation…'), findsOneWidget);
        await h.sign();

        // Error with details open: the tallest error.
        h.gateway.submissions.last.completeError(
          const DeployTransactionFailed(
            'tx_bad_seq: the sequence number does not match the account',
            transactionHash: _txHash,
          ),
        );
        await h.settle();
        await tester.ensureVisible(find.text('Show details'));
        await tester.tap(find.text('Show details'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('deploy-error-details')),
          findsOneWidget,
        );

        // Recovery to live.
        await tester.ensureVisible(find.text('Try again'));
        await tester.tap(find.text('Try again'));
        await h.settle();
        await h.goLive();
        expect(find.text('Agent deployed'), findsOneWidget);
        // Any RenderFlex overflow above would already have failed the test.
        expect(tester.takeException(), isNull);
      });
    }
  });
}
