import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../conversation.dart';

/// [ModelRuntime] for `model.provider: anthropic`: one non-streaming call to
/// the Claude Messages API over HTTP (there is no official Dart SDK).
///
/// The timeout is applied by `AgentRunner`, for every provider; when it fires,
/// the request is aborted through its `abortTrigger`. The API key is sent only
/// in the `x-api-key` header and never appears in a failure.
final class AnthropicRuntime implements ConversationRuntime {
  AnthropicRuntime({required http.Client httpClient, required String apiKey})
    : _http = httpClient,
      _apiKey = apiKey;

  static const provider = 'anthropic';

  final http.Client _http;
  final String _apiKey;

  static final _messagesUrl = Uri.parse(
    'https://api.anthropic.com/v1/messages',
  );

  /// Upper bound for `max_tokens`: non-streaming requests stay under HTTP
  /// timeouts at this size.
  static const maxTokensCeiling = 16000;

  /// Room for adaptive thinking, which counts toward `max_tokens` and cannot
  /// be turned off on the current Opus and Sonnet models.
  static const thinkingHeadroom = 4000;

  /// `max_tokens` for [task]: its `output.max_chars` plus [thinkingHeadroom],
  /// capped at [maxTokensCeiling], so a small limit no longer pays for 16000
  /// tokens. For most text a token covers one or more characters, so an
  /// output within the limit fits. Some scripts and emoji take more than one
  /// token per character, so such an output near the limit can still end as
  /// `output_truncated`. `AgentRunner` enforces the limit on the text.
  static int maxTokensFor(RuntimeTask task) => _maxTokens(task.maxOutputChars);

  static int _maxTokens(int maxOutputChars) =>
      min(maxTokensCeiling, maxOutputChars + thinkingHeadroom);

  /// Models that accept server-side fallbacks on a refusal.
  static const _fallbackModels = {
    'claude-fable-5-1',
    'claude-opus-5-5',
    'claude-opus-5',
    'claude-sonnet-5-5',
  };
  static const _fallbackBeta = 'server-side-fallback-2026-07-01';

  @override
  Future<String> complete(
    RuntimeTask task, {
    Future<void>? abortTrigger,
  }) async {
    if (task.provider != provider) {
      throw RuntimeUnsupportedProvider(task.provider);
    }
    final body = await _post(task.modelId, {
      'model': task.modelId,
      'max_tokens': maxTokensFor(task),
      'system': task.systemPrompt,
      'messages': [
        {'role': 'user', 'content': task.input},
      ],
    }, abortTrigger);
    final (stopReason, content) = _decode(body);
    if (stopReason == 'tool_use') throw _unexpectedStop;
    return _joinText(content);
  }

