import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/screens/playground.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/atoms/primary_button.dart';

import '../studio/studio_fixtures.dart';

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
      MaterialApp(
        theme: Puls3Theme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Playground(draft: draft, gateway: studio, owner: testOwner),
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
      MaterialApp(
        theme: Puls3Theme.dark(),
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
