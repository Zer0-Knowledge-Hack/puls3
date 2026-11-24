import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/app.dart';
import 'package:puls3_flutter/src/data/app_config.dart';
import 'package:puls3_flutter/src/data/server_agent_repository.dart';
import 'package:puls3_flutter/src/hire/server_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/wallet_funds.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/screens/hire_sheet.dart';
import 'package:puls3_flutter/src/ui/atoms/primary_button.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'support/automated_key_wallet.dart';

// Handed in by scripts/e2e-flutter-local.sh (`--dart-define-from-file`). All of
// them belong to the local sandbox: the wallet key is ephemeral.
const _walletSecret = String.fromEnvironment('E2E_WALLET_SECRET');
const _signingPassphrase = String.fromEnvironment('E2E_SIGNING_PASSPHRASE');
const _agentName = String.fromEnvironment('E2E_AGENT_NAME');

/// The hire flow in a real browser against the real server and the local
/// sandbox (#256): market, agent page, `HireSheet`, the wallet signing the
/// prepared envelopes, and the confirmation once the tracker confirms `fund`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a consumer hires an agent from the market to the confirmation', (
    tester,
  ) async {
    final trace = <String>[];
    try {
      await _journey(tester, trace);
      binding.reportData = {'trace': trace};
    } on Object catch (error) {
      // The web driver reports no failure message, so the reason and the texts
      // on screen go in `reportData`, which test_driver/integration_test.dart
      // prints.
      binding.reportData = {
        'failure': '$error',
        'screen': _screenTexts(),
        'trace': trace,
      };
      rethrow;
    }
  });
}

