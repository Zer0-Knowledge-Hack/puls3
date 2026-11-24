import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart'
    show AgentCandidate, RelatedPartyJustification;
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:puls3_server/src/runtime/tool_loop.dart';
import 'package:test/test.dart';

const _callId = 'call-1';

LoopAwaitingChild _paused(List<ConversationMessage> transcript) =>
    LoopAwaitingChild(
      ToolLoopState(
        transcript: transcript,
        turnsUsed: 2,
        childrenUsed: 1,
        remainingReserveStroops: 0,
        searches: const <List<AgentCandidate>>[],
      ),
      pendingToolCallId: _callId,
      childHireId: 7,
      request: ChildRequest(
        parentHireId: 1,
        agentRegistryId: 2,
        agentId: 'agent-b',
        priceStroops: 100,
        task: 'Translate it',
        justification: 'B translates',
        isRelatedParty: false,
        relatedPartyJustification: RelatedPartyJustification.independent,
        ranking: const [],
      ),
    );

int _length(ToolLoopState state) =>
    state.transcript.fold(0, (sum, message) => sum + message.length);

/// The JSON inside the `<untrusted_data>` envelope of the last tool result.
Map<String, Object?> _payload(ToolLoopState state) {
  final content = (state.transcript.last as ToolResultMessage).content;
  final lines = content.split('\n');
  return jsonDecode(lines.sublist(1, lines.length - 1).join('\n'))
      as Map<String, Object?>;
}

void main() {
  final before = [UserMessage('Write the report')];

  test('a child output that fits is passed whole', () {
    final state = ToolLoop.resumedState(
      _paused(before),
      const ChildDelivered('B found three sources.'),
      maxConversationChars: 10000,
    );

    expect(_payload(state), {'output': 'B found three sources.'});
  });

  test('a child output over the conversation budget is cut to fit, and the '
      'cut is labelled', () {
    // Escaping makes '<' six characters, so 16000 runes of it are far over
    // a budget that the raw text would fit.
    final output = '<' * 16000;
    const budget = 20000;

    final state = ToolLoop.resumedState(
      _paused(before),
      ChildDelivered(output),
      maxConversationChars: budget,
    );

    expect(_length(state), lessThanOrEqualTo(budget));
    final payload = _payload(state);
    expect(payload['truncated'], isTrue);
    expect(payload['output_runes'], 16000);
    final kept = payload['output']! as String;
    expect(kept, isNotEmpty);
    expect(output.startsWith(kept), isTrue);
  });

  test('a cut never splits a rune', () {
    final output = '\u{1F600}' * 5000;

    final state = ToolLoop.resumedState(
      _paused(before),
      ChildDelivered(output),
      maxConversationChars: 3000,
    );

    final kept = _payload(state)['output']! as String;
    expect(kept.runes.every((rune) => rune == 0x1F600), isTrue);
    expect(_length(state), lessThanOrEqualTo(3000));
  });

  test('a failed child is reported unchanged', () {
    final state = ToolLoop.resumedState(
      _paused(before),
      const ChildFailed('child_expired'),
      maxConversationChars: 10,
    );

    final last = state.transcript.last as ToolResultMessage;
    expect(last.isError, isTrue);
    expect(last.content, contains('child_expired'));
  });
}
