import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/hire/fake_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/l10n/locale_controller.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';
import 'package:puls3_flutter/src/screens/hire_sheet.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

import '../helpers.dart';
import '../studio/studio_fixtures.dart';

class TestWallet implements WalletPort {
  TestWallet({this.initialAddress});

  final String? initialAddress;

  /// When set, the next signature fails with it once.
  WalletException? failNextSignature;

  /// When set, the signature of this payload fails once.
  String? rejectPayloadOnce;
  final signed = <String>[];
  String? _address;

  @override
  String? get address => _address ?? initialAddress;

  @override
  Future<String> connect() async {
    return _address = initialAddress ?? 'GTESTUSERWALLET1234567890';
  }

  @override
  Future<void> disconnect() async => _address = null;

  @override
  String get name => 'Test wallet';

  @override
  Uri? get installUrl => null;

  @override
  String? get network => address == null ? null : stellarTestnetPassphrase;

  @override
  Future<String> signAuthEntry(String entryXdr) async => entryXdr;

  /// When set, the next sign-in challenge fails with it once.
  WalletException? failNextChallenge;
  final challenges = <String>[];

  @override
  Future<String> signChallenge(SignInChallenge challenge) async {
    final failure = failNextChallenge;
    if (failure != null) {
      failNextChallenge = null;
      throw failure;
    }
    challenges.add(challenge.transactionXdr);
    return 'signed:${challenge.transactionXdr}';
  }

  @override
  Future<String> signTransaction(String unsignedXdr) async {
    final failure = failNextSignature;
    if (failure != null) {
      failNextSignature = null;
      throw failure;
    }
    if (rejectPayloadOnce == unsignedXdr) {
      rejectPayloadOnce = null;
      throw const WalletSignatureRejected();
    }
    signed.add(unsignedXdr);
    return 'signed:$unsignedXdr';
  }
}

/// One hire the scripted backend knows.
class _ScriptedHire {
  _ScriptedHire(this.id);

  final int id;
  int subcontractReserve = 0;
  bool allowRelatedParty = true;
  bool createJobSubmitted = false;
  bool fundSubmitted = false;
}

/// A non-demo hire backend that records every call and, like the server,
/// returns the same hire for the same request id (api.md, "createHire
/// idempotency") and refuses a second fund once one was relayed.
class ScriptedHireGateway implements HireGateway {
  final requestIds = <String>[];
  final inputs = <String>[];

  /// The `subcontractReserve` and `allowRelatedParty` of each `createHire`.
  final reserves = <int>[];
  final relatedPartyFlags = <bool>[];

  /// What `hireTerms` answers; [failTerms] makes it throw instead.
  SubcontractTerms terms = SubcontractTerms.none;
  Object? failTerms;
  var termsReads = 0;
  final submitted = <String>[];
  var createJobPreparations = 0;
  var fundPreparations = 0;
  final _byRequest = <String, _ScriptedHire>{};
  final _byId = <int, _ScriptedHire>{};
  var _nextHire = 3;
  var _nextPreparation = 1;

  /// When set, the next call to that step fails with it once.
  HireGatewayException? failCreate;
  HireGatewayException? failNextSubmit;

  /// When set, the next `create_job` submission fails with it once.
  HireGatewayException? failCreateJobSubmit;

  /// When set, the next `fund` submission fails with it once.
  HireGatewayException? failFundSubmit;

  /// When set, the next `fund` submission throws it once after relaying:
  /// an unexpected failure once funds may have moved.
  Object? crashAfterFundRelay;

  /// How many distinct hires were created.
  int get hireCount => _byId.length;

  /// Wallets that signed in, in order, and how many sessions were dropped.
  final signIns = <String>[];
  var forgottenSessions = 0;

  /// When set, the next sign-in fails with it once.
  HireGatewayException? failSignIn;

  /// Calls recorded across sign-in and hire creation, in order.
  final calls = <String>[];

  @override
  bool get isDemo => false;

  @override
  Future<void> ensureSignedIn(String wallet, ChallengeSigner sign) async {
    calls.add('signIn');
    final failure = failSignIn;
    if (failure != null) {
      failSignIn = null;
      throw failure;
    }
    await sign(
      const SignInChallenge(
        transactionXdr: 'challenge',
        networkPassphrase: stellarTestnetPassphrase,
      ),
    );
    signIns.add(wallet);
  }

  @override
  Future<void> forgetSession() async => forgottenSessions++;

  /// When set, the next funds check fails with it once.
  HireGatewayException? failFunds;

  /// The prices the funds check was asked about, in order.
  final fundsChecks = <int>[];

  @override
  Future<void> checkFunds(String consumer, int priceUsdcStroops) async {
    calls.add('checkFunds');
    fundsChecks.add(priceUsdcStroops);
    final failure = failFunds;
    if (failure != null) {
      failFunds = null;
      throw failure;
    }
  }

