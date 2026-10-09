import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/hire/fake_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/screens/hire_sheet.dart';
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

/// A non-demo hire backend that records every call.
class ScriptedHireGateway implements HireGateway {
  final requestIds = <String>[];
  final submitted = <String>[];
  var createJobPreparations = 0;
  var fundPreparations = 0;

  /// When set, the next call to that step fails with it once.
  HireGatewayException? failCreate;
  HireGatewayException? failNextSubmit;

  /// When set, the next `fund` submission fails with it once.
  HireGatewayException? failFundSubmit;

  /// When set, the next `fund` submission throws it once after relaying:
  /// an unexpected failure once funds may have moved.
  Object? crashAfterFundRelay;

  @override
  bool get isDemo => false;

  @override
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) async {
    requestIds.add(requestId);
    final failure = failCreate;
    if (failure != null) {
      failCreate = null;
      throw failure;
    }
    return HireStart(hireId: 3, createJob: _prep('createJob'));
  }

  @override
  Future<EscrowPreparation> prepareCreateJob(int hireId) async {
    createJobPreparations++;
    return _prep('createJob');
  }

  @override
  Future<EscrowPreparation> prepareFund(int hireId) async {
    fundPreparations++;
    return _prep('fund');
  }

  @override
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) async {
    final failure = failNextSubmit;
    if (failure != null) {
      failNextSubmit = null;
      throw failure;
    }
    final crash = crashAfterFundRelay;
    if (crash != null && preparation.purpose == 'fund') {
      crashAfterFundRelay = null;
      submitted.add(signedTransaction);
      throw crash;
    }
    final fundFailure = failFundSubmit;
    if (fundFailure != null && preparation.purpose == 'fund') {
      failFundSubmit = null;
      throw fundFailure;
    }
    submitted.add(signedTransaction);
    return EscrowSubmission(
      transactionHash: preparation.purpose == 'fund'
          ? 'fa11ce0000000000000000000000000000000000000000000000000000000001'
          : 'c0ffee',
      state: 'submitted',
    );
  }

  EscrowPreparation _prep(String purpose) => EscrowPreparation(
    preparationId: 'prep-$purpose',
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

    testWidgets('without a wallet session the error says so; nothing is '
        'signed', (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');
      final gateway = ScriptedHireGateway()
        ..failCreate = const HireNotSignedIn();
      await pumpSheet(tester, wallet: wallet, gateway: gateway);

      await confirm(tester);
      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.text('Sign-in with your wallet is not available yet.'),
        findsOneWidget,
      );
      expect(wallet.signed, isEmpty);
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
}
