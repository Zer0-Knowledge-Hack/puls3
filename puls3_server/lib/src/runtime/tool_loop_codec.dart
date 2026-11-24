import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart'
    show AgentCandidate, RelatedPartyJustification;

import 'conversation.dart';
import 'subcontract_port.dart';
import 'tool_loop.dart';

/// The version written in every stored [ToolLoopState] and [ChildRequest]
/// (`hire_run.loopState`, `hire_run.childRequest`). A reader refuses any
/// other version instead of guessing its shape; a new shape gets a new
/// version and a reader for the old one.
///
/// Size: the transcript is what the loop sends the model, so it is bounded
/// by the manifest's `input.max_chars` plus the loop's headroom
/// ([defaultConversationHeadroomChars]) and one turn's output, plus each
/// Anthropic turn's opaque `providerContent` (about the same text again)
/// and at most [defaultMaxLoopTurns] search snapshots. That is tens of
/// kilobytes, well within a Postgres `text` column.
const toolLoopCodecVersion = 1;

/// [state] as versioned JSON. Each assistant turn's `providerContent` is
/// kept verbatim, since Anthropic requires it back unchanged.
String encodeToolLoopState(ToolLoopState state) => jsonEncode({
  'v': toolLoopCodecVersion,
  'transcript': [for (final message in state.transcript) _message(message)],
  'turnsUsed': state.turnsUsed,
  'childrenUsed': state.childrenUsed,
  'remainingReserveStroops': state.remainingReserveStroops,
  'searches': [
    for (final search in state.searches)
      [for (final candidate in search) _candidate(candidate)],
  ],
});

/// The state [encodeToolLoopState] wrote. Throws [FormatException] for
/// another version or a malformed value.
ToolLoopState decodeToolLoopState(String source) {
  final json = _versioned(source, 'loop state');
  return ToolLoopState(
    transcript: [
      for (final message in _list(json, 'transcript'))
        _readMessage(_asMap(message, 'message')),
    ],
    turnsUsed: _int(json, 'turnsUsed'),
    childrenUsed: _int(json, 'childrenUsed'),
    remainingReserveStroops: _int(json, 'remainingReserveStroops'),
    searches: [
      for (final search in _list(json, 'searches'))
        _readRanking(_asList(search, 'search')),
    ],
  );
}

/// [request] as versioned JSON: the D10 verdict by name and the ranking
/// snapshot in full.
String encodeChildRequest(ChildRequest request) => jsonEncode({
  'v': toolLoopCodecVersion,
  'parentHireId': request.parentHireId,
  'agentRegistryId': request.agentRegistryId,
  'agentId': request.agentId,
  'priceStroops': request.priceStroops,
  'task': request.task,
  'justification': request.justification,
  'isRelatedParty': request.isRelatedParty,
  'relatedPartyJustification': request.relatedPartyJustification.name,
  'ranking': [for (final candidate in request.ranking) _candidate(candidate)],
});

/// The request [encodeChildRequest] wrote. Throws [FormatException] for
/// another version, an unknown verdict or a malformed value.
ChildRequest decodeChildRequest(String source) {
  final json = _versioned(source, 'child request');
  final verdictName = _string(json, 'relatedPartyJustification');
  final verdict = RelatedPartyJustification.values
      .where((v) => v.name == verdictName)
      .firstOrNull;
  if (verdict == null) {
    throw FormatException('Unknown related-party verdict: $verdictName');
  }
  return ChildRequest(
    parentHireId: _int(json, 'parentHireId'),
    agentRegistryId: _int(json, 'agentRegistryId'),
    agentId: _string(json, 'agentId'),
    priceStroops: _int(json, 'priceStroops'),
    task: _string(json, 'task'),
    justification: _string(json, 'justification'),
    isRelatedParty: _bool(json, 'isRelatedParty'),
    relatedPartyJustification: verdict,
    ranking: _readRanking(_list(json, 'ranking')),
  );
}

