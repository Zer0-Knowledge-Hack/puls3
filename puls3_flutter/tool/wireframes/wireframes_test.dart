/// Renders the wireframes in docs/blueprints/wireframes (#23).
///
/// Not part of `flutter test` (it lives outside test/). Regenerate with:
///
///     cd puls3_flutter
///     flutter test tool/wireframes/wireframes_test.dart --update-goldens
///
/// Text uses Roboto and the Material icons from the Flutter SDK (and the
/// app's Doto accent), not the final brand fonts of #24: the PNGs are low
/// to mid fidelity wireframes with readable labels.
/// Screens that exist render the real widgets with fake data; S05, S06 and
/// S10 are not built yet and are drawn from the same components, after
/// flows F6 and F7 (docs/blueprints/flows.md).
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/domain/stellar_format.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/atoms/address_badge.dart';
import 'package:puls3_flutter/src/ui/atoms/content_width.dart';
import 'package:puls3_flutter/src/ui/atoms/price_tag.dart';
import 'package:puls3_flutter/src/ui/atoms/primary_button.dart';
import 'package:puls3_flutter/src/ui/atoms/section_label.dart';
import 'package:puls3_flutter/src/ui/atoms/skill_chip.dart';
import 'package:puls3_flutter/src/ui/molecules/empty_state.dart';
import 'package:puls3_flutter/src/ui/molecules/key_value_row.dart';
import 'package:puls3_flutter/src/ui/molecules/progress_step_row.dart';
import 'package:puls3_flutter/src/ui/molecules/screen_header.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../../test/helpers.dart';

/// Loads real fonts so labels read instead of the test font's blocks.
Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk == null) throw StateError('Run with flutter test (FLUTTER_ROOT).');
  final material = '$sdk/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File(file).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  final roboto = [
    '$material/roboto-regular.ttf',
    '$material/roboto-medium.ttf',
    '$material/roboto-bold.ttf',
  ];
  // Puls3Fonts.offlineFamily, used while Google Fonts are off.
  await load('Roboto', roboto);
  await load('MaterialIcons', ['$material/materialicons-regular.otf']);
  await load('Doto', ['assets/fonts/Doto-ROND-wght.ttf']);
}

const _desktop = Size(1440, 1000);
const _mobile = Size(390, 844);
const _viewports = {'1440': _desktop, '390': _mobile};

String _png(String name) => '../../../docs/blueprints/wireframes/$name.png';

Future<void> _shoot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile(_png(name)),
  );
}

/// A repository whose answer the test controls, for the loading and error
/// states.
class _Pending implements AgentRepository {
  final _list = Completer<List<Agent>>();

  @override
  Future<List<Agent>> fetchAgents() => _list.future;

  @override
  Future<Agent?> fetchAgent(String id) => Completer<Agent?>().future;
}

class _Failing implements AgentRepository {
  @override
  Future<List<Agent>> fetchAgents() async => throw StateError('down');

  @override
  Future<Agent?> fetchAgent(String id) async => throw StateError('down');
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pump();
  await tester.tap(find.text(text).first);
  await advance(tester, const Duration(milliseconds: 600));
}

/// Fills the Studio form with a manifest the domain accepts.
Future<void> _fillValidManifest(WidgetTester tester) async {
  Future<void> type(String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  await type('agent-name-field', 'Brief Bot');
  await type(
    'agent-description-field',
    'Summarizes long text into a short brief.',
  );
  await tester.ensureVisible(find.byKey(const Key('agent-model-field')));
  await tester.tap(find.byKey(const Key('agent-model-field')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Llama 3.3 70B · free').last);
  await tester.pump(const Duration(milliseconds: 300));
  await type(
    'agent-prompt-field',
    'You are Brief Bot. Reply with at most five bullet points.',
  );
  await _tap(tester, '+ Summaries');
  await type('agent-input-max-field', '6000');
  await type('agent-output-max-field', '2000');
  await type('agent-price-field', '0.10');
}

/// A screen that is not built yet, drawn from the app's components.
Future<void> _pumpSketch(WidgetTester tester, Size size, Widget body) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Puls3Theme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(child: ContentWidth(child: body)),
      ),
    ),
  );
  await tester.pump();
}

/// S05 `/hires`: the client's hires, newest first (F6-6).
Widget _myHires() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const SizedBox(height: Puls3Spacing.xl),
    const ScreenHeader(
      title: 'My hires',
      subtitle:
          'Your hires, newest first. Funds stay in escrow until you '
          'approve.',
    ),
    const SizedBox(height: Puls3Spacing.lg),
    for (final (agent, status, run) in const [
      ('Soroban Auditor', 'Submitted', 'Result ready'),
      ('Ledger Scout', 'Funded', 'Running'),
      ('Remit Pilot', 'Completed', 'Rated 5'),
      ('Invoice Clerk', 'Cancelled', '—'),
    ])
      Card(
        margin: const EdgeInsets.only(bottom: Puls3Spacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(Puls3Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(agent, style: Puls3Text.title),
              const SizedBox(height: Puls3Spacing.xs),
              Wrap(
                spacing: Puls3Spacing.xs,
                runSpacing: Puls3Spacing.xs,
                children: [
                  SkillChip(label: status, selected: true),
                  SkillChip(label: run),
                  const PriceTag(stroops: 45000000),
                ],
              ),
            ],
          ),
        ),
      ),
    const SizedBox(height: Puls3Spacing.xxl),
  ],
);

