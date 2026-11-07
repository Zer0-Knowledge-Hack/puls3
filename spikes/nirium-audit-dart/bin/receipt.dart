// Spike CLI (#246). See README.md.
//
//   dart run bin/receipt.dart keygen  --out attester.secret
//   dart run bin/receipt.dart anchor  --tx <hash> --registry-id 7 --key-file attester.secret [--mode hash]
//   dart run bin/receipt.dart verify  --cid <cid> --key <G…> [--record out/<cid>.json]
//   dart run bin/receipt.dart measure --tx <hash> --registry-id 7 --key-file attester.secret --count 20
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:nirium_audit_spike/nirium_audit.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand(
      'keygen',
      ArgParser()..addOption('out', mandatory: true, help: 'Key file to write'),
    )
    ..addCommand('anchor', _anchorOptions())
    ..addCommand(
      'verify',
      ArgParser()
        ..addOption('cid', mandatory: true)
        ..addOption('key', mandatory: true, help: "puls3's attesting G… key")
        ..addOption('record', help: 'Local record, needed for a hash anchor'),
    )
    ..addCommand(
      'reverify',
      ArgParser()
        ..addOption('measure', mandatory: true, help: 'A measure output file')
        ..addOption('key', mandatory: true, help: "puls3's attesting G… key")
        ..addOption('record', help: 'Local record, needed for hash anchors'),
    )
    ..addCommand(
      'measure',
      _anchorOptions()
        ..addOption('count', defaultsTo: '20')
        ..addOption(
          'interval-ms',
          defaultsTo: '3500',
          help: 'Pause between anchors; 3500 stays under 20 per minute',
        ),
    );

  final ArgResults args;
  try {
    args = parser.parse(arguments);
    if (args.command == null) throw const FormatException('missing command');
  } on FormatException catch (e) {
    stderr
      ..writeln('error: ${e.message}')
      ..writeln('commands: keygen, anchor, verify, reverify, measure');
    exitCode = 64;
    return;
  }

  final client = http.Client();
  try {
    final command = args.command!;
    exitCode = switch (command.name) {
      'keygen' => _keygen(command),
      'anchor' => await _anchor(command, client),
      'verify' => await _verify(command, client),
      'reverify' => await _reverify(command, client),
      _ => await _measure(command, client),
    };
  } on FormatException catch (e) {
    stderr.writeln('error: ${e.message}');
    exitCode = 64;
  } on NiriumError catch (e) {
    stderr.writeln('error: Nirium answered ${e.status}: ${e.body}');
    exitCode = 1;
  } on NotASettlement catch (e) {
    stderr.writeln('error: ${e.message}');
    exitCode = 1;
  } finally {
    client.close();
  }
}

ArgParser _anchorOptions() => ArgParser()
  ..addOption('tx', mandatory: true, help: 'The escrow complete transaction')
  ..addOption('registry-id', mandatory: true, help: "The paid agent's id")
  ..addOption('wallet', help: "The paid agent's wallet (default: sole payee)")
  ..addOption('key-file', mandatory: true)
  ..addOption('mode', allowed: ['record', 'hash'], defaultsTo: 'record')
  ..addOption('tag', defaultsTo: 'puls3-spike-246');

int _keygen(ArgResults args) {
  final file = File(args.option('out')!);
  if (file.existsSync()) {
    throw FormatException('${file.path} exists; refusing to overwrite it');
  }
  final signer = ReceiptSigner.random();
  file.writeAsStringSync('${signer.exportSecret()}\n');
  stdout.writeln('attesting key ${signer.address} written to ${file.path}');
  return 0;
}

