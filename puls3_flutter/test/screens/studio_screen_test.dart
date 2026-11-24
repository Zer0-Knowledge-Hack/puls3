import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_domain/puls3_domain.dart'
    show AgentManifestDraft, ManifestProblem, ModelId, SubcontractOptIn;
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/ui/atoms/primary_button.dart';
import 'package:puls3_flutter/src/ui/molecules/agent_card.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';
import '../studio/studio_fixtures.dart';

Finder _field(String key) => find.byKey(Key(key));

PrimaryButton _deployButton(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_field('studio-deploy'));

PrimaryButton _button(WidgetTester tester, String key) =>
    tester.widget<PrimaryButton>(_field(key));

/// A wallet already connected, so drafts can be saved at once.
MockWallet _connected() => MockWallet()..switchAccount();

FakeStudioGateway _studio({Iterable<(String, StudioDraft)> seed = const []}) =>
    FakeStudioGateway(delay: const Duration(milliseconds: 300), seed: seed);

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_field(key));
  await tester.enterText(_field(key), text);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pump();
  await tester.tap(find.text(text).last);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Fills the four fields a first-time builder sees; Advanced keeps its
/// defaults.
Future<void> _fillValid(WidgetTester tester) async {
  await _type(tester, 'agent-name-field', 'Brief Bot');
  await _type(
    tester,
    'agent-brief-field',
    'Summarizes long text into a short brief.',
  );
  await _tapText(tester, '+ Summaries');
  await _type(tester, 'agent-price-field', '0.10');
}

Future<void> _openAdvanced(WidgetTester tester) async {
  await tester.ensureVisible(_field('agent-advanced-toggle'));
  await tester.tap(_field('agent-advanced-toggle'));
  await tester.pump();
}

