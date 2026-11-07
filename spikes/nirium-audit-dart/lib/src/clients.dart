import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settlement.dart';

/// Nirium's testnet Audit Trail node.
final niriumTestnet = Uri.parse('https://nirium-agent.fly.dev/');

/// Horizon on testnet.
final horizonTestnet = Uri.parse('https://horizon-testnet.stellar.org/');

/// The IPFS gateways Nirium's own verifier tries, in its order.
final ipfsGateways = [
  Uri.parse('https://nirium.myfilebase.com/ipfs/'),
  Uri.parse('https://ipfs.io/ipfs/'),
  Uri.parse('https://dweb.link/ipfs/'),
];

/// A non-2xx answer from Nirium. [status] 429 is its rate limit.
final class NiriumError implements Exception {
  const NiriumError(this.status, this.body);

  final int status;

  /// The response body, cut to 300 characters.
  final String body;

  bool get rateLimited => status == 429;

  @override
  String toString() => 'NiriumError($status): $body';
}

/// What `POST /api/audit/log` answers.
final class AuditAnchor {
  const AuditAnchor({
    required this.cid,
    required this.contentSha256,
    required this.anchoredAt,
    this.gatewayUrl,
    this.attestedBy,
  });

  factory AuditAnchor.fromJson(Map<String, Object?> json) => AuditAnchor(
    cid: json['cid'] as String,
    // The docs say content_sha256; the TypeScript SDK types it contentSha256.
    contentSha256: (json['content_sha256'] ?? json['contentSha256']) as String,
    anchoredAt: json['anchoredAt'] as String,
    gatewayUrl: json['gatewayUrl'] as String?,
    attestedBy: json['attestedBy'] as String?,
  );

  final String cid;
  final String contentSha256;
  final String anchoredAt;
  final String? gatewayUrl;
  final String? attestedBy;
}

/// Anchors a receipt on a Nirium Audit Trail node.
final class NiriumAuditClient {
  NiriumAuditClient(this._http, {Uri? node}) : _node = node ?? niriumTestnet;

  final http.Client _http;
  final Uri _node;

  /// Posts [body] (from `anchorBody`). Throws [NiriumError] on a non-2xx.
  Future<AuditAnchor> anchor(Map<String, Object?> body) async {
    final response = await _http.post(
      _node.resolve('api/audit/log'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode > 299) {
      final text = response.body;
      throw NiriumError(
        response.statusCode,
        text.length > 300 ? text.substring(0, 300) : text,
      );
    }
    return AuditAnchor.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }
}

/// Reads an anchored document from IPFS, trying each gateway in turn.
final class IpfsReader {
  IpfsReader(this._http, {List<Uri>? gateways})
    : _gateways = gateways ?? ipfsGateways;

  final http.Client _http;
  final List<Uri> _gateways;

  /// The JSON document at [cid]. Throws [StateError] naming each gateway's
  /// answer when none returns a JSON object.
  Future<Map<String, Object?>> read(String cid) async {
    if (!RegExp(r'^[A-Za-z0-9]{46,100}$').hasMatch(cid)) {
      throw ArgumentError.value(cid, 'cid', 'is not a CID');
    }
    final failures = <String>[];
    for (final gateway in _gateways) {
      try {
        final response = await _http
            .get(gateway.resolve(cid))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          final doc = jsonDecode(response.body);
          if (doc is Map<String, Object?>) return doc;
          failures.add('${gateway.host}: not a JSON object');
        } else {
          failures.add('${gateway.host}: HTTP ${response.statusCode}');
        }
      } on Object catch (e) {
        failures.add('${gateway.host}: ${e.runtimeType}');
      }
    }
    throw StateError('no gateway returned $cid (${failures.join('; ')})');
  }
}

/// Reads a settled escrow job from Horizon.
final class HorizonReader {
  HorizonReader(this._http, {Uri? horizon, this.network = 'stellar:testnet'})
    : _horizon = horizon ?? horizonTestnet;

  final http.Client _http;
  final Uri _horizon;
  final String network;

  /// The settlement in [txHash]. Throws [NotASettlement] when it is not one,
  /// and [StateError] when Horizon does not know the transaction.
  Future<EscrowSettlement> settlement(String txHash) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(txHash)) {
      throw ArgumentError.value(txHash, 'txHash', 'is not a transaction hash');
    }
    final tx = await _get('transactions/$txHash');
    final operations = await _get('transactions/$txHash/operations');
    return EscrowSettlement.fromHorizon(
      network: network,
      tx: tx,
      operations: operations,
    );
  }

  Future<Map<String, Object?>> _get(String path) async {
    final response = await _http.get(_horizon.resolve(path));
    if (response.statusCode != 200) {
      throw StateError('Horizon $path: HTTP ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, Object?>;
  }
}
