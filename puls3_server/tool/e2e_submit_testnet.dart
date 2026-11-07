// Testnet end-to-end proof of agent-signed escrow submit (#208): a consumer
// creates and funds a hire of a Studio-deployed (custodied) agent; the
// runtime signs `submit` with the custodied provider key; the consumer then
// signs `complete` unchanged. It prints both transaction hashes with Stellar
// Expert links.
//
// What is real: `HireEndpoint` behind a `SessionWallet` seam, HireWiring,
// the chain tracker, the agent runtime (`startAgentRuntime`), PostgreSQL in
// Serverpod test mode, and testnet. The script plays only the consumer.
//
// Seed demo agents that still pay to the escrow admin (`GAFUY…`) are skipped:
// the server has no custodied key for them (#209). Pick a Studio-deployed
// agent with `PULS3_E2E_AGENT_ID`, or the cheapest custodied one.
//
// TESTNET ONLY. `PULS3_E2E_CONSUMER_SECRET` is read from the environment,
// kept in memory, and never printed. The server also needs the custody
// cipher (`PULS3_AGENT_WALLET_SECRET_KEY`), Workers AI (or Anthropic) so
// the run can finish, and the hire relay fee keys used by `e2e_relay_testnet`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/agent/wallet_custody_config.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
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
import 'package:puls3_server/src/runtime/agent_runtime_wiring.dart';
import 'package:serverpod/serverpod.dart' show Serverpod, Session;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _explorer = 'https://stellar.expert/explorer/testnet/tx';
const _confirmTimeout = Duration(minutes: 3);
const _runTimeout = Duration(minutes: 10);