void main() {
  testWidgets('an empty Studio keeps Deploy disabled and shows no errors '
      'until a field is edited', (tester) async {
    await pumpApp(tester, location: '/studio');

    expect(find.text('Agent Studio'), findsOneWidget);
    expect(find.text('MARKETPLACE PREVIEW'), findsOneWidget);
    expect(_deployButton(tester).onPressed, isNull);
    expect(find.text('Give your agent a name.'), findsNothing);
    expect(find.text('4 fields to complete'), findsOneWidget);
  });

  testWidgets('invalid fields show the domain errors', (tester) async {
    await pumpApp(tester, location: '/studio');

    await _type(tester, 'agent-name-field', 'AB');
    expect(find.text('The name is too short.'), findsOneWidget);

    await _type(tester, 'agent-brief-field', 'Too short');
    expect(find.text('The description is too short.'), findsOneWidget);

    await _type(tester, 'agent-price-field', '0');
    expect(find.text('The price must be more than 0.'), findsOneWidget);

    await _openAdvanced(tester);
    await _type(tester, 'agent-prompt-field', 'Too short');
    expect(find.text('The instructions are too short.'), findsOneWidget);

    await _type(tester, 'agent-input-max-field', '99999');
    expect(
      find.text('The input limit is above what agents accept.'),
      findsOneWidget,
    );
    expect(_deployButton(tester).onPressed, isNull);
  });

  testWidgets('"What is missing?" reveals every remaining problem', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');
    await _tapText(tester, 'What is missing?');

    expect(find.text('Give your agent a name.'), findsOneWidget);
    expect(find.text('Say what the agent does.'), findsOneWidget);
    expect(find.text('Add at least one category.'), findsOneWidget);
    expect(find.text('Set a price.'), findsOneWidget);
  });

  testWidgets('a valid manifest enables Deploy; the preview is the '
      'Marketplace AgentCard', (tester) async {
    await pumpApp(tester, location: '/studio');
    await _fillValid(tester);

    expect(find.text('Ready to deploy'), findsOneWidget);
    expect(_deployButton(tester).onPressed, isNotNull);

    final card = tester.widget<AgentCard>(_field('studio-preview-card'));
    expect(card.name, 'Brief Bot');
    expect(card.topSkill, 'Summaries');
    expect(card.priceUsdcStroops, 1000000);
    // A new agent has no reviews: no invented rating.
    expect(card.rating, 0.0);
  });

  testWidgets('the four fields alone enable Deploy; Advanced stays closed', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');
    await _fillValid(tester);

    expect(_field('agent-description-field'), findsNothing);
    expect(find.text('Ready to deploy'), findsOneWidget);
    expect(_deployButton(tester).onPressed, isNotNull);
  });

  testWidgets('Advanced generates the description and prompt from the brief '
      'and keeps the documented defaults', (tester) async {
    await pumpApp(tester, location: '/studio');
    await _type(tester, 'agent-name-field', 'Brief Bot');
    await _type(
      tester,
      'agent-brief-field',
      'Summarizes long text into a short brief.',
    );
    await _openAdvanced(tester);

    String text(String key) =>
        tester.widget<TextField>(_field(key)).controller!.text;

    expect(
      text('agent-description-field'),
      'Summarizes long text into a short brief.',
    );
    expect(text('agent-prompt-field'), contains('You are Brief Bot'));
    expect(
      text('agent-prompt-field'),
      contains('Summarizes long text into a short brief.'),
    );
    expect(text('agent-input-max-field'), '8000');
    expect(text('agent-output-max-field'), '2000');
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.text('Llama 3.3 70B · free'), findsOneWidget);

    // The prompt follows the name until the builder edits it.
    await _type(tester, 'agent-name-field', 'Brief Bot Pro');
    expect(text('agent-prompt-field'), contains('Brief Bot Pro'));
  });

  testWidgets('editing the generated description stops following the brief', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');
    await _type(tester, 'agent-brief-field', 'First brief for the agent.');
    await _openAdvanced(tester);
    await _type(
      tester,
      'agent-description-field',
      'A custom public description.',
    );
    await _type(tester, 'agent-brief-field', 'Second brief for the agent.');

    String text(String key) =>
        tester.widget<TextField>(_field(key)).controller!.text;

    expect(text('agent-description-field'), 'A custom public description.');
    expect(text('agent-prompt-field'), contains('Second brief for the agent.'));
  });

  testWidgets('Studio lays out on a phone without overflow', (tester) async {
    await pumpApp(tester, location: '/studio', size: const Size(390, 844));
    expect(find.text('Agent Studio'), findsOneWidget);
    await _tapText(tester, 'What is missing?');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deploy runs the staged flow and ends as a labelled demo', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');
    await _fillValid(tester);

    await _tapText(tester, 'Deploy to Stellar');
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.text('Deploy agent'), findsOneWidget);
    expect(find.byKey(const ValueKey('deploy-demo-banner')), findsOneWidget);

    // Demo gateway and mock wallet: about 4 s from tap to the end.
    await advance(tester, const Duration(milliseconds: 4500));
    expect(find.text('Demo deploy only'), findsOneWidget);
    expect(find.textContaining('live on Stellar'), findsNothing);

    await tester.tap(find.text('Back to Studio'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(find.text('Deploy agent'), findsNothing);
    expect(find.text('Agent Studio'), findsOneWidget);
  });

  testWidgets('A rejected signature can be tried again from the sheet', (
    tester,
  ) async {
    final wallet = MockWallet()..rejectSignatures = true;
    await pumpApp(tester, location: '/studio', wallet: wallet);
    await _fillValid(tester);

    await _tapText(tester, 'Deploy to Stellar');
    await advance(tester, const Duration(milliseconds: 2500));
    expect(find.text('Signature rejected'), findsOneWidget);

    wallet.rejectSignatures = false;
    await tester.tap(find.text('Try again'));
    await advance(tester, const Duration(milliseconds: 3500));
    expect(find.text('Demo deploy only'), findsOneWidget);
  });

  group('drafts and test runs (F8, F9)', () {
    testWidgets('without a wallet, Save draft asks to connect one', (
      tester,
    ) async {
      await pumpApp(tester, location: '/studio', studioGateway: _studio());
      await _fillValid(tester);

      expect(
        find.text('Connect your wallet to save drafts and test runs.'),
        findsOneWidget,
      );
      await _tapText(tester, 'Save draft');
      await advance(tester, const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('wallet-state-disconnected')),
        findsOneWidget,
      );

      // Connecting, then closing the sheet, continues the same save.
      await tester.tap(find.text('Connect Demo wallet'));
      await advance(tester, const Duration(milliseconds: 700));
      await tester.tapAt(const Offset(20, 20));
      await advance(tester, const Duration(milliseconds: 800));
      expect(find.text('Saved · revision 1 (demo)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Brief Bot'), findsOneWidget);
    });

    testWidgets('Save draft shows the revision, then unsaved changes', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: '/studio',
        wallet: _connected(),
        studioGateway: _studio(),
      );
      await _fillValid(tester);

      await _tapText(tester, 'Save draft');
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Saved · revision 1 (demo)'), findsOneWidget);

      await _type(tester, 'agent-name-field', 'Brief Bot Pro');
      expect(find.text('Unsaved changes · revision 1'), findsOneWidget);

      await _tapText(tester, 'Save draft');
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Saved · revision 2 (demo)'), findsOneWidget);
    });

    testWidgets('a server that does not answer keeps the text', (
      tester,
    ) async {
      final studio = _studio()
        ..nextSaveError = const StudioUnavailable('no answer');
      await pumpApp(
        tester,
        location: '/studio',
        wallet: _connected(),
        studioGateway: studio,
      );
      await _fillValid(tester);

      await _tapText(tester, 'Save draft');
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Not saved: no answer'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Brief Bot'), findsOneWidget);
    });

    testWidgets('server problems show under their field until it is edited', (
      tester,
    ) async {
      final studio = _studio()
        ..nextSaveError = const StudioInvalidDraft([
          ManifestProblem.modelProviderNotEnabled,
        ]);
      await pumpApp(
        tester,
        location: '/studio',
        wallet: _connected(),
        studioGateway: studio,
      );
      await _fillValid(tester);

      await _tapText(tester, 'Save draft');
      await advance(tester, const Duration(milliseconds: 400));
      expect(
        find.text('The server refused the agent: check the fields.'),
        findsOneWidget,
      );
      expect(find.text('This provider is not enabled yet.'), findsOneWidget);
      expect(find.text('Saved · revision 1 (demo)'), findsNothing);
    });

    testWidgets('a newer revision saved elsewhere offers Reload or Keep mine', (
      tester,
    ) async {
      final wallet = _connected();
      final studio = _studio(seed: [(wallet.address!, savedDraft(1))]);
      await pumpApp(
        tester,
        location: '/studio?draft=1',
        wallet: wallet,
        studioGateway: studio,
      );
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Saved · revision 1 (demo)'), findsOneWidget);

      // Another tab saves revision 2.
      await tester.runAsync(
        () => studio.saveDraft(
          validManifest(name: 'Other Tab'),
          owner: wallet.address!,
          draftId: 1,
          revision: 1,
        ),
      );
      await _type(tester, 'agent-name-field', 'This Tab');
      await _tapText(tester, 'Save draft');
      await advance(tester, const Duration(milliseconds: 400));
      expect(
        find.text('This draft was saved somewhere else since you opened it.'),
        findsOneWidget,
      );

      await _tapText(tester, 'Keep mine');
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Saved · revision 3 (demo)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'This Tab'), findsOneWidget);
    });

    testWidgets('Test run stays disabled until the manifest is valid', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: '/studio',
        wallet: _connected(),
        studioGateway: _studio(),
      );
      expect(_button(tester, 'studio-test-run').onPressed, isNull);

      await _fillValid(tester);
      expect(_button(tester, 'studio-test-run').onPressed, isNotNull);
    });

    testWidgets('Test run saves the draft and opens the playground beside '
        'the preview', (tester) async {
      await pumpApp(
        tester,
        location: '/studio',
        wallet: _connected(),
        studioGateway: _studio(),
      );
      await _fillValid(tester);

      await _tapText(tester, 'Test run');
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Saved · revision 1 (demo)'), findsOneWidget);
      expect(find.byKey(const Key('playground-panel')), findsOneWidget);

      await tester.ensureVisible(_field('playground-input'));
      await tester.enterText(_field('playground-input'), 'A long article.');
      await tester.pump();
      await tester.tap(_field('playground-run'));
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Test run: not paid, nothing on chain'), findsOneWidget);
      expect(find.text('9 runs left today'), findsOneWidget);
    });

    testWidgets('on a phone the playground opens as a sheet', (tester) async {
      await pumpApp(
        tester,
        location: '/studio',
        wallet: _connected(),
        studioGateway: _studio(),
        size: const Size(390, 844),
      );
      await _fillValid(tester);

      await _tapText(tester, 'Test run');
      await advance(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const Key('playground-panel')), findsOneWidget);
      expect(find.byKey(const Key('playground-close')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Above the bottom navigation bar: Run is reachable.
      await tester.enterText(_field('playground-input'), 'A short task.');
      await tester.pump();
      await tester.ensureVisible(_field('playground-run'));
      await tester.tap(_field('playground-run'));
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Test run: not paid, nothing on chain'), findsOneWidget);

      await tester.tap(_field('playground-close'));
      await advance(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('playground-panel')), findsNothing);
    });

    testWidgets('a deploy from a saved draft lists it in My agents', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: '/studio',
        wallet: _connected(),
        studioGateway: _studio(),
      );
      await _fillValid(tester);

      await _tapText(tester, 'Deploy to Stellar');
      // Saves first, then the demo deploy runs to the end.
      await advance(tester, const Duration(milliseconds: 5000));
      expect(find.text('Demo deploy only'), findsOneWidget);
      await tester.tap(find.text('Back to Studio'));
      await advance(tester, const Duration(milliseconds: 600));

      await _tapText(tester, 'My agents');
      await advance(tester, const Duration(milliseconds: 800));
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Live · version 1'), findsOneWidget);
      // A demo deploy is not in the catalog: nothing to view.
      expect(find.text('View'), findsNothing);
    });
  });

  group('the subcontract opt-in (#334 T7.2)', () {
    Future<void> pickClaude(WidgetTester tester) async {
      await tester.ensureVisible(_field('agent-model-field'));
      await tester.tap(_field('agent-model-field'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Claude Sonnet 5.5').last);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> toggle(WidgetTester tester) async {
      await tester.ensureVisible(_field('agent-subcontract-toggle'));
      await tester.tap(_field('agent-subcontract-toggle'));
      await tester.pump();
    }

    testWidgets('the toggle shows and hides the subcontract inputs', (
      tester,
    ) async {
      await pumpApp(tester, location: '/studio');
      await _fillValid(tester);
      await _openAdvanced(tester);
      await pickClaude(tester);
      expect(_field('agent-subcontract-children-field'), findsNothing);
      expect(_field('agent-subcontract-reserve-field'), findsNothing);

      await toggle(tester);
      expect(_field('agent-subcontract-children-field'), findsOneWidget);
      expect(_field('agent-subcontract-reserve-field'), findsOneWidget);

      await toggle(tester);
      expect(_field('agent-subcontract-children-field'), findsNothing);
      expect(_field('agent-subcontract-reserve-field'), findsNothing);
    });

    testWidgets('a free model disables the toggle with a note', (
      tester,
    ) async {
      await pumpApp(tester, location: '/studio');
      await _openAdvanced(tester);

      final tile = tester.widget<SwitchListTile>(
        _field('agent-subcontract-toggle'),
      );
      expect(tile.onChanged, isNull);
      expect(tile.value, isFalse);
      expect(
        find.text(
          'Subcontracting needs a Claude model: the free model cannot '
          'call tools.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('too many agents shows the error on the subcontract field', (
      tester,
    ) async {
      await pumpApp(tester, location: '/studio');
      await _fillValid(tester);
      await _openAdvanced(tester);
      await pickClaude(tester);
      await toggle(tester);

      await _type(tester, 'agent-subcontract-children-field', '3');
      final children = tester.widget<TextField>(
        _field('agent-subcontract-children-field'),
      );
      expect(children.decoration!.errorText, 'Choose from 1 to 2 agents.');
      final name = tester.widget<TextField>(_field('agent-name-field'));
      expect(name.decoration!.errorText, isNull);
      expect(_deployButton(tester).onPressed, isNull);
    });

    testWidgets('editing a saved agent keeps its opt-in', (tester) async {
      final wallet = _connected();
      final base = validManifest();
      final manifest = AgentManifestDraft(
        name: base.name,
        description: base.description,
        skills: base.skills,
        model: ModelId(provider: 'anthropic', id: 'claude-sonnet-5-5'),
        systemPrompt: base.systemPrompt,
        inputType: base.inputType,
        inputMaxChars: base.inputMaxChars,
        outputType: base.outputType,
        outputMaxChars: base.outputMaxChars,
        price: base.price,
        subcontract: SubcontractOptIn(
          maxChildren: 2,
          suggestedReserve: 5000000,
        ),
      );
      final studio = _studio(
        seed: [
          (
            wallet.address!,
            StudioDraft(
              draftId: 1,
              manifest: manifest,
              revision: 1,
              deployState: DraftDeployState.draft,
            ),
          ),
        ],
      );
      await pumpApp(
        tester,
        location: '/studio?draft=1',
        wallet: wallet,
        studioGateway: studio,
      );
      await advance(tester, const Duration(milliseconds: 400));
      await _openAdvanced(tester);

      expect(
        tester.widget<SwitchListTile>(_field('agent-subcontract-toggle')).value,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(_field('agent-subcontract-children-field'))
            .controller!
            .text,
        '2',
      );
      expect(
        tester
            .widget<TextField>(_field('agent-subcontract-reserve-field'))
            .controller!
            .text,
        '0.50',
      );

      await _type(tester, 'agent-name-field', 'Brief Bot Two');
      await _tapText(tester, 'Save draft');
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Saved · revision 2 (demo)'), findsOneWidget);
      final saved = await tester.runAsync(
        () => studio.getDraft(1, owner: wallet.address!),
      );
      expect(
        saved!.manifest.subcontract,
        SubcontractOptIn(maxChildren: 2, suggestedReserve: 5000000),
      );
    });
  });
}
