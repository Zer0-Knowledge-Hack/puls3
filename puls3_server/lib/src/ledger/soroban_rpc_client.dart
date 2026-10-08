import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';

import 'envelope_codec.dart';
import 'ledger_errors.dart';
import 'strkey.dart';
import 'xdr_invoke_encoder.dart' show XdrWriter;

/// The `status` of a `sendTransaction` answer.
enum SendTransactionStatus {
  /// Accepted for inclusion; poll `getTransaction` for the final result.
  pending,

  /// The node already has this transaction.
  duplicate,

  /// The node did not take the transaction now; the same envelope may be
  /// sent again later.
  tryAgainLater,

  /// Rejected; [SendTransactionResult.errorResultXdr] says why.
  error,
}

/// A typed `sendTransaction` answer. It says whether the node took the
/// envelope, not whether the transaction succeeded.
final class SendTransactionResult {
  const SendTransactionResult({
    required this.status,
    required this.hash,
    this.latestLedger,
    this.latestLedgerCloseTime,
    this.errorResultXdr,
  });

  final SendTransactionStatus status;

  /// The 64-character hex transaction hash.
  final String hash;
  final int? latestLedger;

  /// Unix seconds.
  final int? latestLedgerCloseTime;

  /// The base64 XDR `TransactionResult` of an [SendTransactionStatus.error].
  final String? errorResultXdr;
}

const _sendStatuses = {
  'PENDING': SendTransactionStatus.pending,
  'DUPLICATE': SendTransactionStatus.duplicate,
  'TRY_AGAIN_LATER': SendTransactionStatus.tryAgainLater,
  'ERROR': SendTransactionStatus.error,
};

/// JSON-RPC transport to a Soroban RPC node: the read methods the adapter and
/// the escrow relay use, plus `sendTransaction` for envelopes the server
/// already persisted. It never signs.
///
/// Every failure to obtain a well-formed `result` object is a
/// [LedgerException]: an unreachable node must never look like "not found".
/// A JSON-RPC `invalid request` or `invalid params` error is a
/// [RpcRequestRejected] (the node refused this request); every other
/// failure, including other JSON-RPC errors, is a [LedgerUnavailable]. Both
/// keep the JSON-RPC code and message in their text.
final class SorobanRpcClient {
  /// [timeout] has no default: the composition root chooses it.
  SorobanRpcClient({
    required http.Client httpClient,
    required Uri url,
    required Duration timeout,
  }) : _http = httpClient,
       _url = url,
       _timeout = timeout;

  final http.Client _http;
  final Uri _url;
  final Duration _timeout;

  /// `simulateTransaction` for an unsigned envelope in base64 XDR. Returns the
  /// JSON-RPC `result`, with ScVal values in JSON form.
  Future<Map<String, Object?>> simulateTransaction(String envelope) =>
      _call('simulateTransaction', {
        'transaction': envelope,
        'xdrFormat': 'json',
      });

  /// `simulateTransaction` for an unsigned envelope in base64 XDR, answered in
  /// base64 XDR: the Soroban data, minimum resource fee and authorization
  /// entries the relay splices into the envelope it prepares.
  ///
  /// A contract failure is a [LedgerContractError]; archived state that needs
  /// a restore, any other simulation error and an answer without the data
  /// are a [LedgerUnavailable].
  Future<SimulationData> simulateTransactionBase64(String envelope) async {
    const method = 'simulateTransaction';
    final result = await _call(method, {
      'transaction': envelope,
      'xdrFormat': 'base64',
    });
    if (result.containsKey('restorePreamble')) {
      throw const LedgerUnavailable(
        '$method needs its archived state restored',
      );
    }
    final error = result['error'];
    if (error is String && error.isNotEmpty) {
      final code = contractErrorCode(error);
      throw code == null
          ? const LedgerUnavailable('$method failed')
          : LedgerContractError(code, '$method failed with #$code');
    }
    final transactionData = result['transactionData'];
    final minResourceFee = switch (result['minResourceFee']) {
      final int fee => fee,
      final String fee => int.tryParse(fee),
      _ => null,
    };
    if (transactionData is! String || minResourceFee == null) {
      throw const LedgerUnavailable(
        '$method answered no Soroban data and minimum fee',
      );
    }
    final results = result['results'];
    final first = results is List && results.isNotEmpty ? results.first : null;
    final auth = first is Map ? first['auth'] : null;
    return SimulationData(
      transactionData: transactionData,
      minResourceFee: minResourceFee,
      auth: auth is List ? auth.whereType<String>().toList() : const [],
    );
  }

