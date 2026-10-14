// Testnet end-to-end proof of feedback (issue #179, F7): a funded hire is
// delivered, released by the server after its approval deadline, and then
// rated by its consumer through the server. It continues the hire left by
// `e2e_relay_testnet.dart`, whose id is passed in PULS3_E2E_HIRE_ID.
//
// What is real: the `HireEndpoint` and `FeedbackEndpoint` behind a
// `SessionWallet` seam, the real wiring (Soroban RPC client, agent catalog,
// envelope codec, reputation registry), the chain tracker with its deadline
// runner (`startChainTracker`, which signs `release` with the relay account),
// and PostgreSQL through a Serverpod session in test mode (migrations
// applied). This script plays two parties: the agent, which signs `submit`
// directly (a fixture: the server does not sign `submit` yet), and the
// consumer, which signs `give_feedback` unchanged.
//
// Steps: submit (agent) -> wait for `approval_deadline` -> the tracker
// releases -> `getHire` reads `completed` -> prepareFeedback / sign /
// submitFeedback -> the tracker confirms `give_feedback` -> `getHire` has a
// `feedbackReference` and `AgentEndpoint.get` counts the new rating.
//
// TESTNET ONLY. Both secrets are read from the environment, kept in memory,
// and never printed or written anywhere:
//
//   PULS3_E2E_HIRE_ID           the funded hire of e2e_relay_testnet.dart
//   PULS3_E2E_CONSUMER_SECRET   the consumer wallet of that hire
//   PULS3_E2E_AGENT_SECRET      the agent wallet (the job's provider)
//
// The server needs the `escrowRelaySigningKey` password (release) and
// `PULS3_STELLAR_REPUTATION_REGISTRY` (feedback), like production. See the
// "End-to-end proof on testnet" section of puls3_server/README.md.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/feedback/feedback_endpoint.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart' show ScArg;
import 'package:serverpod/serverpod.dart' show Serverpod, Session;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

const _testnetPassphrase = 'Test SDF Network ; September 2015';
const _explorer = 'https://stellar.expert/explorer/testnet/tx';
const _confirmTimeout = Duration(minutes: 3);

/// The longest the script waits for the approval deadline and the release.
/// The escrow's approval window bounds it (see the open question in the
/// change design): raise it when the window is longer.
const _releaseTimeout = Duration(minutes: 30);

/// The score the consumer leaves.
const _score = 5;

/// The session seam of this run: every session is [address].
final class _Wallet implements SessionWallet {
  _Wallet(this.address);

  StellarAddress address;

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

stellar.StellarPrivateKey _secret(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    _fail('$name is not set (see the header of this script).');
  }
  return stellar.StellarPrivateKey.fromBase32(value);
}

StellarAddress _addressOf(stellar.StellarPrivateKey key) =>
    StellarAddress.parse(key.toPublicKey().toAddress().address);

