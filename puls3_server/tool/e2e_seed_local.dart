// Seeds the local sandbox for the browser E2E (#256).
//
// It registers one agent, creates and funds the consumer wallet and generates
// the server's wallet-auth signing key, then writes two files into the
// directory in its first argument:
//
//   server.env    environment of the server (sourced by the run script)
//   defines.json  `--dart-define-from-file` for `flutter drive`
//
// Every key is ephemeral and belongs to the local standalone network. Nothing
// secret is printed; the run script deletes the directory when it ends.
//
//   dart run tool/e2e_seed_local.dart <output-dir>
import 'dart:convert';
import 'dart:io';

import '../test/e2e/support/local_sandbox.dart';

/// Price of the seeded agent, in stroops of the sandbox token.
const _priceStroops = 5000000;

const _apiUrl = 'http://localhost:8180/';
const _webPort = 8190;

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/e2e_seed_local.dart <output-dir>');
    exit(64);
  }
  final out = Directory(args.single)..createSync(recursive: true);

  final sandbox = await LocalSandbox.connect();
  final consumer = E2eAccount.random();
  final signing = E2eAccount.random();
  await sandbox.fund(consumer.address.value);
  // Unique per run: the registry keeps every agent of earlier runs, and the
  // test must open this run's agent.
  final agentName =
      'Browser E2E ${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  final agent = await sandbox.registerAgent(
    priceStroops: _priceStroops,
    name: agentName,
  );
  await sandbox.cleanup();

  final serverEnv = {
    ...sandbox.environment,
    'PULS3_ALLOWED_ORIGINS': 'http://localhost:$_webPort',
    'PULS3_AUTH_HOME_DOMAIN': 'localhost',
    'PULS3_AUTH_WEB_AUTH_DOMAIN': 'localhost:8180',
    'SERVERPOD_PASSWORD_walletAuthSigningKey': signing.secretSeed,
  };
  File('${out.path}/server.env').writeAsStringSync(
    [for (final e in serverEnv.entries) '${e.key}="${e.value}"'].join('\n'),
  );

  File('${out.path}/defines.json').writeAsStringSync(
    jsonEncode({
      'PULS3_API_URL': _apiUrl,
      'PULS3_AUTH_SERVER_SIGNING_KEY': signing.address.value,
      'PULS3_AUTH_HOME_DOMAIN': 'localhost',
      'PULS3_AUTH_WEB_AUTH_DOMAIN': 'localhost:8180',
      'E2E_WALLET_SECRET': consumer.secretSeed,
      'E2E_SIGNING_PASSPHRASE': sandbox.passphrase,
      'E2E_AGENT_NAME': agentName,
      'E2E_AGENT_ID': '${agent.id}',
      'E2E_WEB_PORT': '$_webPort',
    }),
  );
  stdout.writeln('Seeded agent ${agent.id} for the browser E2E.');
}
