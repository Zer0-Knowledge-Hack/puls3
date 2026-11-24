import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/ledger/envelope_codec.dart'
    show PreparedEnvelope;
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

/// The file `scripts/setup-local-soroban.sh` writes (#253). It holds only
/// public contract ids and the network passphrase, never a secret.
const localSandboxEnvFile = '.env.local-soroban';

/// The local Stellar standalone network of #253 and the contracts deployed on
/// it, read from [localSandboxEnvFile].
///
/// The E2E suites run on this network only: every account is funded on demand
/// from its Friendbot, and a run never reaches a public network.
final class LocalSandbox {
  LocalSandbox._(this.environment);

  /// `PULS3_STELLAR_*` of the sandbox, ready for `HireWiring`.
  final Map<String, String> environment;

  String get passphrase => environment['PULS3_STELLAR_NETWORK_PASSPHRASE']!;
  String get rpcUrl => environment['PULS3_STELLAR_RPC_URL']!;

  /// The identity that owns the registries and the escrow.
  String get admin => environment['PULS3_STELLAR_SIMULATION_SOURCE']!;

  String get identityRegistry =>
      environment['PULS3_STELLAR_IDENTITY_REGISTRY']!;

  String get friendbotUrl =>
      environment['PULS3_LOCAL_FRIENDBOT_URL'] ??
      rpcUrl.replaceFirst(RegExp(r'/rpc/?$'), '/friendbot');

  /// Connects to the running sandbox, or fails with the commands that start it.
  ///
  /// [overrides] replace the file's and the defaults' values, for the
  /// settings one suite needs (a subcontract reserve ceiling, a job duration).
  static Future<LocalSandbox> connect({
    String? envFile,
    Map<String, String> overrides = const {},
  }) async {
    final file = File(envFile ?? localSandboxEnvFile);
    if (!file.existsSync()) {
      throw StateError(
        'The local sandbox is not set up: ${file.path} is missing. Run '
        '`docker compose -f puls3_server/docker-compose.yaml up -d '
        'soroban_standalone postgres_test redis_test` and then '
        '`bash scripts/setup-local-soroban.sh`.',
      );
    }
    final sandbox = LocalSandbox._({
      ..._parseEnv(file.readAsStringSync()),
      'PULS3_TRACKER_ENABLED': 'true',
      'PULS3_TRACKER_INTERVAL_SECONDS': '2',
      ...overrides,
    });
    // The relay settings the sandbox script does not write. The platform fee
    // matches the escrow it deploys (`--fee-bps 0`) and the job outlives its
    // one-day approval window (`submit` fails with SubmitTooLate otherwise).
    // The duration also leaves a parent room for a child (ADR-0011 D2): a
    // child must expire a full approval window plus `childExpiryMarginSeconds`
    // before its parent and leave `childRunHeadroom` to run, or `subcontract`
    // refuses with `parent_too_short`. With the sandbox's one-day window that
    // takes more than two days, so the default is three windows (259200 s, the
    // example duration of the T6 notes in odd/tasks/agent-subcontracting.md).
    for (final entry in {
      'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': '300',
      'PULS3_STELLAR_INCLUSION_FEE_STROOPS': '100',
      'PULS3_PLATFORM_FEE_BPS': '0',
      'PULS3_HIRE_JOB_DURATION_SECONDS': '259200',
    }.entries) {
      sandbox.environment.putIfAbsent(entry.key, () => entry.value);
    }
    final passphrase = sandbox.environment['PULS3_STELLAR_NETWORK_PASSPHRASE'];
    if (passphrase == null || !passphrase.startsWith('Standalone Network')) {
      // The suites fund accounts for free; a public network must never be hit.
      throw StateError(
        'PULS3_STELLAR_NETWORK_PASSPHRASE is "$passphrase", not the local '
        'standalone network. The E2E suites run on the local sandbox only.',
      );
    }
    if (!await sandbox._rpcHealthy()) {
      throw StateError(
        'Soroban RPC at ${sandbox.rpcUrl} is not healthy. Start it with '
        '`docker compose -f puls3_server/docker-compose.yaml up -d '
        'soroban_standalone`.',
      );
    }
    return sandbox;
  }

