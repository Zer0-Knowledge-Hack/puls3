import 'package:puls3_domain/puls3_domain.dart';

import 'contract_events.dart';
import 'ledger_errors.dart';
import 'sc_val_json.dart';

const _maxSafeInteger = 9007199254740991;

/// The first USDC payment in a `getTransaction` result, or `null` when the
/// transaction is not a successful USDC transfer to a muxed destination.
///
/// An event counts only when every adapter-level check passes: the
/// transaction status is `SUCCESS`; the event is a `transfer` of [usdcSac] shaped
/// `[symbol, address from, address to, string]`; its data is a map with an
/// `i128` `amount` in `1..2^53-1` and a `u64` `to_muxed_id` that is a valid
/// [HireId]. Events that fail a check are skipped, so the first valid one wins.
///
/// Whether the payee, amount and hire match a given hire is left to the
/// domain (`Payment.settles`). Reused transaction hashes are not checked here.
Payment? firstUsdcPayment(
  Map<String, Object?> tx, {
  required TransactionHash transaction,
  required StellarAddress usdcSac,
}) {
  if (tx['status'] != 'SUCCESS') return null;
  for (final event in contractEvents(tx)) {
    final payment = _payment(event, transaction, usdcSac);
    if (payment != null) return payment;
  }
  return null;
}

Payment? _payment(
  Object? event,
  TransactionHash transaction,
  StellarAddress usdcSac,
) {
  if (event is! Map || event['contract_id'] != usdcSac.value) return null;
  try {
    final body = event['body'];
    final v0 = body is Map ? body['v0'] : null;
    if (v0 is! Map) return null;
    final topics = v0['topics'];
    if (topics is! List || topics.length != 4) return null;
    if (readSymbol(topics[0]) != 'transfer') return null;
    final payer = readAddress(topics[1]);
    final payee = readAddress(topics[2]);
    readString(topics[3]);

    final data = readMap(v0['data']);
    final muxedId = data['to_muxed_id'];
    final amount = data['amount'];
    if (muxedId == null || amount == null) return null;

    final stroops = readI128(amount);
    if (stroops < BigInt.one || stroops > BigInt.from(_maxSafeInteger)) {
      return null;
    }
    return Payment(
      transaction: transaction,
      hireId: HireId(readU64(muxedId)),
      payer: payer,
      payee: payee,
      amount: UsdcAmount.stroops(stroops.toInt()),
    );
  } on LedgerUnavailable {
    return null;
  } on InvalidHireId {
    return null;
  }
}
