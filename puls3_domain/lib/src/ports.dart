import 'entities.dart';
import 'stellar_address.dart';
import 'values.dart';

/// Loads and stores agents. Implemented by the backend (Serverpod ORM).
abstract interface class AgentRepository {
  /// The agent with [id], or `null` if there is none.
  Future<Agent?> findById(AgentId id);

  /// Every agent in the catalog.
  Future<List<Agent>> list();

  /// Stores [agent], replacing any agent with the same id.
  Future<void> save(Agent agent);
}

/// The unique index a payment violated: each one enforces one rule.
enum HirePaymentIndex {
  /// The hire already has a payment.
  hireId,

  /// The transaction already paid a hire (replay).
  transactionHash,

  /// The escrow job is already bound to a hire.
  jobId,
}

/// A payment hit a unique index. Thrown by [HireRepository.recordPayment].
final class HirePaymentConflict implements Exception {
  const HirePaymentConflict(this.index);

  final HirePaymentIndex index;

  @override
  String toString() => 'HirePaymentConflict: ${index.name}';
}

/// Loads and stores hires and their payments. Implemented by the backend.
abstract interface class HireRepository {
  /// Stores a new hire in [HireStatus.requested] and returns it with its id.
  /// [expiredAt] (unix seconds) is the `expired_at` the server prepares
  /// `create_job` with.
  Future<Hire> create({
    required AgentId agentId,
    required StellarAddress consumer,
    required UsdcAmount price,
    required int manifestVersion,
    required int expiredAt,
  });

  /// The hire with [id], paid if it has a payment, or `null` if there is none.
  Future<Hire?> findById(HireId id);

  /// The `expired_at` stored by [create] for hire [id] (unix seconds), or
  /// `null` if there is no such hire.
  Future<int?> preparedExpiry(HireId id);

  /// Stores [payment] for [paid] in one atomic insert and returns the stored
  /// paid hire. A retry of the same hire and transaction returns the same
  /// stored hire.
  ///
  /// Throws [HirePaymentConflict] naming the violated index otherwise.
  Future<Hire> recordPayment(Hire paid, Payment payment, int jobId);
}

/// Reads the chain. Implemented by the Stellar RPC adapter (ADR-0003).
abstract interface class LedgerPort {
  /// The USDC payment made by [transaction], or `null` if the transaction
  /// was not found, failed, or is not a USDC transfer.
  Future<Payment?> findPayment(TransactionHash transaction);

  /// The wallet that receives payments for [agent], or `null` if it has none.
  Future<StellarAddress?> agentWallet(AgentId agent);
}

/// Runs agents. Implemented by the agent runtime (#20).
abstract interface class AgentRuntimePort {
  /// Runs [agent] on [input] and returns its output.
  Future<String> run(Agent agent, String input);
}
