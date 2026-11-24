// Testnet evidence for #312 with two real Studio agents: agent A hires agent
// B, and B's output comes from a real model run by the hire runtime.
//
//   1. A throwaway builder (Friendbot-funded keypair made in this process)
//      deploys agents A and B through `StudioEndpoint`: saveDraft,
//      prepareDeploy + signed `register_full`, prepareWalletAuthorization +
//      signed `set_agent_wallet` authorization entry, until both are active.
//      B's manifest runs Workers AI `@cf/meta/llama-3.3-70b-instruct-fp8-fast`.
//   2. The builder saves its Workers AI credential (`saveProviderCredential`):
//      a Studio agent runs on its builder's credential, never the team token.
//   3. A's custodied key buys the escrow's USDC (XLM->USDC path payment), or
//      `--usdc-from <identity>` pays A from a Stellar CLI identity.
//   4. B is upserted into the catalog index, the chain tracker and the agent
//      runtime start, and the builder calls `StudioEndpoint.hireAgentAs`.
//      A's custodied key signs create_job, fund and complete; the runtime
//      runs B's manifest on the model and B's custodied key signs `submit`.
//
// Everything runs in this process against the LOCAL Serverpod database of
// `--mode` (docker postgres_test/redis_test for `test`) and the TESTNET
// contracts. The endpoint seams (`sessionWallet`, `deploys`,
// `credentialStores`, `agentHires`) are wired from this tool's environment,
// so no server code reads a different configuration.
//
// Required:
//   - the Serverpod password `workersAiApiToken` of `--mode`
//     (config/passwords.yaml): the platform runtime key and, saved again as
//     the builder's credential, the key B's run uses;
//   - `PULS3_WORKERS_AI_ACCOUNT_ID` exported in the environment;
//   - the `stellar` CLI on PATH (classic trustline / path payment builds).
// Optional: `PULS3_AGENT_WALLET_SECRET_KEY` (custody key; otherwise a
// throwaway key made in this process), `PULS3_REGISTRATION_BASE_URL`.
//
// TESTNET ONLY. No secret (token, account id, custody key, seeds) is ever
// printed; only public addresses, ids, hashes and B's model output.
//
//   dart run tool/a2a_studio_hire_testnet.dart [--mode test|development]
//       [--price <stroops>] [--budget <stroops>] [--input <text>]
//       [--usdc-from <identity>]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart' as domain;
import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/agent_summary_reader.dart';
import 'package:puls3_server/src/agent/serverpod_agent_index_repository.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/wallet_custody_config.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/agent_hire_service.dart';
import 'package:puls3_server/src/hire/agent_hire_wiring.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/soroban_ledger.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/runtime/agent_runtime_wiring.dart';
import 'package:puls3_server/src/studio/auth_entry_signer.dart';
import 'package:puls3_server/src/studio/serverpod_builder_credential_store.dart';
import 'package:puls3_server/src/studio/serverpod_studio_agent_version_store.dart';
import 'package:puls3_server/src/studio/serverpod_studio_deploy_store.dart';
import 'package:puls3_server/src/studio/studio_deploy_wiring.dart';
import 'package:puls3_server/src/studio/studio_draft_transport.dart';
import 'package:puls3_server/src/studio/studio_endpoint.dart';
import 'package:puls3_server/src/studio/studio_model_policy.dart';
import 'package:serverpod/serverpod.dart' show Serverpod, Session;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _explorer = 'https://stellar.expert/explorer/testnet/tx';
const _usdcAsset =
    'USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';
const _model = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';
const _deployTimeout = Duration(minutes: 4);
const _hireTimeout = Duration(minutes: 20);
const _defaultInput =
    'Summarize in two sentences why escrowed payments matter for AI agents '
    'hiring each other.';

/// The builder the endpoint sees as signed in.
final class _BuilderWallet implements SessionWallet {
  const _BuilderWallet(this.address);

  final domain.StellarAddress address;

  @override
  Future<domain.StellarAddress> requireLogin(Session session) async => address;
}

/// One deployed Studio agent.
typedef _Deployed = ({
  int draftId,
  int registryId,
  domain.StellarAddress wallet,
  String registerHash,
  String walletHash,
});

Never _fail(String message) {
  stderr.writeln('FAIL: $message');
  exit(1);
}

void _step(String message) => stdout.writeln('\n== $message');

void _ok(String message) => stdout.writeln('   ok: $message');

