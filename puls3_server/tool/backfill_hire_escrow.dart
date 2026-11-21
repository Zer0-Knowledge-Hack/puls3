// One-off ops tool for #307: store the escrow on hires that predate the
// `hire.escrow` column, so they keep it after the configured escrow is
// rotated (ADR-0009, "Escrow rotation").
//
// Run it once per environment that has hires, before its first rotation,
// from puls3_server/ with that environment's database and Stellar settings:
//
//   dart run tool/backfill_hire_escrow.dart --escrow C...          # dry run
//   dart run tool/backfill_hire_escrow.dart --escrow C... --apply  # writes
//
// --escrow is the escrow those hires were funded on: the one configured until
// now (PULS3_STELLAR_ESCROW, or contracts/deployments/<network>.json). Every
// hire is checked against that escrow's get_job first, and only a job with the
// same client and agent is written, so a wrong address writes nothing. A hire
// that already has an escrow is never touched. The tool reads the chain only:
// it signs and submits nothing, and needs no secret beyond database access.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_escrow_backfill.dart';
import 'package:puls3_server/src/hire/serverpod_hire_escrow_rows.dart';
import 'package:puls3_server/src/ledger/contract_reader.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:serverpod/serverpod.dart' show Serverpod;

const _usage =
    'Usage: dart run tool/backfill_hire_escrow.dart --escrow <C...> '
    '[--apply] [--mode development|staging|production]';

Never _fail(String message) {
  stderr.writeln('FAIL: $message');
  stderr.writeln(_usage);
  exit(64);
}

String? _option(List<String> args, String name) {
  final at = args.indexOf(name);
  if (at < 0) return null;
  if (at + 1 >= args.length) _fail('$name needs a value');
  return args[at + 1];
}

Future<void> main(List<String> args) async {
  final escrowArg = _option(args, '--escrow');
  if (escrowArg == null) _fail('--escrow is required');
  final StellarAddress escrow;
  try {
    escrow = StellarAddress.parse(escrowArg);
  } on InvalidStellarAddress {
    _fail('--escrow is not a Stellar address');
  }
  if (escrow.kind != StellarAddressKind.contract) {
    _fail('--escrow must be a contract address (C...)');
  }
  final apply = args.contains('--apply');
  final mode = _option(args, '--mode') ?? 'development';
  if (!const {'development', 'staging', 'production'}.contains(mode)) {
    _fail('--mode must be development, staging or production');
  }

  final stellar = StellarConfig.fromEnvironment(Platform.environment);
  stdout.writeln('== Backfill hire.escrow (#307)');
  stdout.writeln('   escrow: ${escrow.value}');
  stdout.writeln('   configured escrow: ${stellar.escrow.value}');
  stdout.writeln('   serverpod mode: $mode');
  stdout.writeln(
    '   ${apply ? 'APPLY: matching hires are written' : 'dry run'}',
  );

  final pod = Serverpod(['--mode', mode], Protocol(), Endpoints());
  await pod.start();
  final session = await pod.createSession();
  final httpClient = http.Client();
  try {
    final rpc = SorobanRpcClient(
      httpClient: httpClient,
      url: stellar.rpcUrl,
      timeout: stellar.rpcTimeout,
    );
    final backfill = HireEscrowBackfill(
      rows: ServerpodHireEscrowRows(session),
      jobs: ContractEscrowJobReader(
        ContractReader(rpc, source: stellar.simulationSource),
        escrow: escrow,
      ),
      escrow: escrow,
    );
    final lines = await backfill.run(apply: apply);

    final counts = <BackfillOutcome, int>{};
    for (final line in lines) {
      counts.update(line.outcome, (n) => n + 1, ifAbsent: () => 1);
      stdout.writeln(
        '   hire ${line.hire.hireId} job ${line.hire.jobId}: '
        '${line.outcome.name}${line.written ? ' (written)' : ''}',
      );
    }
    stdout.writeln(
      '== ${lines.length} hires without an escrow: '
      '${[for (final o in BackfillOutcome.values) '${o.name} ${counts[o] ?? 0}'].join(', ')}',
    );
    if (!apply && (counts[BackfillOutcome.matched] ?? 0) > 0) {
      stdout.writeln('   Rerun with --apply to write the matched hires.');
    }
  } finally {
    httpClient.close();
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
}
