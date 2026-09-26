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
