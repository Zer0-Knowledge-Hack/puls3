import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'cid.dart';
import 'receipt.dart';

/// A Nirium Audit Trail node and its IPFS gateway on `localhost`, for the
/// sandbox (#296).
///
/// It answers the two requests the receipt queue makes, in the shape of the
/// real testnet node, and keeps every document in memory:
///
/// - `POST /api/audit/log` stores a document and answers its CID;
/// - `GET /ipfs/<cid>` serves the bytes of that document.
///
/// The CID is the real CIDv0 of the bytes it serves, so `IpfsReader`
/// recomputes it exactly as it does for a public gateway. Nothing is sent
/// anywhere else, and nothing survives [close]: a run never publishes a
/// record on IPFS.
///
/// Like the real node, it does not check the attestation. Checking it is the
/// verifier's job, which is the point of the sandbox.
final class LocalNiriumNode {
  LocalNiriumNode._(this._server, this._now);

  /// Starts a node on a free loopback port, or on [port].
  static Future<LocalNiriumNode> start({
    int port = 0,
    DateTime Function()? now,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final node = LocalNiriumNode._(
      server,
      now ?? (() => DateTime.now().toUtc()),
    );
    server.listen(node._handle);
    return node;
  }

  final HttpServer _server;
  final DateTime Function() _now;
  final _documents = <String, List<int>>{};

  /// The node's base URL, for `NiriumAuditClient(node: …)`.
  Uri get url => Uri.parse('http://localhost:${_server.port}/');

  /// The gateway URL, for `IpfsReader(gateways: [gateway])`.
  Uri get gateway => url.resolve('ipfs/');

  /// The next anchors that are refused with 429, as the real node does above
  /// 20 requests a minute. Each refused anchor lowers it by one.
  int rateLimitNext = 0;

  /// The next anchors that fail with 503.
  int unavailableNext = 0;

  /// While true, every document answers 404: a CID that has not reached the
  /// gateway yet. The spike read 0 of 20 right after anchoring.
  bool holdDocuments = false;

  /// While true, a document is served with one byte changed, so it no longer
  /// hashes to its CID.
  bool serveOtherBytes = false;

  /// Anchors accepted so far.
  int anchored = 0;

  /// Every request received, as `METHOD path → status`.
  final log = <String>[];

  /// The CIDs stored, oldest first.
  List<String> get cids => _documents.keys.toList();

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    try {
      if (request.method == 'POST' && path == '/api/audit/log') {
        await _anchor(request);
      } else if (request.method == 'GET' && path.startsWith('/ipfs/')) {
        _serve(request, path.substring('/ipfs/'.length));
      } else {
        _json(request, HttpStatus.notFound, {'error': 'not found'});
      }
    } on FormatException {
      _json(request, HttpStatus.badRequest, {'error': 'invalid JSON body'});
    }
    log.add('${request.method} $path → ${request.response.statusCode}');
    await request.response.close();
  }

  Future<void> _anchor(HttpRequest request) async {
    final text = await utf8.decodeStream(request);
    if (rateLimitNext > 0) {
      rateLimitNext--;
      return _json(request, HttpStatus.tooManyRequests, {
        'error': 'rate limit exceeded',
      });
    }
    if (unavailableNext > 0) {
      unavailableNext--;
      return _json(request, HttpStatus.serviceUnavailable, {
        'error': 'unavailable',
      });
    }
    final body = jsonDecode(text);
    if (body is! Map<String, Object?>) throw const FormatException();
    final record = body['record'];
    final declared = body['hash'];
    final String hash;
    if (record is Map<String, Object?>) {
      // As the real node hashes it: JSON.stringify of the stored record.
      hash = sha256.convert(utf8.encode(jsonEncode(record))).toString();
    } else if (declared is String && declared.startsWith('sha-256:')) {
      hash = declared.substring('sha-256:'.length);
    } else {
      return _json(request, HttpStatus.badRequest, {
        'error': 'record or hash is required',
      });
    }
    final agent = body['agent'];
    final anchoredAt = _now().toUtc().toIso8601String();
    final document = <String, Object?>{
      'version': '1.1.0',
      'node': 'local-sandbox',
      'content_sha256': hash,
      if (agent is Map<String, Object?>)
        'agent': {
          ...agent,
          'alg': 'ed25519',
          'statement': attestationStatement(hash),
        },
      'record': ?(record is Map<String, Object?> ? record : null),
      'network': 'stellar:testnet',
      'tag': ?body['tag'],
      'anchoredAt': anchoredAt,
    };
    final bytes = utf8.encode(jsonEncode(document));
    final cid = cidV0ForFile(bytes);
    _documents[cid] = bytes;
    anchored++;
    _json(request, HttpStatus.ok, {
      'cid': cid,
      'content_sha256': hash,
      'anchoredAt': anchoredAt,
      'gatewayUrl': '${gateway.resolve(cid)}',
      if (agent is Map<String, Object?>) 'attestedBy': agent['key'],
    });
  }

  void _serve(HttpRequest request, String cid) {
    final bytes = _documents[cid];
    if (bytes == null || holdDocuments) {
      return _json(request, HttpStatus.notFound, {'error': 'not found'});
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..add(serveOtherBytes ? [...bytes, 0x20] : bytes);
  }

  void _json(HttpRequest request, int status, Map<String, Object?> body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }
}
