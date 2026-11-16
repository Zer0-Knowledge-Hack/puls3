import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_wiring.dart';
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/chain/agent_submit_sender.dart';
import 'package:puls3_server/src/chain/chain_tracker_wiring.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/tracker_loop.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/endpoints.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:serverpod/serverpod.dart' show Serverpod, Session;

import 'local_sandbox.dart';

/// Price of the agent every suite hires, in stroops of the sandbox token.
const e2ePriceStroops = 5000000;

/// The session seam of a run: every session is [address].
final class _SessionAs implements SessionWallet {
  _SessionAs(this.address);

  StellarAddress address;

  @override
  Future<StellarAddress> requireLogin(Session session) async => address;
}

/// The real server stack of one E2E run: Serverpod in test mode on
/// PostgreSQL, the real hire wiring against the local sandbox and the chain
/// tracker. Only the wallets are played by the test, which signs the
/// envelopes the server prepared, unchanged.
final class E2eWorld {
  E2eWorld._({
    required this.sandbox,
    required this.pod,
    required this.session,
    required this.wiring,
    required this.tracker,
    required this.codec,
    required this.consumer,
    required this.agentAccount,
    required this.agentId,
    required _SessionAs wallet,
  }) : _wallet = wallet,
       endpoint = HireEndpoint(),
       hires = ServerpodHireRepository(session),
       submissions = ServerpodChainSubmissionStore(session);

  final LocalSandbox sandbox;
  final Serverpod pod;
  final Session session;
  final HireWiring wiring;
  final TrackerLoop tracker;
  final StellarEnvelopeCodec codec;
  final E2eAccount consumer;
  final E2eAccount agentAccount;

  /// Registry id of the agent the world registered for the suites to hire.
  final int agentId;

  final HireEndpoint endpoint;
  final ServerpodHireRepository hires;
  final ServerpodChainSubmissionStore submissions;
  final _SessionAs _wallet;

  /// Boots the stack, registers one agent on the sandbox and funds the
  /// consumer and the agent wallet from the local Friendbot.
  static Future<E2eWorld> start() async {
    final sandbox = await LocalSandbox.connect();
    final consumer = E2eAccount.random();
    await sandbox.fund(consumer.address.value);
    final agent = await sandbox.registerAgent(priceStroops: e2ePriceStroops);

    final wiring = HireWiring.fromEnvironment(environment: sandbox.environment);
    final pod = Serverpod(
      ['--mode', 'test', '--apply-migrations'],
      Protocol(),
      Endpoints(),
    );
    await pod.start();
    final session = await pod.createSession();
    final tracker = startChainTracker(pod, sandbox.environment);
    if (tracker == null) {
      await session.close();
      await pod.shutdown(exitProcess: false);
      throw StateError('the chain tracker did not start');
    }
    final wallet = _SessionAs(consumer.address);
    // This run plays the consumer wallet through the test seam. Production
    // resolves the wallet from the session.
    // ignore: invalid_use_of_visible_for_testing_member
    HireEndpoint.sessionWallet = wallet;
    // The endpoints read `PULS3_*` from the process environment by default;
    // this run hands them the sandbox wiring instead.
    // ignore: invalid_use_of_visible_for_testing_member
    HireEndpoint.servicesBuilder = wiring.servicesOn;
    // ignore: invalid_use_of_visible_for_testing_member
    AgentEndpoint.service = buildAgentCatalogReader(
      session,
      environment: sandbox.environment,
    );
    return E2eWorld._(
      sandbox: sandbox,
      pod: pod,
      session: session,
      wiring: wiring,
      tracker: tracker,
      codec: StellarEnvelopeCodec.forPassphrase(sandbox.passphrase),
      consumer: consumer,
      agentAccount: agent.account,
      agentId: agent.id,
      wallet: wallet,
    );
  }

  /// The wallet the server sees as signed in.
  StellarAddress get signedInWallet => _wallet.address;