Future<void> main(List<String> args) async {
  final hireId = int.tryParse(Platform.environment['PULS3_E2E_HIRE_ID'] ?? '');
  if (hireId == null) _fail('PULS3_E2E_HIRE_ID is not set.');
  final consumerKey = _secret('PULS3_E2E_CONSUMER_SECRET');
  final agentKey = _secret('PULS3_E2E_AGENT_SECRET');
  final consumer = _addressOf(consumerKey);
  final agentAccount = _addressOf(agentKey);

  final env = {
    ...Platform.environment,
    'PULS3_TRACKER_ENABLED': 'true',
    'PULS3_TRACKER_INTERVAL_SECONDS':
        Platform.environment['PULS3_TRACKER_INTERVAL_SECONDS'] ?? '2',
  };
  final codec = StellarEnvelopeCodec.forPassphrase(_testnetPassphrase);

  _step('Preconditions');
  final wiring = HireWiring.fromEnvironment(environment: env);
  _check(
    wiring.stellar.networkPassphrase == _testnetPassphrase,
    'the passphrase is the testnet one (this script never runs on mainnet)',
  );
  _ok('consumer (public): ${consumer.value}');
  _ok('agent account (public): ${agentAccount.value}');
  _ok('escrow: ${wiring.stellar.escrow.value}');

  final pod = Serverpod(
    ['--mode', 'test', '--apply-migrations'],
    Protocol(),
    Endpoints(),
  );
  await pod.start();
  final session = await pod.createSession();
  final tracker = startChainTracker(pod, env);
  if (tracker == null) _fail('the chain tracker did not start');
  // This run plays the wallets through the test seam. Production resolves the
  // wallet from the session.
  final wallet = _Wallet(consumer);
  // ignore: invalid_use_of_visible_for_testing_member
  HireEndpoint.sessionWallet = wallet;
  final hiresEndpoint = HireEndpoint();
  final feedbackEndpoint = FeedbackEndpoint();
  final submissions = ServerpodChainSubmissionStore(session);

  Future<StoredSubmissionView> confirmedPurpose(SubmissionPurpose purpose) =>
      _until(
        '${purpose.wireName} of hire $hireId to be confirmed',
        () async {
          final rows = await submissions.listByHire(hireId);
          for (final row in rows.where((row) => row.purpose == purpose)) {
            if (row.state == SubmissionState.confirmed) {
              return StoredSubmissionView(row.transactionHash);
            }
          }
          // A `failed` record is not final for the hire: the deadline pass
          // builds a new envelope until the attempts are used up.
          final failed = rows.where(
            (row) =>
                row.purpose == purpose &&
                row.state == SubmissionState.failed &&
                row.errorCode == SubmissionOutcomeCode.escrowCallFailed,
          );
          if (failed.isNotEmpty) {
            _fail('${purpose.wireName} failed: EscrowCallFailed');
          }
          return null;
        },
        timeout: _releaseTimeout,
      );

  try {
    _step('The hire is funded');
    final before = await hiresEndpoint.getHire(session, hireId, consumer.value);
    _check(
      before.hire.status == HireStatus.funded.name,
      'hire $hireId is funded (found ${before.hire.status})',
    );
    final jobId = before.jobId;
    if (jobId == null) _fail('hire $hireId has no escrow job');
    final job = await wiring.ledger.escrowJob(jobId);
    if (job == null) _fail('job $jobId does not exist on the escrow');
    _check(
      job.provider == agentAccount,
      'PULS3_E2E_AGENT_SECRET is the provider of job $jobId',
    );
    final agentId = before.agent.id;
    final ratedBefore = (await AgentEndpoint().get(session, agentId))!;
    _ok(
      'agent $agentId: rating ${ratedBefore.rating}, '
      'paid hires ${ratedBefore.paidHireCount}',
    );

    _step('submit (signed by the agent fixture)');
    if (job.state == EscrowJobState.funded) {
      final until = DateTime.now().toUtc().add(
        Duration(seconds: wiring.config.preparationValiditySeconds),
      );
      final spec = EnvelopeSpec(
        source: agentAccount,
        accountSequence: await wiring.accounts.sequenceOf(agentAccount),
        contract: wiring.stellar.escrow,
        function: 'submit',
        args: [
          ScArg.address(agentAccount),
          ScArg.u64(jobId),
          ScArg.bytes32(Uint8List.fromList(List.filled(32, 0xe2))),
        ],
        inclusionFee: wiring.config.inclusionFeeStroops,
        validUntil: until.millisecondsSinceEpoch ~/ 1000,
      );
      final prepared = codec.build(spec, await wiring.accounts.simulate(spec));
      final signed = _sign(agentKey, codec, prepared.envelopeXdr);
      final sent = await wiring.sender.resend(signed);
      _ok('submit sent: ${sent.status.name} ${prepared.hashHex}');
      _ok('submit tx: $_explorer/${prepared.hashHex}');
    } else {
      _ok('job $jobId is already ${job.state.name}; submit is skipped');
    }
    final submitted = await _until('job $jobId to be submitted', () async {
      final current = await wiring.ledger.escrowJob(jobId);
      return current?.state == EscrowJobState.submitted ? current : null;
    });
    _ok(
      'job $jobId submitted, approval deadline '
      '${DateTime.fromMillisecondsSinceEpoch(submitted.approvalDeadline * 1000, isUtc: true).toIso8601String()}',
    );

    _step('the server releases after the approval deadline');
    final released = await confirmedPurpose(SubmissionPurpose.release);
    _ok('release tx: ${released.transactionHash}');
    _ok('           $_explorer/${released.transactionHash}');
    final completed = await _until('the hire to read completed', () async {
      final detail = await hiresEndpoint.getHire(
        session,
        hireId,
        consumer.value,
      );
      return detail.hire.status == HireStatus.completed.name ? detail : null;
    });
    _check(
      completed.hire.feedbackReference == null,
      'hire $hireId is ${completed.hire.status} and not rated yet',
    );

    _step('prepareFeedback, sign unchanged, submitFeedback');
    final eligibility = await feedbackEndpoint.getFeedbackEligibility(
      session,
      hireId,
      consumer.value,
    );
    _check(eligibility.eligible, 'the consumer may rate hire $hireId');
    final prepared = await feedbackEndpoint.prepareFeedback(
      session,
      hireId,
      _score,
      'e2e testnet proof for issue #179',
    );
    _ok('give_feedback preparation: ${prepared.preparationId}');
    final detail = await feedbackEndpoint.submitFeedback(
      session,
      hireId,
      prepared.preparationId,
      _sign(consumerKey, codec, prepared.unsignedTransactionXdr!),
    );
    final feedbackHash = detail.feedbackSubmission?.transaction;
    _check(
      feedbackHash == prepared.transaction,
      'the relayed hash equals the prepared hash',
    );

    _step('the tracker confirms give_feedback');
    final rated = await _until('the hire to be rated', () async {
      final current = await hiresEndpoint.getHire(
        session,
        hireId,
        consumer.value,
      );
      final submission = current.feedbackSubmission;
      if (submission?.state == SubmissionState.failed.wireName) {
        _fail('give_feedback failed: ${submission?.errorCode}');
      }
      return current.hire.feedbackReference == null ? null : current;
    });
    _check(
      rated.hire.feedbackReference == feedbackHash,
      'feedbackReference is the give_feedback transaction',
    );
    final ratedAfter = await _until(
      'the catalog to count the rating',
      () async {
        final agent = await AgentEndpoint().get(session, agentId);
        return agent != null && agent.paidHireCount > ratedBefore.paidHireCount
            ? agent
            : null;
      },
      timeout: const Duration(minutes: 2),
    );

    _step('RESULT');
    stdout
      ..writeln('hire id:            $hireId')
      ..writeln('job id:             $jobId')
      ..writeln('release tx:         ${released.transactionHash}')
      ..writeln('                    $_explorer/${released.transactionHash}')
      ..writeln('give_feedback tx:   $feedbackHash')
      ..writeln('                    $_explorer/$feedbackHash')
      ..writeln('hire status:        ${rated.hire.status}')
      ..writeln('feedbackReference:  ${rated.hire.feedbackReference}')
      ..writeln(
        'agent rating:       ${ratedBefore.rating} -> ${ratedAfter.rating} '
        '(paid hires ${ratedBefore.paidHireCount} -> '
        '${ratedAfter.paidHireCount})',
      );
    _check(
      ratedAfter.paidHireCount == ratedBefore.paidHireCount + 1,
      'AgentEndpoint.get counts the new rating',
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
  const StoredSubmissionView(this.transactionHash);

  final String transactionHash;
}
