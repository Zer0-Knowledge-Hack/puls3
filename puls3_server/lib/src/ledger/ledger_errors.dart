/// Why a ledger read could not be answered.
///
/// A legitimate "not on chain" result is never an error: the adapter returns
/// `null` for it. These exceptions mean the answer is unknown or unexpected,
/// so a caller must not treat them as "unpaid" or "not found".
sealed class LedgerException implements Exception {
  const LedgerException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The chain could not be read: transport failure, non-2xx status, timeout,
/// JSON-RPC error, malformed response, or archived state that needs a restore.
final class LedgerUnavailable extends LedgerException {
  const LedgerUnavailable(super.message, {this.archived = false});

  /// The read needs archived state restored (`restorePreamble`): the chain
  /// answered, but the entry is in the archive, not live. A caller that can
  /// treat one entry as unreadable checks this instead of failing whole.
  final bool archived;
}

/// The contract rejected the call with an error code the adapter does not
/// expect for that function.
final class LedgerContractError extends LedgerException {
  const LedgerContractError(this.code, String message) : super(message);

  /// The `Error(Contract, #code)` number.
  final int code;
}

/// The node answered and the simulation failed for a reason that is not a
/// contract `Error(Contract, #N)`: an auth failure, a Wasm trap, a budget
/// failure, or another deterministic host error. Unlike
/// [LedgerUnavailable], repeating the same simulation gives the same answer.
final class LedgerSimulationError extends LedgerException {
  const LedgerSimulationError(super.message);
}

/// The node answered and refused the request itself: a JSON-RPC
/// `invalid request` (-32600) or `invalid params` (-32602) error, for
/// example a `sendTransaction` envelope it cannot decode. Sending the same
/// request again gives the same answer, unlike a [LedgerUnavailable].
final class RpcRequestRejected extends LedgerException {
  const RpcRequestRejected(this.code, this.rpcMessage, String message)
    : super(message);

  /// The JSON-RPC error code.
  final int code;

  /// The JSON-RPC error message, as the node sent it.
  final String rpcMessage;
}

final _contractError = RegExp(r'Error\(Contract, #(\d+)\)');

/// The `N` of an `Error(Contract, #N)` in a simulation error text, or `null`
/// when the text names no contract error.
int? contractErrorCode(String simulationError) {
  final code = _contractError.firstMatch(simulationError)?.group(1);
  return code == null ? null : int.parse(code);
}

/// The escrow errors of agent subcontracting (ADR-0011, escrow v0.2.0).
enum EscrowSubcontractError {
  /// `create_child_job` asked for more than the parent's unspent reserve.
  reserveExceeded(124),

  /// `submit` on a parent while a child job is still open (D4).
  childrenOpen(125),

  /// A child below `MAX_DEPTH`, or a sub-reserve at it (D5).
  depthExceeded(126),

  /// The child's provider or agent is already in the ancestor chain (D5).
  subcontractCycle(127);

  const EscrowSubcontractError(this.code);

  /// The `Error(Contract, #code)` number.
  final int code;

  /// The error with [code], or `null` when it is not a subcontract error.
  static EscrowSubcontractError? fromCode(int code) {
    for (final error in values) {
      if (error.code == code) return error;
    }
    return null;
  }

  /// The subcontract error [error] reports, or `null`.
  static EscrowSubcontractError? of(LedgerContractError error) =>
      fromCode(error.code);
}
