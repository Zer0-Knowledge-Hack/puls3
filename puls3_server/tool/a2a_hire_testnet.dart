// Testnet demo of #312 (SOW week 2): agent A hires and pays agent B with no
// human signature. Both agents are custodied by the server (`agent_wallet`
// rows in the LOCAL Serverpod database of `--mode`, encrypted with a local
// key) and registered on the testnet Identity Registry.
//
//   A's custodied key signs: trustline, XLM->USDC swap, register_full,
//                            create_job, fund and (as evaluator) complete.
//   B's custodied key signs: trustline, register_full and `submit`, through
//                            the runtime's `AgentSubmitSender` (#208).
//
// B's work is a deterministic summary computed in this process, not a model
// call: the demo proves the payment path, not a provider. The hire, its
// escrow calls and B's `submit` go through the real server services
// (`HireService`, `EscrowRelayService`, the chain tracker).
//
// `--direct` skips the escrow: A's custodied key signs a USDC SAC `transfer`
// to B (the fallback of #312).
//
// TESTNET ONLY. The custody key is `PULS3_AGENT_WALLET_SECRET_KEY` when set
// (then A and B are reused across runs), otherwise a throwaway key made in
// this process. It is never printed, nor is any secret seed. Only public
// addresses and transaction hashes are printed. Funding comes from Friendbot
// and the testnet DEX; `--usdc-from <identity>` instead pays A from a Stellar
// CLI identity, used by name only.
//
//   dart run tool/a2a_hire_testnet.dart [--mode test|development] [--direct]
//       [--price <stroops>] [--budget <stroops>] [--usdc-from <identity>]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/agent_summary_reader.dart';
import 'package:puls3_server/src/agent/serverpod_agent_index_repository.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/wallet_custody_config.dart';
import 'package:puls3_server/src/chain/agent_submit_sender.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/agent_hire_service.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/soroban_ledger.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart' show ScArg;
import 'package:serverpod/serverpod.dart' show Serverpod;

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _explorer = 'https://stellar.expert/explorer/testnet/tx';
const _usdcAsset = 'USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';
const _timeout = Duration(minutes: 4);
const _inclusionFee = 100000;
const _validitySeconds = 600;

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

