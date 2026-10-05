import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_stellar_wallet_spike/payment_evidence.dart';
import 'package:flutter_stellar_wallet_spike/transaction_events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

const payer = 'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK';
const destination = 'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV';
const issuer = 'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R';
const hash = '17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f';

final contractId = StrKey.encodeContractId(
  Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
);
final muxed = MuxedAccount(destination, BigInt.from(68));

XdrContractEvent transferEvent({
  String? from,
  String? to,
  BigInt? amount,
  BigInt? muxedId,
  String? assetContractId,
}) {
  final body = XdrContractEventBody(0)
    ..v0 = XdrContractEventV0(
      [
        XdrSCVal.forSymbol('transfer'),
        XdrSCVal.forAddressStrKey(from ?? payer),
        XdrSCVal.forAddressStrKey(to ?? destination),
      ],
      XdrSCVal.forMap([
        XdrSCMapEntry(
          XdrSCVal.forSymbol('amount'),
          XdrSCVal.forI128BigInt(amount ?? BigInt.from(10000000)),
        ),
        XdrSCMapEntry(
          XdrSCVal.forSymbol('to_muxed_id'),
          XdrSCVal.forU64(muxedId ?? BigInt.from(68)),
        ),
      ]),
    );
  return XdrContractEvent(
    XdrExtensionPoint(0),
    XdrHash(StrKey.decodeContractId(assetContractId ?? contractId)),
    XdrContractEventType.CONTRACT,
    body,
  );
}

String transactionMeta(XdrContractEvent event) {
  final meta = XdrTransactionMeta(4)
    ..v4 = XdrTransactionMetaV4(
      XdrExtensionPoint(0),
      XdrLedgerEntryChanges([]),
      [],
      XdrLedgerEntryChanges([]),
      null,
      [
        XdrTransactionEvent(
          XdrTransactionEventStage.TRANSACTION_EVENT_STAGE_AFTER_TX,
          event,
        ),
      ],
      [],
    );
  return meta.toBase64EncodedXdrString();
}

String transactionResponse({
  String status = 'SUCCESS',
  String? txHash,
  XdrContractEvent? event,
}) => jsonEncode({
  'jsonrpc': '2.0',
  'id': 1,
  'result': {
    'status': status,
    'latestLedger': 100,
    'latestLedgerCloseTime': '1759200000',
    'oldestLedger': 1,
    'oldestLedgerCloseTime': '1759100000',
    if (status != 'NOT_FOUND') ...{
      'ledger': 99,
      'createdAt': '1759199995',
      'applicationOrder': 1,
      'feeBump': false,
      'txHash': txHash ?? hash,
      'resultMetaXdr': transactionMeta(event ?? transferEvent()),
    },
  },
});

String eventsResponse(XdrContractEvent event) {
  final v0 = event.body.v0!;
  return jsonEncode({
    'jsonrpc': '2.0',
    'id': 2,
    'result': {
      'latestLedger': 100,
      'oldestLedger': 1,
      'events': [
        {
          'type': 'contract',
          'ledger': 99,
          'ledgerClosedAt': '2026-09-30T00:00:00Z',
          'contractId': contractId,
          'id': '0000000099-0000000000000001',
          'topic': v0.topics
              .map((value) => value.toBase64EncodedXdrString())
              .toList(),
          'value': v0.data.toBase64EncodedXdrString(),
          'inSuccessfulContractCall': true,
          'txHash': hash,
          'opIndex': 0,
          'txIndex': 1,
        },
      ],
    },
  });
}

PaymentExpectation get expected => PaymentExpectation(
  transactionHash: hash,
  assetContractId: contractId,
  payer: payer,
  destination: destination,
  muxedId: BigInt.from(68),
  amount: BigInt.from(10000000),
);

