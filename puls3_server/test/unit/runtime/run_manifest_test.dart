import 'dart:convert';

import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/runtime/demo_manifests.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:test/test.dart';

import '../hire/hire_test_fakes.dart';

const _manifest = RunManifest(
  provider: 'anthropic',
  modelId: 'claude-opus-5-5',
  systemPrompt: 'You triage one customer message.',
  inputMaxChars: 4000,
  outputMaxChars: 4000,
);

/// The `id` metadata of every agent of the demo seed,
/// `contracts/deployments/demo-agents.json`.
const _demoSeedAgentIds = [
  'agt-001',
  'agt-002',
  'agt-003',
  'agt-004',
  'agt-005',
  'agt-006',
  'agt-007',
  'agt-008',
];

void main() {
  late FakeLedger registry;
  late SeededRunManifestSource source;

  setUp(() {
    registry = FakeLedger();
    source = SeededRunManifestSource(
      registry: registry,
      manifests: {
        'agt-007': {1: _manifest},
      },
    );
  });

  test(
    'finds the manifest by the agent id metadata, not the registry id',
    () async {
      registry.metadata[13] = {'id': utf8.encode('agt-007')};

      expect(await source.find(13, 1), same(_manifest));
    },
  );

  test(
    'an unknown version, agent or missing id metadata has no manifest',
    () async {
      registry.metadata[13] = {'id': utf8.encode('agt-007')};
      registry.metadata[14] = {'id': utf8.encode('agt-999')};
      registry.metadata[15] = {};

      expect(await source.find(13, 2), isNull);
      expect(await source.find(14, 1), isNull);
      expect(await source.find(15, 1), isNull);
    },
  );

  test('an unreadable registry throws, so the run can be retried', () {
    registry.metadataError = const LedgerUnavailable('rpc down');

    expect(source.find(13, 1), throwsA(isA<LedgerUnavailable>()));
  });

  test('the task carries the manifest fields and the hire input', () {
    final task = _manifest.task('Where is my refund?');

    expect(task.provider, 'anthropic');
    expect(task.modelId, 'claude-opus-5-5');
    expect(task.systemPrompt, 'You triage one customer message.');
    expect(task.input, 'Where is my refund?');
    expect(task.maxInputChars, 4000);
    expect(task.maxOutputChars, 4000);
  });

  group('demo manifests', () {
    test('seed every demo agent at version 1', () {
      expect(demoManifests.length, _demoSeedAgentIds.length);
      for (final MapEntry(key: id, value: versions) in demoManifests.entries) {
        expect(versions.keys, contains(1), reason: id);
      }
    });

    test('follow the ADR-0004 field rules', () {
      for (final versions in demoManifests.values) {
        for (final manifest in versions.values) {
          // The same rules the domain draft validation enforces (#34).
          // The free provider of the #34 model policy.
          expect(manifest.provider, 'workers-ai');
          expect(manifest.modelId, demoWorkersAiModel);
          expect(manifest.modelId, isNotEmpty);
          expect(manifest.modelId, isNot(contains(' ')));
          expect(
            manifest.systemPrompt.runes.length,
            inInclusiveRange(20, 8000),
          );
          expect(manifest.inputMaxChars, inInclusiveRange(1, 8000));
          expect(manifest.outputMaxChars, inInclusiveRange(1, 16000));
        }
      }
    });

    test('cover every agent of the demo seed, so no paid hire fails', () {
      // A hire of an agent with no manifest fails with `manifest_unavailable`
      // and leaves the USDC in the escrow until its deadline (#20).
      expect(demoManifests.keys, containsAll(_demoSeedAgentIds));
    });

    test('the agents that would need chain data work only on pasted data', () {
      // `docs/spikes/agent-definition.md`: the runtime has no tools, so these
      // three take the data as input text and never invent it.
      for (final id in ['agt-001', 'agt-002', 'agt-005']) {
        final prompt = demoManifests[id]![1]!.systemPrompt;

        expect(prompt, contains('the user pastes'), reason: id);
        expect(prompt, contains('Never invent'), reason: id);
      }
    });
  });
}
