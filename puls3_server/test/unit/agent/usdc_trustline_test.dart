import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/usdc_trustline.dart';
import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/ledger/classic_asset.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/ledger/strkey.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

const _passphrase = 'Test SDF Network ; September 2015';
const _sequence = 4242;

final _key = stellar.StellarPrivateKey.fromBytes(
  List<int>.generate(32, (i) => i + 7),
);
final _wallet = StellarAddress.parse(
  _key.toPublicKey().toAddress().baseAddress,
);
const _asset = ClassicAsset.circleTestnetUsdc;

/// Signs with [_key], like [CustodiedEnvelopeSigner] after decrypting it.
final class _KeySigner implements AgentEnvelopeSigner {
  final signedFor = <StellarAddress>[];

  @override
  Future<String> sign(PreparedEnvelope envelope, StellarAddress address) async {
    signedFor.add(address);
    return StellarEnvelopeCodec.forPassphrase(
      _passphrase,
    ).sign(envelope, _key);
  }
}

/// A fake Soroban RPC node, answering by JSON-RPC method.
final class _Node {
  bool hasTrustline = false;
  String sendStatus = 'PENDING';
  List<String> txStatuses = ['NOT_FOUND', 'SUCCESS'];
  final methods = <String>[];
  final ledgerKeys = <String>[];
  final sent = <String>[];

  http.Client get client => MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final method = body['method']! as String;
    final params = body['params']! as Map<String, Object?>;
    methods.add(method);
    final Map<String, Object?> result;
    switch (method) {
      case 'getLedgerEntries':
        final key = (params['keys']! as List).single as String;
        ledgerKeys.add(key);
        final type = ByteData.sublistView(base64Decode(key)).getUint32(0);
        result = {
          'entries': switch (type) {
            0 => [
              {'xdr': base64Encode(_accountEntry())},
            ],
            1 when hasTrustline => [
              {
                'xdr': base64Encode(const [0, 0, 0, 1]),
              },
            ],
            _ => <Object?>[],
          },
          'latestLedger': 10,
        };
      case 'sendTransaction':
        final envelope = params['transaction']! as String;
        sent.add(envelope);
        result = {
          'status': sendStatus,
          'hash': _hashOf(envelope),
          'latestLedger': 10,
        };
      case 'getTransaction':
        result = {
          'status': txStatuses.length > 1
              ? txStatuses.removeAt(0)
              : txStatuses.single,
        };
      default:
        throw StateError('unexpected $method');
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

Uint8List _accountEntry() {
  final out = XdrWriter()
    ..uint32(0)
    ..uint32(0)
    ..opaque(rawKey(_wallet))
    ..int64(100000000)
    ..int64(_sequence);
  return out.bytes;
}

String _hashOf(String envelope) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(envelope))
          as stellar.TransactionV1Envelope;
  return hexOf(_txHash(decoded));
}

Uint8List _txHash(stellar.TransactionV1Envelope envelope) => Uint8List.fromList(
  stellar.TransactionSignaturePayload(
    networkId: stellar.StellarNetwork.testnet.passphraseHash,
    taggedTransaction: envelope.tx,
  ).txHash(),
);

RpcTrustlineEnsurer _ensurer(_Node node, _KeySigner signer) =>
    RpcTrustlineEnsurer(
      rpc: SorobanRpcClient(
        httpClient: node.client,
        url: Uri.parse('https://rpc.example.test'),
        timeout: const Duration(seconds: 1),
      ),
      signer: signer,
      asset: _asset,
      networkPassphrase: _passphrase,
      pollInterval: Duration.zero,
      maxPolls: 3,
      now: () => DateTime.utc(2026, 11, 17, 12),
    );

