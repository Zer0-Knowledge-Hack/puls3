import 'package:puls3_domain/puls3_domain.dart';

import '../generated/protocol.dart' show Puls3ApiException;
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/xdr_invoke_encoder.dart';

/// What the relay reads from the chain before it prepares an envelope: the
/// signer's sequence number and the simulation of the call.
///
/// Every failure is a `Puls3ApiException` `ChainUnavailable` with
/// `details.reason = simulationFailed` (P3): the caller cannot tell a missing
/// account, an unreachable node and a rejected simulation apart, and the
/// wire contract does not distinguish them.
abstract interface class ChainAccounts {
  /// The sequence number [account] has on the ledger now.
  Future<int> sequenceOf(StellarAddress account);

  /// Simulates the call in [spec] (its signer, sequence and fee) and returns
  /// the data the envelope needs.
  Future<SimulationData> simulate(EnvelopeSpec spec);
}

/// [ChainAccounts] over Soroban RPC.
final class RpcChainAccounts implements ChainAccounts {
  RpcChainAccounts(this._rpc);

  final SorobanRpcClient _rpc;

  @override
  Future<int> sequenceOf(StellarAddress account) async {
    final int? sequence;
    try {
      sequence = await _rpc.accountSequence(account);
    } on LedgerException {
      throw chainUnavailable();
    }
    if (sequence == null) throw chainUnavailable();
    return sequence;
  }

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async {
    final envelope = encodeInvokeEnvelope(
      source: spec.source,
      fee: spec.inclusionFee,
      sequence: spec.accountSequence + 1,
      contract: spec.contract,
      function: spec.function,
      args: spec.args,
    );
    try {
      return await _rpc.simulateTransactionBase64(envelope);
    } on LedgerException {
      throw chainUnavailable();
    }
  }
}

/// The error every unreadable chain or failed simulation maps to.
Puls3ApiException chainUnavailable() => Puls3ApiException(
  code: 'ChainUnavailable',
  message: 'The chain could not be read or the call could not be simulated.',
  details: {'reason': 'simulationFailed'},
);
