import 'package:puls3_server/src/ledger/sc_val_json.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';

/// One contract event read back from the sandbox RPC (`getEvents`), decoded
/// from the ScVal JSON form (#287).
///
/// The contracts publish `#[contractevent]` structs: the first topic is the
/// snake_case event name, the `#[topic]` fields follow, and the remaining
/// fields are a symbol-keyed map in the event data.
final class ContractEventRecord {
  const ContractEventRecord({
    required this.name,
    required this.topics,
    required this.data,
    required this.ledger,
    required this.transaction,
  });

  /// The event name, for example `job_created`.
  final String name;

  /// The `#[topic]` fields after the name, each in its raw ScVal JSON form.
  /// Read each one with the reader of its own type (`readU64`, `readAddress`).
  final List<Object?> topics;

  /// The data fields, keyed by field name, in raw ScVal JSON form.
  final Map<String, Object?> data;

  final int ledger;

  /// The transaction that emitted the event, when the node reports it.
  final String? transaction;
}

/// Reads and decodes the events a contract emitted on the local sandbox.
final class ContractEventLog {
  ContractEventLog(this._rpc);

  final SorobanRpcClient _rpc;

  /// The ledger the next [read] should start from to see only what happens
  /// after now. Take it before the actions a test asserts on.
  Future<int> mark() => _rpc.getLatestLedger();

  /// Every event [contractId] emitted from [startLedger] on, oldest first.
  /// Follows the page cursor until the node has no more events.
  Future<List<ContractEventRecord>> read(
    String contractId, {
    required int startLedger,
  }) async {
    final filter = RpcEventFilter(contractIds: [contractId]);
    final records = <ContractEventRecord>[];
    var page = await _rpc.getEvents(
      startLedger: startLedger,
      filters: [filter],
      limit: 100,
    );
    while (true) {
      for (final event in page.events) {
        if (event.inSuccessfulContractCall) records.add(_decode(event));
      }
      final cursor = page.cursor;
      if (page.events.isEmpty || cursor == null) return records;
      page = await _rpc.getEvents(
        cursor: cursor,
        filters: [filter],
        limit: 100,
      );
    }
  }

  ContractEventRecord _decode(RpcEvent event) {
    final topics = event.topicJson;
    final value = event.valueJson;
    return ContractEventRecord(
      name: readSymbol(topics.first),
      topics: topics.sublist(1),
      // An event without data fields publishes void.
      data: value == null || isVoid(value) ? const {} : readMap(value),
      ledger: event.ledger,
      transaction: event.txHash,
    );
  }
}

extension ContractEventRecords on List<ContractEventRecord> {
  /// The events named [name] whose first topic is the u64 [id] (the job id of
  /// the escrow events).
  List<ContractEventRecord> forJob(String name, int id) => [
    for (final event in this)
      if (event.name == name &&
          event.topics.isNotEmpty &&
          readU64(event.topics.first) == id)
        event,
  ];
}
