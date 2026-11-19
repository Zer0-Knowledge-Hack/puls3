import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../conversation.dart';

/// [ModelRuntime] for `model.provider: workers-ai`, the free provider of the
/// #34 model policy: one non-streaming call to the Cloudflare Workers AI REST
/// API (`POST /accounts/{account}/ai/run/{model}`).
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

  /// A plain conversation, always a [FinalText]. Tools are not supported:
  /// the Workers AI docs list function calling for the model, but its
  /// `tool_calls` carry only `name` and `arguments` (no id to answer) and
  /// no way to send a tool result back is documented. So offering tools, or
  /// replaying tool calls or results, fails as `tools_unsupported` with no
  /// call, and subcontracting is Anthropic-only (ADR-0011 D8).
  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) async {
    if (task.provider != provider) {
      throw RuntimeUnsupportedProvider(task.provider);
    }
    final messages = [
      {'role': 'system', 'content': task.systemPrompt},
    ];
    if (task.tools.isNotEmpty) throw const RuntimeToolsUnsupported();
    for (final message in task.messages) {
      switch (message) {
        case UserMessage(:final text):
          messages.add({'role': 'user', 'content': text});
        case AssistantMessage(:final text, :final toolCalls):
          if (toolCalls.isNotEmpty) throw const RuntimeToolsUnsupported();
          messages.add({'role': 'assistant', 'content': text});
        case ToolResultMessage():
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

  @override
  String toString() => 'WorkersAiRuntime()';
}
