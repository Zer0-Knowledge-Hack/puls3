import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart' show HireConfigurationMissing;
import '../hire/chain_accounts.dart';
import '../hire/hire_escrow_effects.dart';
import '../hire/hire_relay_config.dart';
import '../hire/serverpod_escrow_preparation_store.dart';
import '../hire/serverpod_hire_repository.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/soroban_submission_ledger.dart';
import '../ledger/stellar_config.dart';
import '../ledger/stellar_envelope_codec.dart';
import 'chain_log.dart';
import 'chain_submission_tracker.dart';
import 'escrow_server_submit.dart';
import 'serverpod_chain_submission_store.dart';
import 'tracker_loop.dart';

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
/// short session per call.
TrackerLoop? startChainTracker(Serverpod pod, Map<String, String> env) {
  final config = TrackerLoopConfig.fromEnvironment(env);
  if (!config.enabled) return null;
  final stellar = StellarConfig.fromEnvironment(env);
  final httpClient = http.Client();
  final rpc = SorobanRpcClient(
    httpClient: httpClient,
    url: stellar.rpcUrl,
    timeout: stellar.rpcTimeout,
  );
  const ChainLog log = _consoleLog;
  final relay = relaySigningAccount(pod.getPassword('escrowRelaySigningKey'));
  final reader = SorobanLedger(rpc, stellar);
  final codec = StellarEnvelopeCodec.forPassphrase(stellar.networkPassphrase);
  var reportedMissingRelayConfig = false;
  var deadlineAfterId = 0;
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
      lifecycle: <T>(action) async {
        final session = await pod.createSession();
        try {
          return await action(
            ServerpodHireRepository(session),
            ServerpodEscrowPreparationStore(session),
          );
        } finally {
          await session.close();
        }
      },
      ledger: reader,
      jobs: reader,
      usdc: stellar.usdcSac,
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
        if (relay != null) {
          try {
            final fees = HireRelayConfig(env);
            final submissions = ServerpodChainSubmissionStore(session);
            deadlineAfterId = await EscrowDeadlineRunner(
              afterId: deadlineAfterId,
              jobs: reader,
              expiry: reader,
              hires: ServerpodHireRepository(session),
              ledgerTime: rpc.latestLedgerCloseTime,
              log: log,
              sender: RelayEscrowCallSender(
                submissions: submissions,
                accounts: RpcChainAccounts(rpc),
                codec: codec,
                sign: (prepared) =>
                    signWithRelay(codec, prepared, relay.secret),
                send: rpc.sendTransaction,
                source: relay.address,
                escrow: stellar.escrow,
                inclusionFee: fees.inclusionFeeStroops,
                validitySeconds: fees.preparationValiditySeconds,
                now: DateTime.now,
                log: log,
              ),
            ).pass();
          } on HireConfigurationMissing catch (e) {
            if (!reportedMissingRelayConfig) {
              reportedMissingRelayConfig = true;
              log(
                ChainLogLevel.warning,
                'Deadline submissions skipped: ${e.setting} is not set',
              );
            }
          } catch (e) {
            log(ChainLogLevel.error, 'Deadline pass failed: $e');
          }
        }
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
  if (relay == null) {
    log(
      ChainLogLevel.info,
      'escrowRelaySigningKey is not set; release and claim_refund stay off',
    );
  }
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
