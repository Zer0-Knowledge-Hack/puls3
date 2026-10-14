import '../ledger/contract_events.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/sc_val_json.dart';

/// The agent id of the identity registry's `registered` event in a
/// `getTransaction` result, or null when that event is absent.
int? registeredAgentId(
  Map<String, Object?> transaction, {
  required String contractId,
}) {
  for (final event in contractEvents(transaction)) {
    final body = contractEventBody(event, contractId);
    if (body == null || body.topics.isEmpty) continue;
    final name = body.topics.first;
    if (name is! Map || name['symbol'] != 'registered') continue;
    if (body.topics.length < 2) continue;
    try {
      return readU32(body.topics[1]);
    } on LedgerUnavailable {
      continue;
    }
  }
  return null;
}
