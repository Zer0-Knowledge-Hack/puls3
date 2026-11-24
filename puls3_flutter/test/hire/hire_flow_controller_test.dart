import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/hire/hire_flow_controller.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';

import '../screens/hire_sheet_test.dart';

/// A wallet whose account can change between runs.
class _SwitchingWallet extends TestWallet {
  String account = 'GACCOUNTA';

  @override
  String? get address => account;

  @override
  Future<String> connect() async => account;
}

const _agent = Agent(
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

void main() {
  test('switching accounts starts a new hire instead of reusing the previous '
      'account\'s hire and request id', () async {
    final wallet = _SwitchingWallet()..rejectPayloadOnce = 'AAAA-fund';
    final gateway = ScriptedHireGateway();
    final controller = HireFlowController(
      agent: _agent,
      gateway: gateway,
      wallet: WalletController(wallet),
      store: MemoryHireFlowStore(),
    );

    await controller.run('Audit my token');
    expect(controller.error, isNotNull);
    expect(controller.hireId, 3);

    wallet.account = 'GACCOUNTB';
    await controller.run('Audit my token');

    expect(gateway.requestIds, hasLength(2));
    expect(gateway.requestIds.first, isNot(gateway.requestIds.last));
    expect(gateway.hireCount, 2);
    expect(controller.hireId, 4);
    expect(controller.step, HireStep.done);
  });

  test('an ended session is forgotten and the retry signs in again', () async {
    final gateway = ScriptedHireGateway()..failCreate = const HireNotSignedIn();
    final controller = HireFlowController(
      agent: _agent,
      gateway: gateway,
      wallet: WalletController(TestWallet()),
      store: MemoryHireFlowStore(),
    );

    await controller.run('Audit my token');

    expect(controller.error, isNotNull);
    expect(controller.step, isNot(HireStep.done));
    expect(gateway.forgottenSessions, 1);

    await controller.run('Audit my token');

    // The first run signed in before createHire refused it; the retry
    // challenges again instead of keeping the dead session.
    expect(gateway.signIns, hasLength(2));
    expect(controller.error, isNull);
    expect(controller.step, HireStep.done);
  });

  group('subcontract reserve (#334)', () {
    const terms = SubcontractTerms(
      reserveMaxStroops: 20000000,
      maxChildren: 2,
      suggestedReserveStroops: 30000000,
    );

    HireFlowController controllerFor(
      ScriptedHireGateway gateway, {
      HireFlowStore? store,
      TestWallet? wallet,
    }) => HireFlowController(
      agent: _agent,
      gateway: gateway,
      wallet: WalletController(wallet ?? TestWallet()),
      store: store ?? MemoryHireFlowStore(),
    );

    test('terms that fail to load leave no subcontract offer', () async {
      final gateway = ScriptedHireGateway()
        ..terms = terms
        ..failTerms = const HireBackendUnavailable('down');
      final controller = controllerFor(gateway);

      await controller.loadTerms();

      expect(controller.terms.offered, isFalse);
    });

    test('the prefill is the suggested reserve capped by the ceiling', () {
      expect(terms.prefillStroops, 20000000);
      expect(
        const SubcontractTerms(
          reserveMaxStroops: 20000000,
          maxChildren: 1,
          suggestedReserveStroops: 5000000,
        ).prefillStroops,
        5000000,
      );
    });

    test(
      'a reserve above the ceiling is refused before any signature',
      () async {
        final gateway = ScriptedHireGateway()..terms = terms;
        final wallet = TestWallet();
        final controller = controllerFor(gateway, wallet: wallet);
        await controller.loadTerms();

        await controller.run('Audit my token', subcontractReserve: 20000001);

        expect(controller.error, isNotNull);
        expect(gateway.calls, isEmpty);
        expect(wallet.signed, isEmpty);
      },
    );

    test('the funds check covers the price plus the reserve', () async {
      final gateway = ScriptedHireGateway()..terms = terms;
      final controller = controllerFor(gateway);
      await controller.loadTerms();

      await controller.run('Audit my token', subcontractReserve: 10000000);

      expect(gateway.fundsChecks, [45000000 + 10000000]);
    });

    test(
      'createHire receives the reserve and the related-party flag',
      () async {
        final gateway = ScriptedHireGateway()..terms = terms;
        final controller = controllerFor(gateway);
        await controller.loadTerms();

        await controller.run(
          'Audit my token',
          subcontractReserve: 10000000,
          allowRelatedParty: false,
        );

        expect(controller.step, HireStep.done);
        expect(gateway.reserves, [10000000]);
        expect(gateway.relatedPartyFlags, [false]);
      },
    );

    test('a plain hire calls createHire as before', () async {
      final gateway = ScriptedHireGateway();
      final controller = controllerFor(gateway);
      await controller.loadTerms();

      await controller.run('Audit my token');

      expect(controller.step, HireStep.done);
      expect(gateway.reserves, [0]);
      expect(gateway.relatedPartyFlags, [true]);
      expect(gateway.fundsChecks, [45000000]);
    });

    test('a resumed pending hire reuses its stored reserve and flag', () async {
      final store = MemoryHireFlowStore();
      store.write(
        pendingHireKey('GTESTUSERWALLET1234567890', '9'),
        const PendingHire(
          requestId: 'req-stored',
          input: 'Audit my token',
          subcontractReserve: 10000000,
          allowRelatedParty: false,
        ),
      );
      final gateway = ScriptedHireGateway()..terms = terms;
      final controller = controllerFor(gateway, store: store);

      expect(controller.restore('GTESTUSERWALLET1234567890'), 'Audit my token');
      expect(controller.subcontractReserve, 10000000);
      expect(controller.allowRelatedParty, isFalse);
      // The sheet's own values are ignored: the stored hire keeps its terms.
      await controller.run('Something else');

      expect(gateway.requestIds, ['req-stored']);
      expect(gateway.reserves, [10000000]);
      expect(gateway.relatedPartyFlags, [false]);
      expect(controller.step, HireStep.done);
    });
  });
}
