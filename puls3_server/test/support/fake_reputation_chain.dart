import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/ledger/contract_reader.dart';
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

/// The Reputation Registry of #14 as a scripted Soroban RPC: it answers the
/// three reads the adapter makes (`get_clients_paginated`, `get_last_index`,
/// `read_feedback`) from [state], in the ScVal JSON the node returns with
/// `xdrFormat: "json"`. No network is touched.
///
/// An envelope the script does not know throws [StateError], so a call the
/// adapter should not make fails the test instead of being answered.
final class FakeReputationChain {
  FakeReputationChain({StellarAddress? registry})
    : registry = registry ?? _defaultRegistry;

  static final _defaultRegistry = StellarAddress.parse(
    'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
  );

  final StellarAddress registry;
  final _source = StellarConfig.testnet.simulationSource;

  /// agent -> client (in registration order) -> feedback (index 1, 2, ...).
  final state = <int, Map<StellarAddress, List<StoredFeedback>>>{};

  /// Entries `read_feedback` answers `FeedbackNotFound` for, as an expired
  /// or removed record would.
  final missing = <(int, StellarAddress, int)>{};

  /// The RPC bodies received, in order.
  final requests = <Map<String, Object?>>[];

  /// When set, every request gets this HTTP status.
  int? failWithStatus;

  /// When set, every simulation answers a `restorePreamble`.
  bool needsRestore = false;

  /// Adds [feedback] for [client] under [agent].
  void add(int agent, StellarAddress client, StoredFeedback feedback) {
    state
        .putIfAbsent(agent, () => {})
        .putIfAbsent(client, () => [])
        .add(feedback);
  }

  /// The adapter over this chain.
  SorobanReputationRegistry get adapter => SorobanReputationRegistry(
    ContractReader(
      SorobanRpcClient(
        httpClient: _client,
        url: StellarConfig.testnet.rpcUrl,
        timeout: const Duration(seconds: 1),
      ),
      source: _source,
    ),
    registry: registry,
  );

  late final http.Client _client = MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    requests.add(body);
    final status = failWithStatus;
    if (status != null) return http.Response('', status);
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
      result = answer;
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  String _envelope(String function, List<ScArg> args) => encodeInvokeEnvelope(
    source: _source,
    fee: 100,
    sequence: 0,
    contract: registry,
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
    return answers;
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

  @override
  void seed(SeededFeedback entry) =>
      chain.add(entry.agent.value, entry.client, (
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