  @override
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
    int subcontractReserve = 0,
    bool allowRelatedParty = true,
  }) async {
    calls.add('createHire');
    requestIds.add(requestId);
    inputs.add(input);
    reserves.add(subcontractReserve);
    relatedPartyFlags.add(allowRelatedParty);
    final failure = failCreate;
    if (failure != null) {
      failCreate = null;
      throw failure;
    }
    final hire = _byRequest.putIfAbsent(requestId, () {
      final created = _ScriptedHire(_nextHire++)
        ..subcontractReserve = subcontractReserve
        ..allowRelatedParty = allowRelatedParty;
      _byId[created.id] = created;
      return created;
    });
    // Like the server: the same request id with other terms is refused.
    if (hire.subcontractReserve != subcontractReserve ||
        hire.allowRelatedParty != allowRelatedParty) {
      throw const HireRejected('IdempotencyKeyReused');
    }
    return HireStart(
      hireId: hire.id,
      // Null once the create_job was submitted, as the server does.
      createJob: hire.createJobSubmitted ? null : _prep('createJob'),
    );
  }

  @override
  Future<SubcontractTerms> hireTerms(int agentId) async {
    termsReads++;
    final failure = failTerms;
    if (failure != null) throw failure;
    return terms;
  }

  @override
  Future<EscrowPreparation> prepareCreateJob(int hireId) async {
    createJobPreparations++;
    return _prep('createJob');
  }

  @override
  Future<EscrowPreparation> prepareFund(int hireId) async {
    if (_byId[hireId]!.fundSubmitted) {
      throw const HirePaymentAlreadySubmitted();
    }
    fundPreparations++;
    return _prep('fund');
  }

  @override
  Future<EscrowPreparation> prepareComplete(int hireId) async =>
      _prep('complete');

  @override
  Future<EscrowPreparation> prepareReject(int hireId, String reason) async =>
      _prep('reject');

  @override
  Future<EscrowPreparation> prepareClaimRefund(int hireId) async =>
      _prep('claimRefund');

  @override
  Future<EscrowPreparation> prepareFeedback(
    int hireId,
    int score,
    String comment,
  ) => throw UnimplementedError();

  @override
  Future<EscrowSubmission> submitFeedback(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) => throw UnimplementedError();

  @override
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) async {
    final hire = _byId[hireId]!;
    final fund = preparation.purpose == 'fund';
    final failure = failNextSubmit;
    if (failure != null) {
      failNextSubmit = null;
      throw failure;
    }
    final createJobFailure = failCreateJobSubmit;
    if (createJobFailure != null && !fund) {
      failCreateJobSubmit = null;
      throw createJobFailure;
    }
    final crash = crashAfterFundRelay;
    if (crash != null && fund) {
      crashAfterFundRelay = null;
      submitted.add(signedTransaction);
      hire.fundSubmitted = true;
      throw crash;
    }
    final fundFailure = failFundSubmit;
    if (fundFailure != null && fund) {
      failFundSubmit = null;
      throw fundFailure;
    }
    submitted.add(signedTransaction);
    if (fund) {
      hire.fundSubmitted = true;
    } else {
      hire.createJobSubmitted = true;
    }
    return EscrowSubmission(
      transactionHash: fund
          ? 'fa11ce0000000000000000000000000000000000000000000000000000000001'
          : 'c0ffee',
      state: 'submitted',
    );
  }

  @override
  Future<HireProgress> getHire(int hireId, String consumer) async =>
      throw const HireNotFound();

  @override
  Future<List<HireSummaryItem>> listMyHires(String consumer) async => const [];

  EscrowPreparation _prep(String purpose) => EscrowPreparation(
    preparationId: 'prep-$purpose-${_nextPreparation++}',
    purpose: purpose,
    unsignedTransaction: 'AAAA-$purpose',
  );
}

const _onChainAgent = Agent(
  id: 'agt-003',
  name: 'Soroban Auditor',
  description: 'Reviews Soroban contracts.',
  skills: ['Security'],
  priceUsdcStroops: 45000000,
  stellarAddress: 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
  model: 'Claude Opus',
  rating: 0.0,
  registryId: 9,
);

final opened = <Uri>[];

Future<void> pumpSheet(
  WidgetTester tester, {
  required WalletPort wallet,
  HireGateway? gateway,
  Agent agent = _onChainAgent,
  HireFlowStore? store,
  StudioGateway? studio,
  WalletSignIn? signIn,
}) async {
  Puls3Fonts.useGoogleFonts = false;
  opened.clear();
  await tester.pumpWidget(
    localizedTestApp(
      theme: Puls3Theme.dark(),
      home: AppScope(
        catalog: AgentCatalog(InMemoryAgentRepository([agent])),
        wallet: WalletController(wallet, signIn: signIn),
        deployGateway: FakeDeployGateway(),
        studioGateway: studio ?? FakeStudioGateway(delay: Duration.zero),
        hireGateway: gateway ?? FakeHireGateway(delay: Duration.zero),
        hireFlowStore: store ?? MemoryHireFlowStore(),
        locale: LocaleController(
          store: MemoryLocaleStore(),
          initial: const Locale('en'),
        ),
        child: Scaffold(
          body: HireSheet(
            agent: agent,
            openUrl: (url) async => opened.add(url),
          ),
        ),
      ),
    ),
  );
}