void _tx(String label, String hash) {
  stdout
    ..writeln('   tx: $label $hash')
    ..writeln('       $_explorer/$hash');
}

Future<T> _until<T>(
  String what,
  Future<T?> Function() probe, {
  Duration timeout = _deployTimeout,
  Duration every = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = await probe();
    if (value != null) return value;
    await Future<void>.delayed(every);
  }
  _fail('timed out waiting for $what');
}

/// `--name value` from [args], or [fallback].
String? _opt(List<String> args, String name, [String? fallback]) {
  final at = args.indexOf(name);
  if (at < 0 || at + 1 >= args.length) return fallback;
  return args[at + 1];
}

/// [unsigned] with one decorated signature of [key] appended.
String _sign(
  stellar.StellarPrivateKey key,
  StellarEnvelopeCodec codec,
  String unsigned,
) {
  final bytes = base64Decode(unsigned);
  final signature = key.sign(codec.parse(unsigned).hash);
  final out = BytesBuilder()
    ..add(bytes.sublist(0, bytes.length - 4))
    ..add([0, 0, 0, 1])
    ..add(signature.hint)
    ..add([0, 0, 0, 64])
    ..add(signature.signature);
  return base64Encode(out.takeBytes());
}

AgentManifestDraft _draftA(int price) => AgentManifestDraft(
  name: 'A2A Hiring Agent',
  description:
      'Agent A of the #312 evidence: it delegates a task to another '
      'Studio agent and pays it through the puls3 escrow.',
  skills: [
    ManifestSkill(
      id: 'delegate',
      name: 'Delegate',
      description: 'Hires another agent for a sub-task.',
    ),
  ],
  model: ManifestModel(provider: domain.ModelPolicy.freeProvider, id: _model),
  systemPrompt:
      'You coordinate work. Split the request into one clear sub-task and '
      'state it in a single sentence.',
  inputType: 'text',
  inputMaxChars: 2000,
  outputType: 'text',
  outputMaxChars: 2000,
  price: ManifestPrice(asset: 'USDC', amount: price),
);

AgentManifestDraft _draftB(int price) => AgentManifestDraft(
  name: 'A2A Explainer Agent',
  description:
      'Agent B of the #312 evidence: it answers a short question in two '
      'plain sentences.',
  skills: [
    ManifestSkill(
      id: 'explain',
      name: 'Explain',
      description: 'Answers a question briefly.',
      tags: ['summary'],
    ),
  ],
  model: ManifestModel(provider: domain.ModelPolicy.freeProvider, id: _model),
  systemPrompt:
      'You are a concise technical writer. Answer the user in exactly two '
      'plain sentences, with no lists, headings or preamble.',
  inputType: 'text',
  inputMaxChars: 2000,
  outputType: 'text',
  outputMaxChars: 1200,
  price: ManifestPrice(asset: 'USDC', amount: price),
);

/// Fails unless [draft] would pass the Studio deploy validation.
void _validate(String label, AgentManifestDraft draft) {
  try {
    domain.AgentManifestDraft.fromJson(
      draftDocument(draft),
    ).validate(studioServerModelPolicy, domain.ManifestVersion.first);
  } on domain.InvalidManifest catch (e) {
    _fail(
      'manifest of $label is invalid: '
      '${e.problems.map((p) => p.name).join(', ')}',
    );
  }
}

