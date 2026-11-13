// Shared plumbing of the E2E suites (#255): the local Soroban sandbox of
// #253, ephemeral accounts funded on demand by its Friendbot, and the few
// chain calls the suites make as fixtures (registering an agent, signing).
//
// Nothing here prints a secret. Keys live in memory for one run only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart' show ScArg;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

/// A fixture call that was sent and included.
final class SentCall {
  const SentCall(this.hash, this.signedXdr, this.validUntil);

  final String hash;
  final String signedXdr;
  final DateTime validUntil;
}

/// What `scripts/setup-local-soroban.sh` prints, as a pointer for failures.
const sandboxHint =
    'Start the sandbox first: docker compose -f '
    'puls3_server/docker-compose.yaml up -d postgres_test soroban_standalone '
    '&& bash scripts/setup-local-soroban.sh';

/// A throwaway account: its key never leaves this process.
final class E2eAccount {
  E2eAccount._(this.key)
    : address = StellarAddress.parse(key.toPublicKey().toAddress().address);

  factory E2eAccount.random() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return E2eAccount._(stellar.StellarPrivateKey.fromBytes(bytes));
  }

  final stellar.StellarPrivateKey key;
  final StellarAddress address;
}

/// The running local network and the server wiring built on it.
final class E2eSandbox {
  E2eSandbox._(this.env, this.wiring, this.codec, this._friendbot);

  /// The settings the server sees: the sandbox env file, then the process
  /// environment, then the relay settings of these suites.
  final Map<String, String> env;
  final HireWiring wiring;
  final StellarEnvelopeCodec codec;
  final Uri _friendbot;

  String get passphrase => wiring.stellar.networkPassphrase;

  static Future<E2eSandbox> start() async {
    final env = <String, String>{
      ..._readEnvFile(),
      ...Platform.environment,
    };
    for (final name in const [
      'PULS3_STELLAR_RPC_URL',
      'PULS3_STELLAR_NETWORK_PASSPHRASE',
      'PULS3_STELLAR_ESCROW',
      'PULS3_STELLAR_IDENTITY_REGISTRY',
      'PULS3_STELLAR_REPUTATION_REGISTRY',
      'PULS3_STELLAR_USDC_SAC',
    ]) {
      if ((env[name] ?? '').isEmpty) {
        throw StateError('$name is not set. $sandboxHint');
      }
    }
    // These suites only ever run on the throwaway local network.
    if (env['PULS3_STELLAR_NETWORK_PASSPHRASE'] !=
        'Standalone Network ; February 2017') {
      throw StateError(
        'The E2E suites run only on the local standalone network, not on '
        '"${env['PULS3_STELLAR_NETWORK_PASSPHRASE']}".',
      );
    }
    env
      ..putIfAbsent('PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS', () => '600')
      ..putIfAbsent('PULS3_STELLAR_INCLUSION_FEE_STROOPS', () => '100000')
      ..putIfAbsent('PULS3_PLATFORM_FEE_BPS', () => '0')
      ..putIfAbsent('PULS3_HIRE_JOB_DURATION_SECONDS', () => '172800')
      ..['PULS3_TRACKER_ENABLED'] = 'true'
      ..putIfAbsent('PULS3_TRACKER_INTERVAL_SECONDS', () => '2');
    final wiring = HireWiring.fromEnvironment(environment: env);
    final friendbot = Uri.parse(
      env['PULS3_LOCAL_FRIENDBOT_URL'] ?? 'http://localhost:8000/friendbot',
    );
    final sandbox = E2eSandbox._(
      env,
      wiring,
      StellarEnvelopeCodec.forPassphrase(wiring.stellar.networkPassphrase),
      friendbot,
    );
    try {
      await sandbox.wiring.ledger.totalAgents();
    } on Object catch (error) {
      throw StateError('The local RPC does not answer ($error). $sandboxHint');
    }
    return sandbox;
  }