void main() {
  test(
    'decodes official getTransaction/meta and getEvents response shapes',
    () {
      final event = transferEvent();
      final evidence = PaymentEvidence.fromRpcResponses(
        transactionJson: transactionResponse(event: event),
        eventsJson: eventsResponse(event),
        expected: expected,
      );
      expect(evidence.hash, hash);
      expect(evidence.muxedId, BigInt.from(68));
      expect(evidence.destination, destination);
      expect(evidence.amount, BigInt.from(10000000));
    },
  );

  test('fails closed for non-success terminal status', () {
    expect(
      () => PaymentEvidence.fromRpcResponses(
        transactionJson: transactionResponse(status: 'FAILED'),
        eventsJson: eventsResponse(transferEvent()),
        expected: expected,
      ),
      throwsFormatException,
    );
  });

  test('rejects a transaction hash mismatch', () {
    final event = transferEvent();
    expect(
      () => PaymentEvidence.fromRpcResponses(
        transactionJson: transactionResponse(
          txHash: List.filled(64, '0').join(),
          event: event,
        ),
        eventsJson: eventsResponse(event),
        expected: expected,
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects amount, payer, destination, muxed id, and asset mismatches',
    () {
      final wrongContract = StrKey.encodeContractId(Uint8List(32));
      final cases = <XdrContractEvent>[
        transferEvent(amount: BigInt.two),
        transferEvent(from: issuer),
        transferEvent(to: issuer),
        transferEvent(muxedId: BigInt.from(69)),
        transferEvent(assetContractId: wrongContract),
      ];
      for (final event in cases) {
        expect(
          () => PaymentEvidence.fromRpcResponses(
            transactionJson: transactionResponse(event: event),
            eventsJson: eventsResponse(event),
            expected: expected,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('rejects disagreement between result meta and getEvents', () {
    final event = transferEvent(amount: BigInt.two);
    expect(
      () => PaymentEvidence.fromRpcResponses(
        transactionJson: transactionResponse(),
        eventsJson: eventsResponse(event),
        expected: expected,
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed event XDR', () {
    final malformed =
        jsonDecode(eventsResponse(transferEvent())) as Map<String, dynamic>;
    (malformed['result']['events'] as List).first['value'] = 'not-xdr';
    expect(
      () => PaymentEvidence.fromRpcResponses(
        transactionJson: transactionResponse(),
        eventsJson: jsonEncode(malformed),
        expected: expected,
      ),
      throwsFormatException,
    );
  });

  group('recorded SDF Testnet RPC responses', () {
    // Public Testnet data from a live classic native payment to a muxed
    // destination (ledger 4953089). getEvents was trimmed to a few unrelated
    // native-SAC events plus both events of this transaction (fee + transfer).
    const liveHash =
        '820c8a985f219346bd7c5672d33b13b7621d384057098619ef82524501d756b4';
    final liveExpected = PaymentExpectation(
      transactionHash: liveHash,
      assetContractId:
          'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC',
      payer: 'GCCB4MKFLRRD4HBXNGMXQMIIU5TSYX2TBAQIQRIGE5LSILPW77E44GOZ',
      destination: 'GBB4PCYW57UQRKED36ZLOHB4PQMBD7QYEVQKXWYB6ER5LOMJ7I6MS4MT',
      muxedId: BigInt.from(68),
      amount: BigInt.from(10000000),
    );
    String fixture(String name) =>
        File('test/fixtures/$name').readAsStringSync();

    test('verifies the unified SAC transfer event of a muxed payment', () {
      final evidence = PaymentEvidence.fromRpcResponses(
        transactionJson: fixture('testnet_muxed_payment_transaction.json'),
        eventsJson: fixture('testnet_muxed_payment_events.json'),
        expected: liveExpected,
      );
      expect(evidence.hash, liveHash);
      expect(evidence.muxedId, BigInt.from(68));
      expect(evidence.amount, BigInt.from(10000000));
    });

    test(
      'verifies after selecting the transaction events by pagination',
      () async {
        final page =
            jsonDecode(fixture('testnet_muxed_payment_events.json'))
                as Map<String, Object?>;
        final eventsJson = await collectTransactionEvents(
          fetchPage: (_) async => page,
          txHash: liveHash,
          ledger: 4953089,
        );
        final events =
            ((jsonDecode(eventsJson) as Map)['result'] as Map)['events'];
        expect(events, hasLength(2));
        final evidence = PaymentEvidence.fromRpcResponses(
          transactionJson: fixture('testnet_muxed_payment_transaction.json'),
          eventsJson: eventsJson,
          expected: liveExpected,
        );
        expect(evidence.hash, liveHash);
      },
    );

    test('still fails closed on the live data for a wrong muxed id', () {
      expect(
        () => PaymentEvidence.fromRpcResponses(
          transactionJson: fixture('testnet_muxed_payment_transaction.json'),
          eventsJson: fixture('testnet_muxed_payment_events.json'),
          expected: PaymentExpectation(
            transactionHash: liveHash,
            assetContractId: liveExpected.assetContractId,
            payer: liveExpected.payer,
            destination: liveExpected.destination,
            muxedId: BigInt.from(69),
            amount: liveExpected.amount,
          ),
        ),
        throwsFormatException,
      );
    });
  });

  test('prepares a classic asset payment to a muxed hire destination', () {
    final xdr = prepareMuxedAssetPayment(
      payer: payer,
      sequence: BigInt.one,
      destination: destination,
      hireId: BigInt.from(68),
      assetCode: 'USDC',
      assetIssuer: issuer,
      amount: '1',
    );
    final tx = AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
    final payment = tx.operations.single as PaymentOperation;
    expect(payment.destination.accountId, muxed.accountId);
    expect(payment.destination.id, BigInt.from(68));
  });
}
