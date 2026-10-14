import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../hire/hire_endpoint.dart';
import 'feedback_service.dart';

/// Lets the consumer of a completed hire rate it (api.md, `FeedbackEndpoint`).
///
/// It shares the session and services seams of [HireEndpoint]: every method
/// first resolves the caller through the session wallet and only then builds
/// the services, so a caller without a session reaches no store and no chain.
/// The call is relayed, never signed, by the server; the registry call comes
/// from `ReputationCalls` (`PULS3_STELLAR_REPUTATION_REGISTRY`).
class FeedbackEndpoint extends Endpoint {
  /// A request without an access token is HTTP 401 before the method runs.
  @override
  bool get requireLogin => true;

  /// Whether the caller may rate hire [hireId] and, when not, why. [client]
  /// must be the session wallet.
  Future<FeedbackEligibility> getFeedbackEligibility(
    Session session,
    int hireId,
    String client,
  ) async {
    final wallet = await HireEndpoint.sessionWalletOf(session);
    _requireSameWallet(wallet, client);
    return _service(session).eligibility(wallet, hireId);
  }

  /// The unsigned `give_feedback` of hire [hireId], with [score] and
  /// [comment], for the session wallet to sign.
  Future<PreparedTransaction> prepareFeedback(
    Session session,
    int hireId,
    int score,
    String comment,
  ) async {
    final wallet = await HireEndpoint.sessionWalletOf(session);
    return _service(session).prepare(wallet, hireId, score, comment);
  }

  /// Verifies the wallet-signed envelope of [preparationId] and relays it.
  Future<HireDetail> submitFeedback(
    Session session,
    int hireId,
    String preparationId,
    String signedTransactionXdr,
  ) async {
    final wallet = await HireEndpoint.sessionWalletOf(session);
    return _service(session).submit(
      wallet,
      hireId,
      preparationId,
      signedTransactionXdr,
    );
  }

  static FeedbackService _service(Session session) =>
      HireEndpoint.servicesOf(session).feedback ??
      (throw StateError('HireServices has no feedback service'));

  /// Fails with `InvalidStellarAddress` or `WalletMismatch` unless [address]
  /// is the session [wallet].
  static void _requireSameWallet(StellarAddress wallet, String address) {
    final StellarAddress parsed;
    try {
      parsed = StellarAddress.parse(address);
    } on InvalidStellarAddress {
      throw Puls3ApiException(code: 'InvalidStellarAddress');
    }
    if (parsed != wallet) throw Puls3ApiException(code: 'WalletMismatch');
  }
}
