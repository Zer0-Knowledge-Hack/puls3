// The Nirium receipt sandbox (#296). See README.md.
//
//   dart run bin/sandbox.dart [--tx <hash>] [--key-file attester.secret]
//       [--scenario happy --scenario rateLimit …] [--mode hash]
//       [--horizon <url> --rpc <url> --network <label>]
//
// It starts a Nirium node on localhost and runs the receipt queue against it.
// Nothing is sent to Nirium. The chain is only read.
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:nirium_audit_spike/nirium_audit.dart';

/// Job 3 `complete` on testnet, the transaction of the spike (#246).
const _job3Tx =
    'ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('tx', defaultsTo: _job3Tx, help: 'A confirmed escrow complete')
    ..addOption(
      'key-file',
      help: 'An attesting key file. Without it, a key made for this run only',
    )
    ..addMultiOption(
      'scenario',
      allowed: [for (final s in SandboxScenario.values) s.name],
      help: 'Default: all of them',
    )
    ..addOption('mode', allowed: ['record', 'hash'], defaultsTo: 'record')
    ..addOption('horizon', help: 'Default: Horizon on testnet')
    ..addOption('rpc', help: 'Default: Soroban RPC on testnet')
    ..addOption('network', defaultsTo: 'stellar:testnet')
    ..addOption('dir', defaultsTo: 'out/sandbox', help: 'Queue files go here');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln('error: ${e.message}')
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }

  final ReceiptSigner signer;
  final keyFile = args.option('key-file');
  try {
    signer = keyFile == null
        ? ReceiptSigner.random()
        : ReceiptSigner.fromSecret(File(keyFile).readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('error: ${e.message}');
    exitCode = 64;
    return;
  } on FileSystemException {
    stderr.writeln('error: cannot read $keyFile');
    exitCode = 64;
    return;
  }

  final horizon = args.option('horizon');
  final rpc = args.option('rpc');
  final names = args.multiOption('scenario');
  final client = http.Client();
  try {
    stdout
      ..writeln('transaction  ${args.option('tx')}')
      ..writeln('attester     ${signer.address}')
      ..writeln('chain        ${horizon ?? horizonTestnet} (read only)')
      ..writeln('Nirium       a local node on localhost; nothing is published');
    final results = await runSandbox(
      txHash: args.option('tx')!.trim(),
      signer: signer,
      chain: HorizonReader(
        client,
        horizon: horizon == null ? null : Uri.parse(horizon),
        network: args.option('network')!,
      ).settlement,
      job: SorobanJobReader(
        client,
        rpc: rpc == null ? null : Uri.parse(rpc),
      ).job,
      nodeClient: client,
      directory: Directory(args.option('dir')!),
      scenarios: names.isEmpty
          ? SandboxScenario.values
          : [for (final name in names) SandboxScenario.values.byName(name)],
      mode: AnchorMode.values.byName(args.option('mode')!),
      log: stdout.writeln,
    );
    final unexpected = results.where((r) => !r.ok).length;
    stdout
      ..writeln('')
      ..writeln(
        unexpected == 0
            ? 'all ${results.length} scenarios ended as expected'
            : '$unexpected of ${results.length} scenarios did not',
      );
    exitCode = unexpected == 0 ? 0 : 1;
  } finally {
    client.close();
  }
}