void main() {
  group('RpcTrustlineEnsurer', () {
    test('without a trustline it submits a ChangeTrust signed by the '
        'custodied key and confirms it', () async {
      final node = _Node();
      final signer = _KeySigner();

      final added = await _ensurer(node, signer).ensure(_wallet);

      expect(added, isTrue);
      expect(signer.signedFor, [_wallet]);
      expect(node.sent, hasLength(1));
      expect(node.methods, contains('getTransaction'));
      // The trustline key the ensurer looked up: TRUSTLINE, wallet, asset.
      final expectedKey = XdrWriter()
        ..uint32(1)
        ..uint32(0)
        ..opaque(rawKey(_wallet))
        ..raw(_asset.toXdr());
      expect(node.ledgerKeys.first, base64Encode(expectedKey.bytes));

      final envelope =
          stellar.Envelope.fromXdr(base64Decode(node.sent.single))
              as stellar.TransactionV1Envelope;
      final tx = envelope.tx;
      expect(tx.seqNum, BigInt.from(_sequence + 1));
      final op = tx.operations.single.body;
      expect(op, isA<stellar.ChangeTrustOperation>());
      final json = (op as stellar.ChangeTrustOperation).toJson().toString();
      expect(json, contains(_asset.issuer));
      final signature = envelope.signatures.single;
      expect(
        _key.toPublicKey().verify(
          digest: _txHash(envelope),
          signature: signature.signature,
        ),
        isTrue,
      );
    });

    test('with a trustline it submits nothing', () async {
      final node = _Node()..hasTrustline = true;
      final signer = _KeySigner();

      final added = await _ensurer(node, signer).ensure(_wallet);

      expect(added, isFalse);
      expect(node.sent, isEmpty);
      expect(signer.signedFor, isEmpty);
    });

    test('a rejected submission is reported', () async {
      final node = _Node()..sendStatus = 'ERROR';

      await expectLater(
        _ensurer(node, _KeySigner()).ensure(_wallet),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('a failed transaction is reported', () async {
      final node = _Node()..txStatuses = ['FAILED'];

      await expectLater(
        _ensurer(node, _KeySigner()).ensure(_wallet),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('a transaction never confirmed is reported', () async {
      final node = _Node()..txStatuses = ['NOT_FOUND'];

      await expectLater(
        _ensurer(node, _KeySigner()).ensure(_wallet),
        throwsA(isA<LedgerUnavailable>()),
      );
    });
  });

  group('backfillTrustlines', () {
    test(
      'ensures every wallet, logs fixes and failures, never throws',
      () async {
        final a = StellarAddress.parse(
          'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
        );
        final b = StellarAddress.parse(
          'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H',
        );
        final logs = <(ChainLogLevel, String)>[];
        final ensurer = _ScriptedEnsurer({
          a: () async => true,
          b: () async => throw const LedgerUnavailable('down'),
          _wallet: () async => false,
        });

        await backfillTrustlines(
          wallets: () async => [a, b, _wallet],
          ensurer: ensurer,
          log: (level, message) => logs.add((level, message)),
        );

        expect(ensurer.seen, [a, b, _wallet]);
        expect(logs, hasLength(2));
        expect(logs[0].$1, ChainLogLevel.info);
        expect(logs[0].$2, contains(a.value));
        expect(logs[1].$1, ChainLogLevel.warning);
        expect(logs[1].$2, contains(b.value));
      },
    );

    test('a failing wallet list is a warning, not a crash', () async {
      final logs = <(ChainLogLevel, String)>[];

      await backfillTrustlines(
        wallets: () async => throw StateError('db down'),
        ensurer: _ScriptedEnsurer({}),
        log: (level, message) => logs.add((level, message)),
      );

      expect(logs.single.$1, ChainLogLevel.warning);
    });
  });
}

final class _ScriptedEnsurer implements TrustlineEnsurer {
  _ScriptedEnsurer(this.script);

  final Map<StellarAddress, Future<bool> Function()> script;
  final seen = <StellarAddress>[];

  @override
  Future<bool> ensure(StellarAddress account) {
    seen.add(account);
    return script[account]!();
  }
}