/// The S06 states drawn as wireframes.
enum _HireView { submitted, runFailed, completed }

/// S06 `/hires/:id`: status, run progress, result and the decision (F6).
Widget _hireDetail(_HireView view) {
  final (subtitle, steps) = switch (view) {
    _HireView.submitted => (
      'Submitted: review the result before the approval deadline.',
      const [
        ('Funded: price held in escrow', StepStatus.done),
        ('Agent ran the task', StepStatus.done),
        ('Submitted: waiting for your decision', StepStatus.active),
        ('Completed: escrow pays the agent', StepStatus.pending),
      ],
    ),
    _HireView.runFailed => (
      'Funded: the agent run failed. Your USDC is still in escrow.',
      const [
        ('Funded: price held in escrow', StepStatus.done),
        ('Run failed: timed out', StepStatus.failed),
        ('Submitted', StepStatus.pending),
        ('Completed', StepStatus.pending),
      ],
    ),
    _HireView.completed => (
      'Completed: the approval deadline passed and the escrow paid the agent.',
      const [
        ('Funded: price held in escrow', StepStatus.done),
        ('Agent ran the task', StepStatus.done),
        ('Submitted', StepStatus.done),
        ('Completed: released after the deadline', StepStatus.done),
      ],
    ),
  };
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: Puls3Spacing.xl),
      ScreenHeader(title: 'Hire #3 · Soroban Auditor', subtitle: subtitle),
      const SizedBox(height: Puls3Spacing.lg),
      for (final (label, status) in steps)
        ProgressStepRow(label: label, status: status),
      const SizedBox(height: Puls3Spacing.lg),
      if (view != _HireView.runFailed) ...[
        const SectionLabel('Result'),
        const SizedBox(height: Puls3Spacing.sm),
        Container(
          height: 160,
          padding: const EdgeInsets.all(Puls3Spacing.md),
          decoration: BoxDecoration(
            color: Puls3Colors.surface,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          child: Text(
            'The token contract has two findings: an unchecked transfer and '
            'a missing auth check on set_admin.',
            style: Puls3Text.body,
          ),
        ),
        const SizedBox(height: Puls3Spacing.md),
      ],
      const KeyValueRow(label: 'Price', value: '4.50 USDC'),
      KeyValueRow(
        label: view == _HireView.runFailed
            ? 'Failure reason'
            : 'Approval deadline',
        value: switch (view) {
          _HireView.submitted => '23 h left',
          _HireView.runFailed => 'Run timed out',
          _HireView.completed => 'Passed',
        },
      ),
      const KeyValueRow(
        label: 'Payment',
        value: '',
        valueWidget: AddressBadge(
          address: 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
        ),
      ),
      const SizedBox(height: Puls3Spacing.lg),
      ...switch (view) {
        _HireView.submitted => [
          PrimaryButton(
            label: 'Approve',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: () {},
          ),
          const SizedBox(height: Puls3Spacing.sm),
          PrimaryButton(
            label: 'Reject and refund',
            variant: PrimaryButtonVariant.outline,
            expand: true,
            onPressed: () {},
          ),
        ],
        _HireView.runFailed => [
          PrimaryButton(
            label: 'Reject and refund',
            icon: Icons.undo_rounded,
            expand: true,
            onPressed: () {},
          ),
        ],
        // After the deadline Reject is hidden: the escrow refuses it.
        _HireView.completed => [
          PrimaryButton(
            label: 'Rate',
            icon: Icons.star_outline_rounded,
            expand: true,
            onPressed: () {},
          ),
        ],
      },
      const SizedBox(height: Puls3Spacing.xxl),
    ],
  );
}

/// S10: rate a completed hire, score 1 to 5 and an optional comment (F7).
Widget _rateSheet() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const SizedBox(height: Puls3Spacing.xl),
    Text('Rate Soroban Auditor', style: Puls3Text.h3),
    const SizedBox(height: Puls3Spacing.xs),
    Text(
      'Your rating is recorded on Stellar with your wallet.',
      style: Puls3Text.bodyMuted,
    ),
    const SizedBox(height: Puls3Spacing.lg),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= 4 ? Icons.star_rounded : Icons.star_border_rounded,
            size: 40,
            color: Puls3Colors.accent,
          ),
      ],
    ),
    const SizedBox(height: Puls3Spacing.lg),
    const TextField(
      minLines: 3,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: 'Comment (optional)',
        helperText: '0 characters',
      ),
    ),
    const SizedBox(height: Puls3Spacing.lg),
    PrimaryButton(
      label: 'Send rating',
      icon: Icons.send_rounded,
      expand: true,
      onPressed: () {},
    ),
    const SizedBox(height: Puls3Spacing.xxl),
  ],
);

