import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/studio/memory_studio_draft_store.dart';
import 'package:puls3_server/src/studio/studio_draft_errors.dart';
import 'package:puls3_server/src/studio/studio_draft_service.dart';
import 'package:test/test.dart';

void main() {
  const owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
  const other = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
  const prompt = 'You are a private summarizer. Never repeat this sentence.';

  late MemoryStudioDraftStore store;
  late StudioDraftService drafts;

  setUp(() {
    store = MemoryStudioDraftStore();
    drafts = StudioDraftService(
      store,
      now: () => DateTime.utc(2026, 10, 14, 15),
    );
  });

  StellarAddress wallet(String value) => StellarAddress.parse(value);

  Map<String, Object?> document({String? systemPrompt}) => {
    'name': 'Copy Forge',
    'description': 'Rewrites a paragraph in a calmer voice.',
    'system_prompt': ?systemPrompt,
  };

  test(
    'a new draft starts at revision 1 and keeps the prompt for its owner',
    () async {
      final saved = await drafts.save(
        owner: wallet(owner),
        document: document(systemPrompt: prompt),
      );

      expect(saved.draftId, 1);
      expect(saved.revision, 1);
      expect(saved.deployState, 'draft');
      expect(saved.manifest.systemPrompt, prompt);

      final loaded = await drafts.get(
        owner: wallet(owner),
        draftId: saved.draftId,
      );
      expect(loaded.manifest.systemPrompt, prompt);
      expect(loaded.revision, 1);
    },
  );

  test('an update bumps the revision and a stale one conflicts', () async {
    final saved = await drafts.save(
      owner: wallet(owner),
      document: document(systemPrompt: prompt),
    );
    final updated = await drafts.save(
      owner: wallet(owner),
      document: document(systemPrompt: 'A replacement prompt for the owner.'),
      draftId: saved.draftId,
      revision: saved.revision,
    );
    expect(updated.revision, 2);
    expect(
      updated.manifest.systemPrompt,
      'A replacement prompt for the owner.',
    );

    expect(
      () => drafts.save(
        owner: wallet(owner),
        document: document(systemPrompt: 'stale'),
        draftId: saved.draftId,
        revision: 1,
      ),
      throwsA(isA<StudioDraftRevisionConflict>()),
    );
    final current = await drafts.get(
      owner: wallet(owner),
      draftId: saved.draftId,
    );
    expect(current.revision, 2);
    expect(
      current.manifest.systemPrompt,
      'A replacement prompt for the owner.',
    );
  });

  test('overwrite replaces a stale revision', () async {
    final saved = await drafts.save(
      owner: wallet(owner),
      document: document(systemPrompt: prompt),
    );
    final updated = await drafts.save(
      owner: wallet(owner),
      document: document(systemPrompt: 'kept mine'),
      draftId: saved.draftId,
      revision: 0,
      overwrite: true,
    );
    expect(updated.revision, 2);
    expect(updated.manifest.systemPrompt, 'kept mine');
  });

  test('a name over the maximum is refused and nothing is stored', () async {
    expect(
      () => drafts.save(
        owner: wallet(owner),
        document: {'name': 'x' * 49},
      ),
      throwsA(
        isA<InvalidManifest>().having(
          (e) => e.problems,
          'problems',
          contains(ManifestProblem.nameTooLong),
        ),
      ),
    );
    expect(await drafts.list(wallet(owner)), isEmpty);
  });

  test(
    'another wallet cannot read or change the draft, and the error has no prompt',
    () async {
      final saved = await drafts.save(
        owner: wallet(owner),
        document: document(systemPrompt: prompt),
      );

      expect(
        () => drafts.get(owner: wallet(other), draftId: saved.draftId),
        throwsA(isA<StudioDraftNotOwned>()),
      );
      try {
        await drafts.save(
          owner: wallet(other),
          document: document(systemPrompt: 'intruder'),
          draftId: saved.draftId,
          revision: 1,
        );
        fail('expected StudioDraftNotOwned');
      } on StudioDraftNotOwned catch (e) {
        expect(e.toString(), isNot(contains(prompt)));
      }

      final still = await drafts.get(
        owner: wallet(owner),
        draftId: saved.draftId,
      );
      expect(still.manifest.systemPrompt, prompt);
      expect(still.revision, 1);
      expect(await drafts.list(wallet(other)), isEmpty);
      expect((await drafts.list(wallet(owner))).single.draftId, saved.draftId);
    },
  );

  test('a missing id is not a foreign draft', () async {
    expect(
      () => drafts.get(owner: wallet(owner), draftId: 4),
      throwsA(isA<StudioDraftMissing>()),
    );
  });

  test('a bad update does not change the stored prompt', () async {
    final saved = await drafts.save(
      owner: wallet(owner),
      document: document(systemPrompt: prompt),
    );
    expect(
      () => drafts.save(
        owner: wallet(owner),
        document: {'name': 'x' * 49},
        draftId: saved.draftId,
        revision: 1,
      ),
      throwsA(isA<InvalidManifest>()),
    );
    final current = await drafts.get(
      owner: wallet(owner),
      draftId: saved.draftId,
    );
    expect(current.revision, 1);
    expect(current.manifest.systemPrompt, prompt);
  });
}
