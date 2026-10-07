import '../domain/agent_draft.dart';
import '../domain/stellar_format.dart';
import 'deploy_gateway.dart';

/// Demo [DeployGateway]: fake ids after short delays, no network. It stands
/// in for the register/deploy endpoint until #18 ships.
class FakeDeployGateway implements DeployGateway {
  FakeDeployGateway({
    FakeLedgerIds? ids,
    this.prepareDelay = const Duration(milliseconds: 600),
    this.registerDelay = const Duration(milliseconds: 1000),
    this.activateDelay = const Duration(milliseconds: 700),
    int firstAgentId = 100,
  }) : _ids = ids ?? FakeLedgerIds(),
       _nextAgentId = firstAgentId;

  @override
  bool get isDemo => true;

  final FakeLedgerIds _ids;
  final Duration prepareDelay;
  final Duration registerDelay;
  final Duration activateDelay;
  int _nextAgentId;

  @override
  Future<PreparedDeploy> prepare(
    AgentDraft draft, {
    required String builder,
  }) async {
    await Future<void>.delayed(prepareDelay);
    return PreparedDeploy(
      preparationId: _ids.txHash().substring(0, 16),
      unsignedTransaction: 'AAAA-fake-register_full-envelope',
    );
  }

  @override
  Future<Registration> submitRegistration(
    PreparedDeploy prepared,
    String signedTransaction,
  ) async {
    await Future<void>.delayed(registerDelay);
    return Registration(
      agentId: _nextAgentId++,
      transactionHash: _ids.txHash(),
    );
  }

  @override
  Future<String> activate(Registration registration) async {
    await Future<void>.delayed(activateDelay);
    return _ids.accountAddress();
  }
}
