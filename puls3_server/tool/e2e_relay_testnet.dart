// Testnet end-to-end proof of the escrow relay (issue #96, acceptance
// criterion 1): a consumer creates and funds a hire using only the hire
// endpoint (createHire, prepareFund, submitEscrowCall) and signs the
// unsigned XDR it receives UNCHANGED.
//
// Everything on the server side is the real thing: the real `HireEndpoint`
// behind a `SessionWallet` seam, the real `HireWiring` (Soroban RPC client,
// agent catalog, `StellarEnvelopeCodec`, chain accounts, sender), the real
// chain tracker (`startChainTracker`) and PostgreSQL through a Serverpod
// session in test mode (migrations applied). Only the consumer wallet is
// played by this script: it signs with a key read from the environment.
//
// TESTNET ONLY. The consumer secret is read from PULS3_E2E_CONSUMER_SECRET,
// kept in memory, and never printed or written anywhere. See the "End-to-end
// proof on testnet" section of puls3_server/README.md for the exact command.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:serverpod/serverpod.dart' show Serverpod, Session;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _explorer = 'https://stellar.expert/explorer/testnet/tx';
const _confirmTimeout = Duration(minutes: 3);

/// The session seam of this run: every session is the consumer wallet.
final class _ConsumerWallet implements SessionWallet {
  const _ConsumerWallet(this.address);

  final StellarAddress address;

  @override
  Future<StellarAddress> requireLogin(Session session) async => address;
}

Never _fail(String message) {
  stderr.writeln('FAIL: $message');
  exit(1);
}

void _step(String message) => stdout.writeln('\n== $message');

void _ok(String message) => stdout.writeln('   ok: $message');

void _check(bool condition, String message) {
  if (!condition) _fail(message);
  _ok(message);
}

