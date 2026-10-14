import 'package:puls3_domain/puls3_domain.dart';

import 'ledger_errors.dart';
import 'soroban_rpc_client.dart';
import 'xdr_invoke_encoder.dart';

/// Fee and sequence of the unsigned simulation envelopes. The RPC does not
/// charge or check them, so any existing source account works with `0`.
const _simulationFee = 100;
const _simulationSequence = 0;

/// Reads a contract function by simulating an unsigned envelope, never
/// signing or submitting anything. Shared by the read adapters of the
/// registries and the escrow.
final class ContractReader {
  ContractReader(this._rpc, {required StellarAddress source})
    : _source = source;

  final SorobanRpcClient _rpc;

  /// An existing account used only as the source of the simulation.
  final StellarAddress _source;

  /// Simulates `function` on [contract] and returns its raw ScVal JSON, or
  /// `null` when the contract failed with one of [absentErrors].
  ///
  /// Any other contract error is a [LedgerContractError]; a failure to read,
  /// or archived state that needs a restore, is a [LedgerUnavailable].
  Future<Object?> read(
    StellarAddress contract,
    String function,
    List<ScArg> args, {
    Set<int> absentErrors = const {},
  }) async {
    final result = await _rpc.simulateTransaction(
      encodeInvokeEnvelope(
        source: _source,
        fee: _simulationFee,
        sequence: _simulationSequence,
        contract: contract,
        function: function,
        args: args,
      ),
    );
    if (result.containsKey('restorePreamble')) {
      throw LedgerUnavailable('$function needs its archived state restored');
    }
    final error = result['error'];
    if (error is String && error.isNotEmpty) {
      final number = contractErrorCode(error);
      if (number == null) {
        throw LedgerUnavailable('$function simulation failed');
      }
      if (absentErrors.contains(number)) return null;
      throw LedgerContractError(number, '$function failed with #$number');
    }
    final results = result['results'];
    if (results is! List || results.isEmpty) {
      throw LedgerUnavailable('$function simulation returned no result');
    }
    final first = results.first;
    if (first is! Map || !first.containsKey('returnValueJson')) {
      throw LedgerUnavailable('$function simulation result has no value');
    }
    return first['returnValueJson'];
  }
}