  /// One turn of a conversation with tools: [ConversationTask.tools] as
  /// `tools`, assistant turns replayed as content blocks (their
  /// `providerContent` verbatim when present, so thinking blocks come back
  /// unchanged), and consecutive tool results grouped in one user message of
  /// `tool_result` blocks. `stop_reason: tool_use` is a [ToolCallsTurn]; a
  /// `tool_use` block without an id, a name or an object input fails as
  /// `provider_error:malformed_tool_call`.
  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) async {
    if (task.provider != provider) {
      throw RuntimeUnsupportedProvider(task.provider);
    }
    final body = await _post(task.modelId, {
      'model': task.modelId,
      'max_tokens': _maxTokens(task.maxOutputChars),
      'system': task.systemPrompt,
      if (task.tools.isNotEmpty)
        'tools': [
          for (final tool in task.tools)
            {
              'name': tool.name,
              'description': tool.description,
              'input_schema': tool.parameters,
            },
        ],
      'messages': _messages(task.messages),
    }, abortTrigger);
    final (stopReason, content) = _decode(body);
    if (stopReason != 'tool_use') return FinalText(_joinText(content));
    return ToolCallsTurn(
      calls: _toolCalls(content),
      text: _joinText(content),
      providerContent: content,
    );
  }

  /// The Messages API `messages` for [messages].
  static List<Map<String, Object?>> _messages(
    List<ConversationMessage> messages,
  ) {
    final out = <Map<String, Object?>>[];
    List<Map<String, Object?>>? results;
    for (final message in messages) {
      if (message is! ToolResultMessage) results = null;
      switch (message) {
        case UserMessage(:final text):
          out.add({'role': 'user', 'content': text});
        case AssistantMessage():
          out.add({
            'role': 'assistant',
            'content': message.providerContent ?? _blocks(message),
          });
        case ToolResultMessage():
          final block = {
            'type': 'tool_result',
            'tool_use_id': message.callId,
            'content': message.content,
            'is_error': message.isError,
          };
          if (results == null) {
            results = [block];
            out.add({'role': 'user', 'content': results});
          } else {
            results.add(block);
          }
      }
    }
    return out;
  }

  static List<Map<String, Object?>> _blocks(AssistantMessage message) => [
    if (message.text.isNotEmpty) {'type': 'text', 'text': message.text},
    for (final call in message.toolCalls)
      {
        'type': 'tool_use',
        'id': call.id,
        'name': call.name,
        'input': call.arguments,
      },
  ];

  /// POSTs [payload], plus fallbacks for the models that accept them, and
  /// returns the body of a 200 response.
  Future<String> _post(
    String modelId,
    Map<String, Object?> payload,
    Future<void>? abortTrigger,
  ) async {
    final fallbacks = _fallbackModels.contains(modelId);
    final request =
        http.AbortableRequest('POST', _messagesUrl, abortTrigger: abortTrigger)
          ..headers.addAll({
            'content-type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
            if (fallbacks) 'anthropic-beta': _fallbackBeta,
          })
          ..body = jsonEncode({
            ...payload,
            if (fallbacks) 'fallbacks': 'default',
          });
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on http.RequestAbortedException {
      throw const RuntimeProviderFailed(status: null, errorType: 'aborted');
    } on SocketException {
      throw const RuntimeProviderFailed(status: null, errorType: null);
    } on http.ClientException {
      throw const RuntimeProviderFailed(status: null, errorType: null);
    }
    if (response.statusCode != 200) {
      throw RuntimeProviderFailed(
        status: response.statusCode,
        errorType: _errorType(response.body),
      );
    }
    return response.body;
  }

  /// The `error.type` of an API error body, or `null` if there is none.
  static String? _errorType(String body) {
    try {
      final decoded = jsonDecode(body);
      final error = decoded is Map ? decoded['error'] : null;
      final type = error is Map ? error['type'] : null;
      return type is String ? type : null;
    } on FormatException {
      return null;
    }
  }

  static const _malformed = RuntimeProviderFailed(
    status: 200,
    errorType: 'malformed_response',
  );
  static const _malformedToolCall = RuntimeProviderFailed(
    status: 200,
    errorType: 'malformed_tool_call',
  );
  static const _unexpectedStop = RuntimeProviderFailed(
    status: 200,
    errorType: 'unexpected_stop_reason',
  );

  /// The `stop_reason` (`end_turn`, `stop_sequence` or `tool_use`) and the
  /// `content` of a 200 body. Refusals, truncation and other stop reasons
  /// fail.
  static (String, List<Object?>) _decode(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw _malformed;
    }
    if (decoded is! Map<String, Object?>) throw _malformed;
    final content = decoded['content'];
    if (content is! List) throw _malformed;

    switch (decoded['stop_reason']) {
      case final String reason
          when reason == 'end_turn' ||
              reason == 'stop_sequence' ||
              reason == 'tool_use':
        return (reason, content);
      case 'refusal':
        final details = decoded['stop_details'];
        final category = details is Map ? details['category'] : null;
        throw RuntimeRefused(category is String ? category : null);
      case 'max_tokens':
        throw const RuntimeOutputTruncated();
      default:
        throw _unexpectedStop;
    }
  }

  static String _joinText(List<Object?> content) {
    final text = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text' && block['text'] is String) {
        text.write(block['text']);
      }
    }
    return text.toString();
  }

  static List<ToolCall> _toolCalls(List<Object?> content) {
    final calls = <ToolCall>[];
    for (final block in content) {
      if (block is! Map || block['type'] != 'tool_use') continue;
      final id = block['id'];
      final name = block['name'];
      final input = block['input'];
      if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
        throw _malformedToolCall;
      }
      if (input is! Map<String, Object?>) throw _malformedToolCall;
      calls.add(ToolCall(id: id, name: name, arguments: input));
    }
    if (calls.isEmpty) throw _malformedToolCall;
    return calls;
  }

  @override
  String toString() => 'AnthropicRuntime()';
}
