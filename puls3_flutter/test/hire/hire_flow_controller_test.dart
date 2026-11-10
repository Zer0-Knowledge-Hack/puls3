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
}
