import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException, stderr;

import 'package:dart_mcp/server.dart';
import 'package:puls3_sdk/puls3_sdk.dart';

/// The tools this server offers, in the order `tools/list` returns them.
/// Any other name is refused.
const toolNames = [
  'catalog_list',
  'catalog_get',
  'hire_get',
  'hire_prepare_complete',
  'hire_prepare_reject',
  'studio_test_run',
];

/// Why the hire and Studio tools answer with an error for now.
const sessionPending =
    'This tool needs a wallet session, which the SDK does not have yet '
    '(docs/adr/0007-developer-sdk.md, Open decision 1; '
    'https://github.com/Zer0-Knowledge-Hack/puls3/issues/259). '
    'Use the app at https://puls3.org/ meanwhile.';

/// A stdio MCP server over [Puls3Sdk].
///
/// Every tool reads or prepares. None signs, funds, approves, rejects,
/// rates or submits a transaction: a prepared envelope is returned unsigned
/// for a wallet to sign, never sent.
base class Puls3McpServer extends MCPServer with ToolsSupport {
  Puls3McpServer(super.channel, {required this.sdk, required String apiUrl})
    : apiUrl = redactedUrl(apiUrl),
      super.fromStreamChannel(
        implementation: Implementation(name: 'puls3', version: '0.1.0'),
        instructions:
            'Reads the puls3 agent catalog on Stellar testnet. The tools '
            'never sign or submit a transaction.',
      ) {
    registerTool(_catalogList, _onCatalogList);
    registerTool(_catalogGet, _onCatalogGet);
    registerTool(_hireGet, _needsSession);
    registerTool(_hirePrepareComplete, _needsSession);
    registerTool(_hirePrepareReject, _needsSession);
    registerTool(_studioTestRun, _needsSession);
  }

  /// The SDK the tools call. The caller owns it and closes it.
  final Puls3Sdk sdk;

  /// The server URL, as the errors name it, without any user info.
  final String apiUrl;

  final _catalogList = Tool(
    name: 'catalog_list',
    description:
        'Every agent in the puls3 catalog: id, registry id, name, '
        'description, skills, price in USDC stroops, wallet, model, rating '
        'and paid hire count.',
    inputSchema: Schema.object(properties: {}),
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: true),
  );

  final _catalogGet = Tool(
    name: 'catalog_get',
    description:
        'One agent of the puls3 catalog by its id, for example '
        'agt-001 or studio-3.',
    inputSchema: Schema.object(
      properties: {
        'id': Schema.string(description: 'The catalog id of the agent.'),
      },
      required: ['id'],
    ),
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: true),
  );

  final _hireGet = Tool(
    name: 'hire_get',
    description:
        'One hire of the signed-in wallet. Not available until the SDK has '
        'a wallet session (#259).',
    inputSchema: Schema.object(
      properties: {'hireId': Schema.int(description: 'The hire id.')},
      required: ['hireId'],
    ),
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: true),
  );

  final _hirePrepareComplete = Tool(
    name: 'hire_prepare_complete',
    description:
        'Prepares the unsigned escrow `complete` (approve) of a hire, for a '
        'wallet to sign. It does not sign or send it. Not available until '
        'the SDK has a wallet session (#259).',
    inputSchema: Schema.object(
      properties: {'hireId': Schema.int(description: 'The hire id.')},
      required: ['hireId'],
    ),
    // The server stores a preparation; nothing is signed or sent.
    annotations: ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      openWorldHint: true,
    ),
  );

  final _hirePrepareReject = Tool(
    name: 'hire_prepare_reject',
    description:
        'Prepares the unsigned escrow `reject` of a hire, for a wallet to '
        'sign. It does not sign or send it. Not available until the SDK has '
        'a wallet session (#259).',
    inputSchema: Schema.object(
      properties: {
        'hireId': Schema.int(description: 'The hire id.'),
        'reason': Schema.string(description: 'Why the result is rejected.'),
      },
      required: ['hireId', 'reason'],
    ),
    // The server stores a preparation; nothing is signed or sent.
    annotations: ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      openWorldHint: true,
    ),
  );

  final _studioTestRun = Tool(
    name: 'studio_test_run',
    description:
        'Runs one of your Studio drafts on an input, without a hire. The '
        'draft id is required; there is no default draft. Not available '
        'until the SDK has a wallet session (#259).',
    inputSchema: Schema.object(
      properties: {
        'draftId': Schema.int(description: 'The Studio draft id.'),
        'input': Schema.string(description: 'The input to run the draft on.'),
      },
      required: ['draftId', 'input'],
    ),
    annotations: ToolAnnotations(openWorldHint: true),
  );

  Future<CallToolResult> _onCatalogList(CallToolRequest request) =>
      _guard(() async {
        final agents = await sdk.listAgents();
        return _json([for (final agent in agents) agentJson(agent)]);
      });

  Future<CallToolResult> _onCatalogGet(CallToolRequest request) =>
      _guard(() async {
        final id = (request.arguments?['id'] as String? ?? '').trim();
        if (id.isEmpty) return _error('Usage', 'catalog_get needs an id.');
        final agent = await sdk.getAgent(id);
        if (agent == null) return _error('NotFound', 'no agent with id $id');
        return _json(agentJson(agent));
      });

  /// The hire and Studio tools: their arguments are checked by their schema
  /// first (a missing draft id or input is refused there), then they fail
  /// closed until the SDK has a session.
  CallToolResult _needsSession(CallToolRequest request) =>
      _error('SessionUnavailable', sessionPending);

  /// Maps the SDK's errors to a tool error, never a stack trace.
  Future<CallToolResult> _guard(Future<CallToolResult> Function() call) async {
    try {
      return await call();
    } on Puls3ApiException catch (e) {
      return _error(e.code, e.message ?? '');
    } on AgentCatalogUnavailable catch (e) {
      return _error('AgentCatalogUnavailable', e.message);
    } on ServerpodClientException catch (e) {
      return _error('Unreachable', '$apiUrl: ${e.message}');
    } on IOException catch (e) {
      return _error('Unreachable', '$apiUrl: $e');
    } catch (e, stack) {
      // Anything else (a StateError, a response the client cannot read):
      // dart_mcp would return '$e\n$stack' to the client. The detail goes
      // to stderr for whoever runs the server, never to the client.
      stderr.writeln('puls3_mcp: unexpected ${e.runtimeType}: $e\n$stack');
      return _error(
        'Internal',
        'unexpected ${e.runtimeType}; see the server log',
      );
    }
  }
}

/// The fields the tools return for an agent. Named here so the output does
/// not change when the generated model gains a field.
Map<String, Object?> agentJson(AgentSummary agent) => {
  'id': agent.id,
  'registryId': agent.registryId,
  'name': agent.name,
  'description': agent.description,
  'skills': agent.skills,
  'priceUsdcStroops': agent.priceUsdcStroops,
  'priceUsdc': formatUsdc(agent.priceUsdcStroops),
  'wallet': agent.wallet,
  'model': agent.model,
  'rating': agent.rating,
  'paidHireCount': agent.paidHireCount,
};

/// [url] without its user info, so a `https://user:token@host/` never
/// reaches the client in an error. Text that is not a URL stays as it is.
String redactedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.userInfo.isEmpty) return url;
  return uri.replace(userInfo: '').toString();
}

CallToolResult _json(Object value) =>
    CallToolResult(content: [TextContent(text: jsonEncode(value))]);

CallToolResult _error(String code, String message) => CallToolResult(
  isError: true,
  content: [TextContent(text: 'error: $code: $message')],
);
