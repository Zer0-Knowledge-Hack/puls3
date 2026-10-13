import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../generated/protocol.dart';
import '../ledger/xdr_invoke_encoder.dart' show ScArg;

/// A Soroban contract invocation the session wallet signs: the contract, the
/// function and its arguments.
final class ContractCall {
  const ContractCall({
    required this.contract,
    required this.function,
    required this.args,
  });

  final StellarAddress contract;
  final String function;
  final List<ScArg> args;
}

/// Builds the `give_feedback` call of the Reputation Registry.
///
/// The arguments follow the Stellar 8004 drop-in interface of #14, which is
/// not fixed yet, so the real call is bound when #14 lands. Until then the
/// production wiring is [UnwiredReputationCalls].
abstract interface class ReputationCalls {
  /// The call by which [client] leaves [feedback] about [agent].
  ContractCall giveFeedback({
    required StellarAddress client,
    required AgentId agent,
    required Feedback feedback,
  });
}

/// The production [ReputationCalls] until #14 lands: it has no registry to
/// call, so it fails with [HireConfigurationMissing] before anything is
/// prepared.
final class UnwiredReputationCalls implements ReputationCalls {
  const UnwiredReputationCalls();

  /// The setting that is missing: the Reputation Registry contract.
  static const setting = 'PULS3_STELLAR_REPUTATION_REGISTRY';

  @override
  ContractCall giveFeedback({
    required StellarAddress client,
    required AgentId agent,
    required Feedback feedback,
  }) => throw HireConfigurationMissing(setting: setting);
}

/// The production [ReputationRegistry] until #14 lands. It has no registry to
/// read, so every agent has no feedback and the catalog shows the #11
/// empty-input value, as it does today. It cannot record feedback: the server
/// only relays the wallet-signed call through [ReputationCalls].
final class UnwiredReputationRegistry implements ReputationRegistry {
  const UnwiredReputationRegistry();

  @override
  Future<List<Feedback>> feedbacksOf(AgentId agent) async => const [];

  @override
  Future<TransactionHash> giveFeedback(Feedback feedback) =>
      throw HireConfigurationMissing(setting: UnwiredReputationCalls.setting);
}