Map<String, Object?> _message(ConversationMessage message) => switch (message) {
  UserMessage(:final text) => {'role': 'user', 'text': text},
  AssistantMessage(:final text, :final toolCalls, :final providerContent) => {
    'role': 'assistant',
    'text': text,
    'toolCalls': [
      for (final call in toolCalls)
        {'id': call.id, 'name': call.name, 'arguments': call.arguments},
    ],
    'providerContent': ?providerContent,
  },
  ToolResultMessage(:final callId, :final content, :final isError) => {
    'role': 'tool',
    'callId': callId,
    'content': content,
    'isError': isError,
  },
};

ConversationMessage _readMessage(Map<String, Object?> json) {
  switch (_string(json, 'role')) {
    case 'user':
      return UserMessage(_string(json, 'text'));
    case 'assistant':
      final text = _string(json, 'text');
      final calls = [
        for (final call in _list(json, 'toolCalls'))
          _readCall(_asMap(call, 'tool call')),
      ];
      if (text.isEmpty && calls.isEmpty) {
        throw const FormatException('An assistant message needs content');
      }
      return AssistantMessage(
        text: text,
        toolCalls: calls,
        providerContent: json['providerContent'],
      );
    case 'tool':
      return ToolResultMessage(
        callId: _string(json, 'callId'),
        content: _string(json, 'content'),
        isError: _bool(json, 'isError'),
      );
    case final role:
      throw FormatException('Unknown message role: $role');
  }
}

ToolCall _readCall(Map<String, Object?> json) => ToolCall(
  id: _string(json, 'id'),
  name: _string(json, 'name'),
  arguments: _asMap(json['arguments'], 'arguments'),
);

Map<String, Object?> _candidate(AgentCandidate candidate) => {
  'id': candidate.id,
  'registryId': candidate.registryId,
  'name': candidate.name,
  'skills': candidate.skills,
  'priceStroops': candidate.priceStroops,
  'rating': candidate.rating,
  'paidHireCount': candidate.paidHireCount,
  'skillMatch': candidate.skillMatch,
  'score': candidate.score,
  'rank': candidate.rank,
  'isRelatedParty': candidate.isRelatedParty,
  'ownershipKnown': candidate.ownershipKnown,
};

List<AgentCandidate> _readRanking(List<Object?> json) => [
  for (final candidate in json) _readCandidate(_asMap(candidate, 'candidate')),
];

AgentCandidate _readCandidate(Map<String, Object?> json) => AgentCandidate(
  id: _string(json, 'id'),
  registryId: _int(json, 'registryId'),
  name: _string(json, 'name'),
  skills: [
    for (final skill in _list(json, 'skills'))
      skill is String ? skill : throw const FormatException('Bad skill'),
  ],
  priceStroops: _int(json, 'priceStroops'),
  rating: _double(json, 'rating'),
  paidHireCount: _int(json, 'paidHireCount'),
  skillMatch: _double(json, 'skillMatch'),
  score: _double(json, 'score'),
  rank: _int(json, 'rank'),
  isRelatedParty: _bool(json, 'isRelatedParty'),
  ownershipKnown: _bool(json, 'ownershipKnown'),
);

Map<String, Object?> _versioned(String source, String what) {
  final json = _asMap(jsonDecode(source), what);
  final version = json['v'];
  if (version != toolLoopCodecVersion) {
    throw FormatException('Unsupported $what version: $version');
  }
  return json;
}

Map<String, Object?> _asMap(Object? value, String what) {
  if (value is! Map) throw FormatException('Malformed $what');
  final map = <String, Object?>{};
  for (final MapEntry(:key, :value) in value.entries) {
    if (key is! String) throw FormatException('Malformed $what');
    map[key] = value;
  }
  return map;
}

List<Object?> _asList(Object? value, String what) {
  if (value is! List) throw FormatException('Malformed $what');
  return value;
}

List<Object?> _list(Map<String, Object?> json, String key) =>
    _asList(json[key], key);

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Malformed $key');
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Malformed $key');
  return value;
}

double _double(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Malformed $key');
  return value.toDouble();
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Malformed $key');
  return value;
}
