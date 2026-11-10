// ignore_for_file: avoid_print
// Recomputes an agent's rating from the raw Reputation Registry records on
// testnet and compares it with the rating the puls3 server serves (#202).
// Read-only: contract reads are simulations, the server call is the public
// catalog. No key, no signature.
//
//   dart run scripts/verify_reputation.dart <registryId> [--api <url>]
//
// Run it from the repository root: the repository is a pub workspace, so
// the script resolves `puls3_domain` and `puls3_server` without its own
// pubspec.
//
// It prints every record the registry lists, the paid job its `tag2` names
// (checked with the escrow's `get_job`, #201), whether it counts and why not,
// then the recomputed rating (domain `countedFeedback` + `reputationOf`, the
// code the server runs) next to the served one. Exit code: 0 when they
// match, 1 when they differ, 2 when a read fails.
//
// The server keeps a rating for 60 s (`reputationCacheTtl`): right after a
// new feedback, a mismatch can be that cache. Run it again after a minute.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/contract_reader.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/soroban_reputation_registry.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';

const _defaultApi = 'https://puls3-hub-on-stellar.api.serverpod.space';

Future<void> main(List<String> args) async {
  final options = _parse(args);
  if (options == null) {
    print(
      'usage: dart run scripts/verify_reputation.dart <registryId> '
      '[--api <url>]',
    );
    exit(2);
  }
  final (agent, api) = options;
  final config = StellarConfig.testnet;
  final registryAddress = config.reputationRegistry;
  if (registryAddress == null) {
    print('No Reputation Registry is configured for testnet.');
    exit(2);
  }

  final client = http.Client();
  try {
    final reader = ContractReader(
      SorobanRpcClient(
        httpClient: client,
        url: config.rpcUrl,
        timeout: const Duration(seconds: 20),
      ),
      source: config.simulationSource,
    );
    final registry = SorobanReputationRegistry(
      reader,
      registry: registryAddress,
      escrow: config.escrow,
      jobs: ContractEscrowJobReader(reader, escrow: config.escrow),
    );

    final (:records, :provenance, :clientPages) = await registry.readRecords(
      agent,
    );
    final counted = countedFeedback(records, provenance);
    final exclusions = exclusionsOf(records, provenance);
    final recomputed = reputationOf(counted);

    print('registry : ${registryAddress.value}');
    print('escrow   : ${config.escrow.value}');
    print('agent    : ${agent.value}');
    print(
      'pages    : $clientPages page(s) of get_clients_paginated '
      '($reputationPageSize clients per page)',
    );
    print('records  : ${records.length} listed, ${counted.length} counted');
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final reason = exclusions[i];
      final job = record.jobReference;
      print(
        '  ${_short(record.client)} #${record.index}  '
        'value=${record.value ?? '-'} decimals=${record.valueDecimals ?? '-'} '
        'revoked=${record.isRevoked ?? '-'} '
        'job=${job == null ? '-' : _jobOf(job, provenance)}  '
        '${reason == null ? 'counts' : 'excluded: ${reason.name}'}',
      );
    }
    print('');

    final served = await _servedReputation(client, api, agent);
    if (served == null) {
      print('The server at $api does not list agent ${agent.value}.');
      exit(2);
    }
    final ratingMatches = (served.rating - recomputed).abs() < 1e-9;
    final countMatches = served.paidHireCount == counted.length;
    print(
      'recomputed: rating ${recomputed.toStringAsFixed(2)}, '
      '${counted.length} counted feedback',
    );
    print(
      'served    : rating ${served.rating.toStringAsFixed(2)}, '
      'paidHireCount ${served.paidHireCount} ($api)',
    );
    if (ratingMatches && countMatches) {
      print(
        'MATCH: the served rating is the formula over every counted '
        'on-chain record.',
      );
      exit(0);
    }
    print(
      'MISMATCH: the served rating differs from the chain. If a feedback '
      'landed in the last minute, run again after the 60 s cache.',
    );
    exit(1);
  } on Exception catch (e) {
    print('Read failed: $e');
    exit(2);
  } finally {
    client.close();
  }
}

/// The agent id and API url from [args], or null when they are not valid.
(AgentId, String)? _parse(List<String> args) {
  String? id;
  var api = _defaultApi;
  for (var i = 0; i < args.length; i++) {
    if (args.elementAt(i) == '--api' && i + 1 < args.length) {
      api = args.elementAt(++i);
    } else {
      id ??= args.elementAt(i);
    }
  }
  final value = int.tryParse(id ?? '');
  if (value == null || value < 0) return null;
  return (
    AgentId(value),
    api.endsWith('/') ? api.substring(0, api.length - 1) : api,
  );
}

/// The rating and count the public catalog (`agent.list`) serves for
/// [agent], or null when it does not list it.
Future<({double rating, int paidHireCount})?> _servedReputation(
  http.Client client,
  String api,
  AgentId agent,
) async {
  final response = await client.post(
    Uri.parse('$api/agent/list'),
    headers: {'Content-Type': 'application/json'},
    body: '{}',
  );
  if (response.statusCode != 200) {
    throw HttpException('agent.list answered ${response.statusCode}');
  }
  final agents = jsonDecode(response.body) as List<Object?>;
  for (final item in agents) {
    final summary = item! as Map<String, Object?>;
    if (summary['registryId'] == agent.value) {
      return (
        rating: (summary['rating']! as num).toDouble(),
        paidHireCount: summary['paidHireCount']! as int,
      );
    }
  }
  return null;
}

/// The job id and, when the escrow answered, its state.
String _jobOf(PaidJobReference job, FeedbackProvenance provenance) {
  if (job.escrow != provenance.escrow) return '${job.jobId}@other-escrow';
  final read = provenance.jobs[job.jobId];
  return read == null ? '${job.jobId}(unread)' : '${job.jobId}(${read.state.name})';
}

String _short(StellarAddress address) {
  final value = address.value;
  return '${value.substring(0, 4)}…${value.substring(value.length - 4)}';
}
