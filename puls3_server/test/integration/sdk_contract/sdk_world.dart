import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_client/puls3_client.dart' as wire;
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_sdk/puls3_sdk.dart' as sdk;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/agent/serverpod_agent_index_repository.dart';
import 'package:puls3_server/src/auth/wallet_auth_config.dart';
import 'package:puls3_server/src/auth/wallet_auth_endpoint.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/hire/hire_agent_lookup.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_query_service.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/serverpod_escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:puls3_server/src/studio/builder_credential.dart';
import 'package:puls3_server/src/studio/serverpod_studio_draft_store.dart';
import 'package:puls3_server/src/studio/studio_draft_service.dart';
import 'package:puls3_server/src/studio/studio_endpoint.dart';
import 'package:puls3_server/src/studio/studio_model_policy.dart';
import 'package:puls3_server/src/studio/studio_test_run_service.dart';
import 'package:puls3_server/src/studio/test_run_quota.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_test/serverpod_test.dart' show TestSessionBuilder;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import '../../support/fake_chain_accounts.dart';
import '../../support/fake_envelope_codec.dart';
import '../../support/fake_submission_ledger.dart';
import '../../unit/hire/hire_test_fakes.dart';

const _network = 'Test SDF Network ; September 2015';
const _agentWallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _relayEnv = {
  'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': '300',
  'PULS3_STELLAR_INCLUSION_FEE_STROOPS': '100',
  'PULS3_PLATFORM_FEE_BPS': '0',
  'PULS3_HIRE_JOB_DURATION_SECONDS': '86400',
};

/// The agent every hire in these tests is for: registry id 7, `agt-001`.
const agentRegistryId = 7;
const agentPrice = 5000000;

/// This server, wired for the SDK contract tests (#375).
///
/// Every endpoint runs for real on the test database, behind the real HTTP
/// stack and wallet sign-in. Only the chain is replaced: the registry, the
/// account reads and the transaction codec are the fakes the relay tests use,
/// so preparing a transaction needs no network.
final class SdkWorld {
  SdkWorld._(this.sessionBuilder, this._dir);

  /// Wires the endpoints and makes a scratch directory for session files.
  static Future<SdkWorld> start(TestSessionBuilder sessionBuilder) async {
    final world = SdkWorld._(
      sessionBuilder,
      await Directory.systemTemp.createTemp('puls3-sdk-contract-'),
    );
    world._wire();
    return world;
  }

  final TestSessionBuilder sessionBuilder;
  final Directory _dir;
  final _closers = <void Function()>[];

