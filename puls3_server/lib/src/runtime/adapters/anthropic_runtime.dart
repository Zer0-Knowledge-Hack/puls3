import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../runtime_task.dart';

/// [ModelRuntime] for `model.provider: anthropic`: one non-streaming call to
/// the Claude Messages API over HTTP (there is no official Dart SDK).
///
/// The timeout is applied by `AgentRunner`, for every provider; when it fires,
/// the request is aborted through its `abortTrigger`. The API key is sent only
/// in the `x-api-key` header and never appears in a failure.
final class AnthropicRuntime implements ModelRuntime {
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
  static int maxTokensFor(RuntimeTask task) =>
      min(maxTokensCeiling, task.maxOutputChars + thinkingHeadroom);

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
    final fallbacks = _fallbackModels.contains(task.modelId);
    final request =
        http.AbortableRequest('POST', _messagesUrl, abortTrigger: abortTrigger)
          ..headers.addAll({
            'content-type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
            if (fallbacks) 'anthropic-beta': _fallbackBeta,
          })
          ..body = jsonEncode({
            'model': task.modelId,
            'max_tokens': maxTokensFor(task),
            'system': task.systemPrompt,
            'messages': [
              {'role': 'user', 'content': task.input},
            ],
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
    return _text(response.body);
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
    final content = decoded['content'];
    if (content is! List) throw malformed;

    switch (decoded['stop_reason']) {
      case 'end_turn' || 'stop_sequence':
        break;
      case 'refusal':
        final details = decoded['stop_details'];
        final category = details is Map ? details['category'] : null;
        throw RuntimeRefused(category is String ? category : null);
      case 'max_tokens':
        throw const RuntimeOutputTruncated();
      default:
        throw const RuntimeProviderFailed(
          status: 200,
          errorType: 'unexpected_stop_reason',
        );
    }

    final text = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text' && block['text'] is String) {
        text.write(block['text']);
      }
    }
    return text.toString();
  }

  @override
  String toString() => 'AnthropicRuntime()';
}
