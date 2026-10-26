// Testnet ops tool for #209: create a custodied wallet per seed demo agent
// and rebind Identity Registry `set_agent_wallet` (owner auth entry + agent
// envelope). Secrets are read from the environment, kept in memory, and never
// printed. The escrow-admin secret is not a server password.
//
// The Serverpod database of `--mode` is where `agent_wallet` rows are written.
// puls3.org's hire runtime only signs keys in the Cloud database: run this
// against that database (or copy the rows while keeping the same
// `PULS3_AGENT_WALLET_SECRET_KEY`). See docs/infra/secrets.md.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/demo_wallet_rebinder.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/wallet_custody_config.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/ledger/soroban_ledger.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/studio/auth_entry_signer.dart';
import 'package:puls3_server/src/studio/deploy_chain.dart';
import 'package:serverpod/serverpod.dart' show Serverpod;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _explorer = 'https://stellar.expert/explorer/testnet/tx';
const _seedAdmin = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

Never _fail(String message) {
  stderr.writeln('FAIL: $message');
  exit(1);
}

void _ok(String message) => stdout.writeln('   ok: $message');

Future<void> main(List<String> args) async {
  final secret = Platform.environment['PULS3_REBIND_OWNER_SECRET'];
  if (secret == null || secret.isEmpty) {
    _fail('PULS3_REBIND_OWNER_SECRET is not set (see docs/infra/secrets.md).');
  }
  final ownerKey = stellar.StellarPrivateKey.fromBase32(secret);
  final owner = StellarAddress.parse(
    ownerKey.toPublicKey().toAddress().baseAddress,
  );
  final expected = Platform.environment['PULS3_REBIND_OWNER_ADDRESS'];
  if (expected != null && expected != owner.value) {
    _fail('the secret does not belong to PULS3_REBIND_OWNER_ADDRESS.');
  }

  final env = Platform.environment;
  final mode = env['PULS3_E2E_SERVERPOD_MODE'] ?? 'development';
  if (mode != 'test' && mode != 'development') {
    _fail('PULS3_E2E_SERVERPOD_MODE must be test or development.');
  }

  WalletCustodyConfig custodyConfig;
  try {
    custodyConfig = WalletCustodyConfig.fromEnvironment(env);
  } catch (e) {
    _fail(
      'agent-wallet custody is not configured ($e). Set '
      'PULS3_AGENT_WALLET_SECRET_KEY.',
    );
  }
  final stellarCfg = StellarConfig.fromEnvironment(env);
  if (stellarCfg.networkPassphrase != _testnetPassphrase) {
    _fail(
      'the passphrase is not the testnet one (this script never runs on mainnet).',
    );
  }
  final fees = HireRelayConfig(env);
  final admin = StellarAddress.parse(
    env['PULS3_REBIND_ADMIN_WALLET'] ?? _seedAdmin,
  );

  final seedPath =
      env['SEED_FILE'] ??
      '${Directory.current.path}/../contracts/deployments/demo-agents.json';
  final seedFile = File(seedPath);
  if (!seedFile.existsSync()) {
    _fail('seed file not found: $seedPath');
  }
  final seedJson = jsonDecode(seedFile.readAsStringSync());
  final seedUris = <String>{
    for (final agent in seedJson['agents'] as List)
      (agent as Map)['uri'] as String,
  };
  if (seedUris.isEmpty) _fail('seed file has no agents');

  stdout.writeln('== Rebind demo agents (#209)');
  _ok('owner (public): ${owner.value}');
  _ok('admin wallet: ${admin.value}');
  _ok('serverpod mode: $mode');
  _ok('seed uris: ${seedUris.length}');

  final pod = Serverpod(
    ['--mode', mode, if (mode == 'test') '--apply-migrations'],
    Protocol(),
    Endpoints(),
  );
  await pod.start();
  final session = await pod.createSession();
  final httpClient = http.Client();
  final friendbot = http.Client();
  final rpc = SorobanRpcClient(
    httpClient: httpClient,
    url: stellarCfg.rpcUrl,
    timeout: stellarCfg.rpcTimeout,
  );
  final codec = StellarEnvelopeCodec.forPassphrase(
    stellarCfg.networkPassphrase,
  );
  final wallets = ServerpodAgentWalletStore(session);
  final cipher = AesGcmSecretCipher(
    keys: {custodyConfig.keyVersion: custodyConfig.secretKey},
    writeKeyVersion: custodyConfig.keyVersion,
  );
  final ledger = SorobanLedger(rpc, stellarCfg);
  final rebinder = DemoWalletRebinder(
    registry: _LedgerRegistry(ledger),
    custody: StellarAgentWalletCustody(wallets: wallets, cipher: cipher),
    funder: FriendbotFunder(friendbot),
    accounts: RpcChainAccounts(rpc),
    assembler: codec,
    signer: CustodiedEnvelopeSigner(
      wallets: wallets,
      cipher: cipher,
      codec: codec,
    ),
    signOwnerEntry: (entry) async => signAddressAuthEntry(
      entryXdr: entry,
      key: ownerKey,
      networkPassphrase: stellarCfg.networkPassphrase,
    ),
    send: rpc.sendTransaction,
    transactions: RpcChainTxReader(
      rpc,
      identityRegistry: stellarCfg.identityRegistry.value,
    ),
    owner: owner,
    adminWallet: admin,
    identityRegistry: stellarCfg.identityRegistry,
    seedUris: seedUris,
    inclusionFee: fees.inclusionFeeStroops,
    validitySeconds: fees.preparationValiditySeconds,
  );

  try {
    final results = await rebinder.rebindAll();
    if (results.isEmpty) {
      _fail('no seed URIs were found on the identity registry.');
    }
    stdout.writeln('\n== RESULT');
    for (final row in results) {
      final hash = row.transactionHash;
      stdout.writeln(
        '${row.uri}  agent ${row.agentId}  ${row.wallet.value}  '
        '${row.outcome.name}'
        '${hash == null ? '' : '  $hash'}',
      );
      if (hash != null) stdout.writeln('  $_explorer/$hash');
    }
  } finally {
    httpClient.close();
    friendbot.close();
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
  exit(0);
}

final class _LedgerRegistry implements DemoAgentRegistry {
  _LedgerRegistry(this._ledger);

  final SorobanLedger _ledger;

  @override
  Future<int> totalAgents() => _ledger.totalAgents();

  @override
  Future<String?> uriOf(int agentId) => _ledger.agentUri(AgentId(agentId));

  @override
  Future<StellarAddress?> walletOf(int agentId) =>
      _ledger.agentWallet(AgentId(agentId));
}
