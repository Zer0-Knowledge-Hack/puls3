import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart' as api;
import 'package:puls3_flutter/src/screens/playground.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/server_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/atoms/primary_button.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';
import '../studio/studio_fixtures.dart';

/// The real server adapter with its network seams replaced, so the widget
/// runs the same mapping a live server uses.
ServerStudioGateway serverGateway({
  SaveProviderCredentialCall? saveProviderCredential,
  TestRunCall? testRun,
}) => ServerStudioGateway(
  saveDraft: (draft, draftId, revision, overwrite) async =>
      throw UnimplementedError(),
  getDraft: (_) async => throw UnimplementedError(),
  listDrafts: () async => const [],
  testRun:
      testRun ??
      ((draftId, input) async =>
          api.TestRunResult(output: 'ok', remainingDailyRuns: 19)),
  saveProviderCredential:
      saveProviderCredential ?? ((provider, secret, accountId) async {}),
  wallet: MockWallet(),
);

/// S11 states (F9) with the demo gateway: empty, over the limit, running,
/// success, failure and Try again, and the daily quota.
void main() {
  late FakeStudioGateway studio;
  late StudioDraft draft;

  Future<void> pumpPlayground(WidgetTester tester, {int dailyRuns = 10}) async {
    Puls3Fonts.useGoogleFonts = false;
    draft = savedDraft(1);
    studio = FakeStudioGateway(
      delay: const Duration(milliseconds: 300),
      dailyRuns: dailyRuns,
      seed: [(testOwner, draft)],
    );
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Playground(draft: draft, gateway: studio, owner: testOwner),
          ),
        ),
      ),
    );
  }

  Future<void> pumpLive(WidgetTester tester, StudioGateway gateway) async {
    Puls3Fonts.useGoogleFonts = false;
    draft = savedDraft(1);
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Playground(draft: draft, gateway: gateway, owner: testOwner),
          ),
        ),
      ),
    );
  }

  PrimaryButton run(WidgetTester tester) =>
      tester.widget<PrimaryButton>(find.byKey(const Key('playground-run')));

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('playground-input')), text);
    await tester.pump();
  }

  Future<void> tapRun(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('playground-run')));
    await tester.pump();
  }

  testWidgets('empty: Run is disabled and the counter shows the limit', (
    tester,
  ) async {
    await pumpPlayground(tester);

    expect(run(tester).onPressed, isNull);
    expect(find.text('0 / 100'), findsOneWidget);
    expect(
      find.text('Demo test runner: no model answers yet.'),
      findsOneWidget,
    );
  });

  testWidgets('over the input limit: inline error and Run disabled', (
    tester,
  ) async {
    await pumpPlayground(tester);
    await type(tester, 'x' * 101);

    expect(
      find.text('This agent accepts up to 100 characters.'),
      findsOneWidget,
    );
    expect(run(tester).onPressed, isNull);
  });

  testWidgets('running, then the labelled answer with the runs left', (
    tester,
  ) async {
    await pumpPlayground(tester);
    await type(tester, 'Summarize the Stellar whitepaper.');
    await tapRun(tester);

    expect(find.byKey(const Key('playground-running')), findsOneWidget);
    expect(run(tester).onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Test run: not paid, nothing on chain'), findsOneWidget);
    expect(find.textContaining('Demo run: Brief Bot'), findsOneWidget);
    expect(find.text('9 runs left today'), findsOneWidget);
    expect(find.byKey(const Key('playground-copy')), findsOneWidget);
  });

  testWidgets('a failed run shows the reason and Try again recovers', (
    tester,
  ) async {
    await pumpPlayground(tester);
    studio.nextRunError = const StudioRunFailed(
      'The agent stopped at the runtime timeout.',
    );
    await type(tester, 'hello');
    await tapRun(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('playground-error')), findsOneWidget);
    expect(
      find.text('The agent stopped at the runtime timeout.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('playground-error')), findsNothing);
    expect(find.byKey(const Key('playground-result')), findsOneWidget);
  });

  testWidgets('an unavailable runner says so', (tester) async {
    await pumpPlayground(tester);
    studio.nextRunError = const StudioUnavailable('timeout');
    await type(tester, 'hello');
    await tapRun(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('The test runner is unavailable.'), findsOneWidget);
  });

  testWidgets('the daily quota disables Run', (tester) async {
    await pumpPlayground(tester, dailyRuns: 1);
    await type(tester, 'hello');
    await tapRun(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0 runs left today'), findsOneWidget);

    await tapRun(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('playground-quota')), findsOneWidget);
    expect(find.text('You used today\'s test runs.'), findsOneWidget);
    expect(run(tester).onPressed, isNull);
  });

  testWidgets('a live runner asks for the provider account before it runs', (
    tester,
  ) async {
    Puls3Fonts.useGoogleFonts = false;
    final studio = _LiveGateway(seed: [(testOwner, savedDraft(1))]);
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Playground(
              draft: savedDraft(1),
              gateway: studio,
              owner: testOwner,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('playground-input')), 'hello');
    await tester.pump();
    expect(run(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('playground-credential')),
      'builder-token',
    );
    await tester.enterText(
      find.byKey(const Key('playground-account')),
      'builder-account',
    );
    await tester.pump();
    expect(run(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('playground-run')));
    await tester.pump();
    expect(studio.provider, 'workers-ai');
    expect(studio.secret, 'builder-token');
    expect(studio.accountId, 'builder-account');
    expect(find.byKey(const Key('playground-result')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('playground-result')),
        matching: find.textContaining('builder-token'),
      ),
      findsNothing,
    );
  });

  testWidgets('a live server run asks for a credential before it starts', (
    tester,
  ) async {
    await pumpLive(tester, serverGateway());
    await type(tester, 'hello');

    expect(find.byKey(const Key('playground-credential')), findsOneWidget);
    expect(
      find.text('Save your provider credential, then run the draft again.'),
      findsOneWidget,
    );
    expect(run(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('playground-credential')),
      'builder-token',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('playground-credential-missing')),
      findsNothing,
    );
    // Workers AI also needs the account id.
    expect(run(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('playground-account')),
      'builder-account',
    );
    await tester.pump();
    expect(run(tester).onPressed, isNotNull);
  });

  testWidgets('a live server run saves the credential and shows the answer', (
    tester,
  ) async {
    String? provider;
    String? secret;
    String? accountId;
    String? sentInput;
    int? sentDraft;
    final gateway = serverGateway(
      saveProviderCredential: (nextProvider, nextSecret, nextAccount) async {
        provider = nextProvider;
        secret = nextSecret;
        accountId = nextAccount;
      },
      testRun: (draftId, input) async {
        sentDraft = draftId;
        sentInput = input;
        return api.TestRunResult(
          output: 'five bullets',
          remainingDailyRuns: 19,
        );
      },
    );
    await pumpLive(tester, gateway);
    await type(tester, 'A long note.');
    await tester.enterText(
      find.byKey(const Key('playground-credential')),
      'builder-token',
    );
    await tester.enterText(
      find.byKey(const Key('playground-account')),
      'builder-account',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('playground-run')));
    await tester.pump();
    await tester.pump();

    expect(provider, 'workers-ai');
    expect(secret, 'builder-token');
    expect(accountId, 'builder-account');
    expect(sentDraft, 1);
    expect(sentInput, 'A long note.');
    expect(find.byKey(const Key('playground-result')), findsOneWidget);
    expect(find.text('five bullets'), findsOneWidget);
    expect(find.text('19 runs left today'), findsOneWidget);
    expect(find.textContaining('Demo run'), findsNothing);
  });

  testWidgets('a missing server credential stays on screen', (tester) async {
    await pumpLive(
      tester,
      serverGateway(
        testRun: (draftId, input) async =>
            throw api.Puls3ApiException(code: 'RuntimeUnavailable'),
      ),
    );
    await type(tester, 'hello');
    await tester.enterText(
      find.byKey(const Key('playground-credential')),
      'builder-token',
    );
    await tester.enterText(
      find.byKey(const Key('playground-account')),
      'builder-account',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('playground-run')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('playground-error')), findsOneWidget);
    expect(
      find.text('Save your provider credential, then run the draft again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('playground-credential')), findsOneWidget);
    expect(find.byKey(const Key('playground-input')), findsOneWidget);
  });

  testWidgets('the server quota stays on screen and disables Run', (
    tester,
  ) async {
    await pumpLive(
      tester,
      serverGateway(
        testRun: (draftId, input) async => throw api.Puls3ApiException(
          code: 'TestQuotaExceeded',
          details: {'resetsAt': '2026-11-06T00:00:00.000Z'},
        ),
      ),
    );
    await type(tester, 'hello');
    await tester.enterText(
      find.byKey(const Key('playground-credential')),
      'builder-token',
    );
    await tester.enterText(
      find.byKey(const Key('playground-account')),
      'builder-account',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('playground-run')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('playground-quota')), findsOneWidget);

    expect(find.textContaining('You used today\'s test runs'), findsOneWidget);
    expect(run(tester).onPressed, isNull);
  });
}

final class _LiveGateway extends FakeStudioGateway {
  _LiveGateway({required super.seed}) : super(delay: Duration.zero);

  String? provider;
  String? secret;
  String? accountId;

  @override
  bool get isDemo => false;

  @override
  Future<void> saveProviderCredential({
    required String provider,
    required String secret,
    String? accountId,
    required String owner,
  }) async {
    this.provider = provider;
    this.secret = secret;
    this.accountId = accountId;
  }

  @override
  Future<TestRunResult> testRun(
    int draftId,
    String input, {
    required String owner,
  }) async => TestRunResult(output: 'five bullets', remainingDailyRuns: 19);
}
