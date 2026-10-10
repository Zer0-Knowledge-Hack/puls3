import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/hire/fake_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/screens/hire_sheet.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

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
  bool createJobSubmitted = false;
  bool fundSubmitted = false;
}

/// A non-demo hire backend that records every call and, like the server,
/// returns the same hire for the same request id (api.md, "createHire
/// idempotency") and refuses a second fund once one was relayed.
class ScriptedHireGateway implements HireGateway {
  final requestIds = <String>[];
  final inputs = <String>[];
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

  @override
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) async {
    calls.add('createHire');
    requestIds.add(requestId);
    inputs.add(input);
    final failure = failCreate;
    if (failure != null) {
      failCreate = null;
      throw failure;
    }
    final hire = _byRequest.putIfAbsent(requestId, () {
      final created = _ScriptedHire(_nextHire++);
      _byId[created.id] = created;
      return created;
    });
    return HireStart(
      hireId: hire.id,
      // Null once the create_job was submitted, as the server does.
      createJob: hire.createJobSubmitted ? null : _prep('createJob'),
    );
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
}) async {
  Puls3Fonts.useGoogleFonts = false;
  opened.clear();
  await tester.pumpWidget(
    MaterialApp(
      theme: Puls3Theme.dark(),
      home: AppScope(
        catalog: AgentCatalog(InMemoryAgentRepository([agent])),
        wallet: WalletController(wallet),
        deployGateway: FakeDeployGateway(),
        hireGateway: gateway ?? FakeHireGateway(delay: Duration.zero),
        hireFlowStore: store ?? MemoryHireFlowStore(),
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

      await tap(tester, 'View on StellarExpert');
      expect(opened.single.toString(), contains('/tx/fa11ce'));
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

    testWidgets('the wallet signs in before the hire is created (#136)', (
      tester,
    ) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);

      expect(gateway.calls.take(2), ['signIn', 'createHire']);
      expect(gateway.signIns, ['GUSER123']);
      expect(wallet.challenges, ['challenge']);
      expect(gateway.hireCount, 1);
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
}
