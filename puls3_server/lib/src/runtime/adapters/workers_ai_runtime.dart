import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../runtime_task.dart';

/// [ModelRuntime] for `model.provider: workers-ai`, the free provider of the
/// #34 model policy: one non-streaming call to the Cloudflare Workers AI REST
/// API (`POST /accounts/{account}/ai/run/{model}`).
///
/// The timeout is applied by `AgentRunner`; when it fires, the request is
/// aborted through its `abortTrigger`. The API token is sent only in the
/// `Authorization` header and never appears in a failure.
final class WorkersAiRuntime implements ModelRuntime {
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

  /// `max_tokens` for [task]: its `output.max_chars` (a token is at least
  /// about one character), capped at [maxTokensCeiling]. `AgentRunner`
  /// still enforces the limit on the text.
  static int maxTokensFor(RuntimeTask task) =>
      min(maxTokensCeiling, task.maxOutputChars);

  Uri _runUrl(String model) => Uri.parse(
    'https://api.cloudflare.com/client/v4/accounts/'
    '${Uri.encodeComponent(_accountId)}/ai/run/$model',
  );

  @override
  Future<String> complete(
    RuntimeTask task, {
    Future<void>? abortTrigger,
  }) async {
    if (task.provider != provider) {
      throw RuntimeUnsupportedProvider(task.provider);
    }
    final request =
        http.AbortableRequest(
            'POST',
            _runUrl(task.modelId),
            abortTrigger: abortTrigger,
          )
          ..headers.addAll({
            'content-type': 'application/json',
            'authorization': 'Bearer $_apiToken',
          })
          ..body = jsonEncode({
            'messages': [
              {'role': 'system', 'content': task.systemPrompt},
              {'role': 'user', 'content': task.input},
            ],
            'max_tokens': maxTokensFor(task),
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
