import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart' as api;
import 'package:puls3_flutter/src/deploy/deploy_gateway.dart';
import 'package:puls3_flutter/src/deploy/server_deploy_gateway.dart';
import 'package:puls3_flutter/src/domain/agent_draft.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

const _hash =
    'aa11bb22cc33dd44ee55ff6600112233445566778899aabbccddeeff00112233';
const _wallet = 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ';

const _draft = AgentDraft(
  name: 'Visa Scout',
  description: 'Checks visa rules.',
  model: 'Claude Sonnet',
  systemPrompt: 'You check visa rules.',
  skills: ['Travel'],
  priceUsdcStroops: 5000000,
  draftId: 7,
);

void main() {
  test('a draft that was not saved cannot deploy', () async {
    final gateway = _gateway();
    expect(
      () => gateway.prepare(
        const AgentDraft(
          name: 'Visa Scout',
          description: 'Checks visa rules.',
          model: 'Claude Sonnet',
          systemPrompt: 'You check visa rules.',
          skills: ['Travel'],
          priceUsdcStroops: 5000000,
        ),
        builder: 'G',
      ),
      throwsA(isA<DeployBackendError>()),
    );
  });

  test('prepare returns the unsigned register_full envelope', () async {
    int? draftId;
    String? builder;
    final gateway = _gateway(
      prepareDeploy: (id, owner) async {
        draftId = id;
        builder = owner;
        return _session(
          state: 'awaitingRegistrationSignature',
          unsigned: 'unsigned-xdr',
        );
      },
    );

    final prepared = await gateway.prepare(
      _draft,
      builder: 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
    );

    expect(gateway.isDemo, isFalse);
    expect(draftId, 7);
    expect(
      builder,
      'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
    );
    expect(prepared.preparationId, 'prep-1');
    expect(prepared.unsignedTransaction, 'unsigned-xdr');
  });

  test('a first deploy is not a resumed one', () async {
    final prepared = await _gateway().prepare(_draft, builder: 'G');

    expect(prepared.registered, isNull);
    expect(prepared.active, isFalse);
  });

  group('resume after registration (#321)', () {
    test('a confirmed registration resumes at the wallet step', () async {
      final gateway = _gateway(
        prepareDeploy: (draftId, builder) async => _session(
          state: 'awaitingWalletAuthorization',
          hash: _hash,
          agentId: 30,
          entry: 'entry-xdr',
        ),
      );

      final prepared = await gateway.prepare(_draft, builder: 'G');

      expect(prepared.registered?.agentId, 30);
      expect(prepared.registered?.transactionHash, _hash);
      expect(prepared.active, isFalse);
      // The wallet step of the resumed deploy uses the same draft.
      expect(
        await gateway.walletAuthorization(prepared.registered!),
        'entry-xdr',
      );
    });

    test('a submitted registration is polled until confirmed', () async {
      var reads = 0;
      final gateway = _gateway(
        prepareDeploy: (draftId, builder) async => _session(
          state: 'registrationSubmitted',
          unsigned: 'unsigned-xdr',
          hash: _hash,
        ),
        getDeploySession: (draftId) async {
          reads += 1;
          return reads < 2
              ? _session(state: 'registrationSubmitted', hash: _hash)
              : _session(
                  state: 'awaitingWalletAuthorization',
                  hash: _hash,
                  agentId: 30,
                );
        },
      );

      final prepared = await gateway.prepare(_draft, builder: 'G');

      expect(reads, 2);
      expect(prepared.registered?.agentId, 30);
      expect(prepared.active, isFalse);
    });

    test('an active agent resumes straight to live', () async {
      final gateway = _gateway(
        prepareDeploy: (draftId, builder) async => _session(
          state: 'active',
          hash: _hash,
          agentId: 30,
          wallet: _wallet,
          entry: 'entry-xdr',
        ),
      );

      final prepared = await gateway.prepare(_draft, builder: 'G');

      expect(prepared.registered?.agentId, 30);
      expect(prepared.active, isTrue);
    });

    test('a submitted wallet authorization is polled until active', () async {
      var reads = 0;
      final gateway = _gateway(
        prepareDeploy: (draftId, builder) async => _session(
          state: 'walletAuthorizationSubmitted',
          hash: _hash,
          agentId: 30,
          entry: 'entry-xdr',
        ),
        getDeploySession: (draftId) async {
          reads += 1;
          return _session(
            state: 'active',
            hash: _hash,
            agentId: 30,
            wallet: _wallet,
          );
        },
      );

      final prepared = await gateway.prepare(_draft, builder: 'G');

      expect(reads, 1);
      expect(prepared.active, isTrue);
    });

    test('a registered session without its hash is refused', () async {
      final gateway = _gateway(
        prepareDeploy: (draftId, builder) async => _session(
          state: 'awaitingWalletAuthorization',
          agentId: 30,
          entry: 'entry-xdr',
        ),
      );

      await expectLater(
        gateway.prepare(_draft, builder: 'G'),
        throwsA(isA<DeployBackendError>()),
      );
    });
  });

  test('submit waits for the agent id and keeps the real hash', () async {
    var reads = 0;
    final gateway = _gateway(
      getDeploySession: (draftId) async {
        expect(draftId, 7);
        reads += 1;
        return _session(
          state: 'awaitingWalletAuthorization',
          hash: _hash,
          agentId: 42,
        );
      },
    );
    await gateway.prepare(_draft, builder: 'G');

    final registration = await gateway.submitRegistration(
      const PreparedDeploy(
        preparationId: 'prep-1',
        unsignedTransaction: 'unsigned-xdr',
      ),
      'signed-xdr',
    );

    expect(reads, 1);
    expect(registration.agentId, 42);
    expect(registration.transactionHash, _hash);
  });

  test('a typed error the browser client could not decode is mapped', () async {
    final gateway = _gateway(
      prepareDeploy: (draftId, builder) async => throw api.ServerpodClientBadRequest(
        '{"className":"Puls3ApiException","data":{"code":"PreparationExpired",'
        '"message":"That signature expired.","details":{"purpose":"deploy"}}}',
      ),
    );
    await expectLater(
      gateway.prepare(_draft, builder: 'G'),
      throwsA(
        isA<DeployPreparationExpired>().having(
          (error) => error.message,
          'message',
          'That signature expired.',
        ),
      ),
    );
  });

  test('a rejected registration surfaces the chain failure', () async {
    final gateway = _gateway(
      submitRegistration: (draftId, preparationId, signed) async => _session(
        state: 'failed',
        failureCode: 'TransactionFailed',
        hash: _hash,
      ),
    );
    await gateway.prepare(_draft, builder: 'G');

    expect(
      () => gateway.submitRegistration(
        const PreparedDeploy(
          preparationId: 'prep-1',
          unsignedTransaction: 'unsigned-xdr',
        ),
        'signed-xdr',
      ),
      throwsA(
        isA<DeployTransactionFailed>().having(
          (error) => error.transactionHash,
          'transactionHash',
          _hash,
        ),
      ),
    );
  });

  test(
    'the wallet step confirms and activate returns the custodied wallet',
    () async {
      String? signedEntry;
      final gateway = _gateway(
        submitWalletAuthorization: (draftId, preparationId, signed) async {
          expect(draftId, 7);
          expect(preparationId, 'prep-wallet');
          signedEntry = signed;
          return _session(
            state: 'walletAuthorizationSubmitted',
            hash: _hash,
            agentId: 42,
            wallet: _wallet,
            entry: 'entry-xdr',
          );
        },
        getDeploySession: (_) async => _session(
          state: 'active',
          hash: _hash,
          agentId: 42,
          wallet: _wallet,
          entry: 'entry-xdr',
        ),
      );
      await gateway.prepare(_draft, builder: 'G');
      const registration = Registration(agentId: 42, transactionHash: _hash);

      expect(await gateway.walletAuthorization(registration), 'entry-xdr');
      await gateway.submitWalletAuthorization(registration, 'signed-entry');
      expect(signedEntry, 'signed-entry');
      expect(await gateway.activate(registration), _wallet);
    },
  );

  test(
    'a version update waits out registrationSubmitted even with an agent id',
    () async {
      var reads = 0;
      final gateway = _gateway(
        submitRegistration: (draftId, preparationId, signed) async => _session(
          state: 'registrationSubmitted',
          hash: _hash,
          agentId: 42,
        ),
        getDeploySession: (draftId) async {
          reads += 1;
          return _session(
            state: 'awaitingWalletAuthorization',
            hash: _hash,
            agentId: 42,
            purpose: 'setMetadata',
            unsigned: 'version-tx',
          );
        },
      );
      await gateway.prepare(_draft, builder: 'G');

      final registration = await gateway.submitRegistration(
        const PreparedDeploy(
          preparationId: 'prep-1',
          unsignedTransaction: 'unsigned-xdr',
        ),
        'signed-xdr',
      );

      expect(reads, 1);
      expect(registration.agentId, 42);
      expect(registration.transactionHash, _hash);
    },
  );

  test('the second version step returns the metadata envelope', () async {
    final gateway = _gateway(
      prepareWalletAuthorization: (_) async => _session(
        state: 'awaitingWalletAuthorization',
        preparationId: 'prep-version',
        hash: _hash,
        agentId: 42,
        purpose: 'setMetadata',
        unsigned: 'version-tx',
      ),
    );
    await gateway.prepare(_draft, builder: 'G');

    expect(
      await gateway.walletAuthorization(
        const Registration(agentId: 42, transactionHash: _hash),
      ),
      'version-tx',
    );
  });
}