/// Everything an anchor needs, read once.
Future<(Map<String, Object?>, ReceiptSigner, AnchorMode, String)> _prepare(
  ArgResults args,
  http.Client client,
) async {
  final signer = ReceiptSigner.fromSecret(
    File(args.option('key-file')!).readAsStringSync(),
  );
  final registryId = int.tryParse(args.option('registry-id')!);
  if (registryId == null || registryId < 0) {
    throw const FormatException('--registry-id must be a number');
  }
  final settlement = await HorizonReader(
    client,
  ).settlement(args.option('tx')!.trim());
  final payees = {for (final t in settlement.transfers) t.to};
  final wallet =
      args.option('wallet') ?? (payees.length == 1 ? payees.single : null);
  if (wallet == null) {
    throw const FormatException('several payees: pass --wallet');
  }
  final record = receiptRecord(
    settlement,
    agentRegistryId: registryId,
    agentWallet: wallet,
  );
  final mode = AnchorMode.values.byName(args.option('mode')!);
  return (record, signer, mode, args.option('tag')!);
}

Future<int> _anchor(ArgResults args, http.Client client) async {
  final (record, signer, mode, tag) = await _prepare(args, client);
  final watch = Stopwatch()..start();
  final anchor = await NiriumAuditClient(
    client,
  ).anchor(anchorBody(record, signer: signer, mode: mode, tag: tag));
  watch.stop();
  final ours = contentSha256(record);
  _save(anchor.cid, record, anchor);
  stdout
    ..writeln('cid          ${anchor.cid}')
    ..writeln('mode         ${mode.name}')
    ..writeln('attested by  ${anchor.attestedBy ?? '(not echoed)'}')
    ..writeln('hash match   ${anchor.contentSha256 == ours}')
    ..writeln('latency      ${watch.elapsedMilliseconds} ms')
    ..writeln('saved        out/${anchor.cid}.json');
  return anchor.contentSha256 == ours ? 0 : 1;
}

Future<int> _verify(ArgResults args, http.Client client) async {
  final cid = args.option('cid')!.trim();
  Map<String, Object?>? local;
  final recordPath = args.option('record');
  if (recordPath != null) {
    local =
        (jsonDecode(File(recordPath).readAsStringSync()) as Map)['record']
            as Map<String, Object?>;
  }
  final watch = Stopwatch()..start();
  final doc = await IpfsReader(client).read(cid);
  final check = await verifyReceipt(
    doc,
    trustedKey: args.option('key')!.trim(),
    chain: HorizonReader(client).settlement,
    localRecord: local,
  );
  watch.stop();
  if (check.ok) {
    final r = check.record!;
    stdout
      ..writeln('verified     $cid (Nirium API not called)')
      ..writeln('job          ${r['job_id']} on ${r['escrow_contract']}')
      ..writeln(
        'agent        #${(r['agent'] as Map)['registry_id']} ${(r['agent'] as Map)['wallet']}',
      )
      ..writeln('settle tx    ${r['settle_tx']}')
      ..writeln('latency      ${watch.elapsedMilliseconds} ms');
    return 0;
  }
  stderr.writeln('error: NotVerified: $cid');
  for (final failure in check.failures) {
    stderr.writeln('  - $failure');
  }
  return 1;
}