  /// Funds [address] from the local Friendbot.
  Future<void> fund(String address) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse(friendbotUrl).replace(queryParameters: {'addr': address}),
      );
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw StateError(
          'Friendbot funded $address with status ${response.statusCode}.',
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  final _cliIdentities = <String>[];

  /// Registers a new agent paid at [priceStroops] on the identity registry,
  /// owned by and paid to a fresh account.
  ///
  /// `set_agent_wallet` needs the new wallet to authorize, so the account is a
  /// Stellar CLI identity that signs its own registration. Its secret is read
  /// back with `stellar keys secret` into memory only and the identity is
  /// removed by [cleanup].
  ///
  /// [skills] are its listed skills (default `research`); a suite gives the
  /// agents it searches for a skill of their own, so the marketplace ranking
  /// of an agent registered by an earlier run never hides them.
  Future<RegisteredAgent> registerAgent({
    required int priceStroops,
    String? name,
    List<String> skills = const ['research'],
  }) async {
    final tag = _randomHex(4);
    final identity = 'puls3-e2e-$tag';
    await _stellar(['keys', 'generate', identity]);
    _cliIdentities.add(identity);
    final wallet = (await _stellar(['keys', 'address', identity])).trim();
    final account = E2eAccount.fromSecret(
      (await _stellar(['keys', 'secret', identity])).trim(),
    );
    if (account.address.value != wallet) {
      throw StateError('identity $identity has an unexpected address.');
    }
    await fund(wallet);
    final metadata = [
      for (final entry in {
        'id': 'e2e-$tag',
        'name': name ?? 'E2E Agent $tag',
        'description': 'An agent registered by the E2E suite on the sandbox.',
        'skills': jsonEncode(skills),
        'priceUsdcStroops': '$priceStroops',
        'model': 'e2e',
        'puls3.manifestVersion': '1',
      }.entries)
        {
          'key': entry.key,
          'value': utf8
              .encode(entry.value)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
        },
    ];
    final registered = await _invoke(identity, [
      'register_full',
      '--caller',
      wallet,
      '--agent-uri',
      'puls3://e2e/$tag',
      '--metadata',
      jsonEncode(metadata),
    ]);
    final agentId = int.parse(registered.replaceAll(RegExp(r'[^0-9]'), ''));
    await _invoke(identity, [
      'set_agent_wallet',
      '--caller',
      wallet,
      '--agent-id',
      '$agentId',
      '--new-wallet',
      wallet,
    ]);
    return RegisteredAgent(agentId, account);
  }

  /// Removes the Stellar CLI identities this run created.
  Future<void> cleanup() async {
    for (final identity in _cliIdentities) {
      await Process.run('stellar', ['keys', 'rm', identity]);
    }
    _cliIdentities.clear();
  }

  Future<String> _stellar(List<String> arguments) async {
    final result = await Process.run('stellar', arguments);
    if (result.exitCode != 0) {
      // Never echo stdout: `keys secret` prints a secret there.
      throw StateError(
        'stellar ${arguments.take(2).join(' ')} failed: ${result.stderr}',
      );
    }
    return result.stdout as String;
  }

  Future<String> _invoke(String sourceIdentity, List<String> arguments) async {
    final result = await Process.run('stellar', [
      'contract',
      'invoke',
      '--id',
      identityRegistry,
      '--network',
      environment['STELLAR_NETWORK']!,
      '--source-account',
      sourceIdentity,
      '--',
      ...arguments,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'stellar contract invoke ${arguments.first} failed: ${result.stderr}',
      );
    }
    return (result.stdout as String).trim();
  }

  Future<bool> _rpcHealthy() async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(rpcUrl));
      request.headers.contentType = ContentType.json;
      request.write('{"jsonrpc":"2.0","id":1,"method":"getHealth"}');
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      final body = await utf8.decodeStream(response);
      return response.statusCode == 200 && body.contains('healthy');
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, String> _parseEnv(String text) {
    final values = <String, String>{};
    for (final raw in LineSplitter.split(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final at = line.indexOf('=');
      if (at < 1) continue;
      var value = line.substring(at + 1).trim();
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      values[line.substring(0, at).trim()] = value;
    }
    return values;
  }
}

/// An agent the suite registered: its registry id and its payment account.
final class RegisteredAgent {
  const RegisteredAgent(this.id, this.account);

  final int id;
  final E2eAccount account;
}

/// An ephemeral account of one test run. The secret lives in memory only.
final class E2eAccount {
  E2eAccount._(this._key)
    : address = StellarAddress.parse(_key.toPublicKey().toAddress().address);

  /// A new random account, not yet funded.
  factory E2eAccount.random() {
    final random = Random.secure();
    return E2eAccount._(
      stellar.StellarPrivateKey.fromBytes(
        List<int>.generate(32, (_) => random.nextInt(256)),
      ),
    );
  }

  /// The account of Stellar secret seed [secret].
  factory E2eAccount.fromSecret(String secret) =>
      E2eAccount._(stellar.StellarPrivateKey.fromBase32(secret));

  final stellar.StellarPrivateKey _key;
  final StellarAddress address;

  /// The secret seed (`S…`). Only for handing an ephemeral sandbox key to a
  /// process that signs for it; it is never logged.
  String get secretSeed => _key.toBase32();

  /// [prepared] signed by this account, as the server signs a relay call.
  String signPrepared(StellarEnvelopeCodec codec, PreparedEnvelope prepared) =>
      codec.sign(prepared, _key);

  /// [unsigned] carrying this account's signature over its transaction hash.
  /// Only the empty signature list at the end of the envelope is replaced, so
  /// the transaction body the server prepared is signed unchanged.
  String sign(StellarEnvelopeCodec codec, String unsigned) {
    final bytes = base64Decode(unsigned);
    final signature = _key.sign(codec.parse(unsigned).hash);
    final out = BytesBuilder()
      ..add(bytes.sublist(0, bytes.length - 4)) // the empty signature list
      ..add([0, 0, 0, 1])
      ..add(signature.hint)
      ..add([0, 0, 0, 64])
      ..add(signature.signature);
    return base64Encode(out.takeBytes());
  }
}

/// Polls [probe] until it returns a value, or fails with [what] on timeout.
Future<T> until<T>(
  String what,
  Future<T?> Function() probe, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = await probe();
    if (value != null) return value;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw TimeoutException('timed out waiting for $what', timeout);
}

String _randomHex(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