ServerDeployGateway _gateway({
  PrepareDeployCall? prepareDeploy,
  SubmitRegistrationCall? submitRegistration,
  GetDeploySessionCall? getDeploySession,
  PrepareWalletAuthorizationCall? prepareWalletAuthorization,
  SubmitWalletAuthorizationCall? submitWalletAuthorization,
}) => ServerDeployGateway(
  wallet: _IdleWallet(),
  pollInterval: Duration.zero,
  prepareDeploy:
      prepareDeploy ??
      (draftId, builder) async => _session(
        state: 'awaitingRegistrationSignature',
        unsigned: 'unsigned-xdr',
      ),
  submitRegistration:
      submitRegistration ??
      (draftId, preparationId, signed) async => _session(
        state: 'registrationSubmitted',
        hash: _hash,
      ),
  getDeploySession:
      getDeploySession ??
      (draftId) async => _session(
        state: 'awaitingWalletAuthorization',
        hash: _hash,
        agentId: 42,
      ),
  prepareWalletAuthorization:
      prepareWalletAuthorization ??
      (draftId) async => _session(
        state: 'awaitingWalletAuthorization',
        preparationId: 'prep-wallet',
        hash: _hash,
        agentId: 42,
        entry: 'entry-xdr',
      ),
  submitWalletAuthorization:
      submitWalletAuthorization ??
      (draftId, preparationId, signed) async => _session(
        state: 'active',
        hash: _hash,
        agentId: 42,
        wallet: _wallet,
        entry: 'entry-xdr',
      ),
);

