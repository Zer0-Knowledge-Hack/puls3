import 'package:puls3_domain/puls3_domain.dart' show ReputationRegistry;

import '../ledger/agent_owner_reader.dart';
import '../ledger/contract_reader.dart';
import '../ledger/escrow_job.dart';
import '../ledger/soroban_reputation_registry.dart';
import '../ledger/stellar_config.dart';
import '../ledger/terminal_job_store.dart';
import 'reputation_calls.dart';

/// The [ReputationCalls] of [config]: the real `give_feedback` once
/// `PULS3_STELLAR_REPUTATION_REGISTRY` is set, else [UnwiredReputationCalls],
/// which fails closed with `HireConfigurationMissing`.
ReputationCalls reputationCallsFor(StellarConfig config) {
  final registry = config.reputationRegistry;
  return registry == null
      ? const UnwiredReputationCalls()
      : SorobanReputationCalls(registry: registry, escrow: config.escrow);
}

/// The [ReputationRegistry] of [config]: it reads the configured registry
/// through [reader] and checks ratings against the configured escrow and the
/// ones it replaced (#201, #273), else it is [UnwiredReputationRegistry] and
/// every agent has no feedback.
///
/// With [facts], a job read in a final state is kept there and still counts
/// after its entry archives (#273).
ReputationRegistry reputationRegistryFor(
  StellarConfig config,
  ContractReader reader, {
  TerminalJobStore? facts,
}) {
  final registry = config.reputationRegistry;
  return registry == null
      ? const UnwiredReputationRegistry()
      : SorobanReputationRegistry(
          reader,
          registry: registry,
          escrow: config.escrow,
          jobs: ContractEscrowJobReader(reader, escrow: config.escrow),
          otherEscrows: {
            for (final previous in config.previousEscrows)
              if (previous != config.escrow)
                previous: ContractEscrowJobReader(reader, escrow: previous),
          },
          facts: facts,
          owners: ContractAgentOwnerReader(
            reader,
            identityRegistry: config.identityRegistry,
          ),
        );
}