Future<void> confirm(
  WidgetTester tester, {
  String input = 'Audit my token',
}) async {
  await tester.enterText(find.byKey(const ValueKey('hire-input')), input);
  await tester.pump();
  await tap(tester, 'Confirm & sign');
}

/// Scrolls [label] into view, taps it and lets the flow run.
Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('HireSheet with the demo backend', () {
    testWidgets('signs the demo envelopes and shows the demo result', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      await pumpSheet(tester, wallet: wallet);

      expect(find.textContaining('Demo only'), findsOneWidget);
      await confirm(tester);

      expect(find.text('Demo signature only'), findsOneWidget);
      expect(find.text('Payment sent, confirming on Stellar…'), findsNothing);
      expect(find.text('View on StellarExpert'), findsNothing);
      // The demo creates no hire: there is nothing to follow.
      expect(find.text('View hire'), findsNothing);
      // Two prompts: create_job and fund.
      expect(wallet.signed, hasLength(2));
    });

    testWidgets('Confirm needs a task for the agent', (tester) async {
      await pumpSheet(tester, wallet: TestWallet());
      await tap(tester, 'Confirm & sign');
      expect(find.text('Demo signature only'), findsNothing);
    });
  });

  group('HireSheet with the escrow relay (#96)', () {
    testWidgets('create_job and fund are signed unchanged and relayed; the '
        'payment links to StellarExpert', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      expect(find.textContaining('Demo only'), findsNothing);
      expect(find.byKey(const ValueKey('escrow-guarantee')), findsOneWidget);
      await confirm(tester);

      expect(wallet.signed, ['AAAA-createJob', 'AAAA-fund']);
      expect(gateway.submitted, ['signed:AAAA-createJob', 'signed:AAAA-fund']);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('View hire'), findsOneWidget);

      await tap(tester, 'View on StellarExpert');
      expect(opened.single.toString(), contains('/tx/fa11ce'));
    });

    testWidgets('View hire closes the sheet and opens the hire detail (S06)', (
      tester,
    ) async {
      Puls3Fonts.useGoogleFonts = false;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showHireSheet(context, _onChainAgent),
                child: const Text('Open sheet'),
              ),
            ),
          ),
          GoRoute(
            path: '/hires/:id',
            builder: (_, state) =>
                Scaffold(body: Text('detail ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        AppScope(
          catalog: AgentCatalog(InMemoryAgentRepository([_onChainAgent])),
          wallet: WalletController(TestWallet(initialAddress: 'GUSER123')),
          deployGateway: FakeDeployGateway(),
          studioGateway: FakeStudioGateway(),
          hireGateway: ScriptedHireGateway(),
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
      await tester.tap(find.text('Open sheet'));
      await settle(tester);
      await confirm(tester);

      await tap(tester, 'View hire');

      expect(find.byType(HireSheet), findsNothing);
      expect(find.text('detail 3'), findsOneWidget);
    });

    testWidgets('a rejected payment signature resumes at the payment, with '
        'the same hire and no second escrow job', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123')
        ..rejectPayloadOnce = 'AAAA-fund';
      final gateway = ScriptedHireGateway();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);
      // The escrow job was created; only the payment is missing.
      expect(gateway.submitted, ['signed:AAAA-createJob']);

      await tap(tester, 'Try again');
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      expect(gateway.submitted, ['signed:AAAA-createJob', 'signed:AAAA-fund']);
      expect(gateway.requestIds, hasLength(1));
      expect(gateway.fundPreparations, 1);
    });

    testWidgets('a declined wallet prompt is a recoverable error; Try again '
        'resumes without a second hire', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123')
        ..failNextSignature = const WalletSignatureRejected();
      final gateway = ScriptedHireGateway();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.text('You cancelled the payment in your wallet. No funds moved.'),
        findsOneWidget,
      );

      await tap(tester, 'Try again');
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      // One hire, one request id: the retry did not create another.
      expect(gateway.requestIds, hasLength(1));
      expect(gateway.createJobPreparations, 0);
    });

    testWidgets('an expired payment is prepared again before re-signing', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failFundSubmit = const HirePreparationExpired();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(
        find.text('The transaction expired before it was sent.'),
        findsOne,
      );
      expect(gateway.fundPreparations, 1);

      await tap(tester, 'Try again');
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      // A fresh fund was prepared and signed instead of resending the old one.
      expect(gateway.fundPreparations, 2);
      expect(wallet.signed, ['AAAA-createJob', 'AAAA-fund', 'AAAA-fund']);
    });

    testWidgets('an unexpected failure after the payment relay never says '
        'no funds moved', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..crashAfterFundRelay = StateError('lost response');
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      // The fund was relayed before the failure.
      expect(gateway.submitted.last, 'signed:AAAA-fund');
      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.text(
          'The operation could not be completed. Check the transaction '
          'status before trying again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No funds moved'), findsNothing);
      expect(find.textContaining('held by the escrow'), findsNothing);
    });

    testWidgets('a refused session drops it, says so, and signs nothing', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failCreate = const HireNotSignedIn();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.text('Your wallet session ended. Try again to sign in.'),
        findsOneWidget,
      );
      expect(wallet.signed, isEmpty);
      expect(gateway.forgottenSessions, 1);
    });

    testWidgets('the funds are checked, then the wallet signs in, before the '
        'hire is created (#136, F5-2)', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);

      expect(gateway.calls.take(3), ['checkFunds', 'signIn', 'createHire']);
      expect(gateway.fundsChecks, [45000000]);
      expect(gateway.signIns, ['GUSER123']);
      expect(wallet.challenges, ['challenge']);
      expect(gateway.hireCount, 1);
    });

    testWidgets('too little USDC stops the hire before any signature; Try '
        'again checks again (#28)', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failFunds = const HireInsufficientFunds(
          'This hire costs 4.50 USDC and your wallet holds 1.00 USDC.',
        );
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.text('This hire costs 4.50 USDC and your wallet holds 1.00 USDC.'),
        findsOneWidget,
      );
      expect(gateway.calls, ['checkFunds']);
      expect(wallet.challenges, isEmpty);
      expect(wallet.signed, isEmpty);
      expect(gateway.forgottenSessions, 0);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(gateway.fundsChecks, [45000000, 45000000]);
      expect(gateway.hireCount, 1);
    });

    testWidgets('a payment that may have been sent is not checked again', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failFundSubmit = const HireBackendUnavailable('No answer.');
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('No answer.'), findsOneWidget);

      // The balance may already be lower: only the server can tell.
      gateway.failFunds = const HireInsufficientFunds('Too little USDC.');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(gateway.fundsChecks, hasLength(1));
      expect(find.text('Too little USDC.'), findsNothing);
    });

    testWidgets('a declined sign-in creates no hire and can be retried', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123')
        ..failNextChallenge = const WalletSignatureRejected();
      final gateway = ScriptedHireGateway();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(gateway.hireCount, 0);
      expect(wallet.signed, isEmpty);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(gateway.signIns, ['GUSER123']);
      expect(gateway.hireCount, 1);
    });

    testWidgets('a sign-in the server refuses is dropped and redone', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failSignIn = const HireSignInFailed();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(
        find.text('Signing in with your wallet failed. Try again.'),
        findsOneWidget,
      );
      expect(gateway.forgottenSessions, 1);
      expect(gateway.hireCount, 0);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(gateway.signIns, ['GUSER123']);
      expect(gateway.hireCount, 1);
    });

    testWidgets('an agent the server cannot deliver shows the same reason', (
      tester,
    ) async {
      final gateway = ScriptedHireGateway()
        ..failCreate = const HireAgentCannotDeliver();
      await pumpSheet(
        tester,
        wallet: TestWallet(initialAddress: 'GUSER123'),
        gateway: gateway,
      );

      await confirm(tester);
      expect(find.text('This agent cannot be hired yet.'), findsOneWidget);
      expect(gateway.hireCount, 0);
    });

    testWidgets('an agent that is not on chain cannot be hired for real', (
      tester,
    ) async {
      const demoAgent = Agent(
        id: 'agt-001',
        name: 'Ledger Scout',
        description: 'Demo agent.',
        skills: ['Monitoring'],
        priceUsdcStroops: 5000000,
        stellarAddress:
            'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
        model: 'Claude Sonnet',
        rating: 0.0,
      );
      final gateway = ScriptedHireGateway();
      await pumpSheet(
        tester,
        wallet: TestWallet(initialAddress: 'GUSER123'),
        gateway: gateway,
        agent: demoAgent,
      );

      await confirm(tester);
      expect(find.textContaining('not registered on chain'), findsOneWidget);
      expect(gateway.requestIds, isEmpty);
    });
  });
  group('HireSheet: final failures prepare again (review of #144)', () {
    testWidgets('a create_job rejected for good is prepared again', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failCreateJobSubmit = const HireSubmissionFailed('rejected');
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(gateway.createJobPreparations, 0);

      await tap(tester, 'Try again');
      // A fresh create_job, signed again; still one hire.
      expect(gateway.createJobPreparations, 1);
      expect(wallet.signed.where((x) => x == 'AAAA-createJob'), hasLength(2));
      expect(gateway.hireCount, 1);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
    });

    testWidgets('a fund that failed on chain is prepared again', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failFundSubmit = const HireSubmissionFailed('TransactionFailed');
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(gateway.fundPreparations, 1);

      await tap(tester, 'Try again');
      expect(gateway.fundPreparations, 2);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
    });

    testWidgets('an uncertain failure resends the same fund, never a new '
        'one', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failFundSubmit = const HireBackendUnavailable('no answer');
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      await tap(tester, 'Try again');
      // The same preparation is relayed again (the relay is idempotent).
      expect(gateway.fundPreparations, 1);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
    });
  });

  group('HireSheet: an unfinished hire is resumed, never paid twice', () {
    testWidgets('closing the sheet mid-payment and reopening resumes the '
        'same hire', (tester) async {
      final store = MemoryHireFlowStore();
      final gateway = ScriptedHireGateway();
      final wallet = TestWallet(initialAddress: 'GUSER123')
        ..rejectPayloadOnce = 'AAAA-fund';
      await pumpSheet(tester, wallet: wallet, gateway: gateway, store: store);
      await confirm(tester, input: 'Audit my token');
      expect(find.text('Payment failed'), findsOneWidget);

      // The sheet is closed and opened again.
      await tester.pumpWidget(const SizedBox());
      await pumpSheet(tester, wallet: wallet, gateway: gateway, store: store);
      await tester.pump();

      expect(find.byKey(const ValueKey('hire-resume-note')), findsOneWidget);
      expect(find.text('Audit my token'), findsOneWidget);
      await tap(tester, 'Confirm & sign');

      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      // One request id, one hire, one create_job, one fund.
      expect(gateway.requestIds.toSet(), hasLength(1));
      expect(gateway.hireCount, 1);
      expect(wallet.signed.where((x) => x == 'AAAA-createJob'), hasLength(1));
      expect(gateway.submitted.last, 'signed:AAAA-fund');
    });

    testWidgets('after an app restart the stored hire is resumed with its '
        'own task', (tester) async {
      // The browser storage outlives the app: the same backing map.
      final browser = <String, String>{};
      final gateway = ScriptedHireGateway();
      final wallet = TestWallet(initialAddress: 'GUSER123')
        ..rejectPayloadOnce = 'AAAA-fund';
      await pumpSheet(
        tester,
        wallet: wallet,
        gateway: gateway,
        store: MemoryHireFlowStore(browser),
      );
      await confirm(tester, input: 'Audit my token');

      await tester.pumpWidget(const SizedBox());
      await pumpSheet(
        tester,
        wallet: wallet,
        gateway: gateway,
        store: MemoryHireFlowStore(browser),
      );
      await tester.pump();
      await tap(tester, 'Confirm & sign');

      expect(gateway.hireCount, 1);
      // The resumed hire keeps its task, so the request id still matches.
      expect(gateway.inputs.toSet(), {'Audit my token'});
    });

    testWidgets('a resumed hire that is already paid is never paid again', (
      tester,
    ) async {
      final store = MemoryHireFlowStore();
      final gateway = ScriptedHireGateway()
        ..crashAfterFundRelay = StateError('lost response');
      final wallet = TestWallet(initialAddress: 'GUSER123');
      await pumpSheet(tester, wallet: wallet, gateway: gateway, store: store);
      await confirm(tester);
      expect(gateway.submitted.last, 'signed:AAAA-fund');

      await tester.pumpWidget(const SizedBox());
      await pumpSheet(tester, wallet: wallet, gateway: gateway, store: store);
      await tester.pump();
      await tap(tester, 'Confirm & sign');

      expect(find.text('A payment for this hire was already sent.'), findsOne);
      expect(wallet.signed.where((x) => x == 'AAAA-fund'), hasLength(1));
      expect(gateway.hireCount, 1);
    });

    testWidgets('a finished hire is cleared: the next one is new', (
      tester,
    ) async {
      final store = MemoryHireFlowStore();
      final gateway = ScriptedHireGateway();
      final wallet = TestWallet(initialAddress: 'GUSER123');
      await pumpSheet(tester, wallet: wallet, gateway: gateway, store: store);
      await confirm(tester);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pumpSheet(tester, wallet: wallet, gateway: gateway, store: store);
      await tester.pump();
      expect(find.byKey(const ValueKey('hire-resume-note')), findsNothing);
      await confirm(tester, input: 'Another task');
      expect(gateway.hireCount, 2);
    });
  });

  group('Who pays? (hire as my agent, #312)', () {
    const owner = 'GOWNERWALLET123';

    FakeStudioGateway studioWith(List<StudioDraft> drafts) => FakeStudioGateway(
      delay: Duration.zero,
      seed: [for (final draft in drafts) (owner, draft)],
    );

    testWidgets('is not offered when the wallet owns no live agent', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        wallet: TestWallet(initialAddress: owner),
        studio: studioWith([savedDraft(1, name: 'Scout', agentId: '5')]),
      );
      await settle(tester);

      expect(find.byKey(const Key('hire-payer')), findsNothing);
      expect(find.text('Confirm & sign'), findsOneWidget);
    });

    testWidgets('the agent being hired is not offered as its own payer', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        wallet: TestWallet(initialAddress: owner),
        studio: studioWith([
          savedDraft(
            1,
            state: DraftDeployState.live,
            liveVersion: 1,
            agentId: '${_onChainAgent.registryId}',
          ),
        ]),
      );
      await settle(tester);

      expect(find.byKey(const Key('hire-payer')), findsNothing);
    });

    testWidgets('a live agent of the wallet hires and pays from its wallet', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: owner);
      final studio = studioWith([
        savedDraft(
          1,
          name: 'Scout',
          state: DraftDeployState.live,
          liveVersion: 1,
          agentId: '5',
        ),
      ]);
      await pumpSheet(tester, wallet: wallet, studio: studio);
      await settle(tester);

      expect(find.text('Who pays?'), findsOneWidget);
      expect(find.text('You (your wallet)'), findsOneWidget);
      await tap(tester, 'Your agent Scout (pays from its own wallet)');

      expect(find.byKey(const Key('hire-as-agent')), findsOneWidget);
      expect(find.text('Get testnet USDC'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('hire-input')),
        'Audit my token',
      );
      await tester.pump();
      await tap(tester, 'Hire with Scout');

      expect(studio.agentHires, [
        (
          hiringAgentId: 5,
          agentId: 9,
          input: 'Audit my token',
          budget: _onChainAgent.priceUsdcStroops,
        ),
      ]);
      // No wallet signature: the agent's custodied wallet pays.
      expect(wallet.signed, isEmpty);
      await advance(tester, const Duration(seconds: 8));
      expect(find.byKey(const Key('collab-progress')), findsOneWidget);
      expect(find.text('Payment released to the hired agent'), findsOneWidget);
      expect(find.byKey(const Key('collab-result')), findsOneWidget);
    });

    testWidgets('a refused agent hire shows a clear message', (tester) async {
      final studio =
          studioWith([
              savedDraft(
                1,
                name: 'Scout',
                state: DraftDeployState.live,
                liveVersion: 1,
                agentId: '5',
              ),
            ])
            ..nextHireError = const StudioAgentHireRefused(
              AgentHireRefusal.walletUnavailable,
            );
      await pumpSheet(
        tester,
        wallet: TestWallet(initialAddress: owner),
        studio: studio,
      );
      await settle(tester);
      await tap(tester, 'Your agent Scout (pays from its own wallet)');
      await tester.enterText(
        find.byKey(const ValueKey('hire-input')),
        'Audit my token',
      );
      await tester.pump();
      await tap(tester, 'Hire with Scout');

      expect(
        find.text("Your agent's wallet cannot pay right now. Try again later."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('collab-progress')), findsNothing);
    });
  });

  group('Subcontract reserve on the hire form (#334)', () {
    const offered = SubcontractTerms(
      reserveMaxStroops: 20000000,
      maxChildren: 2,
      suggestedReserveStroops: 30000000,
    );
    const section = ValueKey('hire-subcontract');
    const reserveField = ValueKey('hire-subcontract-reserve');
    const consentBox = ValueKey('hire-subcontract-consent');
    const relatedSwitch = ValueKey('hire-subcontract-related-party');

    Future<ScriptedHireGateway> open(
      WidgetTester tester, {
      SubcontractTerms terms = offered,
      Object? failTerms,
      WalletPort? wallet,
      HireFlowStore? store,
    }) async {
      final gateway = ScriptedHireGateway()
        ..terms = terms
        ..failTerms = failTerms;
      await pumpSheet(
        tester,
        wallet: wallet ?? TestWallet(initialAddress: 'GUSER123'),
        gateway: gateway,
        store: store,
      );
      await settle(tester);
      return gateway;
    }

    Future<void> setReserve(WidgetTester tester, String amount) async {
      await tester.ensureVisible(find.byKey(reserveField));
      await tester.enterText(find.byKey(reserveField), amount);
      await tester.pump();
    }

    Future<void> tick(WidgetTester tester, ValueKey<String> key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pump();
      await tester.tap(find.byKey(key));
      await tester.pump();
    }

    String reserveText(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(reserveField)).controller!.text;

    testWidgets('is hidden when the agent did not opt in', (tester) async {
      await open(
        tester,
        terms: const SubcontractTerms(
          reserveMaxStroops: 20000000,
          maxChildren: 0,
          suggestedReserveStroops: 0,
        ),
      );
      expect(find.byKey(section), findsNothing);
    });

    testWidgets('is hidden when the platform ceiling is 0', (tester) async {
      await open(
        tester,
        terms: const SubcontractTerms(
          reserveMaxStroops: 0,
          maxChildren: 2,
          suggestedReserveStroops: 30000000,
        ),
      );
      expect(find.byKey(section), findsNothing);
    });

    testWidgets('is hidden when the terms fail to load, and the hire still '
        'goes through without a reserve', (tester) async {
      final gateway = await open(
        tester,
        failTerms: const HireBackendUnavailable('down'),
      );
      expect(find.byKey(section), findsNothing);

      await confirm(tester);

      expect(gateway.reserves, [0]);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
    });

    testWidgets('is prefilled with the suggested reserve capped by the '
        'ceiling', (tester) async {
      await open(tester);
      expect(find.byKey(section), findsOneWidget);
      expect(reserveText(tester), '2.00');
    });

    testWidgets('a reserve above the ceiling is refused', (tester) async {
      final gateway = await open(tester);
      await setReserve(tester, '2.5');

      expect(find.text('Enter an amount from 0 to 2.00 USDC.'), findsOneWidget);
      await tick(tester, consentBox);
      await confirm(tester);
      expect(gateway.calls, isEmpty);
    });

    testWidgets('the consent is required only while there is a reserve', (
      tester,
    ) async {
      final gateway = await open(tester);
      expect(find.byKey(consentBox), findsOneWidget);
      await confirm(tester);
      expect(gateway.calls, isEmpty);

      await setReserve(tester, '0');
      expect(find.byKey(consentBox), findsNothing);
      await confirm(tester);
      expect(gateway.calls, contains('createHire'));
      expect(gateway.reserves, [0]);
    });

    testWidgets('the total and the funds check use the price plus the '
        'reserve, and createHire gets the reserve and the flag', (
      tester,
    ) async {
      final gateway = await open(tester);
      await setReserve(tester, '1');

      expect(find.byKey(const ValueKey('hire-total')), findsOneWidget);
      expect(find.text('5.50 USDC'), findsOneWidget);
      expect(
        find.text('The unspent reserve is refunded to you when the hire ends.'),
        findsOneWidget,
      );

      await tick(tester, relatedSwitch);
      await tick(tester, consentBox);
      await confirm(tester);

      expect(gateway.fundsChecks, [45000000 + 10000000]);
      expect(gateway.reserves, [10000000]);
      expect(gateway.relatedPartyFlags, [false]);
    });

    testWidgets('a plain hire shows the same summary and sends no reserve', (
      tester,
    ) async {
      final gateway = await open(tester, terms: SubcontractTerms.none);
      expect(find.byKey(const ValueKey('hire-total')), findsNothing);
      expect(find.text('Subcontract reserve'), findsNothing);

      await confirm(tester);

      expect(gateway.fundsChecks, [45000000]);
      expect(gateway.reserves, [0]);
      expect(gateway.relatedPartyFlags, [true]);
    });

    testWidgets('a started hire shows its reserve and flag read-only, and a '
        'resume reuses them', (tester) async {
      final store = MemoryHireFlowStore();
      final wallet = TestWallet(initialAddress: 'GUSER123')
        ..rejectPayloadOnce = 'AAAA-fund';
      final gateway = await open(tester, wallet: wallet, store: store);
      await setReserve(tester, '1');
      await tick(tester, relatedSwitch);
      await tick(tester, consentBox);
      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pumpSheet(tester, wallet: wallet, gateway: gateway, store: store);
      await settle(tester);

      expect(reserveText(tester), '1.00');
      expect(
        tester.widget<TextField>(find.byKey(reserveField)).readOnly,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(find.byKey(relatedSwitch)).onChanged,
        isNull,
      );
      await tap(tester, 'Confirm & sign');

      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      expect(gateway.requestIds.toSet(), hasLength(1));
      expect(gateway.reserves, [10000000, 10000000]);
      expect(gateway.relatedPartyFlags, [false, false]);
    });
  });

  group('Wallet session on the hire form (#334 T8.2)', () {
    const offered = SubcontractTerms(
      reserveMaxStroops: 20000000,
      maxChildren: 2,
      suggestedReserveStroops: 30000000,
    );
    const section = ValueKey('hire-subcontract');
    const reserveField = ValueKey('hire-subcontract-reserve');
    const consentBox = ValueKey('hire-subcontract-consent');

    Future<
      ({
        ScriptedHireGateway gateway,
        _TestSignIn signIn,
        _RecordingStudio studio,
        TestWallet wallet,
      })
    >
    open(
      WidgetTester tester, {
      SubcontractTerms terms = offered,
      bool signedIn = false,
    }) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()..terms = terms;
      final signIn = _TestSignIn(signedInAs: signedIn ? 'GUSER123' : null);
      final studio = _RecordingStudio();
      await pumpSheet(
        tester,
        wallet: wallet,
        gateway: gateway,
        studio: studio,
        signIn: signIn,
      );
      await settle(tester);
      return (gateway: gateway, signIn: signIn, studio: studio, wallet: wallet);
    }

    testWidgets('opening the sheet without a session reads nothing and opens '
        'no wallet prompt', (tester) async {
      final opened = await open(tester);

      expect(opened.gateway.termsReads, 0);
      expect(opened.studio.owners, isEmpty);
      expect(opened.signIn.prompts, isEmpty);
      expect(opened.wallet.challenges, isEmpty);
      expect(find.byKey(section), findsNothing);
    });

    testWidgets('opening the sheet with a session reads the terms and the '
        'paying agents without a prompt', (tester) async {
      final opened = await open(tester, signedIn: true);

      expect(opened.gateway.termsReads, 1);
      expect(opened.studio.owners, ['GUSER123']);
      expect(opened.signIn.prompts, isEmpty);
      expect(opened.wallet.challenges, isEmpty);
      expect(find.byKey(section), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(reserveField)).controller!.text,
        '2.00',
      );
    });

    testWidgets('confirming without a session signs in once, then shows the '
        'reserve before anything is created or paid', (tester) async {
      final opened = await open(tester);

      await confirm(tester);

      expect(opened.signIn.prompts, ['GUSER123']);
      expect(opened.gateway.termsReads, 1);
      expect(find.byKey(section), findsOneWidget);
      expect(opened.gateway.reserves, isEmpty);
      expect(opened.wallet.signed, isEmpty);

      await tester.ensureVisible(find.byKey(consentBox));
      await tester.pump();
      await tester.tap(find.byKey(consentBox));
      await tester.pump();
      await tap(tester, 'Confirm & sign');

      expect(opened.signIn.prompts, ['GUSER123']);
      expect(opened.gateway.reserves, [20000000]);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
    });

    testWidgets('confirming without a session hires right after the sign-in '
        'when the agent offers no reserve', (tester) async {
      final opened = await open(tester, terms: SubcontractTerms.none);

      await confirm(tester);

      expect(opened.signIn.prompts, ['GUSER123']);
      expect(opened.gateway.reserves, [0]);
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
    });

    testWidgets('a second tap while signing in opens no second prompt', (
      tester,
    ) async {
      final opened = await open(tester);
      final gate = Completer<void>();
      opened.signIn.gate = gate;
      await tester.enterText(
        find.byKey(const ValueKey('hire-input')),
        'Audit my token',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm & sign'));
      await tester.tap(find.text('Confirm & sign'));
      await tester.pump();
      await tester.tap(find.text('Confirm & sign'));
      await tester.pump();
      gate.complete();
      await settle(tester);

      expect(opened.signIn.prompts, ['GUSER123']);
      expect(opened.gateway.reserves, isEmpty);
      expect(find.byKey(section), findsOneWidget);
    });

    testWidgets('a session of another wallet is not used', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()..terms = offered;
      final studio = _RecordingStudio();
      await pumpSheet(
        tester,
        wallet: wallet,
        gateway: gateway,
        studio: studio,
        signIn: _TestSignIn(signedInAs: 'GOTHER456'),
      );
      await settle(tester);

      expect(gateway.termsReads, 0);
      expect(studio.owners, isEmpty);
      expect(find.byKey(section), findsNothing);
    });

    testWidgets('declining the sign-in starts nothing', (tester) async {
      final opened = await open(tester);
      opened.wallet.failNextChallenge = const WalletSignatureRejected();

      await confirm(tester);

      expect(opened.signIn.prompts, isEmpty);
      expect(opened.gateway.termsReads, 0);
      expect(opened.gateway.reserves, isEmpty);
      expect(opened.wallet.signed, isEmpty);
    });
  });
}

/// A wallet session that signs in through the wallet, like `WalletSession`.
class _TestSignIn implements WalletSignIn {
  _TestSignIn({this.signedInAs});

  String? signedInAs;

  /// When set, a sign-in waits for it, like an open wallet prompt.
  Completer<void>? gate;

  /// Wallets that were asked to sign in, in order.
  final prompts = <String>[];

  @override
  Future<bool> isSignedInAs(String wallet) async => signedInAs == wallet;

  @override
  Future<void> ensureSignedIn(
    String wallet,
    Future<String> Function(SignInChallenge challenge) sign,
  ) async {
    if (signedInAs == wallet) return;
    await gate?.future;
    await sign(
      const SignInChallenge(
        transactionXdr: 'session-challenge',
        networkPassphrase: stellarTestnetPassphrase,
      ),
    );
    prompts.add(wallet);
    signedInAs = wallet;
  }
}

/// The demo Studio, recording whose drafts were listed.
class _RecordingStudio extends FakeStudioGateway {
  _RecordingStudio() : super(delay: Duration.zero);

  final owners = <String>[];

  @override
  Future<List<StudioDraft>> listDrafts({required String owner}) {
    owners.add(owner);
    return super.listDrafts(owner: owner);
  }
}