api.DeploySession _session({
  required String state,
  String preparationId = 'prep-1',
  String? unsigned,
  String? hash,
  String? entry,
  int? agentId,
  String? wallet,
  String? failureCode,
  String purpose = '',
}) => api.DeploySession(
  state: state,
  agentId: agentId,
  agentWallet: wallet,
  failureCode: failureCode,
  preparation: api.PreparedTransaction(
    preparationId: preparationId,
    purpose: purpose.isNotEmpty
        ? purpose
        : entry == null
        ? 'registerFull'
        : 'setAgentWallet',
    signer: 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
    networkPassphrase: 'Test SDF Network ; September 2015',
    unsignedTransactionXdr: unsigned,
    authorizationEntryXdr: entry,
    transaction: hash,
    expiresAt: DateTime.utc(2026, 10, 14, 17),
  ),
);

final class _IdleWallet implements WalletPort {
  @override
  String? get address => null;

  @override
  String get name => 'idle';

  @override
  Uri? get installUrl => null;

  @override
  String? get network => null;

  @override
  Future<String> connect() => Future.error(const WalletUnavailable());

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> signAuthEntry(String entryXdr) =>
      Future.error(const WalletUnavailable());

  @override
  Future<String> signChallenge(SignInChallenge challenge) =>
      Future.error(const WalletUnavailable());

  @override
  Future<String> signTransaction(String unsignedXdr) =>
      Future.error(const WalletUnavailable());
}
