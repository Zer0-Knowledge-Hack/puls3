import '../wallet/demo_envelope.dart';
import 'hire_gateway.dart';
import 'wallet_session.dart';

/// Labelled demo of the hire backend, used until the deployed server accepts
/// wallet sessions (#136). It prepares harmless, never-submitted Testnet
/// envelopes, so a real wallet still shows its prompts, and moves no funds.
class FakeHireGateway implements HireGateway {
  FakeHireGateway({this.delay = const Duration(milliseconds: 400)});

  /// Simulated server latency.
  final Duration delay;

  var _nextHire = 1;
  var _nextPreparation = 1;
  final _consumers = <int, String>{};

  @override
  bool get isDemo => true;

  /// The demo has no server session.
  @override
  Future<void> ensureSignedIn(String wallet, ChallengeSigner sign) async {}

  @override
  Future<void> forgetSession() async {}

  @override
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) async {
    await Future<void>.delayed(delay);
    final hireId = _nextHire++;
    _consumers[hireId] = consumer;
    return HireStart(hireId: hireId, createJob: _prepare(hireId, 'createJob'));
  }

  @override
  Future<EscrowPreparation> prepareCreateJob(int hireId) async {
    await Future<void>.delayed(delay);
    return _prepare(hireId, 'createJob');
  }

  @override
  Future<EscrowPreparation> prepareFund(int hireId) async {
    await Future<void>.delayed(delay);
    return _prepare(hireId, 'fund');
  }

  @override
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) async {
    await Future<void>.delayed(delay);
    // Nothing is sent: no hash, no explorer link.
    return const EscrowSubmission(transactionHash: '', state: 'demo');
  }

  /// The demo creates no hire, so there is none to read.
  @override
  Future<HireProgress> getHire(int hireId, String consumer) async {
    await Future<void>.delayed(delay);
    throw const HireNotFound();
  }

  EscrowPreparation _prepare(int hireId, String purpose) => EscrowPreparation(
    preparationId: 'demo-${_nextPreparation++}',
    purpose: purpose,
    unsignedTransaction: demoEnvelope(
      _consumers[hireId] ?? '',
      note: 'hire $hireId $purpose',
    ),
  );
}
