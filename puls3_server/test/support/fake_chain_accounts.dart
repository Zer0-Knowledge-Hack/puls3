import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';

/// A [ChainAccounts] that answers from fields and records every call.
/// [sequenceFailure] and [simulationFailure] are thrown when set.
final class FakeChainAccounts implements ChainAccounts {
  /// The sequence number the signer has on the ledger.
  int sequence = 100;

  SimulationData simulation = const SimulationData(
    transactionData: 'AAAAAQ==',
    minResourceFee: 50000,
  );

  Object? sequenceFailure;
  Object? simulationFailure;

  final sequenceReads = <StellarAddress>[];
  final simulated = <EnvelopeSpec>[];

  @override
  Future<int> sequenceOf(StellarAddress account) async {
    sequenceReads.add(account);
    final failure = sequenceFailure;
    if (failure != null) throw failure;
    return sequence;
  }

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async {
    simulated.add(spec);
    final failure = simulationFailure;
    if (failure != null) throw failure;
    return simulation;
  }
}