  Future<void> stop() async {
    // ignore: invalid_use_of_visible_for_testing_member
    HireEndpoint.servicesBuilder = null;
    // ignore: invalid_use_of_visible_for_testing_member
    HireEndpoint.sessionWallet = null;
    // ignore: invalid_use_of_visible_for_testing_member
    AgentEndpoint.service = null;
    await tracker.stop();
    await session.close();
    await pod.shutdown(exitProcess: false);
    await sandbox.cleanup();
  }

  /// Waits for the submission of [preparationId] to be confirmed.
  Future<StoredSubmissionView> confirmed(String preparationId) async {
    final done = await until(
      'submission of $preparationId to finish',
      () async {
        final stored = await submissions.findByPreparation(preparationId);
        if (stored == null) return null;
        if (stored.state == SubmissionState.failed) {
          throw StateError(
            'submission ${stored.transactionHash} failed: ${stored.errorCode}',
          );
        }
        return stored.state == SubmissionState.confirmed ? stored : null;
      },
    );
    return StoredSubmissionView(done.transactionHash);
  }

  /// Creates a hire and walks it to `funded`, with every envelope signed by the
  /// consumer unchanged. Returns the hire id and its escrow job id.
  Future<({int hireId, int jobId})> fundedHire() async {
    final created = await endpoint.createHire(
      session,
      agentId,
      consumer.address.value,
      'e2e hire',
      'e2e-${DateTime.now().microsecondsSinceEpoch}',
    );
    final hireId = created.hire.id;
    final prepared = created.preparedCreateJob!;
    await endpoint.submitEscrowCall(
      session,
      hireId,
      prepared.preparationId,
      consumer.sign(codec, prepared.unsignedTransactionXdr!),
    );
    await confirmed(prepared.preparationId);
    final opened = await hireIn(hireId, HireStatus.open);
    final fund = await endpoint.prepareFund(session, hireId);
    await endpoint.submitEscrowCall(
      session,
      hireId,
      fund.preparationId,
      consumer.sign(codec, fund.unsignedTransactionXdr!),
    );
    await confirmed(fund.preparationId);
    await hireIn(hireId, HireStatus.funded);
    return (hireId: hireId, jobId: opened.jobId!);
  }

  /// The agent delivers hire [hireId]: the production [AgentSubmitSender]
  /// builds and records its escrow `submit`, and the agent account signs it
  /// where the server's custody signer would. Waits until the tracker has
  /// confirmed it and the hire reads `submitted`.
  Future<EscrowJob> agentSubmits(int hireId, int jobId) async {
    final rpc = SorobanRpcClient(
      httpClient: http.Client(),
      url: wiring.stellar.rpcUrl,
      timeout: wiring.stellar.rpcTimeout,
    );
    final sender = AgentSubmitSender(
      submissions: submissions,
      accounts: wiring.accounts,
      codec: codec,
      sign: (prepared, provider) async =>
          agentAccount.sign(codec, prepared.envelopeXdr),
      send: rpc.sendTransaction,
      escrow: wiring.stellar.escrow,
      inclusionFee: wiring.config.inclusionFeeStroops,
      validitySeconds: wiring.config.preparationValiditySeconds,
      now: DateTime.now,
      log: (level, message) {},
    );
    await sender.send(
      DueSubmit(
        hireId: hireId,
        jobId: jobId,
        provider: agentAccount.address,
        result: 'e2e result of hire $hireId',
      ),
    );
    await hireIn(hireId, HireStatus.submitted);
    return (await wiring.ledger.escrowJob(jobId))!;
  }

  /// Waits for hire [hireId] to reach [status] in the database.
  Future<HireRow> hireIn(int hireId, HireStatus status) =>
      until('hire $hireId to be ${status.name}', () async {
        final row = await hires.findHire(hireId);
        return row?.status == status ? row : null;
      });
}

/// What the suites need of a confirmed submission.
final class StoredSubmissionView {
  const StoredSubmissionView(this.transactionHash);

  final String transactionHash;
}