Future<void> _journey(WidgetTester tester, List<String> trace) async {
  // A desktop-sized window: the sheet's button must be inside the viewport.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1600);
  addTearDown(tester.view.reset);

  expect(
    _walletSecret,
    isNotEmpty,
    reason: 'run scripts/e2e-flutter-local.sh',
  );

  const configJson = '{}';
  final client = Client(resolveApiUrl(configJson))
    ..authSessionManager = FlutterAuthSessionManager();
  // Records a failing server call: the app maps every failure to a message.
  Future<T> logged<T>(String name, Future<T> Function() call) async {
    try {
      return await call();
    } on Object catch (e) {
      trace.add('$name failed: ${e.runtimeType} $e');
      rethrow;
    }
  }

  final auth = readAuthConfig(configJson);
  final session = WalletSession(
    createChallenge: client.walletAuth.createChallenge,
    verifyChallenge: client.walletAuth.verifyChallenge,
    isAuthenticated: () => client.auth.isAuthenticated,
    storeSession: client.auth.updateSignedInUser,
    serverSigningKey: auth.serverSigningKey,
    homeDomain: auth.homeDomain,
    webAuthDomain: auth.webAuthDomain,
  );
  final wallet = AutomatedKeyWallet(
    secretSeed: _walletSecret,
    signingPassphrase: _signingPassphrase,
  );

  await tester.pumpWidget(
    Puls3App(
      repository: ServerAgentRepository(
        () => client.agent.list(),
        byId: (id) => client.agent.get(id),
      ),
      wallet: wallet,
      onWalletDisconnect: session.forget,
      // English whatever the browser language, so the finders read the same.
      locale: const Locale('en'),
      initialLocation: '/market',
      hireGateway: ServerHireGateway(
        createHire: (a, b, c, d, {subcontractReserve, allowRelatedParty}) =>
            logged(
              'createHire',
              () => client.hire.createHire(
                a,
                b,
                c,
                d,
                subcontractReserve: subcontractReserve,
                allowRelatedParty: allowRelatedParty,
              ),
            ),
        getHireTerms: client.hire.getHireTerms,
        prepareCreateJob: (a) =>
            logged('prepareCreateJob', () => client.hire.prepareCreateJob(a)),
        prepareFund: (a) =>
            logged('prepareFund', () => client.hire.prepareFund(a)),
        prepareComplete: client.hire.prepareComplete,
        prepareReject: client.hire.prepareReject,
        prepareClaimRefund: client.hire.prepareClaimRefund,
        submitEscrowCall: (a, b, c) => logged(
          'submitEscrowCall',
          () => client.hire.submitEscrowCall(a, b, c),
        ),
        getHire: (a, b) => logged('getHire', () => client.hire.getHire(a, b)),
        prepareFeedback: client.feedback.prepareFeedback,
        submitFeedback: client.feedback.submitFeedback,
        session: session,
        // The funds check reads USDC from Horizon on testnet. The sandbox
        // pays in its native token, so the check is stood in for here and
        // the escrow itself still moves the real balance.
        readFunds: (account) async =>
            const WalletFunds(accountExists: true, usdcStroops: 1000000000000),
      ),
    ),
  );

  // Market: the seeded agent is listed by the real server.
  await _pumpUntil(tester, find.text(_agentName));
  await tester.tap(find.text(_agentName).first);

  // Agent page: Hire opens the sheet.
  // The button is disabled until the server has loaded the agent.
  final hire = find.byWidgetPredicate(
    (widget) =>
        widget is PrimaryButton &&
        widget.label == 'Hire' &&
        widget.onPressed != null,
  );
  await _pumpUntil(tester, hire);
  await tester.tap(hire);
  await _pumpUntil(tester, find.byType(HireSheet));
  await _pumpUntil(tester, find.byKey(const ValueKey('hire-input')));

  // Payment view: the input is signed and sent, the wallet signing both
  // envelopes the server prepared.
  // Set on the field's controller: the browser's text input is not the test
  // one, so `enterText` can leave the field empty and the button disabled.
  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('hire-input')),
  );
  field.controller!.text = 'Browser E2E: summarise this';
  await tester.pump();
  trace.add('input length ${field.controller!.text.length}');
  await tester.ensureVisible(find.text('Confirm & sign'));
  await tester.pump();
  final button = find.text('Confirm & sign');
  trace.add(
    'viewport ${tester.view.physicalSize}, button at ${tester.getCenter(button)}',
  );
  await tester.tap(button);

  // Progress and confirmation: the wallet signs both envelopes, the tracker
  // confirms `fund`, and the sheet links the hire. A failure state ends the
  // wait at once with its texts instead of after the timeout.
  final deadline = DateTime.now().add(const Duration(minutes: 3));
  var lastStage = '';
  while (find.byKey(const ValueKey('confirmed')).evaluate().isEmpty) {
    if (find.byKey(const ValueKey('error')).evaluate().isNotEmpty) {
      fail('the hire failed. On screen: ${_screenTexts()}');
    }
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'timed out waiting for the confirmation. On screen: ${_screenTexts()}',
      );
    }
    final stage = _stage();
    if (stage != lastStage) {
      lastStage = stage;
      trace.add(stage);
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(find.text('View hire'), findsOneWidget);
  expect(find.text('View on StellarExpert'), findsWidgets);
}

/// What the payment view shows now, to record how the flow progressed.
String _stage() {
  final progress = find.byKey(const ValueKey('hire-progress'));
  if (progress.evaluate().isNotEmpty) {
    return 'progress: ${(progress.evaluate().first.widget as Text).data}';
  }
  final label = find.byType(PrimaryButton).evaluate().isEmpty
      ? 'no button'
      : find
            .descendant(
              of: find.byType(PrimaryButton).last,
              matching: find.byType(Text),
            )
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join('/');
  return find.byKey(const ValueKey('summary')).evaluate().isNotEmpty
      ? 'summary, button: $label'
      : 'other';
}

/// Pumps frames until [finder] matches, or fails after [timeout]. A real
/// server answers on its own time, so `pumpAndSettle` is not enough.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out after $timeout waiting for $finder');
}

/// The texts on screen: where the flow stopped.
String _screenTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .toList()
    .reversed
    .take(30)
    .toList()
    .reversed
    .join(' | ');