/// [unsigned] carrying one signature of [key] over its transaction hash. The
/// transaction body is not touched: only the empty signature list at the end
/// of the envelope is replaced.
String _sign(
  stellar.StellarPrivateKey key,
  StellarEnvelopeCodec codec,
  String unsigned,
) {
  final bytes = base64Decode(unsigned);
  final signature = key.sign(codec.parse(unsigned).hash);
  final out = BytesBuilder()
    ..add(bytes.sublist(0, bytes.length - 4)) // the empty signature list
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

Future<void> main(List<String> args) async {
  final secret = Platform.environment['PULS3_E2E_CONSUMER_SECRET'];
  if (secret == null || secret.isEmpty) {
    _fail('PULS3_E2E_CONSUMER_SECRET is not set (see README).');
  }
  final key = stellar.StellarPrivateKey.fromBase32(secret);
  final consumer = StellarAddress.parse(key.toPublicKey().toAddress().address);
  final expected = Platform.environment['PULS3_E2E_CONSUMER_ADDRESS'];
  if (expected != null && expected != consumer.value) {
    _fail('the secret does not belong to PULS3_E2E_CONSUMER_ADDRESS.');
  }

  final env = {
    ...Platform.environment,
    'PULS3_TRACKER_ENABLED': 'true',
    'PULS3_TRACKER_INTERVAL_SECONDS':
        Platform.environment['PULS3_TRACKER_INTERVAL_SECONDS'] ?? '2',
  };
  final codec = StellarEnvelopeCodec.forPassphrase(_testnetPassphrase);

  _step('Preconditions');
  final wiring = HireWiring.fromEnvironment(environment: env);
  _ok('network: ${wiring.stellar.networkPassphrase}');
  _check(
    wiring.stellar.networkPassphrase == _testnetPassphrase,
    'the passphrase is the testnet one (this script never runs on mainnet)',
  );
  _ok('consumer (public): ${consumer.value}');
  _ok('escrow: ${wiring.stellar.escrow.value}');
  _ok('usdc sac: ${wiring.stellar.usdcSac.value}');
  final catalog = await wiring.catalog.list();
  final hireable = [
    for (final agent in catalog)
      if (agent.wallet != null) agent,
  ]..sort((a, b) => a.priceUsdcStroops.compareTo(b.priceUsdcStroops));
  _check(hireable.isNotEmpty, 'the registry lists an agent with a wallet');
  final requestedAgent = int.tryParse(
    Platform.environment['PULS3_E2E_AGENT_ID'] ?? '',
  );
  final agent = requestedAgent == null
      ? hireable.first
      : hireable.firstWhere(
          (a) => a.registryId == requestedAgent,
          orElse: () => _fail('agent $requestedAgent has no wallet'),
        );
  _ok(
    'agent: registry id ${agent.registryId} "${agent.name}" '
    'price ${agent.priceUsdcStroops} stroops wallet ${agent.wallet}',
  );

  final pod = Serverpod(
    ['--mode', 'test', '--apply-migrations'],
    Protocol(),
    Endpoints(),
  );
  await pod.start();
  final session = await pod.createSession();
  final tracker = startChainTracker(pod, env);
  if (tracker == null) _fail('the chain tracker did not start');
  // This run plays the consumer wallet through the test seam. Production
  // resolves the wallet from the session.
  // ignore: invalid_use_of_visible_for_testing_member
  HireEndpoint.sessionWallet = _ConsumerWallet(consumer);
  final endpoint = HireEndpoint();
  final hires = ServerpodHireRepository(session);
  final submissions = ServerpodChainSubmissionStore(session);

  Future<StoredSubmissionView> confirmed(String preparationId) async {
    final done = await _until(
      'submission of $preparationId to finish',
      () async {
        final stored = await submissions.findByPreparation(preparationId);
        if (stored == null) return null;
        if (stored.state == SubmissionState.failed) {
          _fail(
            'submission ${stored.transactionHash} failed: ${stored.errorCode}',
          );
        }
        return stored.state == SubmissionState.confirmed ? stored : null;
      },
    );
    return StoredSubmissionView(done.transactionHash, done.explorerUrl);
  }

  try {
    _step('createHire');
    final requestId = 'e2e-${DateTime.now().millisecondsSinceEpoch}';
    final created = await endpoint.createHire(
      session,
      agent.registryId,
      consumer.value,
      'e2e testnet proof for issue #96',
      requestId,
    );
    final hireId = created.hire.id;
    final createPrepared = created.preparedCreateJob;
    _check(createPrepared != null, 'createHire returned a preparedCreateJob');
    _ok('hire id: $hireId, status: ${created.hire.status}');
    _ok('create_job preparation: ${createPrepared!.preparationId}');
    final unsignedCreate = createPrepared.unsignedTransactionXdr!;

    _step('tamper check (a copy; nothing is broadcast)');
    final tampered = base64Decode(_sign(key, codec, unsignedCreate));
    tampered[71] ^= 0x01; // last byte of the time bounds maxTime
    try {
      await endpoint.submitEscrowCall(
        session,
        hireId,
        createPrepared.preparationId,
        base64Encode(tampered),
      );
      _fail('the tampered envelope was accepted');
    } on Puls3ApiException catch (e) {
      _check(
        e.code == 'EnvelopeMismatch' && e.details?['field'] == 'timeBounds',
        'tampered time bounds rejected: ${e.code} ${e.details}',
      );
    }
    _check(
      await submissions.findByPreparation(createPrepared.preparationId) == null,
      'nothing was stored or sent for the tampered envelope',
    );

    _step('submitEscrowCall create_job (signed unchanged)');
    final signedCreate = _sign(key, codec, unsignedCreate);
    final createDetail = await endpoint.submitEscrowCall(
      session,
      hireId,
      createPrepared.preparationId,
      signedCreate,
    );
    final createHash = createDetail.escrowSubmission!.transaction;
    _check(
      createHash == createPrepared.transaction,
      'the relayed hash equals the prepared hash',
    );
    final again = await endpoint.submitEscrowCall(
      session,
      hireId,
      createPrepared.preparationId,
      signedCreate,
    );
    _check(
      again.escrowSubmission!.transaction == createHash,
      'a second submit of the same preparation returns the existing record',
    );
    _ok('create_job tx: $createHash');

    _step('tracker confirms create_job');
    await confirmed(createPrepared.preparationId);
    final opened = await _until('the hire to open with a job id', () async {
      final row = await hires.findHire(hireId);
      return row?.jobId != null && row?.status == HireStatus.open ? row : null;
    });
    _ok('hire ${opened.id} is ${opened.status!.name}, job id ${opened.jobId}');

    _step('prepareFund and submitEscrowCall fund (signed unchanged)');
    final fundPrepared = await endpoint.prepareFund(session, hireId);
    _ok('fund preparation: ${fundPrepared.preparationId}');
    final signedFund = _sign(key, codec, fundPrepared.unsignedTransactionXdr!);
    final fundDetail = await endpoint.submitEscrowCall(
      session,
      hireId,
      fundPrepared.preparationId,
      signedFund,
    );
    final fundHash = fundDetail.escrowSubmission!.transaction;
    _check(
      fundHash == fundPrepared.transaction,
      'the relayed hash equals the prepared hash',
    );
    _ok('fund tx: $fundHash');

    _step('tracker confirms fund');
    await confirmed(fundPrepared.preparationId);
    final funded = await _until('the hire to be funded', () async {
      final row = await hires.findHire(hireId);
      return row?.status == HireStatus.funded ? row : null;
    });

    _step('RESULT');
    stdout
      ..writeln('hire id:          ${funded.id}')
      ..writeln('job id:           ${funded.jobId}')
      ..writeln('create_job prep:  ${createPrepared.preparationId}')
      ..writeln('fund prep:        ${fundPrepared.preparationId}')
      ..writeln('create_job tx:    $createHash')
      ..writeln('                  $_explorer/$createHash')
      ..writeln('fund tx:          $fundHash')
      ..writeln('                  $_explorer/$fundHash')
      ..writeln('payment tx:       ${funded.paymentTransaction}')
      ..writeln('final status:     ${funded.status!.name}');
    _check(
      funded.paymentTransaction == fundHash,
      'the recorded payment is the relayed fund transaction',
    );
  } finally {
    await tracker.stop();
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
  exit(0);
}

/// What the script needs of a confirmed submission.
final class StoredSubmissionView {
  const StoredSubmissionView(this.transactionHash, this.explorerUrl);

  final String transactionHash;
  final String? explorerUrl;
}
