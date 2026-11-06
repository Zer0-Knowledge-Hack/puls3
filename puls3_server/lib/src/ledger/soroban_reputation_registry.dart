import 'package:puls3_domain/puls3_domain.dart';

import 'contract_reader.dart';
import 'sc_val_json.dart';
import 'xdr_invoke_encoder.dart';

/// How many clients one `get_clients_paginated` call asks for. It is the
/// size of a read, not a rule of the registry.
const reputationPageSize = 50;

/// Registry `FeedbackNotFound`: the record is not there (never written or
/// already revoked, for `revoke_feedback`; for a read, it cannot be loaded).
const _feedbackNotFound = 2;

/// The [ReputationRegistry] over the Reputation Registry of #14
/// (`contracts/contracts/reputation-registry`), read through simulated
/// calls like the other registry readers: no signature, no submission.
///
/// What it reads, per agent: `get_clients_paginated` for the clients,
/// `get_last_index` for how many feedbacks each one gave, and
/// `read_feedback` for each record.
///
/// [recordsOf] returns every record the registry lists, raw. [feedbacksOf]
/// is exactly `countedFeedback` of those records: the four public rules of
/// the domain (`exclusionOf`: unreadable, revoked, not a whole score, outside
/// 1 to 5) are the only reasons a record does not count, and this adapter
/// adds none of its own (#202). Tags are not a filter: they carry no puls3
/// meaning.
///
/// The registry stores no hire and no comment, so the returned [Feedback] has
/// no `hireId` (null: the `feedback_index` is the registry key, not a puls3
/// hire) and an empty comment. Only `score` feeds `reputationOf`.
///
/// Reading is not gated by completed hires: the registry accepts feedback
/// from any address, so a score written straight to the contract is counted.
final class SorobanReputationRegistry implements ReputationRegistry {
  SorobanReputationRegistry(this._reader, {required StellarAddress registry})
    : _registry = registry;

  final ContractReader _reader;
  final StellarAddress _registry;

  /// A registry read failure is a [LedgerException]: the caller must not
  /// treat it as "no feedback".
  @override
  Future<List<Feedback>> feedbacksOf(AgentId agent) async =>
      countedFeedback(await recordsOf(agent));

  /// Every feedback record the registry lists for [agent], raw and in
  /// registry order (client by client, index by index), including the ones
  /// that do not count. What an auditor reads on chain (#202).
  ///
  /// A registry read failure is a [LedgerException], never an empty list.
  Future<List<FeedbackRecord>> recordsOf(AgentId agent) async {
    final records = <FeedbackRecord>[];
    for (final client in await _clientsOf(agent)) {
      final last = readU64(
        await _read('get_last_index', [
          ScArg.u32(agent.value),
          ScArg.address(client),
        ]),
      );
      for (var index = 1; index <= last; index++) {
        records.add(await _recordAt(agent, client, index));
      }
    }
    return records;
  }

  /// The server never signs: the consumer's wallet signs `give_feedback`,
  /// which `SorobanReputationCalls` builds and the relay submits.
  @override
  Future<TransactionHash> giveFeedback(Feedback feedback) =>
      throw UnsupportedError(
        'The server does not record feedback: the wallet signs give_feedback '
        'and the escrow relay submits it',
      );

  /// Every client that gave [agent] feedback, page by page until an empty one.
  Future<List<StellarAddress>> _clientsOf(AgentId agent) async {
    final clients = <StellarAddress>[];
    var start = 0;
    while (true) {
      final page = readVec(
        await _read('get_clients_paginated', [
          ScArg.u32(agent.value),
          ScArg.u32(start),
          const ScArg.u32(reputationPageSize),
        ]),
      ).map(readAddress).toList();
      if (page.isEmpty) return clients;
      clients.addAll(page);
      start += reputationPageSize;
    }
  }

  /// The record `client` gave at [index], as the registry stores it.
  Future<FeedbackRecord> _recordAt(
    AgentId agent,
    StellarAddress client,
    int index,
  ) async {
    final value = await _read(
      'read_feedback',
      [ScArg.u32(agent.value), ScArg.address(client), ScArg.u64(index)],
      absentErrors: const {_feedbackNotFound},
    );
    if (value == null) {
      return FeedbackRecord.unreadable(
        agentId: agent,
        client: client,
        index: index,
      );
    }
    final fields = readMap(value);
    return FeedbackRecord(
      agentId: agent,
      client: client,
      index: index,
      value: readI128(fields['value']),
      valueDecimals: readU32(fields['value_decimals']),
      isRevoked: readBool(fields['is_revoked']),
    );
  }

  Future<Object?> _read(
    String function,
    List<ScArg> args, {
    Set<int> absentErrors = const {},
  }) => _reader.read(_registry, function, args, absentErrors: absentErrors);
}
