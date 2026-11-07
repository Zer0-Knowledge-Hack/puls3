import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:x402_dart_spike/src/xdr.dart';
import 'package:x402_dart_spike/x402_dart.dart';

import 'support.dart';

final _url = Uri.parse('https://tia.test/v1/quote?amount=100');

void main() {
  late CountingSigner signer;

  setUp(() {
    signer = CountingSigner(SecretKeySigner.fromSecret(testSecret()));
  });

  X402Client clientFor(FakeResourceServer server, FakeRpc rpc) => X402Client(
    signer: signer,
    policy: tiaPolicy(),
    rpc: rpc,
    httpClient: server.client,
    clock: () => DateTime.utc(2026, 11, 5),
  );

  group('terms outside the policy are refused before any signature', () {
    final cases = {
      'wrong network': terms(network: 'stellar:pubnet'),
      'wrong asset': terms(asset: otherContract),
      'payTo outside the allow-list': terms(payTo: otherAccount),
      'amount above the maximum': terms(amount: '2500001'),
      'unsupported scheme': {...terms(), 'scheme': 'upto'},
      'fees not sponsored': {...terms(), 'extra': <String, Object?>{}},
    };
    cases.forEach((name, offered) {
      test(name, () async {
        final server = FakeResourceServer([offered]);
        final rpc = FakeRpc(
          payer: signer.address,
          invocation: tiaInvocation(signer.address),
        );
        await expectLater(
          clientFor(server, rpc).get(_url),
          throwsA(isA<TermsRejected>()),
        );
        expect(signer.signatures, 0);
        expect(rpc.simulated, isEmpty);
        expect(server.requests, hasLength(1));
      });
    });
  });

  test('picks the first offered terms that pass', () async {
    final server = FakeResourceServer([
      terms(network: 'stellar:pubnet'),
      terms(),
    ]);
    final rpc = FakeRpc(
      payer: signer.address,
      invocation: tiaInvocation(signer.address),
    );
    final result = await clientFor(server, rpc).get(_url);
    expect(result.terms!.network, 'stellar:testnet');
    expect(signer.signatures, 1);
  });

  group('an authorization other than the transfer is not signed', () {
    test('recipient swapped in the simulated entry', () async {
      final rpc = FakeRpc(
        payer: signer.address,
        invocation: tiaInvocation(signer.address, to: otherAccount),
      );
      await expectLater(
        clientFor(FakeResourceServer([terms()]), rpc).get(_url),
        throwsA(isA<UnexpectedAuthorization>()),
      );
      expect(signer.signatures, 0);
    });

    test('entry for another account', () async {
      final rpc = FakeRpc(
        payer: otherAccount,
        invocation: tiaInvocation(signer.address),
      );
      await expectLater(
        clientFor(FakeResourceServer([terms()]), rpc).get(_url),
        throwsA(isA<UnexpectedAuthorization>()),
      );
      expect(signer.signatures, 0);
    });

    test('more than one entry', () async {
      final rpc = FakeRpc(
        payer: signer.address,
        invocation: tiaInvocation(signer.address),
        entries: 2,
      );
      await expectLater(
        clientFor(FakeResourceServer([terms()]), rpc).get(_url),
        throwsA(isA<UnexpectedAuthorization>()),
      );
      expect(signer.signatures, 0);
    });
  });

  for (final credentialType in [1, 2]) {
    test('pays with a signed credential type $credentialType entry', () async {
      final server = FakeResourceServer([terms()]);
      final rpc = FakeRpc(
        payer: signer.address,
        invocation: tiaInvocation(signer.address),
        credentialType: credentialType,
        ledger: 1000,
        closeSeconds: 6,
      );
      final result = await clientFor(server, rpc).get(_url);

      expect(result.response.statusCode, 200);
      expect(result.payment!.success, isTrue);
      expect(signer.signatures, 1);
      // 300 s at 6 s a ledger: 50 ledgers, never more than maxTimeoutSeconds.
      expect(result.expirationLedger, 1050);

      final header = server.requests.last.headers['PAYMENT-SIGNATURE']!;
      final payload =
          jsonDecode(utf8.decode(base64.decode(header)))
              as Map<String, Object?>;
      expect(payload['x402Version'], 2);
      expect(payload['accepted'], terms());
      expect((payload['resource'] as Map)['url'], 'https://tia.test/v1/quote');

      final envelope = base64.decode(
        (payload['payload'] as Map)['transaction'] as String,
      );
      expect(
        _signedExpiration(envelope, credentialType, signer.publicKey),
        1050,
      );
      // The final envelope is the one simulated with the signature.
      expect(rpc.simulated, hasLength(2));
      expect(envelope, rpc.simulated.last);
    });
  }
}

/// Finds the payer's address credential in [envelope] and reads its
/// expiration ledger.
int _signedExpiration(Uint8List envelope, int credentialType, Uint8List key) {
  final prefix =
      (XdrWriter()
            ..uint32(credentialType)
            ..uint32(0)
            ..uint32(0)
            ..fixed(key))
          .toBytes();
  for (var i = 0; i + prefix.length + 12 <= envelope.length; i++) {
    var match = true;
    for (var j = 0; j < prefix.length && match; j++) {
      match = envelope[i + j] == prefix[j];
    }
    if (match) {
      // After the address: nonce (8 bytes), then the expiration.
      return ByteData.sublistView(envelope).getUint32(i + prefix.length + 8);
    }
  }
  throw StateError('no entry for the payer');
}
