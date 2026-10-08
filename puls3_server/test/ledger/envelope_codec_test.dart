// Tests of the envelope codec (issue #96, escrow relay).
//
// Golden vectors, all real testnet data recorded read-only on 2026-10-07:
//  - get_transaction_{create,fund}_job_3_xdr.json: the signed create_job and
//    fund envelopes of job 3 and their on-chain hash.
//  - simulate_create_job_3_base64.json: simulateTransaction (base64 XDR) of
//    that create_job envelope.
// The fund simulation of job 3 fails on chain (the job is already funded), so
// the fund Soroban data and auth are taken from the recorded fund transaction.
//
// Negative vectors are derived by mutating those real bytes (flipping a bit,
// stripping or duplicating the signature, wrapping the inner envelope, adding
// bytes). No vector is invented.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart' show ScArg;
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _mainnetPassphrase = 'Public Global Stellar Network ; September 2015';

final _signer = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _provider = StellarAddress.parse(
  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
);
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
final _usdc = StellarAddress.parse(
  'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA',
);

const _validUntil = 1791750000;
const _inclusionFee = 100;
// Sequence of the signer just before the recorded create_job (and fund).
const _createAccountSequence = 20602318168784912;
const _fundAccountSequence = 20602318168784913;

/// Byte positions in an unsigned envelope built by the codec: ENVELOPE_TYPE_TX
/// (4), source (4 + 32), fee (4), sequence (8), PRECOND_TIME (4 + 8 + 8), memo
/// (4), operation count (4), operation source (4), operation type (4), host
/// function type (4), contract address (4 + 32), then the function name.
const _sourceKeyAt = 8;
const _feeAt = 40;
const _sequenceAt = 44;
const _maxTimeAt = 64;
const _contractKeyAt = 96;
const _functionNameAt = 132;

Map<String, Object?> _json(String name) =>
    jsonDecode(File('test/fixtures/escrow_relay/$name').readAsStringSync())
        as Map<String, Object?>;

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _flip(List<int> bytes, int index) =>
    Uint8List.fromList(bytes)..[index] ^= 0x01;

/// One recorded signed transaction.
final class _Vector {
  _Vector(String name) {
    final fixture = _json('get_transaction_${name}_job_3_xdr.json');
    txHash = fixture['txHash']! as String;
    signedXdr = fixture['envelopeXdr']! as String;
    envelope = base64Decode(signedXdr);
    decoded =
        stellar.Envelope.fromXdr(envelope) as stellar.TransactionV1Envelope;
  }

  late final String txHash;
  late final String signedXdr;
  late final Uint8List envelope;
  late final stellar.TransactionV1Envelope decoded;

  /// ENVELOPE_TYPE_TX (4) | transaction | signature count (4) | one
  /// DecoratedSignature (hint 4, length 4, signature 64).
  static const _signatureSectionLength = 4 + 4 + 4 + 64;

  Uint8List get body =>
      envelope.sublist(4, envelope.length - _signatureSectionLength);

  Uint8List get signature => envelope.sublist(envelope.length - 64);

  /// The recorded envelope with its signature section removed.
  Uint8List get unsigned => Uint8List.fromList([
    ...envelope.sublist(0, envelope.length - _signatureSectionLength),
    0,
    0,
    0,
    0,
  ]);

  stellar.InvokeHostFunctionOperation get operation =>
      decoded.tx.operations.single.body as stellar.InvokeHostFunctionOperation;

  stellar.InvokeContractArgs get call =>
      (operation.hostFunction as stellar.HostFunctionTypeInvokeContract).args;
}

final _create = _Vector('create');
final _fund = _Vector('fund');

/// The decoded structure of each value. Compared instead of re-encoded
/// bytes because `stellar_dart` cannot serialize a bare `ScVal`.
List<Object?> _structsOf(Iterable<stellar.XDRSerialization> values) => values
    .map(
      (v) => v is stellar.XDRVariantSerialization
          ? v.toVariantLayoutStruct()
          : v.toLayoutStruct(),
    )
    .toList();

