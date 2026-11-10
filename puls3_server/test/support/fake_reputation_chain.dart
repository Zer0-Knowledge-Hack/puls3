import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/ledger/contract_reader.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/soroban_reputation_registry.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';

import 'reputation_registry_contract.dart';

/// The agent ids the chain answers "no clients" for without being seeded.
const _unseededAgents = 20;

/// A feedback record as the registry stores it: `FeedbackData`.
typedef StoredFeedback = ({
  int value,
  int decimals,
  bool revoked,
  String tag1,
  String tag2,
});

/// An escrow job as the reader needs it: client, agent and state.
typedef StoredJob = ({StellarAddress client, int agent, JobState state});

/// The Reputation Registry of #14 and the escrow's `get_job` as a scripted
/// Soroban RPC: it answers the reads the adapter makes
/// (`get_clients_paginated`, `get_last_index`, `read_feedback` on the
/// registry, `get_job` on the escrow) from [state] and [jobs], in the ScVal
/// JSON the node returns with `xdrFormat: "json"`. No network is touched.
///
/// An envelope the script does not know throws [StateError], so a call the
/// adapter should not make fails the test instead of being answered.
final class FakeReputationChain {
  FakeReputationChain({StellarAddress? registry, StellarAddress? escrow})
    : registry = registry ?? _defaultRegistry,
      escrow = escrow ?? defaultEscrow;

  static final _defaultRegistry = StellarAddress.parse(
    'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
  );

  /// The escrow the adapter trusts unless a test says otherwise.
  static final defaultEscrow = StellarAddress.parse(
    'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
  );

  final StellarAddress registry;
  final StellarAddress escrow;

  /// The escrow's jobs by id. A referenced id that is not here answers
  /// `JobNotFound`.
  final jobs = <int, StoredJob>{};

  /// Job ids whose entry is archived: their `get_job` answers a
  /// `restorePreamble`, as a job past its TTL does.
  final archivedJobs = <int>{};

  var _nextJob = 1000;
  final _source = StellarConfig.testnet.simulationSource;

  /// agent -> client (in registration order) -> feedback (index 1, 2, ...).
  final state = <int, Map<StellarAddress, List<StoredFeedback>>>{};

  /// Entries `read_feedback` answers `FeedbackNotFound` for, as an expired
  /// or removed record would.
  final missing = <(int, StellarAddress, int)>{};

  /// The RPC bodies received, in order.
  final requests = <Map<String, Object?>>[];

  /// How many of [requests] were answered as an escrow `get_job`.
  var jobReads = 0;

  /// The `get_job` envelopes of the last [_answers].
  final _jobEnvelopes = <String>{};

  /// When set, every request gets this HTTP status.
  int? failWithStatus;

  /// When set, every request after the first [failAfterRequests] gets a
  /// 503, as a node that drops in the middle of a read would.
  int? failAfterRequests;

  /// When set, every simulation answers a `restorePreamble`.
  bool needsRestore = false;

  /// Adds [feedback] for [client] under [agent], with its `tag2` as given.
  void add(int agent, StellarAddress client, StoredFeedback feedback) {
    state
        .putIfAbsent(agent, () => {})
        .putIfAbsent(client, () => [])
        .add(feedback);
  }

  /// Adds [feedback] as the app writes it: a new escrow job of [client] for
  /// [agent] in [jobState], named in `tag2`. Returns the job id.
  int addPaid(
    int agent,
    StellarAddress client,
    StoredFeedback feedback, {
    JobState jobState = JobState.completed,
  }) {
    final id = _nextJob++;
    jobs[id] = (client: client, agent: agent, state: jobState);
    add(agent, client, (
      value: feedback.value,
      decimals: feedback.decimals,
      revoked: feedback.revoked,
      tag1: feedback.tag1,
      tag2: reference(id),
    ));
    return id;
  }

  /// The `tag2` reference of job [id] on [escrow].
  String reference(int id) => PaidJobReference(escrow: escrow, jobId: id).text;

  /// The adapter over this chain.
  SorobanReputationRegistry get adapter {
    final reader = ContractReader(
      SorobanRpcClient(
        httpClient: _client,
        url: StellarConfig.testnet.rpcUrl,
        timeout: const Duration(seconds: 1),
      ),
      source: _source,
    );
    return SorobanReputationRegistry(
      reader,
      registry: registry,
      escrow: escrow,
      jobs: ContractEscrowJobReader(reader, escrow: escrow),
    );
  }

