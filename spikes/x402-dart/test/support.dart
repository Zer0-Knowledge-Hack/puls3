import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:x402_dart_spike/src/xdr.dart';
import 'package:x402_dart_spike/x402_dart.dart';

const tiaPayTo = 'GB6GCGWLKAMGQI2D7VIO2VLZFREBJBGCAP7E7ZGXHWWNZIXWLPX5YO7Q';
const usdc = 'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA';
const otherAccount = 'GBXHIBZLBY52TEKDSIVNNOK6XEVEEKXKVNPQXBYTH6SFX6ETG5KBWDC3';
const otherContract =
    'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';

/// A key derived from a fixed seed at run time, so no `S…` literal is in
/// the repo.
String testSecret([int fill = 7]) =>
    stellar.StellarPrivateKey.fromBytes(List.filled(32, fill)).toBase32();

/// An [AuthSigner] that counts signatures.
final class CountingSigner implements AuthSigner {
  CountingSigner(this._inner);

  final AuthSigner _inner;
  int signatures = 0;

  @override
  String get address => _inner.address;

  @override
  Uint8List get publicKey => _inner.publicKey;

  @override
  Uint8List sign(Uint8List payload) {
    signatures++;
    return _inner.sign(payload);
  }
}

Map<String, Object?> terms({
  String network = 'stellar:testnet',
  String asset = usdc,
  String payTo = tiaPayTo,
  String amount = '1000000',
  int maxTimeoutSeconds = 300,
}) => {
  'scheme': 'exact',
  'network': network,
  'amount': amount,
  'asset': asset,
  'payTo': payTo,
  'maxTimeoutSeconds': maxTimeoutSeconds,
  'extra': {'areFeesSponsored': true},
};

String paymentRequiredHeader(List<Map<String, Object?>> accepts) =>
    base64.encode(
      utf8.encode(
        jsonEncode({
          'x402Version': 2,
          'error': 'Payment required',
          'resource': {'url': 'https://tia.test/v1/quote', 'mimeType': ''},
          'accepts': accepts,
        }),
      ),
    );

PaymentPolicy tiaPolicy() => PaymentPolicy(
  network: 'stellar:testnet',
  assets: {usdc},
  payTo: {tiaPayTo},
  maxAmount: BigInt.from(2500000),
);

/// A server that answers 402 with [accepts] until a `PAYMENT-SIGNATURE`
/// arrives, then 200 with a settlement receipt.
final class FakeResourceServer {
  FakeResourceServer(this.accepts);

  final List<Map<String, Object?>> accepts;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    final signature =
        request.headers['PAYMENT-SIGNATURE'] ??
        request.headers['payment-signature'];
    if (signature == null) {
      return http.Response(
        '{}',
        402,
        headers: {'payment-required': paymentRequiredHeader(accepts)},
      );
    }
    return http.Response(
      '{"rate":17.2}',
      200,
      headers: {
        'payment-response': base64.encode(
          utf8.encode(
            jsonEncode({
              'success': true,
              'transaction': 'ab' * 32,
              'network': 'stellar:testnet',
            }),
          ),
        ),
      },
    );
  });
}

/// A [SorobanRpc] that records one unsigned entry for [payer] authorizing
/// [invocation], at ledger [ledger].
final class FakeRpc implements SorobanRpc {
  FakeRpc({
    required this.payer,
    required this.invocation,
    this.credentialType = 2,
    this.ledger = 1000,
    this.closeSeconds = 5,
    this.entries = 1,
  });

  final String payer;
  final Uint8List invocation;
  final int credentialType;
  final int ledger;
  final int closeSeconds;
  final int entries;
  final simulated = <Uint8List>[];

  @override
  Future<int> latestLedger() async => ledger;

  @override
  Future<int> ledgerCloseSeconds() async => closeSeconds;

  @override
  Future<Simulation> simulate(Uint8List envelope) async {
    simulated.add(envelope);
    final entry = unsignedEntry(payer, invocation, credentialType);
    return Simulation(
      auth: [for (var i = 0; i < entries; i++) entry],
      transactionData: Uint8List.fromList(List.filled(8, 1)),
      minResourceFee: 50000,
    );
  }
}

/// The invocation TIA's terms ask [payer] to authorize.
Uint8List tiaInvocation(String payer, {String to = tiaPayTo}) => SacTransfer(
  asset: usdc,
  from: payer,
  to: to,
  amount: BigInt.from(1000000),
).expectedInvocation();

Uint8List unsignedEntry(String payer, Uint8List invocation, int type) {
  final out = XdrWriter()
    ..uint32(type)
    ..uint32(0)
    ..uint32(0)
    ..fixed(stellar.StellarAddress.fromBase32Addr(payer).keyBytes())
    ..int64(123456789)
    ..uint32(0)
    ..uint32(1)
    ..raw(invocation);
  return out.toBytes();
}
