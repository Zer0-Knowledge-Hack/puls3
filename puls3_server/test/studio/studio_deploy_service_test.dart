import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    hide AgentManifestDraft;
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/strkey.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:puls3_server/src/studio/auth_entry.dart';
import 'package:puls3_server/src/studio/deploy_chain.dart';
import 'package:puls3_server/src/studio/memory_studio_draft_store.dart';
import 'package:puls3_server/src/studio/registration_call.dart';
import 'package:puls3_server/src/studio/registration_document.dart';
import 'package:puls3_server/src/studio/studio_agent_version.dart';
import 'package:puls3_server/src/studio/studio_deploy_service.dart';
import 'package:puls3_server/src/studio/studio_deploy_store.dart';
import 'package:puls3_server/src/studio/studio_draft_service.dart';
import 'package:puls3_server/src/studio/studio_model_policy.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:puls3_server/src/runtime/studio_run_manifest_source.dart';
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';

const _owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agent = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

void main() {
  late _Rig rig;

  setUp(() => rig = _Rig());

  test('prepareDeploy returns an unsigned register_full for the owner', () async {
    final draftId = await rig.saveDraft();

    final row = await rig.service.prepareDeploy(
      owner: rig.owner,
      draftId: draftId,
    );

    expect(row.state, 'awaitingRegistrationSignature');
    expect(row.agentWallet, _agent);
    expect(row.unsignedEnvelopeXdr, isNotEmpty);
    expect(row.registrationHash, hasLength(64));
    expect(row.registrationUri, startsWith('https://puls3.test/registry/'));
    final built = rig.codec.built.single.spec;
    expect(built.function, 'register_full');
    expect(built.source, rig.owner);
    expect(built.contract, StellarConfig.testnet.identityRegistry);
    expect(
      encodeInvokeHostFunction(
        contract: built.contract,
        function: built.function,
        args: built.args,
      ),
      encodeInvokeHostFunction(
        contract: StellarConfig.testnet.identityRegistry,
        function: 'register_full',
        args: registerFullArgs(
          caller: rig.owner,
          agentUri: row.registrationUri,
          manifestHash: manifestHash(rig.manifest),
          manifest: rig.validated,
          catalogId: 'studio-$draftId',
        ),
      ),
    );
    expect(rig.sent, isEmpty);
  });

  test('submitRegistration keeps the hash and waits for the agent id', () async {
    final draftId = await rig.saveDraft();
    final prepared = await rig.service.prepareDeploy(
      owner: rig.owner,
      draftId: draftId,
    );
    rig.transactions.next = const ChainTx(ChainTxStatus.pending);

    final submitted = await rig.service.submitRegistration(
      owner: rig.owner,
      draftId: draftId,
      preparationId: prepared.preparationId!,
      signedTransactionXdr: FakeEnvelopeCodec.sign(
        prepared.unsignedEnvelopeXdr!,
      ),
    );

    expect(submitted.state, 'registrationSubmitted');
    expect(submitted.registrationHash, prepared.registrationHash);
    expect(rig.sent, hasLength(1));

    rig.transactions.next = const ChainTx(ChainTxStatus.success, agentId: 42);
    final confirmed = await rig.service.getDeploySession(
      owner: rig.owner,
      draftId: draftId,
    );
    expect(confirmed.state, 'awaitingWalletAuthorization');
    expect(confirmed.registryAgentId, 42);
  });

  test('prepareWalletAuthorization returns the builder auth entry', () async {
    final draftId = await rig.registered();
    final entry = _addressEntry(rig.owner);

    rig.accounts.simulation = SimulationData(
      transactionData: base64Encode(const [1, 2, 3, 4]),
      minResourceFee: 50,
      auth: [_sourceEntry(), entry],
    );

    final row = await rig.service.prepareWalletAuthorization(
      owner: rig.owner,
      draftId: draftId,
    );

    expect(row.state, 'awaitingWalletAuthorization');
    expect(row.authorizationEntryXdr, entry);
    expect(row.signatureExpirationLedger, 100);
    expect(readAuthEntry(entry).covers(rig.owner), isTrue);
    expect(rig.accounts.simulated.last.function, 'set_agent_wallet');
    expect(rig.accounts.simulated.last.source.value, _agent);
  });

  test('a changed invocation is rejected before it is signed', () async {
    final draftId = await rig.registered();
    final entry = _addressEntry(rig.owner);
    rig.accounts.simulation = SimulationData(
      transactionData: base64Encode(const [1, 2, 3, 4]),
      minResourceFee: 50,
      auth: [entry],
    );
    final prepared = await rig.service.prepareWalletAuthorization(
      owner: rig.owner,
      draftId: draftId,
    );

    await expectLater(
      rig.service.submitWalletAuthorization(
        owner: rig.owner,
        draftId: draftId,
        preparationId: prepared.preparationId!,
        signedAuthorizationEntryXdr: _addressEntry(rig.owner, invocation: 7),
      ),
      throwsA(
        isA<Puls3ApiException>().having(
          (e) => e.code,
          'code',
          'InvalidAuthorizationEntry',
        ),
      ),
    );
    expect(rig.sent, hasLength(1));
  });

  test('a confirmed wallet publishes without the prompt and activates it', () async {
    final draftId = await rig.registered();
    final entry = _addressEntry(rig.owner);
    rig.accounts.simulation = SimulationData(
      transactionData: base64Encode(const [1, 2, 3, 4]),
      minResourceFee: 50,
      auth: [entry],
    );
    final prepared = await rig.service.prepareWalletAuthorization(
      owner: rig.owner,
      draftId: draftId,
    );
    rig.transactions.next = const ChainTx(ChainTxStatus.success);

    final row = await rig.service.submitWalletAuthorization(
      owner: rig.owner,
      draftId: draftId,
      preparationId: prepared.preparationId!,
      signedAuthorizationEntryXdr: _signedAddressEntry(rig.owner),
    );

    expect(row.state, 'active');
    final document = jsonEncode(registrationDocument(rig.validated));
    expect(document.contains(rig.validated.systemPrompt), isFalse);
    final source = StudioRunManifestSource(
      lookup: (agentId, version) async {
        final found = await rig.versions.find(agentId, version);
        if (found == null) return null;
        return (manifestJson: found.manifestJson, owner: found.owner);
      },
      fallback: _MissingManifests(),
    );
    final run = await source.find(42, 1);
    expect(run, isA<OwnedRunManifest>());
    expect(run!.systemPrompt, rig.validated.systemPrompt);
    expect((run as OwnedRunManifest).owner, _owner);
  });

  test('a new version keeps the agent and the previous snapshot', () async {
    final draftId = await rig.active();
    final first = await rig.deploys.findByDraft(draftId);
    const nextPrompt = 'You are a private editor. Never repeat this sentence.';
    final edited = AgentManifestDraft(
      name: rig.manifest.name,
      description: rig.manifest.description,
      skills: rig.manifest.skills,
      model: rig.manifest.model,
      systemPrompt: nextPrompt,
      inputType: rig.manifest.inputType,
      inputMaxChars: rig.manifest.inputMaxChars,
      outputType: rig.manifest.outputType,
      outputMaxChars: rig.manifest.outputMaxChars,
      price: rig.manifest.price,
    );
    await rig.drafts.save(
      owner: rig.owner,
      document: edited.toJson(),
      draftId: draftId,
      overwrite: true,
    );
    rig.accounts.simulation = const SimulationData(
      transactionData: 'AQIDBA==',
      minResourceFee: 20,
    );
    rig.codec.built.clear();

    final prepared = await rig.service.prepareDeploy(
      owner: rig.owner,
      draftId: draftId,
    );

    expect(prepared.state, 'awaitingRegistrationSignature');
    expect(prepared.registryAgentId, 42);
    expect(prepared.agentWallet, first!.agentWallet);
    expect(prepared.registrationUri, first.registrationUri);
    expect(prepared.registrationHash, first.registrationHash);
    final hashUpdate = rig.codec.built.single.spec;
    expect(hashUpdate.function, 'set_metadata');
    expect(hashUpdate.source, rig.owner);
    expect(
      encodeInvokeHostFunction(
        contract: hashUpdate.contract,
        function: hashUpdate.function,
        args: hashUpdate.args,
      ),
      encodeInvokeHostFunction(
        contract: StellarConfig.testnet.identityRegistry,
        function: 'set_metadata',
        args: setMetadataArgs(
          caller: rig.owner,
          agentId: 42,
          key: 'manifestHash',
          value: manifestHash(edited),
        ),
      ),
    );

    rig.transactions.next = const ChainTx(ChainTxStatus.success);
    final versionStep = await rig.service.submitRegistration(
      owner: rig.owner,
      draftId: draftId,
      preparationId: prepared.preparationId!,
      signedTransactionXdr: FakeEnvelopeCodec.sign(
        prepared.unsignedEnvelopeXdr!,
      ),
    );
    expect(versionStep.state, 'awaitingWalletAuthorization');
    final versionUpdate = rig.codec.built.last.spec;
    expect(
      encodeInvokeHostFunction(
        contract: versionUpdate.contract,
        function: versionUpdate.function,
        args: versionUpdate.args,
      ),
      encodeInvokeHostFunction(
        contract: StellarConfig.testnet.identityRegistry,
        function: 'set_metadata',
        args: setMetadataArgs(
          caller: rig.owner,
          agentId: 42,
          key: 'puls3.manifestVersion',
          value: Uint8List.fromList(utf8.encode('2')),
        ),
      ),
    );

    rig.transactions.next = const ChainTx(ChainTxStatus.success);
    final live = await rig.service.submitWalletAuthorization(
      owner: rig.owner,
      draftId: draftId,
      preparationId: versionStep.preparationId!,
      signedAuthorizationEntryXdr: FakeEnvelopeCodec.sign(
        versionStep.unsignedEnvelopeXdr!,
      ),
    );

    expect(live.state, 'active');
    expect(live.registryAgentId, 42);
    expect(
      rig.codec.built.where((call) => call.spec.function == 'register_full'),
      isEmpty,
    );
    final source = StudioRunManifestSource(
      lookup: (agentId, version) async {
        final found = await rig.versions.find(agentId, version);
        if (found == null) return null;
        return (manifestJson: found.manifestJson, owner: found.owner);
      },
      fallback: _MissingManifests(),
    );
    final previous = await source.find(42, 1);
    final next = await source.find(42, 2);
    expect(previous!.systemPrompt, rig.validated.systemPrompt);
    expect(next!.systemPrompt, nextPrompt);
    final document = jsonEncode(
      registrationDocument(
        edited.validate(studioServerModelPolicy, ManifestVersion(2)),
      ),
    );
    expect(document.contains(nextPrompt), isFalse);
    expect(document, contains('"manifestVersion":2'));
  });
}

