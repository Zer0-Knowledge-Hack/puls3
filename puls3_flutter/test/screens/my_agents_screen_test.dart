import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';
import '../studio/studio_fixtures.dart';

/// S12 (F11) with the demo gateway: no wallet, loading, empty, error and
/// Retry, the grouped rows and their actions, in both viewports.
void main() {
  /// A wallet already connected, so the screen loads at once.
  MockWallet connected() => MockWallet()..switchAccount();

  Future<FakeStudioGateway> pumpMyAgents(
    WidgetTester tester, {
    MockWallet? wallet,
    Iterable<StudioDraft> drafts = const [],
    StudioGatewayException? listError,
    Size size = const Size(1440, 1000),
  }) async {
    final owner = wallet?.address;
    final studio = FakeStudioGateway(
      delay: const Duration(milliseconds: 300),
      seed: [
        if (owner != null)
          for (final draft in drafts) (owner, draft),
      ],
    )..nextListError = listError;
    await pumpApp(
      tester,
      location: '/studio/agents',
      wallet: wallet,
      studioGateway: studio,
      size: size,
    );
    return studio;
  }

  testWidgets('without a wallet it asks to connect one', (tester) async {
    await pumpMyAgents(tester);

    expect(find.text('My agents'), findsWidgets);
    expect(find.byKey(const Key('my-agents-no-wallet')), findsOneWidget);
    // The top bar has its own Connect wallet too.
    expect(find.text('Connect wallet'), findsNWidgets(2));
  });

  testWidgets('loading shows skeleton rows, then the empty state', (
    tester,
  ) async {
    await pumpMyAgents(tester, wallet: connected());

    expect(find.byKey(const Key('my-agents-loading')), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('my-agents-empty')), findsOneWidget);
    expect(find.text('No agents yet'), findsOneWidget);

    await tester.tap(find.text('Create your first agent'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(find.text('Agent Studio'), findsOneWidget);
  });

  testWidgets('an error shows Retry, and Retry loads the list', (
    tester,
  ) async {
    await pumpMyAgents(
      tester,
      wallet: connected(),
      drafts: [savedDraft(1)],
      listError: const StudioUnavailable('The server did not answer.'),
    );
    await advance(tester, const Duration(milliseconds: 400));

    expect(find.byKey(const Key('my-agents-error')), findsOneWidget);
    expect(find.text('Could not load your agents'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('my-agents-error')), findsNothing);
    expect(find.byKey(const Key('my-agents-row-1')), findsOneWidget);
  });

  testWidgets('rows are grouped as drafts, deploying or failed, and live', (
    tester,
  ) async {
    await pumpMyAgents(
      tester,
      wallet: connected(),
      drafts: [
        savedDraft(1, name: 'Draft Bot'),
        savedDraft(
          2,
          name: 'Stuck Bot',
          state: DraftDeployState.failed,
          retryFromStep: 6,
        ),
        savedDraft(
          3,
          name: 'Live Bot',
          state: DraftDeployState.live,
          liveVersion: 2,
          agentId: 'agt-001',
        ),
      ],
    );
    await advance(tester, const Duration(milliseconds: 400));

    expect(find.text('DRAFTS'), findsOneWidget);
    expect(find.text('DEPLOYING OR FAILED'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Draft · revision 1'), findsOneWidget);
    expect(find.text('Deploy failed'), findsOneWidget);
    expect(find.text('Resume deploy (step 6)'), findsOneWidget);
    expect(find.text('Live · version 2'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('View opens the agent in the Marketplace', (tester) async {
    await pumpMyAgents(
      tester,
      wallet: connected(),
      drafts: [
        savedDraft(
          3,
          name: 'Ledger Scout',
          state: DraftDeployState.live,
          liveVersion: 1,
          agentId: 'agt-001',
        ),
      ],
    );
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('my-agents-view-3')));
    await advance(tester, const Duration(milliseconds: 400));

    expect(find.text('Monitors Stellar accounts.'), findsWidgets);
  });

  testWidgets('Continue editing opens the draft in the Studio', (
    tester,
  ) async {
    await pumpMyAgents(
      tester,
      wallet: connected(),
      drafts: [savedDraft(1, name: 'Draft Bot')],
    );
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('my-agents-continue-1')));
    await advance(tester, const Duration(milliseconds: 500));

    expect(find.text('Agent Studio'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Draft Bot'), findsOneWidget);
    expect(find.text('Saved · revision 1 (demo)'), findsOneWidget);
    expect(find.text('Ready to deploy'), findsOneWidget);
  });

  testWidgets('Edit on a live agent opens a new version with a banner', (
    tester,
  ) async {
    await pumpMyAgents(
      tester,
      wallet: connected(),
      drafts: [
        savedDraft(
          3,
          name: 'Live Bot',
          state: DraftDeployState.live,
          liveVersion: 2,
        ),
      ],
    );
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('my-agents-edit-3')));
    await advance(tester, const Duration(milliseconds: 500));

    expect(
      find.text(
        'Editing creates version 3. Hirers keep version 2 until you deploy.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Live Bot'), findsOneWidget);
    // A new draft: nothing saved yet.
    expect(find.textContaining('Saved · revision'), findsNothing);
  });

  testWidgets('on a phone the rows and actions fit', (tester) async {
    await pumpMyAgents(
      tester,
      wallet: connected(),
      size: const Size(390, 844),
      drafts: [
        savedDraft(1, name: 'Draft Bot'),
        savedDraft(
          3,
          name: 'Live Bot',
          state: DraftDeployState.live,
          liveVersion: 1,
          agentId: 'agt-001',
        ),
      ],
    );
    await advance(tester, const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Continue editing'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });
}
