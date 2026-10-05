// Live Testnet harness: submits a Freighter-signed payment through Stellar RPC
// and verifies its unified SAC `transfer` event. Run from this package:
//
//   dart run bin/rpc_payment_harness.dart <rpc-url> <signed-xdr-file> \
//     <asset-contract> <payer> <destination-g> <muxed-id> <amount-stroops>
//
// Imports only Flutter-free SDK libraries (see lib/stellar_sdk_vm.dart) so the
// plain Dart VM can run it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_stellar_wallet_spike/payment_evidence.dart';
import 'package:flutter_stellar_wallet_spike/stellar_sdk_vm.dart';
import 'package:flutter_stellar_wallet_spike/transaction_events.dart';

const _usage =
    'Usage: dart run bin/rpc_payment_harness.dart '
    '<rpc-url> <signed-xdr-file> <asset-contract> <payer> '
    '<destination-g> <muxed-id> <amount-stroops>';

Future<void> main(List<String> args) async {
  if (args.length != 7) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final [rpcUrl, xdrFile, contractId, payer, destination, id, amount] = args;
  final muxedId = BigInt.tryParse(id);
  final stroops = BigInt.tryParse(amount);
  if (muxedId == null || stroops == null) {
    stderr.writeln('muxed-id and amount-stroops must be integers.\n$_usage');
    exitCode = 64;
    return;
  }
  final AbstractTransaction parsed;
  try {
    parsed = AbstractTransaction.fromEnvelopeXdrString(
      File(xdrFile).readAsStringSync().trim(),
    );
  } on Object catch (error) {
    stderr.writeln('Cannot read signed transaction XDR: $error');
    exitCode = 65;
    return;
  }
  if (parsed is! Transaction) {
    stderr.writeln('Harness accepts a standard transaction only.');
    exitCode = 65;
    return;
  }

  final server = SorobanServer(rpcUrl);
  final submitted = await server.sendTransaction(parsed);
  final hash = submitted.hash;
  if (hash == null ||
      (submitted.status != SendTransactionResponse.STATUS_PENDING &&
          submitted.status != SendTransactionResponse.STATUS_DUPLICATE)) {
    throw StateError('RPC rejected submission: ${submitted.status}');
  }
  stdout.writeln('submitted hash=$hash status=${submitted.status}');

  GetTransactionResponse? terminal;
  for (var attempt = 1; attempt <= 30; attempt++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final response = await server.getTransaction(hash);
    stdout.writeln('poll=$attempt status=${response.status}');
    if (response.status == GetTransactionResponse.STATUS_SUCCESS ||
        response.status == GetTransactionResponse.STATUS_FAILED) {
      terminal = response;
      break;
    }
  }
  if (terminal == null) {
    throw StateError('Transaction did not become terminal.');
  }
  if (terminal.status != GetTransactionResponse.STATUS_SUCCESS) {
    throw StateError('Transaction failed: ${terminal.resultXdr}');
  }
  final ledger = terminal.ledger;
  if (ledger == null) {
    throw StateError('getTransaction returned no ledger for $hash.');
  }

  // The native SAC emits many events per ledger: query from the
  // transaction's own ledger and page with the cursor.
  final eventsJson = await collectTransactionEvents(
    txHash: hash,
    ledger: ledger,
    fetchPage: (request) async {
      final response = await server.getEvents(
        GetEventsRequest(
          startLedger: request.startLedger,
          endLedger: request.endLedger,
          filters: [
            EventFilter(type: 'contract', contractIds: [contractId]),
          ],
          paginationOptions: PaginationOptions(
            cursor: request.cursor,
            limit: request.limit,
          ),
        ),
      );
      return response.jsonResponse;
    },
  );
  final evidence = PaymentEvidence.fromRpcResponses(
    transactionJson: jsonEncode(terminal.jsonResponse),
    eventsJson: eventsJson,
    expected: PaymentExpectation(
      transactionHash: hash,
      assetContractId: contractId,
      payer: payer,
      destination: destination,
      muxedId: muxedId,
      amount: stroops,
    ),
  );
  stdout.writeln(
    'verified hash=${evidence.hash} ledger=$ledger '
    'contract=${evidence.contractId} payer=${evidence.payer} '
    'destination=${evidence.destination} '
    'muxedId=${evidence.muxedId} amount=${evidence.amount}',
  );
  stdout.writeln('explorer=https://stellar.expert/explorer/testnet/tx/$hash');
}
