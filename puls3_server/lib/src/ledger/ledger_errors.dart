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
  const LedgerUnavailable(super.message);
}

/// The contract rejected the call with an error code the adapter does not
/// expect for that function.
final class LedgerContractError extends LedgerException {
  const LedgerContractError(this.code, String message) : super(message);

  /// The `Error(Contract, #code)` number.
  final int code;
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
