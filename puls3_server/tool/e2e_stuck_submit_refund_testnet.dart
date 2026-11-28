// Testnet proof of #277: a funded hire whose `submit` can never land is
// refunded by the consumer's own signature, with no server key.
//
// Run 1, reject and refund: the consumer creates and funds a hire. The
// agent's `submit` is attempted through the runtime's `AgentSubmitSender`
// and the escrow refuses it for good (`SubmitTooLate`: the job expires
// before the approval window would end). `getHire` then reports the reason
// in `submitErrorCode`, the consumer signs `reject` from `funded`, and the
// USDC returns.
//
// Run 2, claim refund: the consumer creates and funds a second hire, waits
// past its `expired_at`, then signs `claim_refund` through
// `prepareClaimRefund`. `escrowRelaySigningKey` must be unset, so the relay
// cannot refund on its own and the refund is the consumer's.
//
// What is real: `HireEndpoint` behind a `SessionWallet` seam, the hire
// wiring, the chain tracker, the escrow and token contracts on testnet, and
// PostgreSQL in Serverpod test mode. The script plays the consumer.
//
// The seam: the seed agents pay a wallet the server does not custody, and
// `createHire` refuses them (#276). This run adds a placeholder
// `agent_wallet` row for that payee in the LOCAL test database, so the hire
// can be created, and removes it at the end. The row holds no usable key:
// nothing is ever signed for the agent, and the run fails if the submit
// sender tries to sign.
//
// TESTNET ONLY. `PULS3_E2E_CONSUMER_SECRET` is read from the environment,
// kept in memory and never printed. `PULS3_HIRE_JOB_DURATION_SECONDS` must be
// shorter than the escrow's approval window (that is what makes the submit
// impossible) and long enough to fund and reject; 360 works.
//
//   dart run tool/e2e_stuck_submit_refund_testnet.dart [--only reject|claim]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/chain/agent_submit_sender.dart';
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:serverpod/serverpod.dart' show Serverpod, Session;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _explorer = 'https://stellar.expert/explorer/testnet/tx';
const _horizon = 'https://horizon-testnet.stellar.org';
const _usdcIssuer = 'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';
const _confirmTimeout = Duration(minutes: 3);
const _placeholderKey = 'e2e-277-placeholder';

final class _ConsumerWallet implements SessionWallet {
  const _ConsumerWallet(this.address);

  final StellarAddress address;

  @override
  Future<StellarAddress> requireLogin(Session session) async => address;
}

/// A failed check. [main] maps it to exit code 1 after the `finally` that
/// removes the placeholder custody row has run; `exit` would skip it.
final class _ProofFailed implements Exception {
  const _ProofFailed(this.message);

  final String message;

  @override
  String toString() => 'FAIL: $message';
}

Never _fail(String message) {
  stderr.writeln('FAIL: $message');
  throw _ProofFailed(message);
}

void _step(String message) => stdout.writeln('\n== $message');

void _ok(String message) => stdout.writeln('   ok: $message');

void _check(bool condition, String message) {
  if (!condition) _fail(message);
  _ok(message);
}

/// [unsigned] carrying one signature of [key]; the body is unchanged.
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

Future<T> _until<T>(
  String what,
  Future<T?> Function() probe, {
  Duration timeout = _confirmTimeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = await probe();
    if (value != null) return value;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  _fail('timed out waiting for $what');
}

/// The account's balance of testnet USDC, in stroops, read from Horizon.
Future<int> _usdcStroops(http.Client client, String account) async {
  final response = await client.get(Uri.parse('$_horizon/accounts/$account'));
  if (response.statusCode != 200) {
    _fail('Horizon returned ${response.statusCode} for $account');
  }
  final balances = (jsonDecode(response.body) as Map)['balances'] as List;
  for (final b in balances.cast<Map<String, dynamic>>()) {
    if (b['asset_code'] == 'USDC' && b['asset_issuer'] == _usdcIssuer) {
      final parts = (b['balance'] as String).split('.');
      return int.parse(parts[0]) * 10000000 +
          int.parse(parts[1].padRight(7, '0'));
    }
  }
  _fail('$account holds no testnet USDC');
}

String _usdc(int stroops) => (stroops / 10000000).toStringAsFixed(7);

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } on _ProofFailed {
    // Already reported by [_fail]; cleanup has run by now.
    exit(1);
  }
  exit(0);
}

