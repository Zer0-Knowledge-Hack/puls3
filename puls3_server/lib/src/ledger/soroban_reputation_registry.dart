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

/// The first and last score of a feedback, the scale of #11.
const _lowestScore = 1;
const _highestScore = 5;

/// The [ReputationRegistry] over the Reputation Registry of #14
/// (`contracts/contracts/reputation-registry`), read through simulated
/// calls like the other registry readers: no signature, no submission.
///
/// What it reads, per agent: `get_clients_paginated` for the clients,
/// `get_last_index` for how many feedbacks each one gave, and
/// `read_feedback` for each record.
///
/// What it returns is what `SorobanReputationCalls` writes: a feedback whose
/// `value` is a whole score from 1 to 5 (`value_decimals` 0). Revoked
/// records, records another writer left on the registry with another scale
/// or decimals, and records the registry cannot load are not puls3 scores and
/// are left out. Tags are not a filter: they carry no puls3 meaning.
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
  Future<List<Feedback>> feedbacksOf(AgentId agent) async {
    final feedback = <Feedback>[];
    for (final client in await _clientsOf(agent)) {
      final last = readU64(
        await _read('get_last_index', [
          ScArg.u32(agent.value),
          ScArg.address(client),
        ]),
      );
      for (var index = 1; index <= last; index++) {
        final item = await _feedbackAt(agent, client, index);
        if (item != null) feedback.add(item);
      }
    }
    return feedback;
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

  /// The feedback `client` gave at [index], or `null` when it is not a puls3
  /// score.
  Future<Feedback?> _feedbackAt(
    AgentId agent,
    StellarAddress client,
    int index,
  ) async {
    final value = await _read(
      'read_feedback',
      [ScArg.u32(agent.value), ScArg.address(client), ScArg.u64(index)],
      absentErrors: const {_feedbackNotFound},
    );
    if (value == null) return null;
    final fields = readMap(value);
    if (readBool(fields['is_revoked']) ||
        readU32(fields['value_decimals']) != 0) {
      return null;
    }
    final score = readI128(fields['value']);
    if (score < BigInt.from(_lowestScore) ||
        score > BigInt.from(_highestScore)) {
      return null;
    }
    return Feedback(
      hireId: null,
      agentId: agent,
      client: client,
      score: score.toInt(),
    );
  }

  Future<Object?> _read(
    String function,
    List<ScArg> args, {
    Set<int> absentErrors = const {},
  }) => _reader.read(_registry, function, args, absentErrors: absentErrors);
}