SimulationData _createSimulation({List<String>? auth}) {
  final result =
      _json('simulate_create_job_3_base64.json')['result']!
          as Map<String, Object?>;
  final first = (result['results']! as List).single as Map<String, Object?>;
  return SimulationData(
    transactionData: result['transactionData']! as String,
    minResourceFee: int.parse('${result['minResourceFee']}'),
    auth: auth ?? (first['auth']! as List).cast<String>(),
  );
}

/// The fund simulation of job 3 fails on chain, so its Soroban data and auth
/// come from the recorded fund transaction itself.
SimulationData _fundSimulation() => SimulationData(
  transactionData: base64Encode(_fund.decoded.tx.sorobanData.toXDR()),
  minResourceFee: _fund.decoded.tx.fee - _inclusionFee,
  auth: [
    for (final entry in _fund.operation.auth) base64Encode(entry.toXDR()),
  ],
);

EnvelopeSpec get _createSpec => EnvelopeSpec(
  source: _signer,
  accountSequence: _createAccountSequence,
  contract: _escrow,
  function: 'create_job',
  args: [
    ScArg.address(_signer),
    ScArg.address(_provider),
    ScArg.address(_signer),
    const ScArg.u64(1791747914),
    const ScArg.string('puls3 testnet evidence job'),
    const ScArg.voidValue(),
    const ScArg.u32(7),
    ScArg.address(_usdc),
    const ScArg.i128(5000000),
  ],
  inclusionFee: _inclusionFee,
  validUntil: _validUntil,
);

EnvelopeSpec get _fundSpec => EnvelopeSpec(
  source: _signer,
  accountSequence: _fundAccountSequence,
  contract: _escrow,
  function: 'fund',
  args: [
    ScArg.address(_signer),
    const ScArg.u64(3),
    const ScArg.i128(5000000),
    const ScArg.u32(0),
  ],
  inclusionFee: _inclusionFee,
  validUntil: _validUntil,
);

final _codec = StellarEnvelopeCodec.forPassphrase(_testnetPassphrase);

PreparedEnvelope _builtCreate() =>
    _codec.build(_createSpec, _createSimulation());
PreparedEnvelope _builtFund() => _codec.build(_fundSpec, _fundSimulation());

Uint8List _bytesOf(PreparedEnvelope prepared) =>
    base64Decode(prepared.envelopeXdr);

/// The transaction slice of an unsigned envelope: skip ENVELOPE_TYPE_TX and
/// drop the empty signature list.
Uint8List _bodyOf(Uint8List unsignedEnvelope) =>
    unsignedEnvelope.sublist(4, unsignedEnvelope.length - 4);

Matcher _invalid(InvalidEnvelopeReason reason) => throwsA(
  isA<InvalidSignedEnvelope>().having((e) => e.reason, 'reason', reason),
);

/// A fee-bump envelope (ENVELOPE_TYPE_TX_FEE_BUMP) wrapping a recorded one.
Uint8List _feeBumpAround(_Vector vector) {
  final out = BytesBuilder()
    ..add([0, 0, 0, 5]) // ENVELOPE_TYPE_TX_FEE_BUMP
    ..add([0, 0, 0, 0]) // fee source: KEY_TYPE_ED25519
    ..add(vector.envelope.sublist(_sourceKeyAt, _sourceKeyAt + 32))
    ..add([0, 0, 0, 0, 0, 0, 0x27, 0x10]) // fee 10000
    ..add([0, 0, 0, 2]) // inner envelope type: ENVELOPE_TYPE_TX
    ..add(vector.envelope.sublist(4)) // inner transaction and signatures
    ..add([0, 0, 0, 0]) // fee-bump transaction ext
    ..add([0, 0, 0, 0]); // no outer signatures
  return out.toBytes();
}

