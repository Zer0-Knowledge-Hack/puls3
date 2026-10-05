import 'dart:convert';

import 'stellar_sdk_vm.dart';

String prepareMuxedAssetPayment({
  required String payer,
  required BigInt sequence,
  required String destination,
  required BigInt hireId,
  required String assetCode,
  required String assetIssuer,
  required String amount,
}) {
  final muxed = MuxedAccount(destination, hireId).accountId;
  final transaction =
      (TransactionBuilder(Account(payer, sequence))..addOperation(
            PaymentOperationBuilder(
              muxed,
              Asset.createNonNativeAsset(assetCode, assetIssuer),
              amount,
            ).build(),
          ))
          .build();
  return transaction.toEnvelopeXdrBase64();
}

final class PaymentExpectation {
  const PaymentExpectation({
    required this.transactionHash,
    required this.assetContractId,
    required this.payer,
    required this.destination,
    required this.muxedId,
    required this.amount,
  });

  final String transactionHash;
  final String assetContractId;
  final String payer;
  final String destination;
  final BigInt muxedId;
  final BigInt amount;
}

final class PaymentEvidence {
  const PaymentEvidence({
    required this.contractId,
    required this.payer,
    required this.destination,
    required this.muxedId,
    required this.amount,
    required this.hash,
  });

  final String contractId;
  final String payer;
  final String destination;
  final BigInt muxedId;
  final BigInt amount;
  final String hash;

  /// Decodes the SDK's official `getTransaction` and `getEvents` response
  /// models, then cross-checks the protocol-23 transaction meta event against
  /// the separately retrieved event. Missing or inconsistent evidence fails
  /// closed.
  static PaymentEvidence fromRpcResponses({
    required String transactionJson,
    required String eventsJson,
    required PaymentExpectation expected,
  }) {
    try {
      final transaction = GetTransactionResponse.fromJson(
        _jsonObject(transactionJson),
      );
      if (transaction.status != GetTransactionResponse.STATUS_SUCCESS) {
        throw const FormatException('Transaction did not reach SUCCESS.');
      }
      if (transaction.txHash != expected.transactionHash) {
        throw const FormatException('Transaction hash mismatch.');
      }

      final metaV4 = transaction.xdrTransactionMeta?.v4;
      if (metaV4 == null) {
        throw const FormatException(
          'Transaction metadata is not protocol-23 TransactionMetaV4.',
        );
      }
      // Operation-level contract events (the SAC `transfer`) live in
      // operations[].events; transaction-level events (fees) in events[].
      final metaEvents = [
        ...metaV4.events.map((event) => event.event),
        for (final operation in metaV4.operations) ...operation.events,
      ];
      if (metaEvents.isEmpty) {
        throw const FormatException(
          'Protocol-23 transaction metadata contains no unified events.',
        );
      }
      final metaTransfers = metaEvents
          .map(_decodeContractEvent)
          .whereType<_Transfer>()
          .toList();

      final eventResponse = GetEventsResponse.fromJson(_jsonObject(eventsJson));
      if (eventResponse.error != null) {
        throw const FormatException('getEvents returned an RPC error.');
      }
      final rpcTransfers = (eventResponse.events ?? const <EventInfo>[])
          .where(
            (event) =>
                event.inSuccessfulContractCall == true &&
                event.txHash == expected.transactionHash,
          )
          .map(_decodeEventInfo)
          .whereType<_Transfer>()
          .toList();

      final metaMatch = _singleExpected(metaTransfers, expected, 'metadata');
      final rpcMatch = _singleExpected(rpcTransfers, expected, 'getEvents');
      if (metaMatch != rpcMatch) {
        throw const FormatException(
          'Transaction metadata and getEvents evidence disagree.',
        );
      }
      return PaymentEvidence(
        contractId: rpcMatch.contractId,
        payer: rpcMatch.payer,
        destination: rpcMatch.destination,
        muxedId: rpcMatch.muxedId,
        amount: rpcMatch.amount,
        hash: expected.transactionHash,
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Malformed Stellar RPC/XDR evidence: $error');
    }
  }
}

Map<String, dynamic> _jsonObject(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('RPC response must be a JSON object.');
  }
  return decoded;
}

_Transfer _singleExpected(
  List<_Transfer> transfers,
  PaymentExpectation expected,
  String source,
) {
  final matches = transfers.where((value) => value.matches(expected)).toList();
  if (matches.length != 1) {
    throw FormatException(
      '$source must contain exactly one matching successful transfer.',
    );
  }
  return matches.single;
}

_Transfer? _decodeEventInfo(EventInfo event) {
  if (event.type != 'contract') return null;
  final topics = event.topic.map(XdrSCVal.fromBase64EncodedXdrString).toList();
  return _decodeValues(
    contractId: event.contractId,
    topics: topics,
    data: event.valueXdr,
  );
}

_Transfer? _decodeContractEvent(XdrContractEvent event) {
  final body = event.body.v0;
  final hash = event.hash;
  if (body == null || hash == null) return null;
  return _decodeValues(
    contractId: StrKey.encodeContractId(hash.hash),
    topics: body.topics,
    data: body.data,
  );
}

_Transfer? _decodeValues({
  required String contractId,
  required List<XdrSCVal> topics,
  required XdrSCVal data,
}) {
  // CAP-67 SAC events are ["transfer", from, to, sep0011_asset]; custom
  // SEP-41 tokens may omit the asset topic.
  if (topics.length < 3 || topics.length > 4) return null;
  if (topics.first.sym != 'transfer') return null;
  if (topics.length == 4 && topics[3].str == null) return null;
  final payer = topics[1].address?.toStrKey();
  final destination = topics[2].address?.toStrKey();
  if (payer == null || destination == null || data.map == null) return null;

  XdrSCVal? field(String name) {
    for (final entry in data.map!) {
      if (entry.key.sym == name) return entry.val;
    }
    return null;
  }

  final amount = field('amount')?.i128;
  final muxedId = field('to_muxed_id')?.u64?.uint64;
  if (amount == null || muxedId == null) return null;
  final amountValue = (amount.hi.int64 << 64) + amount.lo.uint64;
  return _Transfer(
    contractId: contractId,
    payer: payer,
    destination: destination,
    muxedId: muxedId,
    amount: amountValue,
  );
}

final class _Transfer {
  const _Transfer({
    required this.contractId,
    required this.payer,
    required this.destination,
    required this.muxedId,
    required this.amount,
  });

  final String contractId;
  final String payer;
  final String destination;
  final BigInt muxedId;
  final BigInt amount;

  bool matches(PaymentExpectation expected) =>
      contractId == expected.assetContractId &&
      payer == expected.payer &&
      destination == expected.destination &&
      muxedId == expected.muxedId &&
      amount == expected.amount;

  @override
  bool operator ==(Object other) =>
      other is _Transfer &&
      contractId == other.contractId &&
      payer == other.payer &&
      destination == other.destination &&
      muxedId == other.muxedId &&
      amount == other.amount;

  @override
  int get hashCode =>
      Object.hash(contractId, payer, destination, muxedId, amount);
}
