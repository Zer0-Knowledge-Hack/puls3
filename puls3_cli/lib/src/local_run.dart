import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';

/// The environment variables `puls3 run` reads the builder's model
/// credentials from. `docs/cli/run-locally.md` lists them.
abstract final class CredentialVariables {
  static const cloudflareAccountId = 'CLOUDFLARE_ACCOUNT_ID';
  static const cloudflareApiToken = 'CLOUDFLARE_API_TOKEN';
  static const anthropicApiKey = 'ANTHROPIC_API_KEY';
}

/// The models a local run accepts: the same policy the server's Studio
/// applies on deploy (`studioServerModelPolicy` in `puls3_server`), so a
/// manifest that runs locally also deploys.
final localModelPolicy = ModelPolicy(
  workersAiModels: {
    '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
    '@cf/mistralai/mistral-small-3.1-24b-instruct',
  },
  paidProviders: {'anthropic'},
);

/// The longest one local run may take, as the server runtime's default.
const localRunTimeout = Duration(seconds: 120);

/// Reads a deployable manifest from its wire document: a Studio draft (no
/// `version`) or a deployed manifest (`schema` and `version`). Throws
/// [InvalidManifest] listing every broken deploy rule under
/// [localModelPolicy].
AgentManifest parseLocalManifest(Object? json) {
  if (json is Map && json.containsKey('version')) {
    return AgentManifest.fromJson(json, localModelPolicy);
  }
  return AgentManifestDraft.fromJson(
    json,
  ).validate(localModelPolicy, ManifestVersion.first);
}

/// Why a local run produced no output. [code] is the `error: <code>` word,
/// [message] never holds a credential, a prompt or a provider message.
final class LocalRunFailure implements Exception {
  const LocalRunFailure(this.code, this.message, {this.unreachable = false});

  final String code;
  final String message;

  /// Whether no answer came from the provider (network or timeout).
  final bool unreachable;

  @override
  String toString() => 'LocalRunFailure($code: $message)';
}

/// The builder's credential for [provider] read from [environment], or a
/// list of the variables still to set.
sealed class Credential {
  const Credential();

  static (Credential?, List<String> missing) read(
    String provider,
    Map<String, String> environment,
  ) {
    String? value(String name) {
      final text = environment[name]?.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    switch (provider) {
      case 'workers-ai':
        final account = value(CredentialVariables.cloudflareAccountId);
        final token = value(CredentialVariables.cloudflareApiToken);
        if (account == null || token == null) {
          return (
            null,
            [
              if (account == null) CredentialVariables.cloudflareAccountId,
              if (token == null) CredentialVariables.cloudflareApiToken,
            ],
          );
        }
        return (WorkersAiCredential(account, token), const []);
      case 'anthropic':
        final key = value(CredentialVariables.anthropicApiKey);
        if (key == null) {
          return (null, const [CredentialVariables.anthropicApiKey]);
        }
        return (AnthropicCredential(key), const []);
      default:
        return (null, const []);
    }
  }
}

final class WorkersAiCredential extends Credential {
  const WorkersAiCredential(this.accountId, this.apiToken);

  final String accountId;
  final String apiToken;

  @override
  String toString() => 'WorkersAiCredential()';
}

final class AnthropicCredential extends Credential {
  const AnthropicCredential(this.apiKey);

  final String apiKey;