Future<int> _measure(ArgResults args, http.Client client) async {
  final count = int.parse(args.option('count')!);
  final pause = Duration(milliseconds: int.parse(args.option('interval-ms')!));
  final (record, signer, mode, tag) = await _prepare(args, client);
  final nirium = NiriumAuditClient(client);
  final ipfs = IpfsReader(client);
  final rows = <Map<String, Object?>>[];

  for (var i = 0; i < count; i++) {
    if (i > 0) await Future<void>.delayed(pause);
    // A distinct tag per anchor, so each gets its own document and CID.
    final body = anchorBody(record, signer: signer, mode: mode, tag: '$tag-$i');
    final row = <String, Object?>{'i': i};
    final anchorWatch = Stopwatch()..start();
    try {
      final anchor = await nirium.anchor(body);
      row['anchorMs'] = anchorWatch.elapsedMilliseconds;
      row['cid'] = anchor.cid;
      final verifyWatch = Stopwatch()..start();
      final check = await verifyReceipt(
        await ipfs.read(anchor.cid),
        trustedKey: signer.address,
        chain: HorizonReader(client).settlement,
        localRecord: record,
      );
      row['verifyMs'] = verifyWatch.elapsedMilliseconds;
      row['verified'] = check.ok;
      if (!check.ok) row['failures'] = check.failures;
    } on NiriumError catch (e) {
      row['anchorMs'] = anchorWatch.elapsedMilliseconds;
      row['error'] = 'HTTP ${e.status}';
    } on Object catch (e) {
      row['error'] = '${e.runtimeType}: $e';
    }
    rows.add(row);
    stdout.writeln(jsonEncode(row));
  }

  List<int> ms(String key) => [
    for (final r in rows)
      if (r[key] is int) r[key] as int,
  ]..sort();
  int? pct(List<int> v, double p) =>
      v.isEmpty ? null : v[((v.length - 1) * p).round()];
  final anchors = ms('anchorMs');
  final verifies = ms('verifyMs');
  final summary = {
    'mode': mode.name,
    'count': count,
    'intervalMs': pause.inMilliseconds,
    'anchored': rows.where((r) => r['cid'] != null).length,
    'verified': rows.where((r) => r['verified'] == true).length,
    'errors': [
      for (final r in rows)
        if (r['error'] != null) r['error'],
    ],
    'anchorMs': {
      'p50': pct(anchors, .5),
      'p95': pct(anchors, .95),
      'max': anchors.lastOrNull,
    },
    'verifyMs': {
      'p50': pct(verifies, .5),
      'p95': pct(verifies, .95),
      'max': verifies.lastOrNull,
    },
  };
  Directory('out').createSync();
  File(
    'out/measure-${mode.name}-${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
  ).writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({'summary': summary, 'rows': rows}),
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
  return summary['verified'] == count ? 0 : 1;
}

/// Verifies again every CID a `measure` run anchored, without anchoring.
Future<int> _reverify(ArgResults args, http.Client client) async {
  final file = File(args.option('measure')!);
  final run = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final local = args.option('record') == null
      ? null
      : (jsonDecode(File(args.option('record')!).readAsStringSync())
                as Map)['record']
            as Map<String, Object?>;
  final ipfs = IpfsReader(client);
  final times = <int>[];
  var verified = 0;
  final cids = [
    for (final r in (run['rows'] as List).cast<Map>())
      if (r['cid'] != null) r['cid'] as String,
  ];
  for (final cid in cids) {
    final watch = Stopwatch()..start();
    try {
      final check = await verifyReceipt(
        await ipfs.read(cid),
        trustedKey: args.option('key')!.trim(),
        chain: HorizonReader(client).settlement,
        localRecord: local,
      );
      times.add(watch.elapsedMilliseconds);
      if (check.ok) verified++;
      stdout.writeln(
        '$cid ${check.ok ? 'verified' : check.failures.join('; ')} '
        '${watch.elapsedMilliseconds} ms',
      );
    } on Object catch (e) {
      stdout.writeln('$cid error ${e.runtimeType}');
    }
  }
  times.sort();
  final summary = {
    'cids': cids.length,
    'verified': verified,
    'verifyMs': {
      'p50': times.isEmpty ? null : times[(times.length - 1) ~/ 2],
      'p95': times.isEmpty ? null : times[((times.length - 1) * .95).round()],
      'max': times.lastOrNull,
    },
  };
  run['reverify'] = {
    ...summary,
    'at': DateTime.now().toUtc().toIso8601String(),
  };
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(run));
  stdout.writeln(jsonEncode(summary));
  return verified == cids.length ? 0 : 1;
}

void _save(String cid, Map<String, Object?> record, AuditAnchor anchor) {
  Directory('out').createSync();
  File('out/$cid.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'record': record,
      'cid': cid,
      'content_sha256': anchor.contentSha256,
      'anchoredAt': anchor.anchoredAt,
      'gatewayUrl': anchor.gatewayUrl,
    }),
  );
}
