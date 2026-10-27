import '../wallet/demo_envelope.dart';
import 'hire_gateway.dart';
import 'wallet_session.dart';

/// Labelled demo of the hire backend. It prepares harmless, never-submitted
/// Testnet envelopes, so a real wallet still shows its prompts, and moves
/// no funds. Created hires are readable as submitted so F6 can be walked
/// without a server.
class FakeHireGateway implements HireGateway {
  FakeHireGateway({this.delay = const Duration(milliseconds: 400)});

  /// Simulated server latency.
  final Duration delay;

  var _nextHire = 1;
  var _nextPreparation = 1;
  final _consumers = <int, String>{};
  final _progress = <int, HireProgress>{};

  @override
  bool get isDemo => true;

  /// The demo has no server session.
  @override
  Future<void> ensureSignedIn(String wallet, ChallengeSigner sign) async {}

  @override
  Future<void> forgetSession() async {}

  /// The demo moves no funds, so any wallet can run it.
  @override
  Future<void> checkFunds(String consumer, int priceUsdcStroops) async {}

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
    _progress[hireId] = _submitted(hireId, input);
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
  Future<EscrowPreparation> prepareComplete(int hireId) async {
    await Future<void>.delayed(delay);
    return _prepare(hireId, 'complete');
  }

  @override
  Future<EscrowPreparation> prepareReject(int hireId, String reason) async {
    await Future<void>.delayed(delay);
    return _prepare(hireId, 'reject');
  }

  @override
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) async {
    await Future<void>.delayed(delay);
    final current = _progress[hireId];
    if (current != null) {
      if (preparation.purpose == 'complete') {
        _progress[hireId] = _copy(current, status: 'completed');
      } else if (preparation.purpose == 'reject') {
        _progress[hireId] = _copy(
          current,
          status: 'rejected',
          rejectedFrom: current.status ?? 'submitted',
        );
      }
    }
    // Nothing is sent: no hash, no explorer link.
    return const EscrowSubmission(transactionHash: '', state: 'demo');
  }

  @override
  Future<HireProgress> getHire(int hireId, String consumer) async {
    await Future<void>.delayed(delay);
    if (_consumers[hireId] != consumer) throw const HireNotFound();
    final hire = _progress[hireId];
    if (hire == null) throw const HireNotFound();
    return hire;
  }

  EscrowPreparation _prepare(int hireId, String purpose) => EscrowPreparation(
    preparationId: 'demo-${_nextPreparation++}',
    purpose: purpose,
    unsignedTransaction: demoEnvelope(
      _consumers[hireId] ?? '',
      note: 'hire $hireId $purpose',
    ),
  );

  HireProgress _submitted(int hireId, String input) => HireProgress(
    hireId: hireId,
    agentName: 'Demo agent',
    priceUsdcStroops: 1,
    input: input,
    status: 'submitted',
    result: 'Demo result. No funds moved.',
    approvalDeadline: DateTime.now().toUtc().add(const Duration(hours: 24)),
  );

  HireProgress _copy(
    HireProgress hire, {
    required String status,
    String? rejectedFrom,
  }) => HireProgress(
    hireId: hire.hireId,
    agentName: hire.agentName,
    priceUsdcStroops: hire.priceUsdcStroops,
    input: hire.input,
    status: status,
    runtimeStatus: hire.runtimeStatus,
    failureReason: hire.failureReason,
    rejectedFrom: rejectedFrom ?? hire.rejectedFrom,
    result: hire.result,
    paymentTransaction: hire.paymentTransaction,
    paymentExplorerUrl: hire.paymentExplorerUrl,
    approvalDeadline: hire.approvalDeadline,
    decisionTransaction: hire.decisionTransaction,
    decisionExplorerUrl: hire.decisionExplorerUrl,
  );
}