Future<T> _until<T>(String what, Future<T?> Function() probe) async {
  final deadline = DateTime.now().add(_timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = await probe();
    if (value != null) return value;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  _fail('timed out waiting for $what');
}

/// `--name value` from [args], or [fallback].
String? _opt(List<String> args, String name, [String? fallback]) {
  final at = args.indexOf(name);
  if (at < 0 || at + 1 >= args.length) return fallback;
  return args[at + 1];
}

/// B's deterministic work: the first sentence and the word count of [input].
String agentBWork(String input) {
  final words = input.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final first = input.split(RegExp(r'(?<=[.!?])\s')).first.trim();
  return 'Summary by agent B: "$first" (${words.length} words).';
}

Future<void> main(List<String> args) async {
  final mode = _opt(args, '--mode', 'test')!;
  if (mode != 'test' && mode != 'development') {
    _fail('--mode must be test or development.');
  }
  final direct = args.contains('--direct');
  final price = int.parse(_opt(args, '--price', '1000000')!);
  final budget = int.parse(_opt(args, '--budget', '2000000')!);
  final usdcFrom = _opt(args, '--usdc-from');

  final providedKey = Platform.environment['PULS3_AGENT_WALLET_SECRET_KEY'];
  final reuse = providedKey != null && providedKey.trim().isNotEmpty;
  final random = Random.secure();
  final custodyKey = reuse
      ? providedKey.trim()
      : base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));
  final runTag = reuse
      ? 'reuse'
      : DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36);

  final env = <String, String>{
    // Public testnet values only; StellarConfig defaults to the testnet
    // contracts. No `.env` or password file is read here.
    for (final key in const [
      'PULS3_STELLAR_RPC_URL',
      'PULS3_STELLAR_USDC_SAC',
      'PULS3_STELLAR_IDENTITY_REGISTRY',
      'PULS3_STELLAR_ESCROW',
    ])
      if (Platform.environment[key] != null) key: Platform.environment[key]!,
    'PULS3_AGENT_WALLET_SECRET_KEY': custodyKey,
    'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': '$_validitySeconds',
    'PULS3_STELLAR_INCLUSION_FEE_STROOPS': '$_inclusionFee',
    'PULS3_PLATFORM_FEE_BPS': '0',
    'PULS3_HIRE_JOB_DURATION_SECONDS': '172800',
    'PULS3_TRACKER_ENABLED': 'true',
    'PULS3_TRACKER_INTERVAL_SECONDS': '2',
  };

  _step('Preconditions');
  final stellarCfg = StellarConfig.fromEnvironment(env);
  if (stellarCfg.networkPassphrase != _testnetPassphrase) {
    _fail('the passphrase is not the testnet one (never runs on mainnet).');
  }
  final custody = WalletCustodyConfig.fromEnvironment(env);
  _ok('network: testnet, rpc ${stellarCfg.rpcUrl}');
  _ok('escrow ${stellarCfg.escrow.value}, token ${stellarCfg.usdcSac.value}');
  _ok('serverpod mode: $mode, custody key: ${reuse ? 'provided' : 'throwaway'}');
  _ok('mode: ${direct ? 'direct transfer' : 'escrow hire'}');

  final pod = Serverpod(
    ['--mode', mode, if (mode == 'test') '--apply-migrations'],
    Protocol(),
    Endpoints(),
  );
  await pod.start();
  final session = await pod.createSession();
  final tracker = direct ? null : startChainTracker(pod, env);
  if (!direct && tracker == null) _fail('the chain tracker did not start');

  final httpClient = http.Client();
  final rpc = SorobanRpcClient(
    httpClient: httpClient,
    url: stellarCfg.rpcUrl,
    timeout: stellarCfg.rpcTimeout,
  );
  final ledger = SorobanLedger(rpc, stellarCfg);
  final codec = StellarEnvelopeCodec.forPassphrase(_testnetPassphrase);
  final accounts = RpcChainAccounts(rpc);
  final wallets = ServerpodAgentWalletStore(session);
  final cipher = AesGcmSecretCipher(
    keys: {custody.keyVersion: custody.secretKey},
    writeKeyVersion: custody.keyVersion,
  );
  final walletCustody = StellarAgentWalletCustody(
    wallets: wallets,
    cipher: cipher,
  );
  final envelopeSigner = CustodiedEnvelopeSigner(
    wallets: wallets,
    cipher: cipher,
    codec: codec,
  );
  final signXdr = custodiedEnvelopeSigner(envelopeSigner, codec);

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
  Future<String> classic(StellarAddress source, List<String> command) async {
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

  /// A Soroban call by [source], simulated and signed with its custodied key.
  Future<String> invoke(
    StellarAddress source,
    StellarAddress contract,
    String function,
    List<ScArg> args,
  ) async {
    final spec = EnvelopeSpec(
      source: source,
      accountSequence: await accounts.sequenceOf(source),
      contract: contract,
      function: function,
      args: args,
      inclusionFee: _inclusionFee,
      validUntil:
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 +
          _validitySeconds,
    );
    final prepared = codec.build(spec, await accounts.simulateRaw(spec));
    return sendSigned(await envelopeSigner.sign(prepared, source));
  }

  Future<int?> findAgentByUri(String uri) async {
    final total = await ledger.totalAgents();
    for (var id = total - 1; id >= max(0, total - 60); id--) {
      if (await ledger.agentUri(AgentId(id)) == uri) return id;
    }
    return null;
  }

  /// Registers [wallet] as an agent (it becomes owner and payment wallet),
  /// or returns the id it already has.
  Future<int> register(
    StellarAddress wallet,
    String label,
    Map<String, String> metadata,
  ) async {
    final uri = 'puls3://a2a/${wallet.value}';
    final existing = reuse ? await findAgentByUri(uri) : null;
    if (existing != null) {
      _ok('$label already registered as agent $existing');
      return existing;
    }
    final hash = await invoke(
      wallet,
      stellarCfg.identityRegistry,
      'register_full',
      [
        ScArg.address(wallet),
        ScArg.string(uri),
        ScArg.vec([
          for (final MapEntry(:key, :value) in metadata.entries)
            ScArg.map({
              'key': ScArg.string(key),
              'value': ScArg.bytes(Uint8List.fromList(utf8.encode(value))),
            }),
        ]),
      ],
    );
    _tx('register_full ($label)', hash);
    final id = await findAgentByUri(uri);
    if (id == null) _fail('registered $label but cannot find its id');
    return id;
  }

  Future<StellarAddress> custodied(String label) async {
    final address = await walletCustody.create(
      owner: StellarAddress.parse(
        'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
      ),
      idempotencyKey: 'a2a-312-$label-$runTag',
    );
    _ok('agent $label custodied wallet: ${address.value}');
    return address;
  }

  Future<bool> funded(StellarAddress account) async {
    try {
      await accounts.sequenceOf(account);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> friendbot(StellarAddress account) async {
    if (await funded(account)) return;
    final response = await httpClient.get(
      Uri.parse('https://friendbot.stellar.org/?addr=${account.value}'),
    );
    if (response.statusCode >= 300) _fail('Friendbot refused ${account.value}');
    _ok('Friendbot funded ${account.value}');
  }

  Future<int> usdcBalance(StellarAddress account) async {
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

  Future<void> trustline(StellarAddress account, String label) async {
    if (await usdcBalance(account) >= 0) return;
    _tx(
      'change_trust USDC ($label)',
      await classic(account, ['change-trust', '--line', _usdcAsset]),
    );
  }

  try {
    _step('Agents A and B (custodied, local DB)');
    final a = await custodied('A');
    final b = await custodied('B');
    await friendbot(a);
    await friendbot(b);
    await trustline(a, 'A');
    await trustline(b, 'B');

    _step("A acquires the escrow's token (Circle testnet USDC)");
    final needed = price + 100000;
    if (await usdcBalance(a) < needed) {
      if (usdcFrom != null) {
        final paid = await Process.run('stellar', [
          'tx',
          'new',
          'payment',
          '--source-account',
          usdcFrom,
          '--destination',
          a.value,
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
          await classic(a, [
            'path-payment-strict-receive',
            '--send-asset',
            'native',
            '--send-max',
            '200000000',
            '--destination',
            a.value,
            '--dest-asset',
            _usdcAsset,
            '--dest-amount',
            '$needed',
          ]),
        );
      }
    }
    _ok('A holds ${await usdcBalance(a)} USDC stroops');

    if (direct) {
      _step('A pays B directly (USDC SAC transfer, signed by A)');
      if (price > budget) _fail('price $price exceeds the budget $budget');
      final hash = await invoke(a, stellarCfg.usdcSac, 'transfer', [
        ScArg.address(a),
        ScArg.address(b),
        ScArg.i128(price),
      ]);
      _tx('transfer A->B', hash);
      _step('RESULT');
      stdout
        ..writeln('payer A:   ${a.value}')
        ..writeln('payee B:   ${b.value}')
        ..writeln('amount:    $price USDC stroops')
        ..writeln('transfer:  $_explorer/$hash');
      return;
    }

    _step('Register A and B on the Identity Registry');
    final common = {'puls3.manifestVersion': '1', 'priceUsdcStroops': '$price'};
    final aId = await register(a, 'A', {
      'id': 'a2a-a-$runTag',
      'name': 'A2A Hiring Agent',
      'description': 'Agent A of the #312 demo: it delegates work and pays.',
      'skills': '["delegate"]',
      ...common,
    });
    final bId = await register(b, 'B', {
      'id': 'a2a-b-$runTag',
      'name': 'A2A Summary Agent',
      'description': 'Agent B of the #312 demo: it summarises a text.',
      'skills': '["summarize"]',
      ...common,
    });
    _ok('A is registry agent $aId, B is registry agent $bId');

    final index = ServerpodAgentIndexRepository(
      session,
      network: _testnetPassphrase,
    );
    if (!await index.isEmpty()) {
      final summary = await readAgentSummary(ledger, bId);
      if (summary == null) _fail('agent $bId has invalid metadata');
      await index.upsertAll([summary]);
      _ok('catalog index has agent $bId');
    }

    _step('A hires B through the escrow (no human signature)');
    final wiring = HireWiring.fromEnvironment(
      environment: env,
      httpClient: httpClient,
    );
    final services = wiring.servicesOn(session);
    final hires = ServerpodHireRepository(session);
    final submissions = ServerpodChainSubmissionStore(session);
    final chain = _TrackerChain(
      hires: hires,
      submissions: submissions,
      sender: AgentSubmitSender(
        submissions: submissions,
        accounts: accounts,
        codec: codec,
        sign: envelopeSigner.sign,
        send: rpc.sendTransaction,
        escrow: stellarCfg.escrow,
        inclusionFee: _inclusionFee,
        validitySeconds: _validitySeconds,
        now: DateTime.now,
        log: (level, message) => stdout.writeln('   [$level] $message'),
      ),
      provider: b,
    );
    final service = AgentHireService(
      escrow: HireServicesEscrow(services),
      chain: chain,
      agentOf: (id) => readAgentSummary(ledger, id),
      sign: signXdr,
    );
    const input =
        'Agent A delegates this paragraph to agent B. B must summarise it '
        'and is paid through the puls3 escrow on Stellar testnet.';
    final receipt = await service.hire(
      hiringWallet: a,
      agentId: bId,
      input: input,
      budgetUsdcStroops: budget,
      requestId: 'a2a-312-${DateTime.now().millisecondsSinceEpoch}',
    );

    _step('RESULT');
    final job = (await hires.findHire(receipt.hireId))!;
    stdout
      ..writeln('hiring agent A:  registry $aId  ${a.value}')
      ..writeln('hired agent B:   registry $bId  ${b.value}')
      ..writeln('hire id:         ${receipt.hireId}  job id: ${job.jobId}')
      ..writeln('price / budget:  ${receipt.priceUsdcStroops} / $budget')
      ..writeln('B output:        ${agentBWork(input)}')
      ..writeln('final status:    ${job.status?.name}');
    _tx('create_job (signed by A)', receipt.createJobTransaction);
    _tx('fund (signed by A)', receipt.fundTransaction);
    _tx('submit (signed by B)', receipt.submitTransaction);
    _tx('complete (signed by A)', receipt.completeTransaction);
  } finally {
    await tracker?.stop();
    httpClient.close();
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
  exit(0);
}

/// [AgentHireChain] over the chain tracker's submission rows. B's delivery
/// runs [agentBWork] and sends B's `submit` with the runtime's sender.
final class _TrackerChain implements AgentHireChain {
  _TrackerChain({
    required this.hires,
    required this.submissions,
    required this.sender,
    required this.provider,
  });

  final ServerpodHireRepository hires;
  final ChainSubmissionStore submissions;
  final AgentSubmitSender sender;
  final StellarAddress provider;

  @override
  Future<String> confirmed(String preparationId) async {
    final stored = await _until('submission $preparationId', () async {
      final row = await submissions.findByPreparation(preparationId);
      if (row?.state == SubmissionState.failed) {
        throw AgentHireFailed('$preparationId failed: ${row!.errorCode}');
      }
      return row?.state == SubmissionState.confirmed ? row : null;
    });
    // Wait for the escrow effects the next step depends on.
    final hireId = stored.hireId!;
    await _until('hire $hireId to reflect ${stored.purpose.name}', () async {
      final hire = await hires.findHire(hireId);
      return switch (stored.purpose) {
        SubmissionPurpose.createJob => hire?.jobId,
        SubmissionPurpose.fund =>
          hire?.status == HireStatus.funded ? true : null,
        SubmissionPurpose.complete =>
          hire?.status == HireStatus.completed ? true : null,
        _ => true,
      };
    });
    return stored.transactionHash;
  }

  @override
  Future<String> delivered(int hireId) async {
    final hire = (await hires.findHire(hireId))!;
    final output = agentBWork(hire.input ?? '');
    _ok('agent B ran: $output');
    await sender.send(
      DueSubmit(
        hireId: hireId,
        jobId: hire.jobId!,
        provider: provider,
        result: output,
      ),
    );
    final submit = await _until('B submit of hire $hireId', () async {
      final rows = await submissions.listByHire(hireId);
      final row = rows
          .where((r) => r.purpose == SubmissionPurpose.submit)
          .lastOrNull;
      if (row?.state == SubmissionState.failed) {
        throw AgentHireFailed('submit failed: ${row!.errorCode}');
      }
      return row?.state == SubmissionState.confirmed ? row : null;
    });
    await _until('hire $hireId to be submitted', () async {
      final row = await hires.findHire(hireId);
      return row?.status == HireStatus.submitted ? true : null;
    });
    return submit.transactionHash;
  }
}