String _sourceEntry() => base64Encode((XdrWriter()..uint32(0)).bytes);

String _addressEntry(StellarAddress account, {int invocation = 0x10}) {
  final out = XdrWriter()
    ..uint32(1)
    ..uint32(0)
    ..uint32(0)
    ..opaque(rawKey(account))
    ..int64(9)
    ..uint32(100)
    ..uint32(1)
    ..uint32(invocation);
  return base64Encode(out.bytes);
}

String _signedAddressEntry(StellarAddress account) {
  final out = XdrWriter()
    ..uint32(1)
    ..uint32(0)
    ..uint32(0)
    ..opaque(rawKey(account))
    ..int64(9)
    ..uint32(100)
    ..uint32(3)
    ..uint32(1)
    ..uint32(0x10);
  return base64Encode(out.bytes);
}

final class _Rig {
  _Rig() {
    drafts = StudioDraftService(MemoryStudioDraftStore());
    deploys = MemoryStudioDeployStore();
    versions = MemoryAgentVersionStore();
    codec = FakeEnvelopeCodec();
    assembler = _Assembler(codec);
    accounts = _Accounts();
    transactions = _Transactions();
    service = StudioDeployService(
      drafts: drafts,
      deploys: deploys,
      versions: versions,
      wallets: _Wallets(),
      accounts: accounts,
      codec: codec,
      assembler: assembler,
      sender: _Sender(sent),
      transactions: transactions,
      funder: _Funder(),
      signer: _Signer(),
      stellar: StellarConfig.testnet,
      registrationBase: Uri.parse('https://puls3.test'),
      preparationValiditySeconds: 300,
      inclusionFeeStroops: 100,
      now: () => DateTime.utc(2026, 10, 14, 16),
      newPreparationId: () => 'prep-1',
    );
  }