void main() {
  setUpAll(_loadFonts);

  for (final MapEntry(key: width, value: size) in _viewports.entries) {
    group('$width px', () {
      testWidgets('S01-landing', (tester) async {
        await pumpApp(tester, location: '/', size: size);
        await _shoot(tester, 'S01-landing-$width');
      });

      testWidgets('S02-marketplace', (tester) async {
        await pumpApp(tester, location: '/market', size: size);
        await _shoot(tester, 'S02-marketplace-$width');
      });

      testWidgets('S02-marketplace states', (tester) async {
        await pumpApp(
          tester,
          location: '/market',
          size: size,
          repository: _Pending(),
        );
        await _shoot(tester, 'S02-marketplace-loading-$width');

        await pumpApp(
          tester,
          location: '/market',
          size: size,
          repository: _Failing(),
        );
        await _shoot(tester, 'S02-marketplace-error-$width');

        await pumpApp(
          tester,
          location: '/market',
          size: size,
          repository: const InMemoryAgentRepository([]),
        );
        await _shoot(tester, 'S02-marketplace-empty-$width');
      });

      testWidgets('S03-agent-detail', (tester) async {
        await pumpApp(tester, location: '/agent/agt-001', size: size);
        await _shoot(tester, 'S03-agent-detail-$width');
      });

      testWidgets('S03-agent-detail states', (tester) async {
        await pumpApp(
          tester,
          location: '/agent/agt-001',
          size: size,
          repository: _Pending(),
        );
        await _shoot(tester, 'S03-agent-detail-loading-$width');

        await pumpApp(
          tester,
          location: '/agent/agt-001',
          size: size,
          repository: _Failing(),
        );
        await _shoot(tester, 'S03-agent-detail-error-$width');

        await pumpApp(tester, location: '/agent/unknown', size: size);
        await _shoot(tester, 'S03-agent-detail-empty-$width');
      });

      testWidgets('S04-hire-sheet', (tester) async {
        await pumpApp(tester, location: '/agent/agt-001', size: size);
        await _tap(tester, 'Hire');
        await _shoot(tester, 'S04-hire-sheet-$width');
      });

      testWidgets('S05-my-hires', (tester) async {
        await _pumpSketch(tester, size, _myHires());
        await _shoot(tester, 'S05-my-hires-$width');
      });

      testWidgets('S06-hire-detail', (tester) async {
        await _pumpSketch(tester, size, _hireDetail(_HireView.submitted));
        await _shoot(tester, 'S06-hire-detail-$width');
      });

      testWidgets('S06-hire-detail states', (tester) async {
        await _pumpSketch(tester, size, _hireDetail(_HireView.runFailed));
        await _shoot(tester, 'S06-hire-detail-run-failed-$width');

        await _pumpSketch(tester, size, _hireDetail(_HireView.completed));
        await _shoot(tester, 'S06-hire-detail-deadline-passed-$width');
      });

      testWidgets('S07-studio', (tester) async {
        await pumpApp(tester, location: '/studio', size: size);
        await _shoot(tester, 'S07-studio-$width');
      });

      testWidgets('S08-deploy-sheet', (tester) async {
        // A seeded demo wallet: its address shows in the top bar, so the PNG
        // is the same on every run.
        await pumpApp(
          tester,
          location: '/studio',
          size: size,
          wallet: MockWallet(ids: FakeLedgerIds(Random(23))),
        );
        // Deploy opens only for a valid manifest (S07, #37).
        await _fillValidManifest(tester);
        await _tap(tester, 'Deploy to Stellar');
        await advance(tester, const Duration(milliseconds: 1500));
        await _shoot(tester, 'S08-deploy-sheet-$width');
        // Let the demo flow finish so no timer is left pending.
        await advance(tester, const Duration(seconds: 6));
      });

      testWidgets('S09-wallet-connect', (tester) async {
        await pumpApp(tester, location: '/market', size: size);
        await _tap(tester, size.width < 640 ? 'Connect' : 'Connect wallet');
        await _shoot(tester, 'S09-wallet-connect-$width');
      });

      testWidgets('S10-rate-sheet', (tester) async {
        await _pumpSketch(tester, size, _rateSheet());
        await _shoot(tester, 'S10-rate-sheet-$width');
      });
    });
  }

  // Keeps the sketches honest: the empty state they reference exists.
  test('EmptyState is part of the inventory', () {
    expect(
      const EmptyState(icon: Icons.inbox, title: 't', message: 'm'),
      isA<StatelessWidget>(),
    );
  });
}
