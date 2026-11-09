import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:x402_dart_spike/x402_dart.dart';

import 'support.dart';

// Built with @stellar/stellar-sdk (authorizeEntry, TransactionBuilder) from
// the same seed (32 bytes of 7), nonce 123456789 and expiration ledger
// 5575600. Dart must produce the same bytes.
const _jsInvocation =
    'AAAAAAAAAAFQRc1ewHKado/VrQJQWFLfTwKNzoMOWsUiCbpISDsvAQAAAAh0cmFuc2ZlcgAAAAMAAAASAAAAAAAAAADqSmxj4pxSCr71UHsTLsX5lUd2rr6+e5JCHuppFEbSLAAAABIAAAAAAAAAAHxhGstQGGgjQ/1Q7VV5LEgUhMID/k/k1z2s3KL2W+/cAAAACgAAAAAAAAAAAAAAAAAPQkAAAAAA';
const _jsV1Unsigned =
    'AAAAAQAAAAAAAAAA6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAAAB1vNFQAAAAAAAAABAAAAAAAAAAFQRc1ewHKado/VrQJQWFLfTwKNzoMOWsUiCbpISDsvAQAAAAh0cmFuc2ZlcgAAAAMAAAASAAAAAAAAAADqSmxj4pxSCr71UHsTLsX5lUd2rr6+e5JCHuppFEbSLAAAABIAAAAAAAAAAHxhGstQGGgjQ/1Q7VV5LEgUhMID/k/k1z2s3KL2W+/cAAAACgAAAAAAAAAAAAAAAAAPQkAAAAAA';
const _jsV1Signed =
    'AAAAAQAAAAAAAAAA6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAAAB1vNFQBVE7AAAAAQAAAAAQAAAAEAAAARAAAAAQAAAAIAAAAPAAAACnB1YmxpY19rZXkAAAAAAA0AAAAg6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAAPAAAACXNpZ25hdHVyZQAAAAAAAA0AAABArF9PPJ4Tfsv3mLgogOPNVIaneLHmnjQFSgDzxNj/g7D/3nHI2uh3OhGVyD8iQQr6qXG87aX+KRrWMHuvYDa9AAAAAAAAAAABUEXNXsBymnaP1a0CUFhS308Cjc6DDlrFIgm6SEg7LwEAAAAIdHJhbnNmZXIAAAADAAAAEgAAAAAAAAAA6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAASAAAAAAAAAAB8YRrLUBhoI0P9UO1VeSxIFITCA/5P5Nc9rNyi9lvv3AAAAAoAAAAAAAAAAAAAAAAAD0JAAAAAAA==';
const _jsV2Unsigned =
    'AAAAAgAAAAAAAAAA6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAAAB1vNFQAAAAAAAAABAAAAAAAAAAFQRc1ewHKado/VrQJQWFLfTwKNzoMOWsUiCbpISDsvAQAAAAh0cmFuc2ZlcgAAAAMAAAASAAAAAAAAAADqSmxj4pxSCr71UHsTLsX5lUd2rr6+e5JCHuppFEbSLAAAABIAAAAAAAAAAHxhGstQGGgjQ/1Q7VV5LEgUhMID/k/k1z2s3KL2W+/cAAAACgAAAAAAAAAAAAAAAAAPQkAAAAAA';
const _jsV2Signed =
    'AAAAAgAAAAAAAAAA6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAAAB1vNFQBVE7AAAAAQAAAAAQAAAAEAAAARAAAAAQAAAAIAAAAPAAAACnB1YmxpY19rZXkAAAAAAA0AAAAg6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAAPAAAACXNpZ25hdHVyZQAAAAAAAA0AAABA/TMU3W5ApXDX9VHHrINk30odqT4BX+sKk2xyPR8phpD53JzfJDWffK7hCXwM5EMatFb72weewvCAbrrbh57mBAAAAAAAAAABUEXNXsBymnaP1a0CUFhS308Cjc6DDlrFIgm6SEg7LwEAAAAIdHJhbnNmZXIAAAADAAAAEgAAAAAAAAAA6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAASAAAAAAAAAAB8YRrLUBhoI0P9UO1VeSxIFITCA/5P5Nc9rNyi9lvv3AAAAAoAAAAAAAAAAAAAAAAAD0JAAAAAAA==';
const _jsEnvelope =
    'AAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGQAAAAAAAAAAQAAAAEAAAAAAAAAAAAAAABq7MUWAAAAAAAAAAEAAAAAAAAAGAAAAAAAAAABUEXNXsBymnaP1a0CUFhS308Cjc6DDlrFIgm6SEg7LwEAAAAIdHJhbnNmZXIAAAADAAAAEgAAAAAAAAAA6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iwAAAASAAAAAAAAAAB8YRrLUBhoI0P9UO1VeSxIFITCA/5P5Nc9rNyi9lvv3AAAAAoAAAAAAAAAAAAAAAAAD0JAAAAAAAAAAAAAAAAA';

void main() {
  final signer = SecretKeySigner.fromSecret(testSecret());
  final transfer = SacTransfer(
    asset: usdc,
    from: signer.address,
    to: tiaPayTo,
    amount: BigInt.from(1000000),
  );
  final testnet = networkId('Test SDF Network ; September 2015');

  test('the signer derives the same account as the JS SDK', () {
    expect(
      signer.address,
      'GDVEU3DD4KOFECV66VIHWEZOYX4ZKR3WV27L464SIIPOU2IUI3JCZA57',
    );
  });

  test('the transfer invocation matches the JS SDK', () {
    expect(base64.encode(transfer.expectedInvocation()), _jsInvocation);
  });

  test('the unsigned envelope matches the JS SDK', () {
    final envelope = transfer.envelope(fee: 100, maxTime: 1793901846);
    expect(base64.encode(envelope), _jsEnvelope);
  });

  for (final (name, unsigned, signed) in [
    ('ADDRESS', _jsV1Unsigned, _jsV1Signed),
    ('ADDRESS_V2', _jsV2Unsigned, _jsV2Signed),
  ]) {
    test('a signed $name entry matches the JS SDK byte for byte', () {
      final entry = AuthEntry.parse(base64.decode(unsigned));
      final result = entry.sign(signer, testnet, 5575600);
      expect(base64.encode(result), signed);
    });
  }

  test('ADDRESS and ADDRESS_V2 sign different payloads', () {
    final v1 = AuthEntry.parse(base64.decode(_jsV1Unsigned));
    final v2 = AuthEntry.parse(base64.decode(_jsV2Unsigned));
    expect(v1.preimage(testnet, 1), isNot(v2.preimage(testnet, 1)));
  });

  test('an expiration of zero is refused', () {
    final entry = AuthEntry.parse(base64.decode(_jsV2Unsigned));
    expect(() => entry.sign(signer, testnet, 0), throwsArgumentError);
  });

  test('a source-account or signed entry is not accepted for signing', () {
    expect(
      () => AuthEntry.parse(Uint8List.fromList([0, 0, 0, 0])),
      throwsA(isA<UnexpectedAuthorization>()),
    );
    expect(
      () => AuthEntry.parse(base64.decode(_jsV2Signed)),
      throwsA(isA<UnexpectedAuthorization>()),
    );
  });
}