  late final http.Client _client = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    requests.add(body);
    final status = failWithStatus;
    if (status != null) return http.Response('', status);
    final after = failAfterRequests;
    if (after != null && requests.length > after) {
      return http.Response('', 503);
    }
    final params = body['params']! as Map<String, Object?>;
    final envelope = params['transaction']! as String;
    final Map<String, Object?> result;
    if (needsRestore) {
      result = {'restorePreamble': <String, Object?>{}};
    } else {
      final answer = _answers()[envelope];
      if (answer == null) {
        throw StateError('The fake chain has no answer for this envelope');
      }
      if (_jobEnvelopes.contains(envelope)) jobReads++;
      result = answer;
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  String _envelope(
    String function,
    List<ScArg> args, {
    StellarAddress? contract,
  }) => encodeInvokeEnvelope(
    source: _source,
    fee: 100,
    sequence: 0,
    contract: contract ?? registry,
    function: function,
    args: args,
  );

  Map<String, Map<String, Object?>> _answers() {
    final answers = <String, Map<String, Object?>>{};
    Map<String, Object?> value(Object? json) => {
      'results': [
        {'returnValueJson': json},
      ],
      'latestLedger': 1,
    };
    for (final agent in {
      ...state.keys,
      for (var id = 0; id < _unseededAgents; id++) id,
    }) {
      final byClient = state[agent] ?? const {};
      final clients = byClient.keys.toList();
      // Every page up to and including the first empty one.
      var start = 0;
      while (true) {
        final page = clients.skip(start).take(reputationPageSize);
        answers[_envelope('get_clients_paginated', [
          ScArg.u32(agent),
          ScArg.u32(start),
          const ScArg.u32(reputationPageSize),
        ])] = value({
          'vec': [
            for (final client in page) {'address': client.value},
          ],
        });
        if (start >= clients.length) break;
        start += reputationPageSize;
      }
      for (final MapEntry(key: client, value: entries) in byClient.entries) {
        answers[_envelope('get_last_index', [
          ScArg.u32(agent),
          ScArg.address(client),
        ])] = value({
          'u64': '${entries.length}',
        });
        for (var i = 1; i <= entries.length; i++) {
          final args = [ScArg.u32(agent), ScArg.address(client), ScArg.u64(i)];
          answers[_envelope(
            'read_feedback',
            args,
          )] = missing.contains((agent, client, i))
              ? {'error': 'HostError: Error(Contract, #2)\n'}
              : value(_feedbackData(entries[i - 1]));
        }
      }
    }
    // get_job for every job id a stored record names on this escrow.
    _jobEnvelopes.clear();
    for (final byClient in state.values) {
      for (final entries in byClient.values) {
        for (final entry in entries) {
          final reference = PaidJobReference.tryParse(entry.tag2);
          if (reference == null || reference.escrow != escrow) continue;
          final job = jobs[reference.jobId];
          final envelope = _envelope('get_job', [
            ScArg.u64(reference.jobId),
          ], contract: escrow);
          _jobEnvelopes.add(envelope);
          if (archivedJobs.contains(reference.jobId)) {
            answers[envelope] = {'restorePreamble': <String, Object?>{}};
            continue;
          }
          answers[envelope] = job == null
              ? {'error': 'HostError: Error(Contract, #1)\n'}
              : value(_jobData(job));
        }
      }
    }
    return answers;
  }

  /// An escrow `Job` as the node prints it (see
  /// `test/unit/ledger/fixtures/simulate_escrow_job_3.json`).
  Map<String, Object?> _jobData(StoredJob job) {
    Map<String, Object?> entry(String key, Object? val) => {
      'key': {'symbol': key},
      'val': val,
    };
    return {
      'map': [
        entry('agent_id', {'u32': job.agent}),
        entry('approval_deadline', {'u64': '0'}),
        entry('budget', {'i128': '5000000'}),
        entry('client', {'address': job.client.value}),
        entry('deliverable', 'void'),
        entry('description', {'string': 'puls3 test job'}),
        entry('evaluator', {'address': job.client.value}),
        entry('expired_at', {'u64': '1800000000'}),
        entry('fee_bps', {'u32': 0}),
        entry('provider', {
          'address': 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
        }),
        entry('state', {'u32': job.state.index}),
        entry('submitted_at', {'u64': '0'}),
        entry('token', {
          'address': 'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA',
        }),
      ],
    };
  }

  /// `FeedbackData` as the node prints it: a map with symbol keys.
  Map<String, Object?> _feedbackData(StoredFeedback f) => {
    'map': [
      {
        'key': {'symbol': 'is_revoked'},
        'val': {'bool': f.revoked},
      },
      {
        'key': {'symbol': 'tag1'},
        'val': {'string': f.tag1},
      },
      {
        'key': {'symbol': 'tag2'},
        'val': {'string': f.tag2},
      },
      {
        'key': {'symbol': 'value'},
        'val': {'i128': '${f.value}'},
      },
      {
        'key': {'symbol': 'value_decimals'},
        'val': {'u32': f.decimals},
      },
    ],
  };
}

/// The shared contract suite's view of the Soroban adapter over a
/// [FakeReputationChain].
final class ChainReputationRegistryRig implements ReputationRegistryRig {
  ChainReputationRegistryRig() : chain = FakeReputationChain();

  final FakeReputationChain chain;

  @override
  ReputationRegistry get registry => chain.adapter;

  /// Each seeded feedback is written as the app writes it: for its own
  /// completed escrow job (#201).
  @override
  void seed(SeededFeedback entry) =>
      chain.addPaid(entry.agent.value, entry.client, (
        value: entry.score,
        decimals: 0,
        revoked: entry.revoked,
        tag1: '',
        tag2: '',
      ));

  @override
  void breakReads() => chain.failWithStatus = 503;
}

/// A valid account address that differs for every [n] (0 to 65535): the
/// strkey of a 32-byte key holding [n].
StellarAddress testAccount(int n) {
  final payload = Uint8List(35)
    ..[0] =
        6 <<
        3 // ed25519 public key version byte
    ..[31] = n >> 8
    ..[32] = n & 0xff;
  final crc = _crc16Xmodem(payload.sublist(0, 33));
  payload
    ..[33] = crc & 0xff
    ..[34] = crc >> 8;
  return StellarAddress.parse(_base32(payload));
}

int _crc16Xmodem(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xffff;
    }
  }
  return crc;
}

String _base32(List<int> bytes) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(alphabet[(buffer >> bits) & 31]);
    }
    buffer &= (1 << bits) - 1;
  }
  if (bits > 0) out.write(alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}