Future<void> _run(List<String> args) async {
  final onlyAt = args.indexOf('--only');
  final only = onlyAt >= 0 && onlyAt + 1 < args.length
      ? args[onlyAt + 1]
      : null;
  if (only != null && only != 'reject' && only != 'claim') {
    _fail('--only must be reject or claim.');
  }
  final secret = Platform.environment['PULS3_E2E_CONSUMER_SECRET'];
  if (secret == null || secret.isEmpty) {
    _fail('PULS3_E2E_CONSUMER_SECRET is not set.');
  }
  if ((Platform.environment['SERVERPOD_PASSWORD_escrowRelaySigningKey'] ?? '')
      .isNotEmpty) {
    _fail(
      'escrowRelaySigningKey is set: the refund would not prove the '
      "consumer's signature alone.",
    );
  }
  final key = stellar.StellarPrivateKey.fromBase32(secret);
  final consumer = StellarAddress.parse(key.toPublicKey().toAddress().address);
  final env = {
    ...Platform.environment,
    'PULS3_TRACKER_ENABLED': 'true',
    'PULS3_TRACKER_INTERVAL_SECONDS': '2',
  };
  final codec = StellarEnvelopeCodec.forPassphrase(_testnetPassphrase);
  final httpClient = http.Client();

  _step('Preconditions');
  final wiring = HireWiring.fromEnvironment(environment: env);
  _check(
    wiring.stellar.networkPassphrase == _testnetPassphrase,
    'the passphrase is the testnet one (this script never runs on mainnet)',
  );
  final duration = int.tryParse(
    Platform.environment['PULS3_HIRE_JOB_DURATION_SECONDS'] ?? '',
  );
  _check(
    duration != null && duration >= 180 && duration < 86400,
    'job duration ${duration}s is under the approval window',
  );
  _ok('consumer (public): ${consumer.value}');
  _ok('escrow: ${wiring.stellar.escrow.value}');

  // The catalog reads agent owners through Serverpod, so it starts first.
  final pod = Serverpod(
    ['--mode', 'test', '--apply-migrations'],
    Protocol(),
    Endpoints(),
  );
  await pod.start();
  final catalog = await wiring.catalog.list();
  final candidates = [
    for (final agent in catalog)
      if (agent.wallet != null) agent,
  ]..sort((a, b) => a.priceUsdcStroops.compareTo(b.priceUsdcStroops));
  _check(candidates.isNotEmpty, 'the registry lists an agent with a wallet');
  final requested = int.tryParse(
    Platform.environment['PULS3_E2E_AGENT_ID'] ?? '',
  );
  final agent = requested == null
      ? candidates.first
      : candidates.firstWhere(
          (a) => a.registryId == requested,
          orElse: () => _fail('agent $requested has no wallet'),
        );
  final payee = StellarAddress.parse(agent.wallet!);
  _ok(
    'agent: registry id ${agent.registryId} "${agent.name}", price '
    '${_usdc(agent.priceUsdcStroops)} USDC, payee ${payee.value}',
  );

  final session = await pod.createSession();
  final tracker = startChainTracker(pod, env);
  if (tracker == null) _fail('the chain tracker did not start');
  // ignore: invalid_use_of_visible_for_testing_member
  HireEndpoint.sessionWallet = _ConsumerWallet(consumer);
  final endpoint = HireEndpoint();
  final hires = ServerpodHireRepository(session);
  final submissions = ServerpodChainSubmissionStore(session);
  final wallets = ServerpodAgentWalletStore(session);

  var addedPlaceholder = false;
  if (await wallets.findByAddress(payee) == null) {
    await wallets.save(
      owner: payee,
      address: payee,
      idempotencyKey: _placeholderKey,
      // Not a key: nothing can be decrypted or signed with this row.
      secret: const EncryptedSecret(
        ciphertext: 'AA==',
        nonce: 'AA==',
        mac: 'AA==',
        keyVersion: 1,
      ),
      createdAt: DateTime.now().toUtc(),
    );
    addedPlaceholder = true;
    _ok('placeholder custody row added for ${payee.value} (local test DB)');
  }

  Future<String> confirmed(String preparationId) async {
    final done = await _until('submission $preparationId', () async {
      final stored = await submissions.findByPreparation(preparationId);
      if (stored == null) return null;
      if (stored.state == SubmissionState.failed) {
        _fail(
          'submission ${stored.transactionHash} failed: '
          '${stored.errorCode}',
        );
      }
      return stored.state == SubmissionState.confirmed ? stored : null;
    });
    return done.transactionHash;
  }

  Future<String> signAndSend(int hireId, PreparedTransaction prepared) async {
    final detail = await endpoint.submitEscrowCall(
      session,
      hireId,
      prepared.preparationId,
      _sign(key, codec, prepared.unsignedTransactionXdr!),
    );
    final hash = detail.escrowSubmission!.transaction;
    _check(hash == prepared.transaction, 'relayed hash equals prepared hash');
    return confirmed(prepared.preparationId);
  }

  /// A new hire, created and funded by the consumer's signatures.
  Future<({HireRow hire, String createTx, String fundTx})> fundedHire(
    String label,
  ) async {
    final created = await endpoint.createHire(
      session,
      agent.registryId,
      consumer.value,
      'Testnet proof for #277 ($label).',
      'e2e-277-$label-${DateTime.now().millisecondsSinceEpoch}',
    );
    final hireId = created.hire.id;
    _ok('hire $hireId created');
    final createTx = await signAndSend(hireId, created.preparedCreateJob!);
    _ok('create_job confirmed: $createTx');
    await _until('hire $hireId to open', () async {
      final row = await hires.findHire(hireId);
      return row?.status == HireStatus.open ? row : null;
    });
    final fundTx = await signAndSend(
      hireId,
      await endpoint.prepareFund(session, hireId),
    );
    _ok('fund confirmed: $fundTx');
    final hire = await _until('hire $hireId to be funded', () async {
      final row = await hires.findHire(hireId);
      return row?.status == HireStatus.funded ? row : null;
    });
    return (hire: hire, createTx: createTx, fundTx: fundTx);
  }

  final results = <String>[];
  try {
    if (only != 'claim') {
      _step('Run 1: the submit cannot land, the consumer rejects and refunds');
      final before = await _usdcStroops(httpClient, consumer.value);
      _ok('consumer USDC before: ${_usdc(before)}');
      final run = await fundedHire('reject');
      final hireId = run.hire.id;
      final funded = await _usdcStroops(httpClient, consumer.value);
      _check(
        funded == before - agent.priceUsdcStroops,
        'the escrow holds the price (consumer USDC ${_usdc(funded)})',
      );

      _step("the agent's submit, through the runtime's sender");
      final rpc = SorobanRpcClient(
        httpClient: httpClient,
        url: wiring.stellar.rpcUrl,
        timeout: wiring.stellar.rpcTimeout,
      );
      final sender = AgentSubmitSender(
        submissions: submissions,
        accounts: RpcChainAccounts(rpc),
        codec: codec,
        sign: (_, _) async => _fail('the submit reached signing'),
        send: rpc.sendTransaction,
        escrow: wiring.stellar.escrow,
        inclusionFee: 100000,
        validitySeconds: 600,
        now: DateTime.now,
        log: (level, message) => stdout.writeln('   [$level] $message'),
      );
      await sender.send(
        DueSubmit(
          hireId: hireId,
          jobId: run.hire.jobId!,
          provider: payee,
          result: 'deterministic output of the #277 proof',
        ),
      );

      final detail = await endpoint.getHire(session, hireId, consumer.value);
      _check(
        detail.hire.status == 'funded' &&
            detail.submitErrorCode ==
                SubmissionOutcomeCode.submitSimulationRejected,
        'getHire reports funded with submitErrorCode '
        '${detail.submitErrorCode}',
      );
      _check(detail.result == null, 'the result stays hidden while funded');

      _step('Reject and refund (consumer-signed reject from funded)');
      final rejectTx = await signAndSend(
        hireId,
        await endpoint.prepareReject(
          session,
          hireId,
          'The result could not be recorded on Stellar.',
        ),
      );
      final rejected = await _until('hire $hireId to be rejected', () async {
        final row = await hires.findHire(hireId);
        return row?.status == HireStatus.rejected ? row : null;
      });
      final after = await _usdcStroops(httpClient, consumer.value);
      _check(
        after == before,
        'the consumer got the price back (USDC ${_usdc(after)})',
      );
      results.addAll([
        'run 1 (reject and refund): hire ${rejected.id}, job ${rejected.jobId}',
        '  agent submit refused: ${detail.submitErrorCode}',
        '  create_job $_explorer/${run.createTx}',
        '  fund       $_explorer/${run.fundTx}',
        '  reject     $_explorer/$rejectTx',
        '  consumer USDC ${_usdc(before)} -> ${_usdc(funded)} -> '
            '${_usdc(after)}',
      ]);
    }

    if (only != 'reject') {
      _step('Run 2: past expired_at, the consumer claims the refund');
      final before = await _usdcStroops(httpClient, consumer.value);
      _ok('consumer USDC before: ${_usdc(before)}');
      final run = await fundedHire('claim');
      final hireId = run.hire.id;
      final funded = await _usdcStroops(httpClient, consumer.value);
      _check(
        funded == before - agent.priceUsdcStroops,
        'the escrow holds the price (consumer USDC ${_usdc(funded)})',
      );
      try {
        await endpoint.prepareClaimRefund(session, hireId);
        _fail('prepareClaimRefund was accepted before expired_at');
      } on Puls3ApiException catch (e) {
        _check(
          e.code == 'InvalidHireTransition',
          'before expired_at prepareClaimRefund refuses: ${e.code}',
        );
      }
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        run.hire.expiredAt * 1000,
      );
      final wait =
          expiry.difference(DateTime.now()) +
          const Duration(
            seconds: 15,
          );
      _ok('waiting ${wait.inSeconds}s for expired_at ${expiry.toUtc()}');
      if (!wait.isNegative) await Future<void>.delayed(wait);
      final still = await hires.findHire(hireId);
      _check(
        still?.status == HireStatus.funded,
        'no server key refunded it: the hire is still funded after expiry',
      );

      _step('Claim refund (consumer-signed claim_refund)');
      final claim = await endpoint.prepareClaimRefund(session, hireId);
      final claimTx = await signAndSend(hireId, claim);
      // preparationId tells them apart: null for a relay-signed claimRefund,
      // set when the consumer prepared it.
      final claims = [
        for (final s in await submissions.listByHire(hireId))
          if (s.purpose == SubmissionPurpose.claimRefund) s,
      ];
      _check(
        claims.any((s) => s.preparationId == claim.preparationId),
        'the claim_refund record carries the preparationId of '
        'prepareClaimRefund',
      );
      _check(
        claims.every((s) => s.preparationId != null),
        'no relay-signed claim_refund exists for the hire',
      );
      final expired = await _until('hire $hireId to be expired', () async {
        final row = await hires.findHire(hireId);
        return row?.status == HireStatus.expired ? row : null;
      });
      final after = await _usdcStroops(httpClient, consumer.value);
      _check(
        after == before,
        'the consumer got the price back (USDC ${_usdc(after)})',
      );
      results.addAll([
        'run 2 (claim refund): hire ${expired.id}, job ${expired.jobId}',
        '  create_job   $_explorer/${run.createTx}',
        '  fund         $_explorer/${run.fundTx}',
        '  claim_refund $_explorer/$claimTx',
        '  consumer USDC ${_usdc(before)} -> ${_usdc(funded)} -> '
            '${_usdc(after)}',
      ]);
    }

    _step('RESULT');
    results.forEach(stdout.writeln);
  } finally {
    if (addedPlaceholder) {
      await AgentWallet.db.deleteWhere(
        session,
        where: (t) => t.idempotencyKey.equals(_placeholderKey),
      );
      _ok('placeholder custody row removed');
    }
    await tracker.stop();
    await session.close();
    await pod.shutdown(exitProcess: false);
    httpClient.close();
  }
}