  /// The signing wallet of every session: a fixed test key, never a real one.
  final walletKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 9),
  );
  final _serverKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 7),
  );

  /// The chain fakes behind the hire services, shared by every request.
  final ledger = FakeLedger();
  final accounts = FakeChainAccounts();
  final codec = FakeEnvelopeCodec();
  final sender = FakeSubmissionLedger();

  /// Every task the Studio runtime was asked to run: the model is replaced
  /// by one that answers `echo: <input>`.
  final studioTasks = <RuntimeTask>[];
  final _credentials = MemoryBuilderCredentialStore();
  final _quota = MemoryTestRunQuota();

  String get wallet => _address(walletKey);

  /// The session file the last [signedInSdk] wrote.
  String get sessionFile => '${_dir.path}${Platform.pathSeparator}session.json';

  Uri get apiUrl =>
      Uri.parse('http://localhost:${Serverpod.instance.server.port}/');

  /// A database session for setting up and reading rows.
  Session get db => sessionBuilder.build();

  void _wire() {
    ledger
      ..wallets[agentRegistryId] = StellarAddress.parse(_agentWallet)
      ..metadata[agentRegistryId] = {
        'id': utf8.encode('agt-001'),
        'name': utf8.encode('Test Agent'),
        'description': utf8.encode('A helpful test agent for verification.'),
        'skills': utf8.encode(jsonEncode(['coding'])),
        'priceUsdcStroops': utf8.encode('$agentPrice'),
        'puls3.manifestVersion': utf8.encode('1'),
      }.map((k, v) => MapEntry(k, Uint8List.fromList(v)));

    WalletAuthEndpoint.debugConfig = WalletAuthConfig(
      signingKey: _serverKey.toBase32(),
      serverAccount: _address(_serverKey),
      homeDomain: 'puls3.app',
      webAuthDomain: 'auth.puls3.app',
      networkPassphrase: _network,
    );
    WalletAuthEndpoint.debugChain = _SingleKeyAccounts();

    final catalog = AgentCatalogService(ledger);
    AgentEndpoint.service = catalog;
    HireEndpoint.servicesBuilder = (session) => _hireServices(session, catalog);
    StudioEndpoint.testRuns = (session) => StudioTestRunService(
      drafts: StudioDraftService(ServerpodStudioDraftStore(session)),
      quota: _quota,
      credentials: _credentials,
      policy: studioServerModelPolicy,
      run: (task, credential) async {
        studioTasks.add(task);
        return 'echo: ${task.input}';
      },
    );
  }

  /// A Studio draft of [wallet] in the database, with a stored model
  /// credential so it can be test-run.
  Future<int> saveDraft() async {
    final saved = await StudioDraftService(
      ServerpodStudioDraftStore(db),
    ).save(owner: StellarAddress.parse(wallet), document: _draftDocument);
    await _credentials.save(
      owner: wallet,
      credential: const BuilderProviderCredential(
        provider: 'workers-ai',
        secret: 'builder-token',
        accountId: 'builder-account',
      ),
    );
    return saved.draftId;
  }

  HireServices _hireServices(Session session, AgentCatalogService catalog) {
    final hires = ServerpodHireRepository(session);
    final preparations = ServerpodEscrowPreparationStore(session);
    final submissions = ServerpodChainSubmissionStore(session);
    // The production lookup: the index is empty here, so it reads the
    // catalog over the fake registry.
    final agentOf = hireAgentLookup(
      index: ServerpodAgentIndexRepository(
        session,
        network: StellarConfig.testnet.networkPassphrase,
      ),
      fallback: catalog,
    );
    final relay = EscrowRelayService(
      preparations: preparations,
      submissions: submissions,
      hires: hires,
      accounts: accounts,
      codec: codec,
      sender: sender,
      agentWallets: ledger,
      agents: agentOf,
      stellar: StellarConfig.testnet,
      config: const HireRelayConfig(_relayEnv),
    );
    return HireServices(
      hires: HireService(
        hires: hires,
        preparations: preparations,
        relay: relay,
        registry: ledger,
        catalog: catalog,
        custody: (addresses) async => addresses.toSet(),
        config: const HireRelayConfig(_relayEnv),
        agentOf: agentOf,
      ),
      relay: relay,
      query: HireQueryService(
        hires: hires,
        runs: ServerpodHireRunStore(session),
        submissions: submissions,
        preparations: preparations,
        agents: agentOf,
        jobs: ledger,
      ),
    );
  }

  /// Signs in as [wallet] over HTTP the way the app does (SEP-10), creates a
  /// CLI session, and opens the SDK on it exactly as a program outside the
  /// app would: `PULS3_REFRESH_TOKEN` and a session file.
  Future<sdk.Puls3Sdk> signedInSdk() async {
    final bootstrap = wire.Client(apiUrl.toString());
    final String refreshToken;
    try {
      final challenge = await bootstrap.walletAuth.createChallenge(wallet);
      final signedIn = await bootstrap.walletAuth.verifyChallenge(
        challenge.challengeId,
        wallet,
        _sign(challenge.payload, walletKey, challenge.networkPassphrase),
      );
      bootstrap.authKeyProvider = _Bearer(signedIn.token);
      refreshToken = (await bootstrap.cliSession.create()).refreshToken;
    } finally {
      bootstrap.close();
    }

    final session = await sdk.CliSession.open(
      apiUrl,
      environment: {
        sdk.refreshTokenVariable: refreshToken,
        sdk.sessionFileVariable: sessionFile,
      },
    );
    if (session == null) throw StateError('CliSession.open found no session');
    final client = sdk.Puls3Sdk.connect(apiUrl, session: session);
    _closers
      ..add(client.close)
      ..add(session.close);
    return client;
  }

  /// A hire of [agentRegistryId] by [wallet], created by the server's own
  /// service so its rows are exactly what `createHire` writes.
  Future<CreateHireResult> createHire({
    String input = 'summarise this',
    required String requestId,
  }) => HireEndpoint.servicesOf(db).hires.createHire(
    agentId: agentRegistryId,
    consumer: wallet,
    input: input,
    requestId: requestId,
  );

  Future<void> close() async {
    for (final close in _closers.reversed) {
      close();
    }
    _closers.clear();
    HireEndpoint.servicesBuilder = null;
    StudioEndpoint.testRuns = null;
    WalletAuthEndpoint.resetDebug();
    AgentEndpoint.service = null;
    if (_dir.existsSync()) await _dir.delete(recursive: true);
  }
}

const _draftDocument = <String, Object?>{
  'name': 'Brief Bot',
  'description': 'Summarizes long text into a short brief with the key points.',
  'skills': [
    {
      'id': 'summarize',
      'name': 'Summarize',
      'description': 'Turns a long text into five bullet points.',
      'tags': ['summary'],
    },
  ],
  'model': {
    'provider': 'workers-ai',
    'id': '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
  },
  'system_prompt': 'Summarize the text in five short bullet points.',
  'input': {'type': 'text', 'max_chars': 100},
  'output': {'type': 'markdown', 'max_chars': 2000},
  'price': {'asset': 'USDC', 'amount': 1000000},
};

final class _Bearer implements wire.ClientAuthKeyProvider {
  _Bearer(this._token);

  final String _token;

  @override
  Future<String?> get authHeaderValue async =>
      wire.wrapAsBearerAuthHeaderValue(_token);
}

/// Every account is a fresh one: its master key alone signs.
final class _SingleKeyAccounts implements ChainAccounts {
  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async =>
      const AccountAuthority(masterWeight: 1, mediumThreshold: 1, signers: {});

  @override
  Future<SimulationData> simulateRaw(EnvelopeSpec spec) =>
      throw UnimplementedError('sign-in never simulates');

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) =>
      throw UnimplementedError('sign-in never simulates');

  @override
  Future<int> sequenceOf(StellarAddress account) =>
      throw UnimplementedError('sign-in never reads a sequence');
}

String _address(stellar.StellarPrivateKey key) =>
    key.toPublicKey().toAddress().address;

/// Appends the wallet's signature to the server-signed challenge.
String _sign(String xdr, stellar.StellarPrivateKey key, String network) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(xdr))
          as stellar.TransactionV1Envelope;
  final hash = Uint8List.fromList(
    stellar.TransactionSignaturePayload(
      networkId: stellar.StellarNetwork.fromPassphrase(network).passphraseHash,
      taggedTransaction: decoded.tx,
    ).txHash(),
  );
  return base64Encode(
    stellar.TransactionV1Envelope(
      tx: decoded.tx,
      signatures: [...decoded.signatures, key.sign(hash)],
    ).toVariantXDR(),
  );
}
