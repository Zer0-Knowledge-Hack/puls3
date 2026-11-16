import 'package:puls3_domain/puls3_domain.dart';

import 'contract_reader.dart';
import 'escrow_job.dart';
import 'ledger_errors.dart';
import 'sc_val_json.dart';
import 'xdr_invoke_encoder.dart';

/// How many clients one `get_clients_paginated` call asks for. It is the
/// size of a read, not a rule of the registry.
const reputationPageSize = 50;

/// Registry `FeedbackNotFound`: the record is not there (never written or
/// already revoked, for `revoke_feedback`; for a read, it cannot be loaded).
const _feedbackNotFound = 2;

/// How many `get_job` reads run at once.
const jobReadConcurrency = 8;

/// The [ReputationRegistry] over the Reputation Registry of #14
/// (`contracts/contracts/reputation-registry`), read through simulated
/// calls like the other registry readers: no signature, no submission.
///
/// What it reads, per agent: `get_clients_paginated` for the clients,
/// `get_last_index` for how many feedbacks each one gave, `read_feedback`
/// for each record, the identity registry's `owner_of` for the agent, then
/// the escrow's `get_job` once for each job those records reference (#201).
///
/// [recordsOf] returns every record the registry lists, raw. [feedbacksOf]
/// is exactly `countedFeedback` of those records and of the jobs read from
/// the configured [escrow]: the public rules of the domain (`exclusionOf`
/// and `exclusionsOf`) are the only reasons a record does not count, and
/// this adapter adds none of its own (#202). A record counts only when its
/// `tag2` names a job of [escrow] that is `Completed` for the same client
/// and agent, once per job; a score written straight to the contract
/// without such a job does not count.
///
/// The registry stores no puls3 hire id and no comment, so the returned
/// [Feedback] has no `hireId` (null: the `feedback_index` is the registry
/// key, not a puls3 hire) and an empty comment. Only `score` feeds
/// `reputationOf`.
final class SorobanReputationRegistry implements ReputationRegistry {
  SorobanReputationRegistry(
    this._reader, {
    required StellarAddress registry,
    required StellarAddress escrow,
    required EscrowJobReader jobs,
    required AgentOwnerReader owners,
  }) : _registry = registry,
       _escrow = escrow,
       _jobs = jobs,
       _owners = owners;

  final ContractReader _reader;
  final StellarAddress _registry;
  final StellarAddress _escrow;
  final EscrowJobReader _jobs;
  final AgentOwnerReader _owners;

  /// Jobs read in a final state (`Completed`, `Rejected`, `Expired`). The
  /// escrow never changes them again, so they are not read twice, and a job
  /// that later archives keeps counting while this process runs.
  final _final = <int, ReferencedJob>{};

  /// The escrow contract whose completed jobs make a rating count. It comes
  /// from the configuration, never from a record.
  StellarAddress get escrow => _escrow;

  /// A registry or escrow read failure is a [LedgerException]: the caller
  /// must not treat it as "no feedback".
  @override
  Future<List<Feedback>> feedbacksOf(AgentId agent) async {
    final (:records, :provenance, clientPages: _) = await readRecords(agent);
    return countedFeedback(records, provenance);
  }

  /// Every feedback record the registry lists for [agent], raw and in
  /// registry order (client by client, index by index), including the ones
  /// that do not count. What an auditor reads on chain (#202).
  ///
  /// A registry read failure is a [LedgerException], never an empty list.
  Future<List<FeedbackRecord>> recordsOf(AgentId agent) async =>
      (await _recordsOf(agent)).records;

  /// [recordsOf], the jobs they reference read from [escrow], and how many
  /// `get_clients_paginated` pages were read (the empty page that ends the
  /// list included), for the verification tool.
  Future<
    ({
      List<FeedbackRecord> records,
      FeedbackProvenance provenance,
      int clientPages,
    })
  >
  readRecords(AgentId agent) async {
    final (:records, :clientPages) = await _recordsOf(agent);
    return (
      records: records,
      provenance: await provenanceOf(
        records,
        owner: records.isEmpty ? null : await _ownerOf(agent),
      ),
      clientPages: clientPages,
    );
  }

  /// The owner of [agent], or null when the identity registry has no such
  /// agent: then no record is excluded as the owner's. An owner that cannot
  /// be read, archived entry included, is a [LedgerException] for the whole
  /// read: the owner rule fails closed, as `FeedbackService` does.
  Future<StellarAddress?> _ownerOf(AgentId agent) => _owners.ownerOf(agent);

  /// The jobs [records] reference on [escrow], each read once with
  /// `get_job`, [jobReadConcurrency] at a time. A job in a final state is
  /// read only once per process.
  ///
  /// A job the escrow does not have, or whose entry is archived, is left out,
  /// so the domain reports that one record as `jobUnreadable` and every other
  /// record still counts. Any other failure (the node, the network) is a
  /// [LedgerException] for the whole read, as for the registry reads.
  ///
  /// [owner] is the rated agent's owner, whose ratings do not count.
  Future<FeedbackProvenance> provenanceOf(
    Iterable<FeedbackRecord> records, {
    StellarAddress? owner,
  }) async {
    final jobs = <int, ReferencedJob>{};
    final toRead = <int>[];
    for (final id in referencedJobIds(records, _escrow)) {
      final known = _final[id];
      if (known != null) {
        jobs[id] = known;
      } else {
        toRead.add(id);
      }
    }
    for (var start = 0; start < toRead.length; start += jobReadConcurrency) {
      final end = start + jobReadConcurrency < toRead.length
          ? start + jobReadConcurrency
          : toRead.length;
      final batch = toRead.sublist(start, end);
      final read = await Future.wait([for (final id in batch) _job(id)]);
      for (var i = 0; i < batch.length; i++) {
        final job = read[i];
        if (job == null) continue;
        jobs[batch[i]] = job;
        if (job.state == JobState.completed ||
            job.state == JobState.rejected ||
            job.state == JobState.expired) {
          _final[batch[i]] = job;
        }
      }
    }
    return FeedbackProvenance(escrow: _escrow, jobs: jobs, owner: owner);
  }

  /// Job [id], or null when the escrow has no such job or its entry is
  /// archived.
  Future<ReferencedJob?> _job(int id) async {
    final EscrowJob? job;
    try {
      job = await _jobs.escrowJob(id);
    } on LedgerUnavailable catch (e) {
      if (e.archived) return null;
      rethrow;
    }
    if (job == null) return null;
    return ReferencedJob(
      client: job.client,
      agentId: job.agentId,
      state: job.state.domain,
    );
  }

  Future<({List<FeedbackRecord> records, int clientPages})> _recordsOf(
    AgentId agent,
  ) async {
    final (:clients, :pages) = await _clientsOf(agent);
    final records = <FeedbackRecord>[];
    for (final client in clients) {
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
    return (records: records, clientPages: pages);
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
  Future<({List<StellarAddress> clients, int pages})> _clientsOf(
    AgentId agent,
  ) async {
    final clients = <StellarAddress>[];
    var start = 0;
    var pages = 0;
    while (true) {
      pages++;
      final page = readVec(
        await _read('get_clients_paginated', [
          ScArg.u32(agent.value),
          ScArg.u32(start),
          const ScArg.u32(reputationPageSize),
        ]),
      ).map(readAddress).toList();
      if (page.isEmpty) return (clients: clients, pages: pages);
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
      tag2: readString(fields['tag2']),
    );
  }

  Future<Object?> _read(
    String function,
    List<ScArg> args, {
    Set<int> absentErrors = const {},
  }) => _reader.read(_registry, function, args, absentErrors: absentErrors);
}
