import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../conversation.dart';

/// The Workers AI models that hold a conversation with tools (ADR-0011 D8,
/// as amended for #334 T8.0). Each one was checked against the subcontract
/// loop: it searches, subcontracts once and answers with the result. Other
/// Workers AI models fail as `tools_unsupported` when offered tools; llama
/// 3.3 70B, for example, sends malformed calls and repeats them.
const workersAiToolModels = {'@cf/mistralai/mistral-small-3.1-24b-instruct'};

/// [ModelRuntime] for `model.provider: workers-ai`, the free provider of the
/// #34 model policy: one non-streaming call to the Cloudflare Workers AI REST
/// API (`POST /accounts/{account}/ai/run/{model}`). A conversation with tools
/// uses the OpenAI-compatible endpoint instead (see [converse]).
///
/// The timeout is applied by `AgentRunner`; when it fires, the request is
/// aborted through its `abortTrigger`. The API token is sent only in the
/// `Authorization` header and never appears in a failure.
final class WorkersAiRuntime implements ConversationRuntime {
  WorkersAiRuntime({
    required http.Client httpClient,
    required String accountId,
    required String apiToken,
  }) : _http = httpClient,
       _accountId = accountId,
       _apiToken = apiToken;

  static const provider = 'workers-ai';

  final http.Client _http;
  final String _accountId;
  final String _apiToken;

  /// Upper bound for `max_tokens`. Workers AI defaults to 256, which cuts
  /// most answers short, so the runtime always sets it.
  static const maxTokensCeiling = 4096;

  /// `max_tokens` for [task]: its `output.max_chars`, capped at
  /// [maxTokensCeiling]. For most text a token covers one or more
  /// characters; some scripts and emoji take more, so such an output near
  /// the limit can be cut short. `AgentRunner` enforces the limit on the
  /// text.
  static int maxTokensFor(RuntimeTask task) =>
      min(maxTokensCeiling, task.maxOutputChars);

  /// `POST /accounts/{account}/ai/run/{model}`, or `null` when [model]
  /// cannot be a path. A model id is `/`-separated (`@cf/meta/…`), so each
  /// segment is percent-encoded on its own: `?`, `#`, `%` or a space stay
  /// inside the model path, and `@` stays as Cloudflare writes it. Empty,
  /// `.` and `..` segments are refused, since URL normalization would turn
  /// them into another path.
  static Uri? runUrl(String accountId, String model) {
    final segments = model.split('/');
    if (segments.any((s) => s.isEmpty || s == '.' || s == '..')) return null;
    return Uri(
      scheme: 'https',
      host: 'api.cloudflare.com',
      pathSegments: [
        'client',
        'v4',
        'accounts',
        accountId,
        'ai',
        'run',
        ...segments,
      ],
    );
  }

  @override
  Future<String> complete(
    RuntimeTask task, {
    Future<void>? abortTrigger,
  }) async {
    if (task.provider != provider) {
      throw RuntimeUnsupportedProvider(task.provider);
    }
    return _run(
      task.modelId,
      [
        {'role': 'system', 'content': task.systemPrompt},
        {'role': 'user', 'content': task.input},
      ],
      maxTokensFor(task),
      abortTrigger,
    );
  }

  /// `POST /accounts/{account}/ai/v1/chat/completions`, the OpenAI-compatible
  /// endpoint. Unlike `/ai/run`, its `tool_calls` carry an id and it takes
  /// tool results back as `role: "tool"` messages.
  static Uri chatCompletionsUrl(String accountId) => Uri(
    scheme: 'https',
    host: 'api.cloudflare.com',
    pathSegments: [
      'client',
      'v4',
      'accounts',
      accountId,
      'ai',
      'v1',
      'chat',
      'completions',
    ],
  );