Future<void> main(List<String> args) async {
  final mode = _opt(args, '--mode', 'test')!;
  if (mode != 'test' && mode != 'development') {
    _fail('--mode must be test or development.');
  }
  final price = int.tryParse(_opt(args, '--price', '1000000')!);
  final budget = int.tryParse(_opt(args, '--budget', '2000000')!);
  if (price == null || price <= 0 || budget == null || budget <= 0) {
    _fail('--price and --budget must be positive whole numbers of stroops.');
  }
  final input = _opt(args, '--input', _defaultInput)!;
  final usdcFrom = _opt(args, '--usdc-from');

  final process = Platform.environment;
  final accountId = workersAiAccountId(process[workersAiAccountVariable]);
  if (accountId == null) {
    _fail(
      'export $workersAiAccountVariable (the Cloudflare account id, letters '
      'and digits only) before running this tool.',
    );
  }
  final providedKey = process['PULS3_AGENT_WALLET_SECRET_KEY'];
  final reuse = providedKey != null && providedKey.trim().isNotEmpty;
  final random = Random.secure();
  final custodyKey = reuse
      ? providedKey.trim()
      : base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));

  String fallback(String key, String value) {
    final current = process[key];
    return current == null || current.trim().isEmpty ? value : current;
  }

  final env = <String, String>{
    ...process,
    'PULS3_AGENT_WALLET_SECRET_KEY': custodyKey,
    'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': fallback(
      'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS',
      '600',
    ),
    'PULS3_STELLAR_INCLUSION_FEE_STROOPS': fallback(
      'PULS3_STELLAR_INCLUSION_FEE_STROOPS',
      '100000',
    ),
    'PULS3_PLATFORM_FEE_BPS': fallback('PULS3_PLATFORM_FEE_BPS', '0'),
    'PULS3_HIRE_JOB_DURATION_SECONDS': fallback(
      'PULS3_HIRE_JOB_DURATION_SECONDS',
      '172800',
    ),
    'PULS3_REGISTRATION_BASE_URL': fallback(
      'PULS3_REGISTRATION_BASE_URL',
      'http://localhost:8082',
    ),
    'PULS3_TRACKER_ENABLED': 'true',
    'PULS3_TRACKER_INTERVAL_SECONDS': fallback(
      'PULS3_TRACKER_INTERVAL_SECONDS',
      '2',
    ),
    'PULS3_RUNTIME_ENABLED': 'true',
    'PULS3_RUNTIME_INTERVAL_SECONDS': fallback(
      'PULS3_RUNTIME_INTERVAL_SECONDS',
      '2',
    ),
  };

  _step('Preconditions');
  final stellarCfg = StellarConfig.fromEnvironment(env);
  if (stellarCfg.networkPassphrase != _testnetPassphrase) {
    _fail('the passphrase is not the testnet one (never runs on mainnet).');
  }
  final WalletCustodyConfig custody;
  try {
    custody = WalletCustodyConfig.fromEnvironment(env);
  } on Object catch (e) {
    _fail('PULS3_AGENT_WALLET_SECRET_KEY is invalid (${e.runtimeType}).');
  }
  final draftA = _draftA(price);
  final draftB = _draftB(price);
  _validate('A', draftA);
  _validate('B', draftB);
  _ok('network: testnet, rpc ${stellarCfg.rpcUrl}');
  _ok('escrow ${stellarCfg.escrow.value}, token ${stellarCfg.usdcSac.value}');
  _ok(
    'serverpod mode: $mode, custody key: ${reuse ? 'provided' : 'throwaway'}',
  );
  _ok('$workersAiAccountVariable is set; manifests validate');

  final pod = Serverpod(
    ['--mode', mode, if (mode == 'test') '--apply-migrations'],
    Protocol(),
    Endpoints(),
  );
  await pod.start();
  final token = pod.getPassword(workersAiTokenPassword);
  if (token == null || token.trim().isEmpty) {
    await pod.shutdown(exitProcess: false);
    _fail(
      'the "$workersAiTokenPassword" password of mode $mode is not set '
      '(config/passwords.yaml).',
    );
  }
  final session = await pod.createSession();

  final httpClient = http.Client();
  final rpc = SorobanRpcClient(
    httpClient: httpClient,
    url: stellarCfg.rpcUrl,
    timeout: stellarCfg.rpcTimeout,
  );
  final ledger = SorobanLedger(rpc, stellarCfg);
  final codec = StellarEnvelopeCodec.forPassphrase(_testnetPassphrase);
  final cipher = AesGcmSecretCipher(
    keys: {custody.keyVersion: custody.secretKey},
    writeKeyVersion: custody.keyVersion,
  );
  final signXdr = custodiedEnvelopeSigner(
    CustodiedEnvelopeSigner(
      wallets: ServerpodAgentWalletStore(session),
      cipher: cipher,
      codec: codec,
    ),
    codec,
  );

  // Every seam reads this tool's environment, not the process one.
  final deployWiring = StudioDeployWiring.fromEnvironment(env);
  final builderKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  final builder = domain.StellarAddress.parse(
    builderKey.toPublicKey().toAddress().baseAddress,
  );
  // ignore_for_file: invalid_use_of_visible_for_testing_member
  StudioEndpoint.sessionWallet = _BuilderWallet(builder);
  StudioEndpoint.deploys = deployWiring.serviceOn;
  StudioEndpoint.credentialStores = (s) =>
      ServerpodBuilderCredentialStore(s, cipher: cipher);
  StudioEndpoint.agentHires = AgentHireWiring.fromEnvironment(env).launcher;
  final studio = StudioEndpoint();

  final tracker = startChainTracker(pod, env);
  final runtime = startAgentRuntime(pod, env);

  Future<void> waitTx(String hash) async {
    await _until('transaction $hash', () async {
      final result = await rpc.getTransaction(hash);
      final status = result['status'];
      if (status == 'FAILED') _fail('transaction $hash failed');
      return status == 'SUCCESS' ? true : null;
    });
  }

  Future<String> sendSigned(String signed) async {
    final hash = codec.parse(signed).hashHex;
    final sent = await rpc.sendTransaction(signed, hash);
    if (sent.status == SendTransactionStatus.error) {
      _fail('the node refused $hash: ${sent.errorResultXdr}');
    }
    await waitTx(hash);
    return hash;
  }

  /// A classic transaction built by the Stellar CLI for [source] (public key
  /// only, `--build-only`), signed with its custodied key.
  Future<String> classic(
    domain.StellarAddress source,
    List<String> command,
  ) async {
    final built = await Process.run('stellar', [
      'tx',
      'new',
      ...command,
      '--source-account',
      source.value,
      '--network',
      'testnet',
      '--build-only',
    ]);
    if (built.exitCode != 0) {
      _fail('stellar tx new ${command.first} failed: ${built.stderr}');
    }
    return sendSigned(await signXdr((built.stdout as String).trim(), source));
  }

  Future<int> usdcBalance(domain.StellarAddress account) async {
    final response = await httpClient.get(
      Uri.parse(
        'https://horizon-testnet.stellar.org/accounts/${account.value}',
      ),
    );
    if (response.statusCode != 200) return -1;
    final balances = (jsonDecode(response.body) as Map)['balances'] as List;
    for (final b in balances.cast<Map>()) {
      if ('${b['asset_code']}:${b['asset_issuer']}' == _usdcAsset) {
        final parts = (b['balance'] as String).split('.');
        return int.parse(parts[0]) * 10000000 +
            int.parse(parts[1].padRight(7, '0'));
      }
    }
    return -1;
  }

  Future<DeploySession> deployCall(
    String what,
    Future<DeploySession> Function() call,
  ) async {
    try {
      return await call();
    } on Puls3ApiException catch (e) {
      _fail(
        '$what refused: ${e.code}${e.message == null ? '' : ' (${e.message})'}',
      );
    }
  }

  Future<_Deployed> deploy(String label, AgentManifestDraft manifest) async {
    final StudioDraft draft;
    try {
      draft = await studio.saveDraft(session, manifest, null, null, null);
    } on Puls3ApiException catch (e) {
      _fail('saveDraft of $label refused: ${e.code}');
    }
    final draftId = draft.draftId;
    _ok('$label draft $draftId saved');

    final prepared = await deployCall(
      'prepareDeploy of $label',
      () => studio.prepareDeploy(session, draftId, builder.value),
    );
    final registration = prepared.preparation;
    final unsigned = registration?.unsignedTransactionXdr;
    if (registration == null || unsigned == null) {
      _fail('prepareDeploy of $label returned no register_full to sign');
    }
    _ok('$label agent wallet (custodied): ${prepared.agentWallet}');
    await deployCall(
      'submitRegistration of $label',
      () => studio.submitRegistration(
        session,
        draftId,
        registration.preparationId,
        _sign(builderKey, codec, unsigned),
      ),
    );
    final registered = await _until('register_full of $label', () async {
      final current = await deployCall(
        'getDeploySession of $label',
        () => studio.getDeploySession(session, draftId),
      );
      if (current.state == 'failed') {
        _fail('deploy of $label failed: ${current.failureCode}');
      }
      return current.state == 'awaitingWalletAuthorization' &&
              current.agentId != null
          ? current
          : null;
    });
    final registryId = registered.agentId!;
    _ok('$label is registry agent $registryId');

    final authorization = await deployCall(
      'prepareWalletAuthorization of $label',
      () => studio.prepareWalletAuthorization(session, draftId),
    );
    final entry = authorization.preparation?.authorizationEntryXdr;
    if (entry == null) {
      _fail('prepareWalletAuthorization of $label returned no auth entry');
    }
    await deployCall(
      'submitWalletAuthorization of $label',
      () => studio.submitWalletAuthorization(
        session,
        draftId,
        authorization.preparation!.preparationId,
        signAddressAuthEntry(
          entryXdr: entry,
          key: builderKey,
          networkPassphrase: _testnetPassphrase,
        ),
      ),
    );
    await _until('$label to become active', () async {
      final current = await deployCall(
        'getDeploySession of $label',
        () => studio.getDeploySession(session, draftId),
      );
      if (current.state == 'failed') {
        _fail('deploy of $label failed: ${current.failureCode}');
      }
      return current.state == 'active' ? current : null;
    });
    final row = await ServerpodStudioDeployStore(session).findByDraft(draftId);
    final registerHash = row?.registrationHash;
    final walletHash = row?.walletTxHash;
    if (row == null || registerHash == null || walletHash == null) {
      _fail('the deploy row of $label has no transaction hashes');
    }
    _tx('register_full ($label, signed by the builder)', registerHash);
    _tx('set_agent_wallet ($label, builder auth entry)', walletHash);
    return (
      draftId: draftId,
      registryId: registryId,
      wallet: domain.StellarAddress.parse(row.agentWallet),
      registerHash: registerHash,
      walletHash: walletHash,
    );
  }

  try {
    if (tracker == null) _fail('the chain tracker did not start');
    if (runtime == null) {
      _fail(
        'runtime did not start: set $mode.$workersAiTokenPassword '
        '(config/passwords.yaml) and $workersAiAccountVariable.',
      );
    }

    _step('Throwaway builder');
    final friendbot = await httpClient.get(
      Uri.parse('https://friendbot.stellar.org/?addr=${builder.value}'),
    );
    if (friendbot.statusCode >= 300) {
      _fail('Friendbot refused ${builder.value}');
    }
    _ok('builder (public): ${builder.value}, funded by Friendbot');
    try {
      await studio.saveProviderCredential(
        session,
        domain.ModelPolicy.freeProvider,
        token,
        accountId,
      );
    } on Puls3ApiException catch (e) {
      _fail('saveProviderCredential refused: ${e.code}');
    }
    _ok('builder Workers AI credential saved (encrypted, not printed)');

    _step('Deploy agent A through the Studio endpoints');
    final a = await deploy('A', draftA);
    _step('Deploy agent B through the Studio endpoints');
    final b = await deploy('B', draftB);

    _step("A acquires the escrow's token (Circle testnet USDC)");
    final needed = price + 100000;
    if (await usdcBalance(a.wallet) < needed) {
      if (usdcFrom != null) {
        final paid = await Process.run('stellar', [
          'tx',
          'new',
          'payment',
          '--source-account',
          usdcFrom,
          '--destination',
          a.wallet.value,
          '--asset',
          _usdcAsset,
          '--amount',
          '$needed',
          '--network',
          'testnet',
        ]);
        if (paid.exitCode != 0) _fail('USDC payment failed: ${paid.stderr}');
        _ok('$usdcFrom paid A $needed USDC stroops');
      } else {
        _tx(
          'path_payment XLM->USDC (A, signed by A)',
          await classic(a.wallet, [
            'path-payment-strict-receive',
            '--send-asset',
            'native',
            '--send-max',
            '200000000',
            '--destination',
            a.wallet.value,
            '--dest-asset',
            _usdcAsset,
            '--dest-amount',
            '$needed',
          ]),
        );
      }
    }
    _ok('A holds ${await usdcBalance(a.wallet)} USDC stroops');

    _step('Catalog index');
    final index = ServerpodAgentIndexRepository(
      session,
      network: _testnetPassphrase,
    );
    final summary = await readAgentSummary(ledger, b.registryId);
    if (summary == null) _fail('agent ${b.registryId} has invalid metadata');
    if (summary.wallet != b.wallet.value) {
      _fail('agent ${b.registryId} does not pay its custodied wallet yet');
    }
    await index.upsertAll([summary]);
    _ok(
      'catalog index has agent ${b.registryId} '
      '(price ${summary.priceUsdcStroops}, model ${summary.model})',
    );

    _step('A hires B with StudioEndpoint.hireAgentAs (no human signature)');
    final AgentHireStarted started;
    try {
      started = await studio.hireAgentAs(
        session,
        a.registryId,
        b.registryId,
        input,
        budget,
      );
    } on Puls3ApiException catch (e) {
      _fail(
        'hireAgentAs refused: ${e.code}'
        '${e.message == null ? '' : ' (${e.message})'}',
      );
    }
    final hireId = started.hireId;
    _ok('hire $hireId started by ${started.hiringWallet}');

    final hires = ServerpodHireRepository(session);
    final submissions = ServerpodChainSubmissionStore(session);
    final reported = <int>{};
    String? lastState;
    var lastAttempts = 0;
    final done = await _until(
      'hire $hireId to complete',
      () async {
        final hire = await hires.findHire(hireId);
        final run = await HireRunRecord.db.findFirstRow(
          session,
          where: (t) => t.hireId.equals(hireId),
        );
        final rows = await submissions.listByHire(hireId);
        for (final row in rows) {
          if (row.state != SubmissionState.failed || !reported.add(row.id)) {
            continue;
          }
          final what =
              '${row.purpose.name} of hire $hireId failed: ${row.errorCode} '
              '${row.transactionHash}';
          if (row.purpose != SubmissionPurpose.submit) _fail(what);
          stderr.writeln('   warn: $what');
        }
        final failedSubmits = rows.where(
          (r) =>
              r.purpose == SubmissionPurpose.submit &&
              r.state == SubmissionState.failed,
        );
        if (failedSubmits.length >= maxEscrowCallAttempts) {
          _fail('B\'s submit failed $maxEscrowCallAttempts times');
        }
        if (run != null && run.state == 'failed') {
          _fail('B\'s run failed: ${run.failureReason ?? 'no reason code'}');
        }
        if (run != null &&
            run.attempts > lastAttempts &&
            run.state != 'succeeded') {
          lastAttempts = run.attempts;
          stdout.writeln('   run attempt ${run.attempts} (${run.state})');
        }
        final status = hire?.status;
        final state =
            '${status?.name ?? 'no job yet'} / run ${run?.state ?? '-'}';
        if (state != lastState) {
          lastState = state;
          stdout.writeln('   hire $hireId: $state');
        }
        if (status != null &&
            status.isTerminal &&
            status != domain.HireStatus.completed) {
          _fail('hire $hireId ended ${status.name}');
        }
        final completed = rows.any(
          (r) =>
              r.purpose == SubmissionPurpose.complete &&
              r.state == SubmissionState.confirmed,
        );
        return status == domain.HireStatus.completed && completed
            ? (hire: hire!, run: run, rows: rows)
            : null;
      },
      timeout: _hireTimeout,
      every: const Duration(seconds: 5),
    );

    String hashOf(SubmissionPurpose purpose) {
      final StoredSubmission? row = done.rows
          .where(
            (r) => r.purpose == purpose && r.state == SubmissionState.confirmed,
          )
          .firstOrNull;
      if (row == null) _fail('no confirmed ${purpose.name} for hire $hireId');
      return row.transactionHash;
    }

    final version = await ServerpodStudioAgentVersionStore(
      session,
    ).find(b.registryId, done.hire.manifestVersion);
    final model = version == null
        ? null
        : (jsonDecode(version.manifestJson) as Map)['model'] as Map?;

    _step('RESULT');
    stdout
      ..writeln('builder:         ${builder.value}')
      ..writeln(
        'hiring agent A:  registry ${a.registryId}  ${a.wallet.value}  '
        '(draft ${a.draftId})',
      )
      ..writeln(
        'hired agent B:   registry ${b.registryId}  ${b.wallet.value}  '
        '(draft ${b.draftId})',
      )
      ..writeln(
        'B manifest:      v${done.hire.manifestVersion} provider '
        '${model?['provider']} model ${model?['id']}',
      )
      ..writeln('hire id:         $hireId  job id: ${done.hire.jobId}')
      ..writeln('price / budget:  ${done.hire.price} / $budget USDC stroops')
      ..writeln('input:           $input')
      ..writeln('B model output:  ${done.run?.result ?? '(no run result)'}')
      ..writeln('final status:    ${done.hire.status?.name}');
    _tx('register_full (A)', a.registerHash);
    _tx('set_agent_wallet (A)', a.walletHash);
    _tx('register_full (B)', b.registerHash);
    _tx('set_agent_wallet (B)', b.walletHash);
    _tx('create_job (signed by A)', hashOf(SubmissionPurpose.createJob));
    _tx('fund (signed by A)', hashOf(SubmissionPurpose.fund));
    _tx(
      'submit (signed by B, after the model run)',
      hashOf(SubmissionPurpose.submit),
    );
    _tx('complete (signed by A)', hashOf(SubmissionPurpose.complete));
  } finally {
    await runtime?.stop();
    await tracker?.stop();
    httpClient.close();
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
  exit(0);
}
