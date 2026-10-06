import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../hire/hire_escrow_effects.dart';
import '../hire/serverpod_hire_repository.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/soroban_submission_ledger.dart';
import '../ledger/stellar_config.dart';
import 'chain_log.dart';
import 'chain_submission_tracker.dart';
import 'serverpod_chain_submission_store.dart';
import 'tracker_loop.dart';

const _rpcTimeout = Duration(seconds: 8);

/// Longest a pass may run before the loop gives up on it. A full batch of
/// RPC calls normally takes seconds; this only catches a hung pass, such as
/// a stuck database call.
const _passTimeout = Duration(minutes: 5);

/// Starts the chain submission tracker when [env] enables it (see
/// [TrackerLoopConfig]) and returns its loop, or returns `null`. Stopping
/// the loop also closes its HTTP client.
///
/// Each pass opens its own session, so a pass never holds a connection
/// between ticks. The escrow effects ([HireEscrowEffects]) open their own
/// short session per call; recording the job id after `create_job` waits for
/// the hire lifecycle (#96).
TrackerLoop? startChainTracker(Serverpod pod, Map<String, String> env) {
  final config = TrackerLoopConfig.fromEnvironment(env);
  if (!config.enabled) return null;
  final stellar = StellarConfig.fromEnvironment(env);
  final httpClient = http.Client();
  final rpc = SorobanRpcClient(
    httpClient: httpClient,
    url: stellar.rpcUrl,
    timeout: _rpcTimeout,
  );
  const ChainLog log = _consoleLog;
  final reader = SorobanLedger(rpc, stellar);
  final tracker = ChainSubmissionTracker(
    ledger: SorobanSubmissionLedger(rpc, escrow: stellar.escrow),
    effects: HireEscrowEffects(
      repositories: <T>(action) async {
        final session = await pod.createSession();
        try {
          return await action(ServerpodHireRepository(session));
        } finally {
          await session.close();
        }
      },
      ledger: reader,
      jobs: reader,
      usdc: stellar.usdcSac,
      log: log,
    ),
    log: log,
  );
  final loop = TrackerLoop(
    interval: config.interval,
    passTimeout: _passTimeout,
    log: log,
    runPass: () async {
      final session = await pod.createSession();
      try {
        final summary = await tracker.pass(
          ServerpodChainSubmissionStore(session),
        );
        if (summary.listed > 0) log(ChainLogLevel.info, 'Pass: $summary');
      } finally {
        await session.close();
      }
    },
    onStop: () async => httpClient.close(),
  )..start();
  log(
    ChainLogLevel.info,
    'Chain submission tracker started, every ${config.interval.inSeconds}s',
  );
  return loop;
}

void _consoleLog(ChainLogLevel level, String message) {
  final line = '[chain-tracker] ${level.name}: $message';
  if (level == ChainLogLevel.info) {
    stdout.writeln(line);
  } else {
    stderr.writeln(line);
  }
}
