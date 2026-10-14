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
  );

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
          throw api.Puls3ApiException(code: 'RuntimeUnavailable'),
    );
    expect(
      () => missing.testRun(1, 'Hi', owner: 'G'),
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
        throw api.Puls3ApiException(code: 'RuntimeUnavailable');
      },
    );
    try {
      await refused.saveProviderCredential(
        provider: 'workers-ai',
        secret: token,
        accountId: 'builder-account',
        owner: 'G',
      );
      fail('expected StudioUnavailable');
    } on StudioUnavailable catch (e) {
      expect(provider, 'workers-ai');
      expect(secret, token);
      expect(accountId, 'builder-account');
      expect('$e', isNot(contains(token)));
    }
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
