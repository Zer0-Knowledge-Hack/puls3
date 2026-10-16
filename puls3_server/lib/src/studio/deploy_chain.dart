import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';

import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import 'registration_events.dart';

/// What the chain currently says about one transaction.
enum ChainTxStatus { pending, success, failed }

final class ChainTx {
  const ChainTx(this.status, {this.agentId});

  final ChainTxStatus status;

  /// Set when the transaction emitted the registry's `registered` event.
  final int? agentId;
}

/// Reads a transaction the deploy relay already submitted.
abstract interface class ChainTxReader {
  Future<ChainTx> read(String hash);
}

/// [ChainTxReader] over `getTransaction`.
final class RpcChainTxReader implements ChainTxReader {
  RpcChainTxReader(this._rpc, {required this.identityRegistry});

  final SorobanRpcClient _rpc;
  final String identityRegistry;

  @override
  Future<ChainTx> read(String hash) async {
    final tx = await _rpc.getTransaction(hash);
    final status = switch (tx['status']) {
      'SUCCESS' => ChainTxStatus.success,
      'FAILED' => ChainTxStatus.failed,
      _ => ChainTxStatus.pending,
    };
    if (status != ChainTxStatus.success) return ChainTx(status);
    return ChainTx(
      status,
      agentId: registeredAgentId(tx, contractId: identityRegistry),
    );
  }
}

/// Creates a testnet account so it can be the source of `set_agent_wallet`.
abstract interface class AccountFunder {
  Future<void> fund(StellarAddress account);
}

/// Funds [account] with Friendbot. The response body is not logged.
final class FriendbotFunder implements AccountFunder {
  FriendbotFunder(this._client, {Uri? friendbot})
    : _friendbot = friendbot ?? Uri.parse('https://friendbot.stellar.org');

  final http.Client _client;
  final Uri _friendbot;

  @override
  Future<void> fund(StellarAddress account) async {
    final uri = _friendbot.replace(
      queryParameters: {'addr': account.value},
    );
    final response = await _client.get(uri);
    if (response.statusCode >= 300) {
      throw const LedgerUnavailable('Friendbot refused the account');
    }
  }
}

/// SHA-256 of the draft document, the bytes stored as `manifestHash`.
Uint8List manifestHash(AgentManifestDraft manifest) => Uint8List.fromList(
  sha256.convert(utf8.encode(jsonEncode(manifest.toJson()))).bytes,
);

/// The registration-file URI for [hash], served by the web server at
/// `/registry/<hex>`.
String registrationUri(Uri base, Uint8List hash) =>
    '${base.origin}/registry/${_hex(hash)}';

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
