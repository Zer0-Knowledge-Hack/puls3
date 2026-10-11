import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_models.dart';

import 'studio_fixtures.dart';

void main() {
  FakeStudioGateway gateway({int dailyRuns = 10}) => FakeStudioGateway(
    delay: Duration.zero,
    dailyRuns: dailyRuns,
    policy: studioModelPolicy,
  );

  test('saving creates a draft, then new revisions of it', () async {
    final studio = gateway();
    final first = await studio.saveDraft(validManifest(), owner: testOwner);
    expect(first.revision, 1);
    expect(first.deployState, DraftDeployState.draft);

    final second = await studio.saveDraft(
      validManifest(name: 'Brief Bot Two'),
      owner: testOwner,
      draftId: first.draftId,
      revision: 1,
    );
    expect(second.draftId, first.draftId);
    expect(second.revision, 2);
    expect(
      (await studio.listDrafts(owner: testOwner)).single.name,
      'Brief Bot Two',
    );
  });

  test(
    'a stale revision is a conflict unless the builder keeps theirs',
    () async {
      final studio = gateway();
      final draft = await studio.saveDraft(validManifest(), owner: testOwner);
      await studio.saveDraft(
        validManifest(),
        owner: testOwner,
        draftId: draft.draftId,
        revision: 1,
      );

      expect(
        () => studio.saveDraft(
          validManifest(),
          owner: testOwner,
          draftId: draft.draftId,
          revision: 1,
        ),
        throwsA(isA<StudioDraftConflict>()),
      );
      final kept = await studio.saveDraft(
        validManifest(),
        owner: testOwner,
        draftId: draft.draftId,
        revision: 1,
        overwrite: true,
      );
      expect(kept.revision, 3);
    },
  );

  test('drafts belong to the wallet that saved them', () async {
    final studio = gateway();
    final draft = await studio.saveDraft(validManifest(), owner: testOwner);

    expect(await studio.listDrafts(owner: 'GOTHER'), isEmpty);
    expect(
      () => studio.getDraft(draft.draftId, owner: 'GOTHER'),
      throwsA(isA<StudioDraftNotFound>()),
    );
    expect(
      () => studio.testRun(draft.draftId, 'hello', owner: 'GOTHER'),
      throwsA(isA<StudioDraftNotFound>()),
    );
  });

  test(
    'test runs count down the daily quota and check the input limit',
    () async {
      final studio = gateway(dailyRuns: 2);
      final draft = await studio.saveDraft(validManifest(), owner: testOwner);

      expect(
        () => studio.testRun(draft.draftId, 'x' * 101, owner: testOwner),
        throwsA(isA<StudioInputTooLong>()),
      );
      final run = await studio.testRun(
        draft.draftId,
        'hello',
        owner: testOwner,
      );
      expect(run.remainingDailyRuns, 1);
      expect(run.output, contains('Brief Bot'));
      await studio.testRun(draft.draftId, 'hello', owner: testOwner);
      expect(
        () => studio.testRun(draft.draftId, 'hello', owner: testOwner),
        throwsA(isA<StudioTestQuotaExceeded>()),
      );
    },
  );

  test(
    'recording a live deploy sets the version and keeps the draft',
    () async {
      final studio = gateway();
      final draft = await studio.saveDraft(validManifest(), owner: testOwner);
      await studio.recordDeploy(
        draft.draftId,
        owner: testOwner,
        state: DraftDeployState.live,
        agentId: '42',
      );

      final live = await studio.getDraft(draft.draftId, owner: testOwner);
      expect(live.deployState, DraftDeployState.live);
      expect(live.liveVersion, 1);
      expect(live.agentId, '42');
    },
  );
}