  @override
  String toString() => 'AnthropicCredential()';
}

/// Runs [manifest] on [input] with the builder's [credential]: the same
/// request shape, limits and failure handling as the server runtime
/// (`AgentRunner` with the Workers AI and Anthropic adapters).
///
/// Throws [LocalRunFailure]. Input over `input.max_chars` fails before the
/// model is called; a blank output or one over `output.max_chars` fails after.
Future<String> runManifestLocally(
  AgentManifest manifest,
  String input, {
  required Credential credential,
  required http.Client client,
  Duration timeout = localRunTimeout,
}) async {
  final inputLength = input.runes.length;
  if (inputLength > manifest.inputMaxChars) {
    throw LocalRunFailure(
      'InputTooLong',
      'the input is $inputLength characters; '
          'the manifest allows ${manifest.inputMaxChars}',
    );
  }

  final provider = manifest.model.provider;
  final abort = Completer<void>();
  final request = switch (credential) {
    WorkersAiCredential() => _workersAiRequest(
      manifest,
      input,
      credential,
      abort.future,
    ),
    AnthropicCredential() => _anthropicRequest(
      manifest,
      input,
      credential,
      abort.future,
    ),
  };

  final http.Response response;
  try {
    response = await http.Response.fromStream(
      await client.send(request),
    ).timeout(timeout);
  } on TimeoutException {
    abort.complete();
    throw LocalRunFailure(
      'Unreachable',
      '$provider did not answer in ${timeout.inSeconds} seconds',
      unreachable: true,
    );
  } on SocketException {
    throw LocalRunFailure(
      'Unreachable',
      '$provider could not be reached',
      unreachable: true,
    );
  } on http.ClientException {
    throw LocalRunFailure(
      'Unreachable',
      '$provider could not be reached',
      unreachable: true,
    );
  }

  final output = switch (credential) {
    WorkersAiCredential() => _workersAiText(response),
    AnthropicCredential() => _anthropicText(response),
  };
  if (output.trim().isEmpty) {
    throw const LocalRunFailure('EmptyOutput', 'the model answered no text');
  }
  final outputLength = output.runes.length;
  if (outputLength > manifest.outputMaxChars) {
    throw LocalRunFailure(
      'OutputTooLong',
      'the output is $outputLength characters; '
          'the manifest allows ${manifest.outputMaxChars}',
    );
  }
  return output;
}

LocalRunFailure _providerError(String provider, int status, String? type) =>
    LocalRunFailure(
      'ProviderError',
      '$provider answered HTTP $status${type == null ? '' : ' ($type)'}',
    );

// Workers AI: mirrors puls3_server's WorkersAiRuntime.

/// Workers AI defaults to 256 tokens, so the request always sets it.
const workersAiMaxTokensCeiling = 4096;

http.BaseRequest _workersAiRequest(
  AgentManifest manifest,
  String input,
  WorkersAiCredential credential,
  Future<void> abort,
) {
  final segments = manifest.model.id.split('/');
  if (segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
    throw const LocalRunFailure(
      'InvalidModel',
      'the model id cannot be sent to workers-ai',
    );
  }
  final url = Uri(
    scheme: 'https',
    host: 'api.cloudflare.com',
    pathSegments: [
      'client',
      'v4',
      'accounts',
      credential.accountId,
      'ai',
      'run',
      ...segments,
    ],
  );
  return http.AbortableRequest('POST', url, abortTrigger: abort)
    ..headers.addAll({
      'content-type': 'application/json',
      'authorization': 'Bearer ${credential.apiToken}',
    })
    ..body = jsonEncode({
      'messages': [
        {'role': 'system', 'content': manifest.systemPrompt},
        {'role': 'user', 'content': input},
      ],
      'max_tokens': min(workersAiMaxTokensCeiling, manifest.outputMaxChars),
    });
}

String _workersAiText(http.Response response) {
  const provider = 'workers-ai';
  String? errorType(Object? decoded) {
    final errors = decoded is Map ? decoded['errors'] : null;
    final first = errors is List && errors.isNotEmpty ? errors.first : null;
    final code = first is Map ? first['code'] : null;
    return code is int ? 'cloudflare_$code' : null;
  }

  final decoded = _decode(response.body);
  if (response.statusCode != 200) {
    throw _providerError(provider, response.statusCode, errorType(decoded));
  }
  final malformed = _providerError(provider, 200, 'malformed_response');
  if (decoded is! Map<String, Object?>) throw malformed;
  if (decoded['success'] != true) {
    throw _providerError(provider, 200, errorType(decoded) ?? 'unsuccessful');
  }
  final result = decoded['result'];
  final text = result is Map ? result['response'] : null;
  if (text is! String) throw malformed;
  return text;
}

// Anthropic: mirrors puls3_server's AnthropicRuntime.

final _anthropicMessagesUrl = Uri.parse(
  'https://api.anthropic.com/v1/messages',
);
const anthropicMaxTokensCeiling = 16000;
const anthropicThinkingHeadroom = 4000;

/// Models that accept server-side fallbacks on a refusal.
const _anthropicFallbackModels = {
  'claude-fable-5-1',
  'claude-opus-5-5',
  'claude-opus-5',
  'claude-sonnet-5-5',
};

http.BaseRequest _anthropicRequest(
  AgentManifest manifest,
  String input,
  AnthropicCredential credential,
  Future<void> abort,
) {
  final fallbacks = _anthropicFallbackModels.contains(manifest.model.id);
  return http.AbortableRequest(
      'POST',
      _anthropicMessagesUrl,
      abortTrigger: abort,
    )
    ..headers.addAll({
      'content-type': 'application/json',
      'x-api-key': credential.apiKey,
      'anthropic-version': '2023-06-01',
      if (fallbacks) 'anthropic-beta': 'server-side-fallback-2026-07-01',
    })
    ..body = jsonEncode({
      'model': manifest.model.id,
      'max_tokens': min(
        anthropicMaxTokensCeiling,
        manifest.outputMaxChars + anthropicThinkingHeadroom,
      ),
      'system': manifest.systemPrompt,
      'messages': [
        {'role': 'user', 'content': input},
      ],
      if (fallbacks) 'fallbacks': 'default',
    });
}

String _anthropicText(http.Response response) {
  const provider = 'anthropic';
  final decoded = _decode(response.body);
  if (response.statusCode != 200) {
    final error = decoded is Map ? decoded['error'] : null;
    final type = error is Map ? error['type'] : null;
    throw _providerError(
      provider,
      response.statusCode,
      type is String ? type : null,
    );
  }
  final malformed = _providerError(provider, 200, 'malformed_response');
  if (decoded is! Map<String, Object?>) throw malformed;
  final content = decoded['content'];
  if (content is! List) throw malformed;
  switch (decoded['stop_reason']) {
    case 'end_turn' || 'stop_sequence':
      break;
    case 'refusal':
      throw const LocalRunFailure('Refused', 'the model declined the task');
    case 'max_tokens':
      throw const LocalRunFailure(
        'OutputTruncated',
        'the model stopped at its token limit',
      );
    default:
      throw _providerError(provider, 200, 'unexpected_stop_reason');
  }
  final text = StringBuffer();
  for (final block in content) {
    if (block is Map && block['type'] == 'text' && block['text'] is String) {
      text.write(block['text']);
    }
  }
  return text.toString();
}

Object? _decode(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}
