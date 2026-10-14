import 'dart:typed_data';

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

/// Builds the `give_feedback` call of the Reputation Registry (#14).
///
/// The production implementation is [SorobanReputationCalls]; without a
/// configured registry the wiring falls back to [UnwiredReputationCalls].
abstract interface class ReputationCalls {
  /// The call by which [client] leaves [feedback] about [agent].
  ContractCall giveFeedback({
    required StellarAddress client,
    required AgentId agent,
    required Feedback feedback,
  });
}

/// The real `give_feedback` of the Reputation Registry deployed by #14
/// (`contracts/contracts/reputation-registry/src/lib.rs`):
///
/// ```text
/// give_feedback(caller: Address, agent_id: u32, value: i128,
///   value_decimals: u32, tag1: String, tag2: String, endpoint: String,
///   feedback_uri: String, feedback_hash: BytesN<32>) -> Result<(), _>
/// ```
///
/// The registry stores `value`, `value_decimals` and both tags; `endpoint`,
/// `feedback_uri` and `feedback_hash` are only emitted in `NewFeedback`. What
/// is sent:
///
/// - `caller` is the client, who signs (`caller.require_auth()`).
/// - `value` is the score (1 to 5, the scale of #11) and `value_decimals` is
///   0, so the stored value is the score itself.
/// - `tag1`, `tag2` and `endpoint` are empty: the registry's summary filter
///   treats an empty tag as "any", and puls3 has no tag or endpoint scheme.
/// - `feedback_uri` is empty and `feedback_hash` is 32 zero bytes: puls3 has
///   no off-chain host for the comment, so the comment is not sent. It stays
///   in the domain [Feedback] only.
///
/// The hire is not an argument either: the registry has no hire field (the
/// paid-hire rule is applied off-chain, ADR-0005 D5).
final class SorobanReputationCalls implements ReputationCalls {
  const SorobanReputationCalls({required this.registry});

  /// The Reputation Registry contract.
  final StellarAddress registry;

  /// The registry's own function name.
  static const function = 'give_feedback';

  /// The `value_decimals` of every score: a score is a whole number.
  static const scoreDecimals = 0;

  @override
  ContractCall giveFeedback({
    required StellarAddress client,
    required AgentId agent,
    required Feedback feedback,
  }) => ContractCall(
    contract: registry,
    function: function,
    args: [
      ScArg.address(client),
      ScArg.u32(agent.value),
      ScArg.i128(feedback.score),
      const ScArg.u32(scoreDecimals),
      const ScArg.string(''),
      const ScArg.string(''),
      const ScArg.string(''),
      const ScArg.string(''),
      ScArg.bytes32(Uint8List(32)),
    ],
  );
}

/// The [ReputationCalls] used while `PULS3_STELLAR_REPUTATION_REGISTRY` is
/// unset: it has no registry to call, so it fails with
/// [HireConfigurationMissing] before anything is prepared.
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

/// The [ReputationRegistry] used while `PULS3_STELLAR_REPUTATION_REGISTRY` is
/// unset. It has no registry to read, so every agent has no feedback and the
/// catalog shows the #11 empty-input value. It cannot record feedback: the server
/// only relays the wallet-signed call through [ReputationCalls].
final class UnwiredReputationRegistry implements ReputationRegistry {
  const UnwiredReputationRegistry();

  @override
  Future<List<Feedback>> feedbacksOf(AgentId agent) async => const [];

  @override
  Future<TransactionHash> giveFeedback(Feedback feedback) =>
      throw HireConfigurationMissing(setting: UnwiredReputationCalls.setting);
}
