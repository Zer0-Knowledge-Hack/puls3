import 'registry_events.dart';

/// The identity-registry event reads the catalog indexer needs.
///
/// The catalog owns this port so it does not depend on Soroban; the ledger
/// adapter implements it. An unreadable chain throws a `LedgerException`, so
/// a caller never mistakes an outage for "no events".
abstract interface class RegistryEventReader {
  /// The most recent ledger the node knows about.
  Future<int> latestLedger();

  /// Every recognized identity-registry event at or after [startLedger].
  ///
  /// Events older than the node's retention window (about 7 days) cannot be
  /// read; the catalog bootstraps older agents from state instead.
  ///
  /// [RegistryEventBatch.truncated] is true when the reader stopped at its page
  /// bound while more events remained, so the caller must not assume the batch
  /// is complete.
  Future<RegistryEventBatch> eventsSince(int startLedger);
}
