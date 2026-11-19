import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart'
    show AgentCandidate, RelatedPartyJustification;
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:puls3_server/src/runtime/tool_loop.dart';
import 'package:puls3_server/src/runtime/tool_loop_codec.dart';
import 'package:test/test.dart';

AgentCandidate _candidate(int registryId, {double skillMatch = 1}) =>
    AgentCandidate(
      id: 'agt-$registryId',
      registryId: registryId,
      name: 'Agent <$registryId>',
      skills: const ['research', 'writing'],
      priceStroops: 400 + registryId,
      rating: 4.5,
      paidHireCount: 3,
      skillMatch: skillMatch,
      score: 0.875,
      rank: registryId,
      isRelatedParty: registryId.isEven,
      ownershipKnown: registryId != 3,
    );

/// Anthropic content blocks as the adapter keeps them: thinking first.
final _providerContent = [
  {'type': 'thinking', 'thinking': 'Need sources.', 'signature': 'sig=='},
  {
    'type': 'tool_use',
    'id': 'toolu_1',
    'name': 'search_agents',
    'input': {'query': 'research'},
  },
];

ToolLoopState _state() => ToolLoopState(
  transcript: [
    UserMessage('Write the report about <tags> and émojis 🚀.'),
    AssistantMessage(
      text: 'Searching first.',
      toolCalls: [
        ToolCall(
          id: 'toolu_1',
          name: 'search_agents',
          arguments: {
            'query': 'research',
            'skills': ['a', 'b'],
            'nested': {'n': 1, 'f': 1.5, 'z': null},
          },
        ),
      ],
      providerContent: _providerContent,
    ),
    ToolResultMessage(callId: 'toolu_1', content: '<untrusted_data>x'),
    ToolResultMessage(callId: 'toolu_2', content: '{"e":1}', isError: true),
    AssistantMessage(text: 'Plain turn, no provider content.'),
  ],
  turnsUsed: 2,
  childrenUsed: 1,
  remainingReserveStroops: 600,
  searches: [
    [_candidate(1), _candidate(2, skillMatch: 0.5)],
    [],
    [_candidate(3)],
  ],
);

ChildRequest _request() => ChildRequest(
  parentHireId: 41,
  agentRegistryId: 2,
  agentId: 'agt-2',
  priceStroops: 402,
  task: 'Find sources.',
  justification: 'Cheapest comparable.',
  isRelatedParty: true,
  relatedPartyJustification:
      RelatedPartyJustification.notPricierThanIndependent,
  ranking: [_candidate(1), _candidate(2, skillMatch: 0.5)],
);

Map<String, Object?> _messageJson(ConversationMessage message) =>
    switch (message) {
      UserMessage(:final text) => {'user': text},
      AssistantMessage(:final text, :final toolCalls, :final providerContent) =>
        {
          'assistant': text,
          'calls': [
            for (final c in toolCalls)
              {'id': c.id, 'name': c.name, 'arguments': c.arguments},
          ],
          'provider': providerContent,
        },
      ToolResultMessage(:final callId, :final content, :final isError) => {
        'tool': callId,
        'content': content,
        'isError': isError,
      },
    };

Map<String, Object?> _candidateJson(AgentCandidate c) => {
  'id': c.id,
  'registryId': c.registryId,
  'name': c.name,
  'skills': c.skills,
  'price': c.priceStroops,
  'rating': c.rating,
  'paid': c.paidHireCount,
  'match': c.skillMatch,
  'score': c.score,
  'rank': c.rank,
  'related': c.isRelatedParty,
  'known': c.ownershipKnown,
};

/// A comparable view of [state]: equal views mean an exact round trip.
String _view(ToolLoopState state) => jsonEncode({
  'transcript': [for (final m in state.transcript) _messageJson(m)],
  'turns': state.turnsUsed,
  'children': state.childrenUsed,
  'reserve': state.remainingReserveStroops,
  'searches': [
    for (final s in state.searches) [for (final c in s) _candidateJson(c)],
  ],
});

void main() {
  group('ToolLoopState', () {
    test('round-trips exactly, provider content included', () {
      final state = _state();

      final decoded = decodeToolLoopState(encodeToolLoopState(state));

      expect(_view(decoded), _view(state));
      final assistant = decoded.transcript[1] as AssistantMessage;
      expect(
        jsonEncode(assistant.providerContent),
        jsonEncode(_providerContent),
      );
      expect(
        (decoded.transcript[4] as AssistantMessage).providerContent,
        isNull,
      );
      expect(decoded.searches[0][1].skillMatch, 0.5);
      expect(decoded.searches[0][0].skillMatch, isA<double>());
    });

    test('writes the codec version', () {
      final json = jsonDecode(encodeToolLoopState(_state())) as Map;
      expect(json['v'], toolLoopCodecVersion);
      expect(toolLoopCodecVersion, 1);
    });

    test('refuses another version and malformed JSON', () {
      final json = jsonDecode(encodeToolLoopState(_state())) as Map;
      json['v'] = 2;
      expect(
        () => decodeToolLoopState(jsonEncode(json)),
        throwsFormatException,
      );
      expect(() => decodeToolLoopState('not json'), throwsFormatException);
      expect(() => decodeToolLoopState('[]'), throwsFormatException);
      expect(
        () => decodeToolLoopState(jsonEncode({'v': 1, 'transcript': 3})),
        throwsFormatException,
      );
      expect(
        () => decodeToolLoopState(
          jsonEncode({
            'v': 1,
            'transcript': [
              {'role': 'assistant', 'text': ''},
            ],
            'turnsUsed': 0,
            'childrenUsed': 0,
            'remainingReserveStroops': 0,
            'searches': <Object?>[],
          }),
        ),
        throwsFormatException,
        reason: 'an assistant message needs text or tool calls',
      );
    });
  });

  group('ChildRequest', () {
    test('round-trips with the D10 verdict and the ranking snapshot', () {
      final request = _request();

      final decoded = decodeChildRequest(encodeChildRequest(request));

      expect(decoded.parentHireId, 41);
      expect(decoded.agentRegistryId, 2);
      expect(decoded.agentId, 'agt-2');
      expect(decoded.priceStroops, 402);
      expect(decoded.task, 'Find sources.');
      expect(decoded.justification, 'Cheapest comparable.');
      expect(decoded.isRelatedParty, isTrue);
      expect(
        decoded.relatedPartyJustification,
        RelatedPartyJustification.notPricierThanIndependent,
      );
      expect(
        jsonEncode([for (final c in decoded.ranking) _candidateJson(c)]),
        jsonEncode([for (final c in request.ranking) _candidateJson(c)]),
      );
    });

    test('refuses an unknown verdict or version', () {
      final json = jsonDecode(encodeChildRequest(_request())) as Map;
      expect(json['v'], toolLoopCodecVersion);
      final unknownVerdict = {...json, 'relatedPartyJustification': 'bribed'};
      expect(
        () => decodeChildRequest(jsonEncode(unknownVerdict)),
        throwsFormatException,
      );
      expect(
        () => decodeChildRequest(jsonEncode({...json, 'v': 0})),
        throwsFormatException,
      );
    });
  });
}
