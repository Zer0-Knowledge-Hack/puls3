import 'package:puls3_domain/puls3_domain.dart' show ReputationRegistry;

import '../ledger/contract_reader.dart';
import '../ledger/soroban_reputation_registry.dart';
import '../ledger/stellar_config.dart';
import 'reputation_calls.dart';

/// The [ReputationCalls] of [config]: the real `give_feedback` once
/// `PULS3_STELLAR_REPUTATION_REGISTRY` is set, else [UnwiredReputationCalls],
/// which fails closed with `HireConfigurationMissing`.
ReputationCalls reputationCallsFor(StellarConfig config) {
  final registry = config.reputationRegistry;
  return registry == null
      ? const UnwiredReputationCalls()
      : SorobanReputationCalls(registry: registry);
}

/// The [ReputationRegistry] of [config]: it reads the configured registry
/// through [reader], else it is [UnwiredReputationRegistry] and every agent
/// has no feedback.
ReputationRegistry reputationRegistryFor(
  StellarConfig config,
  ContractReader reader,
) {
  final registry = config.reputationRegistry;
  return registry == null
      ? const UnwiredReputationRegistry()
      : SorobanReputationRegistry(reader, registry: registry);
}