  /// The sequence number of [account] through `getLedgerEntries`, or `null`
  /// when the account does not exist on the ledger. An unreachable node or an
  /// entry that is not an account is a [LedgerUnavailable], never `null`.
  Future<int?> accountSequence(StellarAddress account) async {
    const method = 'getLedgerEntries';
    final key = XdrWriter()
      ..uint32(_ledgerKeyAccount)
      ..uint32(_publicKeyTypeEd25519)
      ..opaque(rawKey(account));
    final result = await _call(method, {
      'keys': [base64Encode(key.bytes)],
      'xdrFormat': 'base64',
    });
    if (!result.containsKey('entries')) {
      throw const LedgerUnavailable('$method answered no entries');
    }
    final entries = result['entries'];
    if (entries == null || (entries is List && entries.isEmpty)) return null;
    final entry = entries is List ? entries.first : null;
    final xdr = entry is Map ? entry['xdr'] : null;
    if (xdr is! String) {
      throw const LedgerUnavailable('$method answered an entry without xdr');
    }
    final Uint8List data;
    try {
      data = base64Decode(xdr);
    } on FormatException {
      throw const LedgerUnavailable('$method answered an entry not in base64');
    }
    if (data.length < _accountEntrySequenceEnd ||
        ByteData.sublistView(data).getUint32(0) != _ledgerKeyAccount) {
      throw const LedgerUnavailable(
        '$method answered an entry that is not an account',
      );
    }
    return ByteData.sublistView(data).getInt64(_accountEntrySequenceAt);
  }

  /// `getTransaction` for a 64-character hex [hash]. Returns the JSON-RPC
  /// `result`, which has `status` `NOT_FOUND` for an unknown or expired hash.
  Future<Map<String, Object?>> getTransaction(String hash) =>
      _call('getTransaction', {'hash': hash, 'xdrFormat': 'json'});

  /// `sendTransaction` for a signed envelope in base64 XDR. A transport
  /// failure or an answer without a known `status` and a `hash` is a
  /// [LedgerUnavailable]: the caller cannot know whether the node took it.
  /// A [RpcRequestRejected] means the node refused the envelope itself, so
  /// sending it again cannot succeed. Status `ERROR` is a result, not an
  /// exception.
  Future<SendTransactionResult> sendTransaction(String envelopeXdr) async {
    const method = 'sendTransaction';
    final result = await _call(method, {'transaction': envelopeXdr});
    final status = _sendStatuses[result['status']];
    final hash = result['hash'];
    if (status == null || hash is! String) {
      throw LedgerUnavailable('$method answered no known status and hash');
    }
    final latestLedger = result['latestLedger'];
    final closeTime = result['latestLedgerCloseTime'];
    final errorResult = result['errorResultXdr'];
    return SendTransactionResult(
      status: status,
      hash: hash,
      latestLedger: latestLedger is int ? latestLedger : null,
      latestLedgerCloseTime: closeTime is String
          ? int.tryParse(closeTime)
          : (closeTime is int ? closeTime : null),
      errorResultXdr: errorResult is String ? errorResult : null,
    );
  }

  Future<Map<String, Object?>> _call(
    String method,
    Map<String, Object?> params,
  ) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            _url,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': method,
              'params': params,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw LedgerUnavailable('$method timed out after $_timeout');
    } on SocketException catch (e) {
      throw LedgerUnavailable('$method could not connect: ${e.message}');
    } on http.ClientException catch (e) {
      throw LedgerUnavailable('$method failed: ${e.message}');
    }
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw LedgerUnavailable('$method answered HTTP ${response.statusCode}');
    }
    return _result(method, response.body);
  }

  Map<String, Object?> _result(String method, String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw LedgerUnavailable('$method answered a body that is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw LedgerUnavailable('$method answered JSON that is not an object');
    }
    if (decoded.containsKey('error')) {
      throw _rpcError(method, decoded['error']);
    }
    final result = decoded['result'];
    if (result is! Map<String, Object?>) {
      throw LedgerUnavailable('$method answered no result object');
    }
    return result;
  }

  /// A JSON-RPC `error` object as an exception that keeps its code and
  /// message. Only `invalid request` and `invalid params` say the request
  /// itself was refused; every other code may pass on a retry.
  LedgerException _rpcError(String method, Object? error) {
    final code = error is Map ? error['code'] : null;
    final rpcMessage = error is Map ? '${error['message'] ?? ''}' : '';
    if (code is! int) {
      return LedgerUnavailable('$method answered a malformed JSON-RPC error');
    }
    final description = '$method answered JSON-RPC error $code: $rpcMessage';
    return _rejectedRequestCodes.contains(code)
        ? RpcRequestRejected(code, rpcMessage, description)
        : LedgerUnavailable(description);
  }
}

// LedgerEntryType ACCOUNT, which is also the LedgerKey ACCOUNT discriminant,
// and PUBLIC_KEY_TYPE_ED25519, from Stellar-ledger-entries.x.
const _ledgerKeyAccount = 0;
const _publicKeyTypeEd25519 = 0;

// An account LedgerEntryData is: type (4), account id (4 + 32), balance (8),
// then the sequence number (8).
const _accountEntrySequenceAt = 48;
const _accountEntrySequenceEnd = 56;

/// JSON-RPC `invalid request` and `invalid params`.
const _rejectedRequestCodes = {-32600, -32602};
