import 'package:puls3_domain/puls3_domain.dart' hide AgentManifestDraft;
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:puls3_server/src/studio/builder_credential.dart';
import 'package:puls3_server/src/studio/memory_studio_draft_store.dart';
import 'package:puls3_server/src/studio/studio_draft_service.dart';
import 'package:puls3_server/src/studio/studio_endpoint.dart';
import 'package:puls3_server/src/studio/studio_model_policy.dart';
import 'package:puls3_server/src/studio/studio_test_run_service.dart';
import 'package:puls3_server/src/studio/test_run_quota.dart';
import 'package:serverpod/serverpod.dart'
    show AuthenticationFailureReason, NotAuthorizedException, Session;
import 'package:test/test.dart';

final class _UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('The endpoint must not use the session');
}

final class _FakeSessionWallet implements SessionWallet {
  _FakeSessionWallet(this.events, {this.wallet, this.failure});

  final List<String> events;
  final StellarAddress? wallet;
  final Object? failure;

  @override
  Future<StellarAddress> requireLogin(Session session) async {
    events.add('requireLogin');
    final failure = this.failure;
    if (failure != null) throw failure;
    return wallet!;
  }
}

void main() {
  const owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
  const prompt = 'You are a private summarizer. Never repeat this sentence.';
  final session = _UnusedSession();
  final endpoint = StudioEndpoint();

  late List<String> events;
  late MemoryStudioDraftStore store;

  setUp(() {
    events = [];
    store = MemoryStudioDraftStore();
    StudioEndpoint.sessionWallet = _FakeSessionWallet(
      events,
      wallet: StellarAddress.parse(owner),
    );
    StudioEndpoint.services = (_) {
      events.add('services');
      return StudioDraftService(store);
    };
  });

  tearDown(() {
    StudioEndpoint.sessionWallet = null;
    StudioEndpoint.services = null;
    StudioEndpoint.testRuns = null;
  });

  AgentManifestDraft draft({String? systemPrompt}) => AgentManifestDraft(
    name: 'Copy Forge',
    description: 'Rewrites a paragraph in a calmer voice.',
    systemPrompt: systemPrompt,
  );

  test('a caller without a session never reaches the store', () async {
    StudioEndpoint.sessionWallet = _FakeSessionWallet(
      events,
      failure: NotAuthorizedException(
        reason: AuthenticationFailureReason.unauthenticated,
      ),
    );
    expect(
      () => endpoint.saveDraft(session, draft(), null, null, null),
      throwsA(isA<NotAuthorizedException>()),
    );
    expect(events, ['requireLogin']);
  });

  test('save and get return the prompt only to the session wallet', () async {
    final saved = await endpoint.saveDraft(
      session,
      draft(systemPrompt: prompt),
      null,
      null,
      null,
    );
    expect(saved.revision, 1);
    expect(saved.manifest.systemPrompt, prompt);
    expect(events, ['requireLogin', 'services']);

    final loaded = await endpoint.getDraft(session, saved.draftId);
    expect(loaded.manifest.systemPrompt, prompt);

    final listed = await endpoint.listDrafts(session);
    expect(listed.single.draftId, saved.draftId);
    expect(listed.single.manifest.systemPrompt, prompt);
  });

  test(
    'a stale revision is DraftVersionConflict and keeps the prompt',
    () async {
      final saved = await endpoint.saveDraft(
        session,
        draft(systemPrompt: prompt),
        null,
        null,
        null,
      );
      await endpoint.saveDraft(
        session,
        draft(systemPrompt: 'second'),
        saved.draftId,
        1,
        false,
      );
      expect(
        () => endpoint.saveDraft(
          session,
          draft(systemPrompt: 'stale'),
          saved.draftId,
          1,
          false,
        ),
        throwsA(
          isA<Puls3ApiException>().having(
            (e) => e.code,
            'code',
            'DraftVersionConflict',
          ),
        ),
      );
      final current = await endpoint.getDraft(session, saved.draftId);
      expect(current.manifest.systemPrompt, 'second');
    },
  );

  test(
    'an invalid manifest is InvalidManifest and lists the problem',
    () async {
      expect(
        () => endpoint.saveDraft(
          session,
          AgentManifestDraft(name: 'x' * 49),
          null,
          null,
          null,
        ),
        throwsA(
          isA<Puls3ApiException>()
              .having((e) => e.code, 'code', 'InvalidManifest')
              .having(
                (e) => e.details?['problems'],
                'problems',
                contains('nameTooLong'),
              ),
        ),
      );
    },
  );

  test('another session wallet gets DraftNotOwned and no prompt', () async {
    final store = MemoryStudioDraftStore();
    StudioEndpoint.services = (_) => StudioDraftService(store);
    final saved = await endpoint.saveDraft(
      session,
      draft(systemPrompt: prompt),
      null,
      null,
      null,
    );
    const intruder = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
    StudioEndpoint.sessionWallet = _FakeSessionWallet(
      events,
      wallet: StellarAddress.parse(intruder),
    );

    Future<void> expectOwned(Future<Object?> call) async {
      try {
        await call;
        fail('expected DraftNotOwned');
      } on Puls3ApiException catch (e) {
        expect(e.code, 'DraftNotOwned');
        expect(e.message, isNot(contains(prompt)));
        expect(e.details?.values.join(), isNot(contains(prompt)));
        expect('$e', isNot(contains(prompt)));
      }
    }

    await expectOwned(endpoint.getDraft(session, saved.draftId));
    await expectOwned(
      endpoint.saveDraft(
        session,
        draft(systemPrompt: 'intruder'),
        saved.draftId,
        1,
        false,
      ),
    );
    expect(await endpoint.listDrafts(session), isEmpty);

    StudioEndpoint.sessionWallet = _FakeSessionWallet(
      events,
      wallet: StellarAddress.parse(owner),
    );
    final still = await endpoint.getDraft(session, saved.draftId);
    expect(still.manifest.systemPrompt, prompt);
    expect(still.revision, 1);
  });

  test('a caller without a session never starts a test run', () {
    StudioEndpoint.sessionWallet = _FakeSessionWallet(
      events,
      failure: NotAuthorizedException(
        reason: AuthenticationFailureReason.unauthenticated,
      ),
    );
    var called = false;
    StudioEndpoint.testRuns = (_) {
      called = true;
      throw StateError('must not build a runner');
    };
    expect(
      () => endpoint.testRun(session, 1, 'Hi'),
      throwsA(isA<NotAuthorizedException>()),
    );
    expect(called, isFalse);
    expect(events, ['requireLogin']);
  });

  test('a test run returns the output and hides a provider failure', () async {
    const secretPrompt =
        'You are Brief Bot. Reply with at most five bullet points.';
    final drafts = MemoryStudioDraftStore();
    final saved = await StudioDraftService(drafts).save(
      owner: StellarAddress.parse(owner),
      document: {
        'name': 'Brief Bot',
        'description':
            'Summarizes long text into a short brief with the key points.',
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
        'system_prompt': secretPrompt,
        'input': {'type': 'text', 'max_chars': 100},
        'output': {'type': 'markdown', 'max_chars': 2000},
        'price': {'asset': 'USDC', 'amount': 1000000},
      },
    );
    final credentials = MemoryBuilderCredentialStore();
    StudioTestRunService runs({StudioTestRunner? run}) => StudioTestRunService(
      drafts: StudioDraftService(drafts),
      quota: MemoryTestRunQuota(),
      credentials: credentials,
      policy: studioServerModelPolicy,
      now: () => DateTime.utc(2026, 10, 14, 15),
      run: run ?? (task, credential) async => 'five bullets',
    );
    StudioEndpoint.testRuns = (_) => runs();
    await runs().saveCredential(
      owner: StellarAddress.parse(owner),
      credential: const BuilderProviderCredential(
        provider: 'workers-ai',
        secret: 'builder-token',
        accountId: 'builder-account',
      ),
    );

    final result = await endpoint.testRun(session, saved.draftId, 'Hi');
    expect(result.output, 'five bullets');
    expect(result.remainingDailyRuns, 19);
    expect('$result', isNot(contains(secretPrompt)));

    StudioEndpoint.testRuns = (_) => runs(
      run: (task, credential) async {
        throw const RuntimeProviderFailed(status: 503, errorType: 'down');
      },
    );
    try {
      await endpoint.testRun(session, saved.draftId, 'Hi');
      fail('expected AgentExecutionFailed');
    } on Puls3ApiException catch (e) {
      expect(e.code, 'AgentExecutionFailed');
      expect(e.details?['reason'], contains('provider_error'));
      expect(e.details?['reason'], isNot(contains(secretPrompt)));
      expect('$e', isNot(contains(secretPrompt)));
    }
  });

  test('a missing credential is RuntimeUnavailable', () async {
    final saved = await StudioDraftService(store).save(
      owner: StellarAddress.parse(owner),
      document: {
        'name': 'Brief Bot',
        'description':
            'Summarizes long text into a short brief with the key points.',
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
        'system_prompt': prompt,
        'input': {'type': 'text', 'max_chars': 100},
        'output': {'type': 'markdown', 'max_chars': 2000},
        'price': {'asset': 'USDC', 'amount': 1000000},
      },
    );
    StudioEndpoint.testRuns = (_) => StudioTestRunService(
      drafts: StudioDraftService(store),
      quota: MemoryTestRunQuota(),
      credentials: MemoryBuilderCredentialStore(),
      policy: studioServerModelPolicy,
      run: (task, credential) async => 'no',
    );
    await expectLater(
      () => endpoint.testRun(session, saved.draftId, 'Hi'),
      throwsA(
        isA<Puls3ApiException>().having(
          (e) => e.code,
          'code',
          'RuntimeUnavailable',
        ),
      ),
    );
  });

  test('an empty provider secret is RuntimeUnavailable', () async {
    StudioEndpoint.testRuns = (_) => StudioTestRunService(
      drafts: StudioDraftService(store),
      quota: MemoryTestRunQuota(),
      credentials: MemoryBuilderCredentialStore(),
      policy: studioServerModelPolicy,
      run: (task, credential) async => 'no',
    );
    await expectLater(
      () => endpoint.saveProviderCredential(
        session,
        'workers-ai',
        '  ',
        'acct',
      ),
      throwsA(
        isA<Puls3ApiException>().having(
          (e) => e.code,
          'code',
          'RuntimeUnavailable',
        ),
      ),
    );
  });
}