  /// One turn of a conversation. Without tools, and with no tool call or
  /// result to replay, it is a plain `/ai/run` call and always a
  /// [FinalText].
  ///
  /// With tools, a model in [workersAiToolModels] gets an OpenAI-compatible
  /// chat completion: [ConversationTask.tools] as `function` tools, assistant
  /// turns replayed with their `tool_calls`, and each tool result as a
  /// `role: "tool"` message with its `tool_call_id`. A reply with tool calls
  /// is a [ToolCallsTurn]; a call without an id or a name, or whose
  /// arguments are not a JSON object, fails as
  /// `provider_error:malformed_tool_call`. Any other Workers AI model fails
  /// as `tools_unsupported` with no call: the native `/ai/run` `tool_calls`
  /// carry no id to answer.
  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) async {
    if (task.provider != provider) {
      throw RuntimeUnsupportedProvider(task.provider);
    }
    final usesTools =
        task.tools.isNotEmpty ||
        task.messages.any(
          (m) =>
              m is ToolResultMessage ||
              (m is AssistantMessage && m.toolCalls.isNotEmpty),
        );
    if (usesTools) {
      if (!workersAiToolModels.contains(task.modelId)) {
        throw const RuntimeToolsUnsupported();
      }
      return _converseWithTools(task, abortTrigger);
    }
    final messages = [
      {'role': 'system', 'content': task.systemPrompt},
    ];
    for (final message in task.messages) {
      switch (message) {
        case UserMessage(:final text):
          messages.add({'role': 'user', 'content': text});
        case AssistantMessage(:final text):
          messages.add({'role': 'assistant', 'content': text});
        case ToolResultMessage():
          // Excluded by usesTools above.
          throw const RuntimeToolsUnsupported();
      }
    }
    final text = await _run(
      task.modelId,
      messages,
      min(maxTokensCeiling, task.maxOutputChars),
      abortTrigger,
    );
    return FinalText(text);
  }

  Future<String> _run(
    String modelId,
    List<Map<String, String>> messages,
    int maxTokens,
    Future<void>? abortTrigger,
  ) async {
    final url =
        runUrl(_accountId, modelId) ?? (throw const RuntimeInvalidModel());
    final request =
        http.AbortableRequest('POST', url, abortTrigger: abortTrigger)
          ..headers.addAll({
            'content-type': 'application/json',
            'authorization': 'Bearer $_apiToken',
          })
          ..body = jsonEncode({'messages': messages, 'max_tokens': maxTokens});
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
    return _text(response.body);
  }

  /// `cloudflare_<code>` for the first entry of a Cloudflare API `errors`
  /// array, or `null` when there is none. Only the numeric code is kept, so
  /// the failure stays safe to store.
  static String? _errorType(String body) {
    try {
      final decoded = jsonDecode(body);
      final errors = decoded is Map ? decoded['errors'] : null;
      final first = errors is List && errors.isNotEmpty ? errors.first : null;
      final code = first is Map ? first['code'] : null;
      return code is int ? 'cloudflare_$code' : null;
    } on FormatException {
      return null;
    }
  }

  static String _text(String body) {
    const malformed = RuntimeProviderFailed(
      status: 200,
      errorType: 'malformed_response',
    );
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw malformed;
    }
    if (decoded is! Map<String, Object?>) throw malformed;
    if (decoded['success'] != true) {
      throw RuntimeProviderFailed(
        status: 200,
        errorType: _errorType(body) ?? 'unsuccessful',
      );
    }
    final result = decoded['result'];
    final text = result is Map ? result['response'] : null;
    if (text is! String) throw malformed;
    return text;
  }

  Future<ModelTurn> _converseWithTools(
    ConversationTask task,
    Future<void>? abortTrigger,
  ) async {
    final request =
        http.AbortableRequest(
            'POST',
            chatCompletionsUrl(_accountId),
            abortTrigger: abortTrigger,
          )
          ..headers.addAll({
            'content-type': 'application/json',
            'authorization': 'Bearer $_apiToken',
          })
          ..body = jsonEncode({
            'model': task.modelId,
            'messages': _chatMessages(task),
            'tools': [
              for (final tool in task.tools)
                {
                  'type': 'function',
                  'function': {
                    'name': tool.name,
                    'description': tool.description,
                    'parameters': tool.parameters,
                  },
                },
            ],
            'max_tokens': min(maxTokensCeiling, task.maxOutputChars),
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
    return _turn(response.body);
  }

  /// The chat completion `messages` of [task], system prompt first.
  static List<Map<String, Object?>> _chatMessages(ConversationTask task) => [
    {'role': 'system', 'content': task.systemPrompt},
    for (final message in task.messages)
      switch (message) {
        UserMessage(:final text) => {'role': 'user', 'content': text},
        AssistantMessage(:final text, :final toolCalls) => {
          'role': 'assistant',
          'content': text,
          if (toolCalls.isNotEmpty)
            'tool_calls': [
              for (final call in toolCalls)
                {
                  'id': call.id,
                  'type': 'function',
                  'function': {
                    'name': call.name,
                    'arguments': jsonEncode(call.arguments),
                  },
                },
            ],
        },
        ToolResultMessage(:final callId, :final content) => {
          'role': 'tool',
          'tool_call_id': callId,
          'content': content,
        },
      },
  ];

  static const _malformedResponse = RuntimeProviderFailed(
    status: 200,
    errorType: 'malformed_response',
  );
  static const _malformedToolCall = RuntimeProviderFailed(
    status: 200,
    errorType: 'malformed_tool_call',
  );

  /// The [ModelTurn] of a chat completion body.
  static ModelTurn _turn(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw _malformedResponse;
    }
    final choices = decoded is Map ? decoded['choices'] : null;
    final choice = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = choice is Map ? choice['message'] : null;
    if (message is! Map) throw _malformedResponse;
    if (choice['finish_reason'] == 'length') {
      throw const RuntimeOutputTruncated();
    }
    final content = message['content'];
    final rawCalls = message['tool_calls'];
    if (rawCalls is List && rawCalls.isNotEmpty) {
      return ToolCallsTurn(
        calls: [for (final raw in rawCalls) _toolCall(raw)],
        text: content is String ? content : '',
      );
    }
    if (content is! String) throw _malformedResponse;
    return FinalText(content);
  }

  static ToolCall _toolCall(Object? raw) {
    final function = raw is Map ? raw['function'] : null;
    final id = raw is Map ? raw['id'] : null;
    final name = function is Map ? function['name'] : null;
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw _malformedToolCall;
    }
    var arguments = (function as Map)['arguments'];
    // OpenAI-compatible endpoints send a call with no arguments as null, an
    // empty string or no field: that is `{}`, and the tool validates it.
    if (arguments == null ||
        (arguments is String && arguments.trim().isEmpty)) {
      arguments = <String, Object?>{};
    } else if (arguments is String) {
      try {
        arguments = jsonDecode(arguments);
      } on FormatException {
        throw _malformedToolCall;
      }
    }
    if (arguments is! Map<String, Object?>) throw _malformedToolCall;
    return ToolCall(id: id, name: name, arguments: arguments);
  }

  @override
  String toString() => 'WorkersAiRuntime()';
}