  /// A new account with XLM from the local Friendbot.
  Future<E2eAccount> fundedAccount() async {
    final account = E2eAccount.random();
    final client = HttpClient();
    try {
      final deadline = DateTime.now().add(const Duration(minutes: 1));
      while (true) {
        final request = await client.getUrl(
          _friendbot.replace(
            queryParameters: {'addr': account.address.value},
          ),
        );
        final response = await request.close();
        await response.drain<void>();
        if (response.statusCode == 200) return account;
        if (DateTime.now().isAfter(deadline)) {
          throw StateError(
            'Friendbot answered ${response.statusCode}. $sandboxHint',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } finally {
      client.close();
    }
  }

  /// [unsigned] carrying one signature of [key] over its transaction hash.
  /// The transaction body is not touched: only the empty signature list at
  /// the end of the envelope is replaced.
  String sign(E2eAccount account, String unsigned) {
    final bytes = base64Decode(unsigned);
    final signature = account.key.sign(codec.parse(unsigned).hash);
    final out = BytesBuilder()
      ..add(bytes.sublist(0, bytes.length - 4))
      ..add([0, 0, 0, 1])
      ..add(signature.hint)
      ..add([0, 0, 0, 64])
      ..add(signature.signature);
    return base64Encode(out.takeBytes());
  }

  /// Builds, signs, sends and waits for a contract call that [account]
  /// signs directly, as a fixture.
  Future<SentCall> call(
    E2eAccount account, {
    required StellarAddress contract,
    required String function,
    required List<ScArg> args,
  }) async {
    final validUntil = DateTime.now().toUtc().add(const Duration(minutes: 5));
    final spec = EnvelopeSpec(
      source: account.address,
      accountSequence: await wiring.accounts.sequenceOf(account.address),
      contract: contract,
      function: function,
      args: args,
      inclusionFee: wiring.config.inclusionFeeStroops,
      validUntil: validUntil.millisecondsSinceEpoch ~/ 1000,
    );
    final prepared = codec.build(spec, await wiring.accounts.simulate(spec));
    final signed = sign(account, prepared.envelopeXdr);
    await wiring.sender.resend(signed, prepared.hashHex);
    await until('$function to be included', () async {
      final lookup = await wiring.sender.lookup(prepared.hashHex);
      if (lookup.status == TransactionStatus.failed) {
        throw StateError('$function failed on chain (${prepared.hashHex})');
      }
      return lookup.status == TransactionStatus.success ? lookup : null;
    });
    return SentCall(prepared.hashHex, signed, validUntil);
  }

  /// Registers an agent owned by, and paid to, [account], priced at
  /// [priceStroops], and returns its registry id.
  ///
  /// Ids start at 0 and `HireEndpoint` refuses 0, so a fresh registry first
  /// gets a filler agent. `register_full` binds the wallet to the caller.
  Future<int> registerAgent(
    E2eAccount account, {
    required String name,
    required int priceStroops,
  }) async {
    if (await wiring.ledger.totalAgents() == 0) {
      await _register(account, 'e2e-filler', 'Filler', 1, 'filler');
    }
    final agentId = await wiring.ledger.totalAgents();
    await _register(account, 'e2e-agent', name, priceStroops, 'agent');
    return agentId;
  }

  Future<void> _register(
    E2eAccount account,
    String catalogId,
    String name,
    int priceStroops,
    String uriKind,
  ) async {
    ScArg entry(String key, String value) => ScArg.map({
      'key': ScArg.string(key),
      'value': ScArg.bytes(Uint8List.fromList(utf8.encode(value))),
    });
    await call(
      account,
      contract: wiring.stellar.identityRegistry,
      function: 'register_full',
      args: [
        ScArg.address(account.address),
        ScArg.string('e2e://$uriKind/${account.address.value}'),
        ScArg.vec([
          entry('id', catalogId),
          entry('name', name),
          entry('description', 'An agent registered by the E2E suites.'),
          entry('skills', jsonEncode(['coding'])),
          entry('priceUsdcStroops', priceStroops.toString()),
          entry('puls3.manifestVersion', '1'),
        ]),
      ],
    );
  }
}

/// Polls [probe] until it returns a value or [timeout] passes.
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

Map<String, String> _readEnvFile() {
  final file = File('.env.local-soroban');
  if (!file.existsSync()) return const {};
  final values = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final split = line.indexOf('=');
    if (split < 1) continue;
    var value = line.substring(split + 1).trim();
    if (value.length > 1 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    values[line.substring(0, split).trim()] = value;
  }
  return values;
}
