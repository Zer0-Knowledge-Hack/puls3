import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

/// The registry reads the agent catalog needs.
///
/// The catalog owns this port so it does not depend on Soroban; the ledger
/// adapter implements it. A `null` result means the chain says "not there",
/// while an unreadable chain throws a `LedgerException`.
abstract interface class RegistryReader {
  /// How many agents were ever registered (ids `0` to `n - 1`).
  Future<int> totalAgents();

  /// The raw metadata value of [id] under [key], or `null` when it is unset.
  Future<Uint8List?> agentMetadata(AgentId id, String key);

  /// The wallet registered for [id], or `null` when there is none.
  Future<StellarAddress?> agentWallet(AgentId id);
}