void main() {
  group('build', () {
    for (final (name, built, vector, simulation) in [
      ('create_job', _builtCreate, _create, _createSimulation),
      ('fund', _builtFund, _fund, _fundSimulation),
    ]) {
      group(name, () {
        test('splices the recorded call, auth and Soroban data', () {
          final prepared = built();
          final decoded =
              stellar.Envelope.fromXdr(_bytesOf(prepared))
                  as stellar.TransactionV1Envelope;
          final op =
              decoded.tx.operations.single.body
                  as stellar.InvokeHostFunctionOperation;
          final call =
              (op.hostFunction as stellar.HostFunctionTypeInvokeContract).args;

          expect(
            _structsOf([call.contractAddress]),
            _structsOf([vector.call.contractAddress]),
          );
          expect(call.functionName.value, vector.call.functionName.value);
          expect(_structsOf(call.args), _structsOf(vector.call.args));
          expect(_structsOf(op.auth), _structsOf(vector.operation.auth));
          // The recorded create_job was simulated at an earlier ledger, so its
          // Soroban data differs from today's simulation: compare with that.
          expect(
            base64Encode(decoded.tx.sorobanData.toXDR()),
            simulation().transactionData,
          );
          expect(decoded.signatures, isEmpty);
        });

        test('uses the signer sequence plus one and the exact fee', () {
          final decoded =
              stellar.Envelope.fromXdr(_bytesOf(built()))
                  as stellar.TransactionV1Envelope;

          expect(decoded.tx.seqNum, vector.decoded.tx.seqNum);
          expect(decoded.tx.fee, _inclusionFee + simulation().minResourceFee);
        });

        test('bounds the time window to [0, validUntil] with no memo', () {
          final decoded =
              stellar.Envelope.fromXdr(_bytesOf(built()))
                  as stellar.TransactionV1Envelope;
          final cond = decoded.tx.cond as stellar.PrecondTime;

          expect(cond.timeBounds.minTime, BigInt.zero);
          expect(cond.timeBounds.maxTime, BigInt.from(_validUntil));
          expect(decoded.tx.memo, isA<stellar.StellarMemoNone>());
        });

        test('re-encodes byte-identically and reports the network hash', () {
          final prepared = built();
          final bytes = _bytesOf(prepared);
          final decoded =
              stellar.Envelope.fromXdr(bytes) as stellar.TransactionV1Envelope;

          expect(base64Encode(decoded.toVariantXDR()), prepared.envelopeXdr);
          expect(prepared.body, _bodyOf(bytes));
          expect(
            prepared.hashHex,
            decoded.txId(stellar.StellarNetwork.testnet.passphraseHash),
          );
          expect(prepared.hash, hasLength(32));
          expect(_hex(prepared.hash), prepared.hashHex);
        });
      });
    }

    test('is deterministic for the same inputs', () {
      expect(_builtCreate().envelopeXdr, _builtCreate().envelopeXdr);
    });

    test('a different network passphrase changes only the hash', () {
      final mainnet = StellarEnvelopeCodec.forPassphrase(
        _mainnetPassphrase,
      ).build(_createSpec, _createSimulation());

      expect(mainnet.envelopeXdr, _builtCreate().envelopeXdr);
      expect(mainnet.hashHex, isNot(_builtCreate().hashHex));
    });

    test('the fee follows the inclusion fee over the same simulation', () {
      final simulation = _createSimulation();

      for (final inclusion in [_inclusionFee, 250]) {
        final spec = EnvelopeSpec(
          source: _createSpec.source,
          accountSequence: _createSpec.accountSequence,
          contract: _createSpec.contract,
          function: _createSpec.function,
          args: _createSpec.args,
          inclusionFee: inclusion,
          validUntil: _validUntil,
        );
        final decoded =
            stellar.Envelope.fromXdr(
                  _bytesOf(_codec.build(spec, simulation)),
                )
                as stellar.TransactionV1Envelope;

        expect(decoded.tx.fee, inclusion + simulation.minResourceFee);
      }
    });

    test('accepts a simulation without auth entries', () {
      final prepared = _codec.build(_createSpec, _createSimulation(auth: []));
      final decoded =
          stellar.Envelope.fromXdr(_bytesOf(prepared))
              as stellar.TransactionV1Envelope;
      final op =
          decoded.tx.operations.single.body
              as stellar.InvokeHostFunctionOperation;

      expect(op.auth, isEmpty);
    });

    test('rejects an auth entry whose credentials are not SOURCE_ACCOUNT', () {
      final recorded = _createSimulation().auth.single;
      final real = base64Decode(recorded);
      // SorobanCredentials discriminant: 0 = SOURCE_ACCOUNT, 1 = ADDRESS.
      expect(real.sublist(0, 4), [0, 0, 0, 0]);
      final address = Uint8List.fromList(real)..[3] = 1;

      expect(
        () => _codec.build(
          _createSpec,
          _createSimulation(auth: [base64Encode(address)]),
        ),
        throwsA(isA<UnsupportedAuthorization>()),
      );
    });

    test('rejects the whole call when only one of several entries differs', () {
      final recorded = _createSimulation().auth.single;
      final address = Uint8List.fromList(base64Decode(recorded))..[3] = 1;

      expect(
        () => _codec.build(
          _createSpec,
          _createSimulation(auth: [recorded, base64Encode(address)]),
        ),
        throwsA(isA<UnsupportedAuthorization>()),
      );
    });
  });

  group('parse', () {
    for (final (name, vector) in [('create_job', _create), ('fund', _fund)]) {
      test(
        'decodes the recorded $name envelope into body, hash, signature',
        () {
          final signed = _codec.parse(vector.signedXdr);

          expect(signed.body, vector.body);
          expect(_hex(signed.hash), vector.txHash);
          expect(signed.signatures, hasLength(1));
          expect(signed.signatures.single.hint, [230, 12, 46, 131]);
          expect(signed.signatures.single.signature, vector.signature);
        },
      );
    }

    test('an unsigned envelope parses with no signatures', () {
      final signed = _codec.parse(_builtCreate().envelopeXdr);

      expect(signed.signatures, isEmpty);
      expect(signed.body, _builtCreate().body);
      expect(signed.hash, _builtCreate().hash);
    });

    group('malformed', () {
      test('empty', () {
        expect(() => _codec.parse(''), _invalid(InvalidEnvelopeReason.empty));
      });

      test('not base64', () {
        expect(
          () => _codec.parse('***not base64***'),
          _invalid(InvalidEnvelopeReason.notBase64),
        );
        expect(
          () => _codec.parse('AAAAAg='),
          _invalid(InvalidEnvelopeReason.notBase64),
        );
      });

      test('truncated inside the signature', () {
        final cut = _create.envelope.sublist(0, _create.envelope.length - 10);

        expect(
          () => _codec.parse(base64Encode(cut)),
          _invalid(InvalidEnvelopeReason.truncated),
        );
      });

      test('truncated inside the transaction', () {
        final cut = _fund.envelope.sublist(0, 60);

        expect(
          () => _codec.parse(base64Encode(cut)),
          _invalid(InvalidEnvelopeReason.truncated),
        );
      });

      test('trailing bytes after the signatures', () {
        for (final extra in [
          [0, 0, 0, 0],
          [0xff],
        ]) {
          final padded = [..._create.envelope, ...extra];

          expect(
            () => _codec.parse(base64Encode(padded)),
            _invalid(InvalidEnvelopeReason.trailingBytes),
          );
        }
      });

      test('a fee-bump envelope', () {
        for (final vector in [_create, _fund]) {
          expect(
            () => _codec.parse(base64Encode(_feeBumpAround(vector))),
            _invalid(InvalidEnvelopeReason.feeBump),
          );
        }
      });
    });
  });

  group('firstDifference', () {
    final prepared = _builtCreate();
    final preparedBytes = _bytesOf(prepared);

    Uint8List signedWith(void Function(Uint8List bytes) mutate) {
      final bytes = Uint8List.fromList(preparedBytes);
      mutate(bytes);
      return _bodyOf(bytes);
    }

    // The first argument of create_job is an address: ScVal type (4), ScAddress
    // type (4), key type (4), then the key.
    final argsAt = _functionNameAt + 12 + 4; // "create_job" pads to 12 bytes
    final firstArgKeyAt = argsAt + 12;

    test('is null when the bodies are equal', () {
      expect(
        _codec.firstDifference(prepared.body, _bodyOf(preparedBytes)),
        isNull,
      );
    });

    test('names the contract', () {
      final body = signedWith((b) => b[_contractKeyAt + 5] ^= 1);

      expect(_codec.firstDifference(prepared.body, body), 'contract');
    });

    test('names the function', () {
      // "create_job" -> "create_joc": same length, still a valid symbol.
      final body = signedWith((b) => b[_functionNameAt + 9] ^= 1);

      expect(_codec.firstDifference(prepared.body, body), 'function');
    });

    test('names the arguments', () {
      final body = signedWith((b) => b[firstArgKeyAt + 5] ^= 1);

      expect(_codec.firstDifference(prepared.body, body), 'arguments');
    });

    test('names the source', () {
      final body = signedWith((b) => b[_sourceKeyAt + 5] ^= 1);

      expect(_codec.firstDifference(prepared.body, body), 'source');
    });

    test('names the time bounds', () {
      final body = signedWith((b) => b[_maxTimeAt + 7] ^= 1);

      expect(_codec.firstDifference(prepared.body, body), 'timeBounds');
    });

    group('other', () {
      test('fee', () {
        final body = signedWith((b) => b[_feeAt + 3] ^= 1);

        expect(_codec.firstDifference(prepared.body, body), 'other');
      });

      test('sequence number', () {
        final body = signedWith((b) => b[_sequenceAt + 7] ^= 1);

        expect(_codec.firstDifference(prepared.body, body), 'other');
      });

      test('Soroban data', () {
        // The Soroban data is the last field of the transaction.
        final body = signedWith((b) => b[b.length - 5] ^= 1);

        expect(_codec.firstDifference(prepared.body, body), 'other');
      });

      test('memo', () {
        // MEMO_NONE (0) -> MEMO_TEXT (1) with an empty string needs 4 more
        // bytes: splice them after the discriminant.
        final memoAt = _maxTimeAt + 8;
        final bytes = Uint8List.fromList([
          ...preparedBytes.sublist(0, memoAt),
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          ...preparedBytes.sublist(memoAt + 4),
        ]);

        expect(_codec.firstDifference(prepared.body, _bodyOf(bytes)), 'other');
      });

      test('a body that does not decode', () {
        final garbage = Uint8List.fromList(List.filled(32, 7));

        expect(_codec.firstDifference(prepared.body, garbage), 'other');
      });
    });

    group('order of the groups', () {
      test('contract wins over arguments', () {
        final body = signedWith((b) {
          b[_contractKeyAt + 5] ^= 1;
          b[firstArgKeyAt + 5] ^= 1;
        });

        expect(_codec.firstDifference(prepared.body, body), 'contract');
      });

      test('arguments win over source and time bounds', () {
        final body = signedWith((b) {
          b[firstArgKeyAt + 5] ^= 1;
          b[_sourceKeyAt + 5] ^= 1;
          b[_maxTimeAt + 7] ^= 1;
        });

        expect(_codec.firstDifference(prepared.body, body), 'arguments');
      });

      test('source wins over time bounds and other', () {
        final body = signedWith((b) {
          b[_sourceKeyAt + 5] ^= 1;
          b[_maxTimeAt + 7] ^= 1;
          b[_feeAt + 3] ^= 1;
        });

        expect(_codec.firstDifference(prepared.body, body), 'source');
      });

      test('time bounds win over other', () {
        final body = signedWith((b) {
          b[_maxTimeAt + 7] ^= 1;
          b[_feeAt + 3] ^= 1;
        });

        expect(_codec.firstDifference(prepared.body, body), 'timeBounds');
      });
    });

    test('names the function of a fund body too', () {
      final fund = _builtFund();
      final bytes = Uint8List.fromList(_bytesOf(fund))
        ..[_functionNameAt + 3] ^= 1; // "fund" -> "fune"

      expect(_codec.firstDifference(fund.body, _bodyOf(bytes)), 'function');
      expect(
        _codec.firstDifference(fund.body, _bodyOf(_bytesOf(fund))),
        isNull,
      );
    });

    test('compares the recorded body (no time bounds) with a built one', () {
      // Same call, but PRECOND_NONE against PRECOND_TIME.
      expect(
        _codec.firstDifference(_create.body, _builtCreate().body),
        'timeBounds',
      );
    });
  });

  group('verify', () {
    test('accepts the recorded signature of the source account', () {
      for (final vector in [_create, _fund]) {
        final signed = _codec.parse(vector.signedXdr);

        expect(
          _codec.verify(signed, _signer, signed.hash),
          SignatureCheck.valid,
        );
      }
    });

    test('an envelope with no signature is missing', () {
      final signed = _codec.parse(base64Encode(_create.unsigned));

      expect(signed.body, _create.body);
      expect(
        _codec.verify(signed, _signer, signed.hash),
        SignatureCheck.missing,
      );
    });

    test('a signature whose hint is another key is the wrong signer', () {
      final signed = _codec.parse(_create.signedXdr);

      expect(
        _codec.verify(signed, _provider, signed.hash),
        SignatureCheck.wrongSigner,
      );
    });

    test('a tampered hint is the wrong signer', () {
      final hintAt = _create.envelope.length - 64 - 4 - 4;
      final signed = _codec.parse(
        base64Encode(_flip(_create.envelope, hintAt)),
      );

      expect(
        _codec.verify(signed, _signer, signed.hash),
        SignatureCheck.wrongSigner,
      );
    });

    test('two signatures are the wrong signer, even if one is right', () {
      final section = _create.envelope.sublist(
        _create.envelope.length - 4 - 4 - 4 - 64,
      );
      final twoSignatures = Uint8List.fromList([
        ..._create.envelope.sublist(
          0,
          _create.envelope.length - section.length,
        ),
        0,
        0,
        0,
        2,
        ...section.sublist(4),
        ...section.sublist(4),
      ]);
      final signed = _codec.parse(base64Encode(twoSignatures));

      expect(signed.signatures, hasLength(2));
      expect(
        _codec.verify(signed, _signer, signed.hash),
        SignatureCheck.wrongSigner,
      );
    });

    test('a corrupted signature does not verify', () {
      for (final vector in [_create, _fund]) {
        final signed = _codec.parse(
          base64Encode(_flip(vector.envelope, vector.envelope.length - 1)),
        );

        expect(
          _codec.verify(signed, _signer, signed.hash),
          SignatureCheck.doesNotVerify,
        );
      }
    });

    test('a signature over another network passphrase does not verify', () {
      final mainnetHash = StellarEnvelopeCodec.forPassphrase(
        _mainnetPassphrase,
      ).parse(_create.signedXdr).hash;
      final signed = _codec.parse(_create.signedXdr);

      expect(mainnetHash, isNot(signed.hash));
      expect(
        _codec.verify(signed, _signer, mainnetHash),
        SignatureCheck.doesNotVerify,
      );
    });

    test('a signature over another transaction does not verify', () {
      final signed = _codec.parse(_create.signedXdr);

      expect(
        _codec.verify(signed, _signer, _builtCreate().hash),
        SignatureCheck.doesNotVerify,
      );
    });
  });
}
