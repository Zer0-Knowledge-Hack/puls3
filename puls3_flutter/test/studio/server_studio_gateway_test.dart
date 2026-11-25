import 'package:puls3_client/puls3_client.dart' as api;
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_flutter/src/studio/server_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';
import 'package:flutter_test/flutter_test.dart';

const _prompt = 'You are a private summarizer. Never repeat this sentence.';

void main() {
  ServerStudioGateway gateway({
    SaveDraftCall? saveDraft,
    GetDraftCall? getDraft,
    ListDraftsCall? listDrafts,
    TestRunCall? testRun,
    SaveProviderCredentialCall? saveProviderCredential,
    GetAgentHireCall? getAgentHire,
  }) => ServerStudioGateway(
    wallet: _IdleWallet(),
    saveDraft:
        saveDraft ??
        (draft, draftId, revision, overwrite) async => api.StudioDraft(
          draftId: 3,
          manifest: draft,
          revision: 2,
          deployState: 'draft',
        ),
    getDraft: getDraft ?? ((_) async => throw UnimplementedError()),
    listDrafts: listDrafts ?? (() async => const []),
    testRun:
        testRun ??
        ((draftId, input) async =>
            api.TestRunResult(output: 'ok', remainingDailyRuns: 19)),
    saveProviderCredential:
        saveProviderCredential ?? ((provider, secret, accountId) async {}),
    getAgentHire: getAgentHire,
  );

  api.HireDetail agentHire({
    int subcontractReserve = 0,
    List<api.HireReceiptLine>? receipt,
  }) => api.HireDetail(
    hire: api.Hire(
      id: 8,
      agentId: 9,
      consumer: 'GHIRINGAGENT',
      price: 45000000,
      manifestVersion: 1,
      status: 'funded',
      subcontractReserve: subcontractReserve,
    ),
    agent: api.AgentSummary(
      id: 'agt-009',
      registryId: 9,
      name: 'Support Relay',
      description: 'Answers support tickets',
      skills: ['support'],
      priceUsdcStroops: 45000000,
    ),
    input: 'Answer this ticket',
    receipt: receipt,
  );

  group('getAgentHire subcontract receipt (#334)', () {
    test('maps the reserve and the receipt lines of the agent hire', () async {
      final created = DateTime.utc(2026, 11, 24, 10);
      final progress =
          await gateway(
            getAgentHire: (agentId, hireId) async => agentHire(
              subcontractReserve: 30000000,
              receipt: [
                api.HireReceiptLine(
                  id: 7,
                  childHireId: 41,
                  childJobId: 52,
                  providerAgentId: 19,
                  providerWallet: 'GPROVIDER',
                  budget: 12000000,
                  fee: 600000,
                  payout: 11400000,
                  state: 'completed',
                  createTransaction: 'c0ffee',
                  createExplorerUrl: 'https://example.test/tx/c0ffee',
                  settleTransaction: '5e771e',
                  settleExplorerUrl: 'https://example.test/tx/5e771e',
                  deliverableHash: 'd311',
                  relatedParty: true,
                  justification: 'Best rated translator',
                  createdAt: created,
                ),
              ],
            ),
          ).getAgentHire(
            hiringAgentId: 9,
            hireId: 8,
            owner: 'GOWNER',
          );

      expect(progress.subcontractReserveUsdcStroops, 30000000);
      final line = progress.receipt.single;
      expect(line.id, 7);
      expect(line.childHireId, 41);
      expect(line.childJobId, 52);
      expect(line.providerAgentId, 19);
      expect(line.providerWallet, 'GPROVIDER');
      expect(line.budgetUsdcStroops, 12000000);
      expect(line.feeUsdcStroops, 600000);
      expect(line.payoutUsdcStroops, 11400000);
      expect(line.state, 'completed');
      expect(line.createTransaction, 'c0ffee');
      expect(line.createExplorerUrl, 'https://example.test/tx/c0ffee');
      expect(line.settleTransaction, '5e771e');
      expect(line.settleExplorerUrl, 'https://example.test/tx/5e771e');
      expect(line.deliverableHash, 'd311');
      expect(line.relatedParty, isTrue);
      expect(line.justification, 'Best rated translator');
      expect(line.createdAt, created);
    });

    test('a plain agent hire has no receipt and no reserve', () async {
      final progress = await gateway(
        getAgentHire: (agentId, hireId) async => agentHire(),
      ).getAgentHire(hiringAgentId: 9, hireId: 8, owner: 'GOWNER');

      expect(progress.receipt, isEmpty);
      expect(progress.subcontractReserveUsdcStroops, 0);
      expect(progress.status, 'funded');
    });
  });

  test('saveDraft sends the subcontract opt-in and reads it back '
      '(#334 T8.1)', () async {
    api.AgentManifestDraft? sent;
    final saved = await gateway(
      saveDraft: (draft, draftId, revision, overwrite) async {
        sent = draft;
        return api.StudioDraft(
          draftId: 7,
          manifest: draft,
          revision: 1,
          deployState: 'draft',
        );
      },
    ).saveDraft(
      AgentManifestDraft(
        name: 'T8 Post Writer',
        subcontract: SubcontractOptIn(
          maxChildren: 2,
          suggestedReserve: 2000000,
        ),
      ),
      owner: 'G',
    );

    expect(sent?.subcontract?.maxChildren, 2);
    expect(sent?.subcontract?.suggestedReserve, 2000000);
    expect(
      saved.manifest.subcontract,
      SubcontractOptIn(maxChildren: 2, suggestedReserve: 2000000),
    );
  });

  test('a draft without the opt-in is sent and read without it', () async {
    api.AgentManifestDraft? sent;
    final saved = await gateway(
      saveDraft: (draft, draftId, revision, overwrite) async {
        sent = draft;
        return api.StudioDraft(
          draftId: 7,
          manifest: draft,
          revision: 1,
          deployState: 'draft',
        );
      },
    ).saveDraft(AgentManifestDraft(name: 'Copy Forge'), owner: 'G');

    expect(sent?.subcontract, isNull);
    expect(saved.manifest.subcontract, isNull);
  });

  test(
    'saveDraft keeps the prompt and the revision the server returns',
    () async {
      api.AgentManifestDraft? sent;
      final saved =
          await gateway(
            saveDraft: (draft, draftId, revision, overwrite) async {
              sent = draft;
              expect(draftId, 7);
              expect(revision, 1);
              expect(overwrite, true);
              return api.StudioDraft(
                draftId: 7,
                manifest: draft,
                revision: 2,
                deployState: 'draft',
              );
            },
          ).saveDraft(
            AgentManifestDraft(name: 'Copy Forge', systemPrompt: _prompt),
            owner: 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
            draftId: 7,
            revision: 1,
            overwrite: true,
          );

      expect(sent?.systemPrompt, _prompt);
      expect(saved.draftId, 7);
      expect(saved.revision, 2);
      expect(saved.manifest.systemPrompt, _prompt);
    },
  );

  test(
    'DraftNotOwned and DraftVersionConflict use the Studio errors',
    () async {
      final owned = gateway(
        getDraft: (_) async =>
            throw api.Puls3ApiException(code: 'DraftNotOwned'),
      );
      expect(
        () => owned.getDraft(4, owner: 'G'),
        throwsA(isA<StudioDraftNotFound>()),
      );

      final stale = gateway(
        saveDraft: (draft, draftId, revision, overwrite) async =>
            throw api.Puls3ApiException(code: 'DraftVersionConflict'),
      );
      expect(
        () =>
            stale.saveDraft(AgentManifestDraft(name: 'Copy Forge'), owner: 'G'),
        throwsA(isA<StudioDraftConflict>()),
      );
    },
  );

  test('InvalidManifest lists the domain problem and not the prompt', () async {
    final refused = gateway(
      saveDraft: (draft, draftId, revision, overwrite) async =>
          throw api.Puls3ApiException(
            code: 'InvalidManifest',
            details: {'problems': 'nameTooLong'},
          ),
    );
    try {
      await refused.saveDraft(
        AgentManifestDraft(systemPrompt: _prompt),
        owner: 'G',
      );
      fail('expected StudioInvalidDraft');
    } on StudioInvalidDraft catch (e) {
      expect(e.problems, [ManifestProblem.nameTooLong]);
      expect('$e', isNot(contains(_prompt)));
    }
  });

  test('a test run returns the output and is not a demo', () async {
    String? sent;
    final result = await gateway(
      testRun: (draftId, input) async {
        expect(draftId, 4);
        sent = input;
        return api.TestRunResult(
          output: 'five bullets',
          remainingDailyRuns: 19,
        );
      },
    ).testRun(4, 'A long note.', owner: 'G');

    expect(gateway().isDemo, isFalse);
    expect(sent, 'A long note.');
    expect(result.output, 'five bullets');
    expect(result.remainingDailyRuns, 19);
  });

  test(
    'a quota error the browser client could not decode keeps its time',
    () async {
      final quota = gateway(
        testRun: (draftId, input) async => throw api.ServerpodClientBadRequest(
          '{"className":"Puls3ApiException","data":{"code":"TestQuotaExceeded",'
          '"details":{"resetsAt":"2026-10-15T00:00:00.000Z"}}}',
        ),
      );
      await expectLater(
        quota.testRun(1, _prompt, owner: 'G'),
        throwsA(
          isA<StudioTestQuotaExceeded>().having(
            (e) => e.resetsAt,
            'resetsAt',
            DateTime.utc(2026, 10, 15),
          ),
        ),
      );
    },
  );

  test('test run errors keep the prompt out of the message', () async {
    final quota = gateway(
      testRun: (draftId, input) async => throw api.Puls3ApiException(
        code: 'TestQuotaExceeded',
        details: {'resetsAt': '2026-10-15T00:00:00.000Z'},
      ),
    );
    try {
      await quota.testRun(1, _prompt, owner: 'G');
      fail('expected StudioTestQuotaExceeded');
    } on StudioTestQuotaExceeded catch (e) {
      expect(e.resetsAt, DateTime.utc(2026, 10, 15));
      expect('$e', isNot(contains(_prompt)));
    }

    final failed = gateway(
      testRun: (draftId, input) async => throw api.Puls3ApiException(
        code: 'AgentExecutionFailed',
        details: {'reason': 'timeout'},
      ),
    );
    expect(
      () => failed.testRun(1, _prompt, owner: 'G'),
      throwsA(
        isA<StudioRunFailed>().having((e) => e.message, 'message', 'timeout'),
      ),
    );

    final missing = gateway(
      testRun: (draftId, input) async =>
          throw api.Puls3ApiException(code: 'CredentialMissing'),
    );
    expect(
      () => missing.testRun(1, 'Hi', owner: 'G'),
      throwsA(isA<StudioCredentialMissing>()),
    );

    final invalid = gateway(
      testRun: (draftId, input) async =>
          throw api.Puls3ApiException(code: 'CredentialInvalid'),
    );
    expect(
      () => invalid.testRun(1, 'Hi', owner: 'G'),
      throwsA(isA<StudioCredentialInvalid>()),
    );

    final unsupported = gateway(
      testRun: (draftId, input) async =>
          throw api.Puls3ApiException(code: 'ProviderUnsupported'),
    );
    expect(
      () => unsupported.testRun(1, 'Hi', owner: 'G'),
      throwsA(isA<StudioProviderUnsupported>()),
    );

    final unavailable = gateway(
      testRun: (draftId, input) async =>
          throw api.Puls3ApiException(code: 'RuntimeUnavailable'),
    );
    expect(
      () => unavailable.testRun(1, 'Hi', owner: 'G'),
      throwsA(isA<StudioUnavailable>()),
    );

    final long = gateway(
      testRun: (draftId, input) async =>
          throw api.Puls3ApiException(code: 'InputTooLong'),
    );
    expect(
      () => long.testRun(1, 'Hi', owner: 'G'),
      throwsA(isA<StudioInputTooLong>()),
    );
  });

  test('a provider credential is sent and stays out of the error', () async {
    const token = 'builder-cloudflare-token';
    String? provider;
    String? secret;
    String? accountId;
    final refused = gateway(
      saveProviderCredential: (nextProvider, nextSecret, nextAccount) async {
        provider = nextProvider;
        secret = nextSecret;
        accountId = nextAccount;
        throw api.Puls3ApiException(code: 'CredentialInvalid');
      },
    );
    try {
      await refused.saveProviderCredential(
        provider: 'workers-ai',
        secret: token,
        accountId: 'builder-account',
        owner: 'G',
      );
      fail('expected StudioCredentialInvalid');
    } on StudioCredentialInvalid catch (e) {
      expect(provider, 'workers-ai');
      expect(secret, token);
      expect(accountId, 'builder-account');
      expect('$e', isNot(contains(token)));
    }

    final unavailable = gateway(
      saveProviderCredential: (nextProvider, nextSecret, nextAccount) async =>
          throw api.Puls3ApiException(code: 'RuntimeUnavailable'),
    );
    expect(
      () => unavailable.saveProviderCredential(
        provider: 'workers-ai',
        secret: token,
        accountId: 'builder-account',
        owner: 'G',
      ),
      throwsA(isA<StudioUnavailable>()),
    );
  });
}

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
