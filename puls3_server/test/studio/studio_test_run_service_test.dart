import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:puls3_server/src/studio/builder_credential.dart';
import 'package:puls3_server/src/studio/memory_studio_draft_store.dart';
import 'package:puls3_server/src/studio/studio_draft_errors.dart';
import 'package:puls3_server/src/studio/studio_draft_service.dart';
import 'package:puls3_server/src/studio/studio_model_policy.dart';
import 'package:puls3_server/src/studio/studio_test_errors.dart';
import 'package:puls3_server/src/studio/studio_test_run_service.dart';
import 'package:puls3_server/src/studio/test_run_quota.dart';
import 'package:test/test.dart';

void main() {
  const owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
  const other = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
  const prompt = 'You are Brief Bot. Reply with at most five bullet points.';
  const builderToken = 'builder-cloudflare-token';

  StellarAddress wallet(String value) => StellarAddress.parse(value);

  ({
    StudioTestRunService runs,
    List<RuntimeTask> tasks,
    List<String> secrets,
    MemoryStudioDraftStore drafts,
  })
  harness({
    StudioTestRunner? run,
    MemoryTestRunQuota? quota,
    MemoryBuilderCredentialStore? credentials,
  }) {
    final store = MemoryStudioDraftStore();
    final tasks = <RuntimeTask>[];
    final secrets = <String>[];
    final runs = StudioTestRunService(
      drafts: StudioDraftService(
        store,
        now: () => DateTime.utc(2026, 10, 14, 15),
      ),
      quota: quota ?? MemoryTestRunQuota(),
      credentials: credentials ?? MemoryBuilderCredentialStore(),
      policy: studioServerModelPolicy,
      now: () => DateTime.utc(2026, 10, 14, 15),
      run:
          run ??
          (task, credential) async {
            tasks.add(task);
            secrets.add(credential.secret);
            return 'five bullets';
          },
    );
    return (runs: runs, tasks: tasks, secrets: secrets, drafts: store);
  }

  Map<String, Object?> document() => {
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
  };

  Future<int> save(MemoryStudioDraftStore drafts) async {
    final saved = await StudioDraftService(drafts).save(
      owner: wallet(owner),
      document: document(),
    );
    return saved.draftId;
  }

  Future<void> storeCredential(StudioTestRunService runs) =>
      runs.saveCredential(
        owner: wallet(owner),
        credential: const BuilderProviderCredential(
          provider: 'workers-ai',
          secret: builderToken,
          accountId: 'builder-account',
        ),
      );

  test(
    'a test run uses the builder credential and does not spend a hire',
    () async {
      final box = harness();
      final id = await save(box.drafts);
      await storeCredential(box.runs);

      final result = await box.runs.testRun(
        owner: wallet(owner),
        draftId: id,
        input: 'A long note.',
      );

      expect(result.output, 'five bullets');
      expect(result.remainingDailyRuns, studioDailyTestRuns - 1);
      expect(box.tasks, hasLength(1));
      expect(box.tasks.single.systemPrompt, prompt);
      expect(box.tasks.single.input, 'A long note.');
      expect(box.secrets.single, builderToken);
    },
  );

  test(
    'no credential never calls the model and does not spend quota',
    () async {
      final box = harness();
      final id = await save(box.drafts);

      await expectLater(
        () => box.runs.testRun(owner: wallet(owner), draftId: id, input: 'Hi'),
        throwsA(isA<StudioRuntimeUnavailable>()),
      );
      expect(box.tasks, isEmpty);

      await storeCredential(box.runs);
      final result = await box.runs.testRun(
        owner: wallet(owner),
        draftId: id,
        input: 'Hi',
      );
      expect(result.remainingDailyRuns, studioDailyTestRuns - 1);
    },
  );

  test('another wallet gets no prompt and no run', () async {
    final box = harness();
    final id = await save(box.drafts);
    await storeCredential(box.runs);
    try {
      await box.runs.testRun(owner: wallet(other), draftId: id, input: 'Hi');
      fail('expected StudioDraftNotOwned');
    } on StudioDraftNotOwned catch (e) {
      expect('$e', isNot(contains(prompt)));
    }
    expect(box.tasks, isEmpty);
  });

  test(
    'an input over the limit is refused before the model and the quota',
    () async {
      final box = harness();
      final id = await save(box.drafts);
      await storeCredential(box.runs);
      await expectLater(
        () => box.runs.testRun(
          owner: wallet(owner),
          draftId: id,
          input: 'x' * 101,
        ),
        throwsA(isA<StudioInputTooLong>()),
      );
      expect(box.tasks, isEmpty);
      final result = await box.runs.testRun(
        owner: wallet(owner),
        draftId: id,
        input: 'ok',
      );
      expect(result.remainingDailyRuns, studioDailyTestRuns - 1);
    },
  );

  test(
    'a draft that cannot be deployed is rejected before the model',
    () async {
      final box = harness();
      final saved = await StudioDraftService(box.drafts).save(
        owner: wallet(owner),
        document: {'name': 'Brief Bot'},
      );
      await storeCredential(box.runs);
      await expectLater(
        () => box.runs.testRun(
          owner: wallet(owner),
          draftId: saved.draftId,
          input: 'Hi',
        ),
        throwsA(isA<InvalidManifest>()),
      );
      expect(box.tasks, isEmpty);
    },
  );

  test('the 21st run is the quota error and does not call the model', () async {
    final box = harness();
    final id = await save(box.drafts);
    await storeCredential(box.runs);
    for (var i = 0; i < studioDailyTestRuns; i++) {
      await box.runs.testRun(owner: wallet(owner), draftId: id, input: 'Hi');
    }
    expect(box.tasks, hasLength(studioDailyTestRuns));
    await expectLater(
      () => box.runs.testRun(owner: wallet(owner), draftId: id, input: 'Hi'),
      throwsA(
        isA<StudioTestQuotaExceeded>().having(
          (e) => e.resetsAt,
          'resetsAt',
          DateTime.utc(2026, 10, 15),
        ),
      ),
    );
    expect(box.tasks, hasLength(studioDailyTestRuns));
  });

  test('a provider failure spends the run and hides the prompt', () async {
    final quota = MemoryTestRunQuota();
    final credentials = MemoryBuilderCredentialStore();
    final failing = harness(
      quota: quota,
      credentials: credentials,
      run: (task, credential) async {
        throw const RuntimeProviderFailed(
          status: 503,
          errorType: 'unavailable',
        );
      },
    );
    final id = await save(failing.drafts);
    await storeCredential(failing.runs);
    try {
      await failing.runs.testRun(
        owner: wallet(owner),
        draftId: id,
        input: 'Hi',
      );
      fail('expected StudioRunFailed');
    } on StudioRunFailed catch (e) {
      expect(e.code, contains('provider_error'));
      expect(e.code, isNot(contains(prompt)));
      expect('$e', isNot(contains(prompt)));
    }
    final next = await StudioTestRunService(
      drafts: StudioDraftService(failing.drafts),
      quota: quota,
      credentials: credentials,
      policy: studioServerModelPolicy,
      now: () => DateTime.utc(2026, 10, 14, 15),
      run: (task, credential) async => 'ok',
    ).testRun(owner: wallet(owner), draftId: id, input: 'Hi');
    expect(next.remainingDailyRuns, studioDailyTestRuns - 2);
  });
}