/// Escrow admin / seed-agent wallet. Not a custodied row (#209).
const _seedAdmin = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

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
    'PULS3_RUNTIME_ENABLED': 'true',
    'PULS3_RUNTIME_INTERVAL_SECONDS':
        Platform.environment['PULS3_RUNTIME_INTERVAL_SECONDS'] ?? '2',
  };
  final codec = StellarEnvelopeCodec.forPassphrase(_testnetPassphrase);
  final mode = Platform.environment['PULS3_E2E_SERVERPOD_MODE'] ?? 'test';
  if (mode != 'test' && mode != 'development') {
    _fail('PULS3_E2E_SERVERPOD_MODE must be test or development.');
  }

  _step('Preconditions');
  try {
    WalletCustodyConfig.fromEnvironment(env);
  } catch (e) {
    _fail(
      'agent-wallet custody is not configured ($e). Set '
      'PULS3_AGENT_WALLET_SECRET_KEY (see docs/infra/secrets.md).',
    );
  }
  final wiring = HireWiring.fromEnvironment(environment: env);
  _ok('network: ${wiring.stellar.networkPassphrase}');
  _check(
    wiring.stellar.networkPassphrase == _testnetPassphrase,
    'the passphrase is the testnet one (this script never runs on mainnet)',
  );
  _ok('consumer (public): ${consumer.value}');
  _ok('serverpod mode: $mode');

  final pod = Serverpod(
    [
      '--mode',
      mode,
      if (mode == 'test') '--apply-migrations',
    ],
    Protocol(),
    Endpoints(),
  );
  await pod.start();
  final session = await pod.createSession();
  final tracker = startChainTracker(pod, env);
  if (tracker == null) _fail('the chain tracker did not start');
  final runtime = startAgentRuntime(pod, env);
  if (runtime == null) {
    _fail(
      'the agent runtime did not start. Set PULS3_RUNTIME_ENABLED=true and '
      'configure Workers AI or Anthropic (passwords.yaml).',
    );
  }

  // ignore: invalid_use_of_visible_for_testing_member
  HireEndpoint.sessionWallet = _ConsumerWallet(consumer);
  final endpoint = HireEndpoint();
  final hires = ServerpodHireRepository(session);
  final submissions = ServerpodChainSubmissionStore(session);
  final wallets = ServerpodAgentWalletStore(session);

  Future<StoredSubmission> confirmed(String preparationId) async {
    return _until('submission of $preparationId to finish', () async {
      final stored = await submissions.findByPreparation(preparationId);
      if (stored == null) return null;
      if (stored.state == SubmissionState.failed) {
        _fail(
          'submission ${stored.transactionHash} failed: ${stored.errorCode}',
        );
      }
      return stored.state == SubmissionState.confirmed ? stored : null;
    });
  }

  try {
    _step('Pick a custodied agent');
    final catalog = await wiring.catalog.list();
    final hireable = <AgentSummary>[];
    for (final agent in catalog) {
      final wallet = agent.wallet;
      if (wallet == null || wallet == _seedAdmin) continue;
      final stored = await wallets.findByAddress(StellarAddress.parse(wallet));
      if (stored != null) hireable.add(agent);
    }
    hireable.sort((a, b) => a.priceUsdcStroops.compareTo(b.priceUsdcStroops));
    if (hireable.isEmpty) {
      _fail(
        'no Studio-deployed agent with a custodied wallet is in the catalog. '
        'Seed agents still pay $_seedAdmin (#209). Deploy one from Studio, '
        'or rebind the demo catalog, then re-run.',
      );
    }
    final requestedAgent = int.tryParse(
      Platform.environment['PULS3_E2E_AGENT_ID'] ?? '',
    );
    final agent = requestedAgent == null
        ? hireable.first
        : hireable.firstWhere(
            (a) => a.registryId == requestedAgent,
            orElse: () => _fail(
              'agent $requestedAgent is not in the catalog with a custodied '
              'wallet',
            ),
          );
    _ok(
      'agent: registry id ${agent.registryId} "${agent.name}" '
      'wallet ${agent.wallet}',
    );

    _step('createHire and fund');
    final requestId = 'e2e-submit-${DateTime.now().millisecondsSinceEpoch}';
    final created = await endpoint.createHire(
      session,
      agent.registryId,
      consumer.value,
      'e2e testnet proof for issue #208',
      requestId,
    );
    final hireId = created.hire.id;
    final createPrepared = created.preparedCreateJob;
    _check(createPrepared != null, 'createHire returned a preparedCreateJob');
    final signedCreate = _sign(
      key,
      codec,
      createPrepared!.unsignedTransactionXdr!,
    );
    await endpoint.submitEscrowCall(
      session,
      hireId,
      createPrepared.preparationId,
      signedCreate,
    );
    await confirmed(createPrepared.preparationId);
    final fundPrepared = await endpoint.prepareFund(session, hireId);
    await endpoint.submitEscrowCall(
      session,
      hireId,
      fundPrepared.preparationId,
      _sign(key, codec, fundPrepared.unsignedTransactionXdr!),
    );
    await confirmed(fundPrepared.preparationId);
    _ok('hire $hireId is funded, job will run');

    _step('runtime submit');
    final submitted = await _until('the hire to become submitted', () async {
      final detail = await endpoint.getHire(session, hireId, consumer.value);
      if (detail.hire.status == 'submitted' &&
          detail.approvalDeadline != null) {
        return detail;
      }
      return null;
    }, timeout: _runTimeout);
    _check(
      submitted.result != null && submitted.result!.isNotEmpty,
      'getHire.result is the run output',
    );
    _check(
      submitted.approvalDeadline != null,
      'approvalDeadline is set once submitted',
    );
    final submitRow = (await submissions.listByHire(hireId))
        .where(
          (row) =>
              row.purpose == SubmissionPurpose.submit &&
              row.state == SubmissionState.confirmed,
        )
        .firstOrNull;
    if (submitRow == null) {
      _fail('no confirmed submit submission for hire $hireId');
    }
    final submitHash = submitRow.transactionHash;
    _ok('submit tx: $submitHash');
    _ok('status: submitted, approvalDeadline: ${submitted.approvalDeadline}');

    _step('prepareComplete and submitEscrowCall complete');
    final completePrepared = await endpoint.prepareComplete(session, hireId);
    final completeDetail = await endpoint.submitEscrowCall(
      session,
      hireId,
      completePrepared.preparationId,
      _sign(key, codec, completePrepared.unsignedTransactionXdr!),
    );
    final completeHash = completeDetail.escrowSubmission!.transaction;
    await confirmed(completePrepared.preparationId);
    final completed = await _until('the hire to complete', () async {
      final row = await hires.findHire(hireId);
      return row?.status == HireStatus.completed ? row : null;
    });

    _step('RESULT');
    stdout
      ..writeln('hire id:          ${completed.id}')
      ..writeln('job id:           ${completed.jobId}')
      ..writeln('submit tx:        $submitHash')
      ..writeln('                  $_explorer/$submitHash')
      ..writeln('complete tx:      $completeHash')
      ..writeln('                  $_explorer/$completeHash')
      ..writeln('final status:     ${completed.status!.name}');
  } finally {
    await runtime.stop();
    await tracker.stop();
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
  exit(0);
}