  late final StudioDraftService drafts;
  late final MemoryStudioDeployStore deploys;
  late final MemoryAgentVersionStore versions;
  late final FakeEnvelopeCodec codec;
  late final _Assembler assembler;
  late final _Accounts accounts;
  late final _Transactions transactions;
  late final StudioDeployService service;
  final sent = <String>[];
  final owner = StellarAddress.parse(_owner);
  final manifest = AgentManifestDraft(
    name: 'Copy Forge',
    description: 'Rewrites a paragraph in a calmer voice.',
    skills: [Skill(id: 'rewrite', name: 'Rewrite')],
    model: ModelId(
      provider: 'workers-ai',
      id: '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
    ),
    systemPrompt: 'You are a private summarizer. Never repeat this sentence.',
    inputType: InputType.text,
    inputMaxChars: 1000,
    outputType: OutputType.text,
    outputMaxChars: 1000,
    price: UsdcAmount.stroops(5000000),
  );

  AgentManifest get validated =>
      manifest.validate(studioServerModelPolicy, ManifestVersion.first);

  Future<int> saveDraft() async {
    final saved = await drafts.save(
      owner: owner,
      document: manifest.toJson(),
    );
    return saved.draftId;
  }

  Future<int> registered() async {
    final draftId = await saveDraft();
    final prepared = await service.prepareDeploy(owner: owner, draftId: draftId);
    transactions.next = const ChainTx(ChainTxStatus.success, agentId: 42);
    await service.submitRegistration(
      owner: owner,
      draftId: draftId,
      preparationId: prepared.preparationId!,
      signedTransactionXdr: FakeEnvelopeCodec.sign(prepared.unsignedEnvelopeXdr!),
    );
    transactions.next = const ChainTx(ChainTxStatus.pending);
    return draftId;
  }

