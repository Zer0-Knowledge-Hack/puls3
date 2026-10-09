import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_sep10_codec.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

void main() {
  final serverKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 7),
  );
  final serverSecret = serverKey.toBase32();
  final serverAccount = StellarAddress.parse(
    serverKey.toPublicKey().toAddress().address,
  );
  final wallet = StellarAddress.parse(
    stellar.StellarPrivateKey.fromBytes(
      List<int>.filled(32, 9),
    ).toPublicKey().toAddress().address,
  );
  final nonce = Uint8List.fromList(List<int>.generate(48, (i) => i + 1));
  final now = DateTime.utc(2026, 10, 9, 12);
  const home = 'puls3.app';
  const web = 'auth.puls3.app';
  const network = 'Test SDF Network ; September 2015';

  StellarSep10Codec codec() => StellarSep10Codec(
    signingKey: serverSecret,
    homeDomain: home,
    webAuthDomain: web,
    networkPassphrase: network,
  );

  BuiltChallenge built() =>
      codec().build(wallet: wallet, nonce: nonce, now: now);

  test('a challenge has the SEP-10 shape and a valid server signature', () {
    final challenge = built();
    final decoded =
        stellar.Envelope.fromXdr(base64Decode(challenge.envelopeXdr))
            as stellar.TransactionV1Envelope;
    final tx = decoded.tx;

    expect(tx.seqNum, BigInt.zero);
    expect(
      tx.sourceAccount.toVariantXDR(),
      stellar.MuxedAccount.fromBase32Address(
        serverAccount.value,
      ).toVariantXDR(),
    );
    final bounds = (tx.cond as stellar.PrecondTime).timeBounds;
    final min = BigInt.from(now.millisecondsSinceEpoch ~/ 1000);
    expect(bounds.minTime, min);
    expect(bounds.maxTime, min + BigInt.from(900));

    expect(tx.operations, hasLength(2));
    final auth = tx.operations[0];
    final authBody = auth.body as stellar.ManageDataOperation;
    expect(authBody.dataName, '$home auth');
    expect(authBody.dataValue, utf8.encode(base64Encode(nonce)));
    expect(utf8.decode(authBody.dataValue!), hasLength(64));
    expect(base64Decode(utf8.decode(authBody.dataValue!)), nonce);
    expect(
      auth.sourceAccount!.toVariantXDR(),
      stellar.MuxedAccount.fromBase32Address(wallet.value).toVariantXDR(),
    );

    final domain = tx.operations[1];
    final domainBody = domain.body as stellar.ManageDataOperation;
    expect(domainBody.dataName, 'web_auth_domain');
    expect(utf8.decode(domainBody.dataValue!), web);
    expect(
      domain.sourceAccount!.toVariantXDR(),
      stellar.MuxedAccount.fromBase32Address(
        serverAccount.value,
      ).toVariantXDR(),
    );

    final parsed = codec().parse(challenge.envelopeXdr);
    expect(parsed.hash, challenge.hash);
    expect(parsed.signatures, hasLength(1));
    expect(
      codec().verifies(serverAccount, parsed.signatures.single, parsed.hash),
      isTrue,
    );
  });

  test('two nonces produce two challenges', () {
    final other = codec().build(
      wallet: wallet,
      nonce: Uint8List(48),
      now: now,
    );

    expect(other.envelopeXdr, isNot(built().envelopeXdr));
    expect(other.hash, isNot(built().hash));
  });

  test('a corrupted server signature does not verify', () {
    final parsed = codec().parse(built().envelopeXdr);
    final signature = parsed.signatures.single;
    final corrupted = EnvelopeSignature(
      hint: signature.hint,
      signature: Uint8List.fromList([
        ...signature.signature.sublist(0, signature.signature.length - 1),
        signature.signature.last ^ 0xff,
      ]),
    );

    expect(codec().verifies(serverAccount, corrupted, parsed.hash), isFalse);
  });

  test('parse rejects envelopes the relay codec already rejects', () {
    final xdr = base64Decode(built().envelopeXdr);
    final sep10 = codec();

    expect(
      () => sep10.parse(''),
      throwsA(
        isA<InvalidSignedEnvelope>().having(
          (error) => error.reason,
          'reason',
          InvalidEnvelopeReason.empty,
        ),
      ),
    );
    expect(
      () => sep10.parse('***not base64***'),
      throwsA(
        isA<InvalidSignedEnvelope>().having(
          (error) => error.reason,
          'reason',
          InvalidEnvelopeReason.notBase64,
        ),
      ),
    );
    expect(
      () => sep10.parse(base64Encode(xdr.sublist(0, xdr.length - 10))),
      throwsA(
        isA<InvalidSignedEnvelope>().having(
          (error) => error.reason,
          'reason',
          InvalidEnvelopeReason.truncated,
        ),
      ),
    );
    expect(
      () => sep10.parse(base64Encode([...xdr, 0xff])),
      throwsA(
        isA<InvalidSignedEnvelope>().having(
          (error) => error.reason,
          'reason',
          InvalidEnvelopeReason.trailingBytes,
        ),
      ),
    );
    expect(
      () => sep10.parse(base64Encode([0, 0, 0, 5, 0, 0, 0, 0])),
      throwsA(
        isA<InvalidSignedEnvelope>().having(
          (error) => error.reason,
          'reason',
          InvalidEnvelopeReason.feeBump,
        ),
      ),
    );
  });

  test('the pinned vector matches this build', () {
    final json =
        jsonDecode(
              File(
                '../docs/architecture/examples/sep10/challenge.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;

    expect(built().envelopeXdr, json['envelopeXdr']);
    expect(hexOf(built().hash), json['transactionHash']);
  });
}
