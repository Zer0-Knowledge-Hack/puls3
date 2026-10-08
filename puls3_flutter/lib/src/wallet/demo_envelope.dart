import 'dart:convert';
import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// An unsigned Stellar Testnet transaction for [source] that does nothing
/// harmful: one `manage_data` entry named "puls3" with [note].
///
/// The demo gateways hand it to the wallet so a real wallet (Freighter) shows
/// a real signing prompt before the server relay exists (#18, #96). It is
/// never submitted: its sequence number is 0, so the network would reject
/// it anyway.
///
/// Simulated wallets may use addresses that are not real Stellar keys; for
/// those it returns a placeholder, since they never parse the payload.
String demoEnvelope(String source, {required String note}) {
  final bytes = utf8.encode(note);
  // manage_data values are at most 64 bytes.
  final value = Uint8List.fromList(
    bytes.length > 64 ? bytes.sublist(0, 64) : bytes,
  );
  try {
    final tx = TransactionBuilder(Account(source, BigInt.zero))
        .addOperation(ManageDataOperationBuilder('puls3', value).build())
        .addMemo(MemoText('puls3 demo'))
        .build();
    return tx.toEnvelopeXdrBase64();
  } on Object {
    return 'demo-unsigned:$note';
  }
}