  Future<int> active() async {
    final draftId = await registered();
    final entry = _addressEntry(owner);
    accounts.simulation = SimulationData(
      transactionData: base64Encode(const [1, 2, 3, 4]),
      minResourceFee: 50,
      auth: [entry],
    );
    final prepared = await service.prepareWalletAuthorization(
      owner: owner,
      draftId: draftId,
    );
    transactions.next = const ChainTx(ChainTxStatus.success);
    await service.submitWalletAuthorization(
      owner: owner,
      draftId: draftId,
      preparationId: prepared.preparationId!,
      signedAuthorizationEntryXdr: _signedAddressEntry(owner),
    );
    transactions.next = const ChainTx(ChainTxStatus.pending);
    return draftId;
  }
}

final class _MissingManifests implements RunManifestSource {
  @override
  Future<RunManifest?> find(int agentId, int manifestVersion) async => null;
}

final class _Wallets implements AgentWalletCustody {
  @override
  Future<StellarAddress> create({
    required StellarAddress owner,
    required String idempotencyKey,
  }) async => StellarAddress.parse(_agent);
}

final class _Accounts implements ChainAccounts {
  SimulationData simulation = const SimulationData(
    transactionData: 'AQIDBA==',
    minResourceFee: 20,
  );
  final simulated = <EnvelopeSpec>[];

  @override
  Future<int> sequenceOf(StellarAddress account) async => 10;

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async {
    simulated.add(spec);
    return simulation;
  }

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async =>
      const AccountAuthority(masterWeight: 1, mediumThreshold: 0, signers: {});
}

final class _Assembler implements AddressAuthAssembler {
  _Assembler(this.codec);

  final FakeEnvelopeCodec codec;
  final specs = <EnvelopeSpec>[];

  @override
  PreparedEnvelope assembleAllowingAddressAuth(
    EnvelopeSpec spec,
    SimulationData sim,
  ) {
    specs.add(spec);
    return codec.build(spec, sim);
  }
}

final class _Sender implements SubmissionLedger {
  _Sender(this.sent);

  final List<String> sent;

  @override
  Future<TransactionLookup> lookup(String hash) =>
      throw UnimplementedError();

  @override
  Future<SendTransactionResult> resend(String envelopeXdr) async {
    sent.add(envelopeXdr);
    return const SendTransactionResult(
      status: SendTransactionStatus.pending,
      hash: 'ab',
    );
  }
}

final class _Transactions implements ChainTxReader {
  ChainTx next = const ChainTx(ChainTxStatus.pending);

  @override
  Future<ChainTx> read(String hash) async => next;
}

final class _Funder implements AccountFunder {
  @override
  Future<void> fund(StellarAddress account) async {}
}

final class _Signer implements AgentEnvelopeSigner {
  @override
  Future<String> sign(PreparedEnvelope envelope, StellarAddress address) async =>
      'signed';
}
