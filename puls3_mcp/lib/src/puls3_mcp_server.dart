import 'dart:async';
import 'dart:convert';
import 'dart:io' show FileSystemException, IOException, stderr;

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

/// The environment variable with the public address of the session wallet,
/// which `hire_get` uses when the call names no wallet. It is not a secret.
const walletVariable = 'PULS3_WALLET';

/// What the hire and Studio tools answer when the server has no session.
const sessionMissing =
    'This tool needs a wallet session. In the app at https://puls3.org/, '
    'open the wallet sheet and use "Copy session for CLI". Then set '
    '$refreshTokenVariable for this server once and restart it '
    '(docs/mcp/setup.md).';

/// What they answer when the server refuses the session.
const sessionRefused =
    'The server refused the wallet session: it ended (72 hours after the '
    'app created it) or it was revoked. Copy a new session for the CLI from '
    'the app, set $refreshTokenVariable and restart this server.';

/// A stdio MCP server over [Puls3Sdk].
///
/// Every tool reads or prepares. None signs, funds, approves, rejects,
/// rates or submits a transaction: a prepared envelope is returned unsigned
/// for a wallet to sign, never sent.
base class Puls3McpServer extends MCPServer with ToolsSupport {
  Puls3McpServer(
    super.channel, {
    required this.sdk,
    required String apiUrl,
    String? wallet,
  }) : apiUrl = redactedUrl(apiUrl),
       wallet = (wallet ?? '').trim().isEmpty ? null : wallet!.trim(),
       super.fromStreamChannel(
         implementation: Implementation(name: 'puls3', version: '0.1.0'),
         instructions:
             'Reads the puls3 agent catalog on Stellar testnet and, with a '
             'wallet session, reads a hire, prepares its approve or reject '
             'and runs a Studio draft. The tools never sign or submit a '
             'transaction: a prepared envelope is for the wallet to sign in '
             'the app.',
       ) {
    registerTool(_catalogList, _onCatalogList);
    registerTool(_catalogGet, _onCatalogGet);
    registerTool(_hireGet, _onHireGet);
    registerTool(_hirePrepareComplete, _onHirePrepareComplete);
    registerTool(_hirePrepareReject, _onHirePrepareReject);
    registerTool(_studioTestRun, _onStudioTestRun);
  }

  /// The SDK the tools call. The caller owns it and closes it.
  final Puls3Sdk sdk;

  /// The server URL, as the errors name it, without any user info.
  final String apiUrl;

  /// The session wallet's public address ([walletVariable]), which `hire_get`
  /// uses when the call names none.
  final String? wallet;

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
        'One hire of the session wallet: status, agent, price, input, '
        'result and deadlines. Needs a wallet session.',
    inputSchema: Schema.object(
      properties: {
        'hireId': Schema.int(description: 'The hire id.'),
        'wallet': Schema.string(
          description:
              'The session wallet (G...). Optional when the server was '
              'started with PULS3_WALLET.',
        ),
      },
      required: ['hireId'],
    ),
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: true),
  );

  final _hirePrepareComplete = Tool(
    name: 'hire_prepare_complete',
    description:
        'Prepares the unsigned escrow `complete` (approve) of a hire, for a '
        'wallet to sign. It does not sign or send it: approve in the app. '
        'Needs a wallet session.',
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
        'sign. It does not sign or send it: reject in the app. Needs a '
        'wallet session.',
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
        'draft id is required; there is no default draft. It uses one of '
        'the daily test runs of the builder. Needs a wallet session.',
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

  Future<CallToolResult> _onHireGet(CallToolRequest request) =>
      _guard(() async {
        final hireId = _int(request, 'hireId');
        if (hireId == null) return _error('Usage', 'hire_get needs a hireId.');
        final named = (request.arguments?['wallet'] as String? ?? '').trim();
        final consumer = named.isEmpty ? wallet : named;
        // Without a session the missing session is the thing to fix first.
        if (!sdk.hasSession) throw const SessionRequired('getHire');
        if (consumer == null) {
          return _error(
            'Usage',
            'hire_get needs the session wallet: pass wallet, or start the '
                'server with $walletVariable.',
          );
        }
        return _json(hireJson(await sdk.getHire(hireId, consumer)));
      });

  Future<CallToolResult> _onHirePrepareComplete(CallToolRequest request) =>
      _guard(() async {
        final hireId = _int(request, 'hireId');
        if (hireId == null) {
          return _error('Usage', 'hire_prepare_complete needs a hireId.');
        }
        return _json(preparedJson(await sdk.prepareComplete(hireId)));
      });

  Future<CallToolResult> _onHirePrepareReject(CallToolRequest request) =>
      _guard(() async {
        final hireId = _int(request, 'hireId');
        final reason = (request.arguments?['reason'] as String? ?? '').trim();
        if (hireId == null || reason.isEmpty) {
          return _error(
            'Usage',
            'hire_prepare_reject needs a hireId and a reason.',
          );
        }
        return _json(preparedJson(await sdk.prepareReject(hireId, reason)));
      });

  Future<CallToolResult> _onStudioTestRun(CallToolRequest request) =>
      _guard(() async {
        final draftId = _int(request, 'draftId');
        final input = request.arguments?['input'] as String? ?? '';
        if (draftId == null || input.trim().isEmpty) {
          return _error(
            'Usage',
            'studio_test_run needs a draftId and an input.',
          );
        }
        final run = await sdk.testRun(draftId, input);
        return _json({
          'output': run.output,
          'remainingDailyRuns': run.remainingDailyRuns,
        });
      });

  /// The whole-number argument [name], or null when it is missing or is not
  /// a whole number.
  static int? _int(CallToolRequest request, String name) {
    final value = request.arguments?[name];
    if (value is int) return value;
    if (value is num && value == value.truncate()) return value.toInt();
    return null;
  }

  /// Maps the SDK's errors to a tool error, never a stack trace.
  Future<CallToolResult> _guard(Future<CallToolResult> Function() call) async {
    try {
      return await call();
    } on SessionRequired {
      return _error('SessionUnavailable', sessionMissing);
    } on ArgumentError catch (e) {
      // The SDK refused an argument before calling the server.
      return _error('Usage', '${e.name ?? 'argument'} ${e.message}');
    } on Puls3ApiException catch (e) {
      return _error(e.code, e.message ?? '');
    } on AgentCatalogUnavailable catch (e) {
      return _error('AgentCatalogUnavailable', e.message);
    } on ServerpodClientUnauthorized {
      return _error('SessionExpired', sessionRefused);
    } on ServerpodClientException catch (e) {
      return _error('Unreachable', '$apiUrl: ${e.message}');
    } on FileSystemException catch (e) {
      // The session file could not be read or written. Its path is not a
      // secret; its content never reaches an error.
      return _error('SessionFile', '${e.message}: ${e.path ?? '-'}');
    } on IOException catch (e) {
      return _error('Unreachable', '$apiUrl: $e');
    } catch (e, stack) {
      // Anything else (a StateError, a response the client cannot read):
      // dart_mcp would return '$e\n$stack' to the client. The detail goes
      // to stderr for whoever runs the server, never to the client.
      stderr.writeln(
        redactedTokens('puls3_mcp: unexpected ${e.runtimeType}: $e\n$stack'),
      );
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

/// The fields `hire_get` returns, the same as `puls3 hire get --json`.
Map<String, Object?> hireJson(HireDetail detail) => {
  'id': detail.hire.id,
  'status': detail.hire.status ?? 'open',
  'agentId': detail.agent.id,
  'agentName': detail.agent.name,
  'consumer': detail.hire.consumer,
  'priceUsdcStroops': detail.hire.price,
  'priceUsdc': formatUsdc(detail.hire.price),
  'jobId': detail.jobId,
  'expiresAt': _iso(detail.expiresAt),
  'approvalDeadline': _iso(detail.approvalDeadline),
  'input': detail.input,
  'result': detail.result,
  'rejectReason': detail.rejectReason,
  'paymentExplorerUrl': detail.paymentExplorerUrl,
};

/// The fields the prepare tools return: an envelope for the wallet named in
/// `signer`. `submitted` is always false, because this server sends nothing.
Map<String, Object?> preparedJson(PreparedTransaction prepared) => {
  'preparationId': prepared.preparationId,
  'purpose': prepared.purpose,
  'signer': prepared.signer,
  'networkPassphrase': prepared.networkPassphrase,
  'unsignedTransactionXdr': prepared.unsignedTransactionXdr,
  'expiresAt': _iso(prepared.expiresAt),
  'submitted': false,
  'next':
      'Not signed and not sent. Approve or reject in the app at '
      'https://puls3.org/, where the wallet signs.',
};

String? _iso(DateTime? time) => time?.toUtc().toIso8601String();

/// [url] without its user info, so a `https://user:token@host/` never
/// reaches the client in an error. Text that is not a URL stays as it is.
String redactedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.userInfo.isEmpty) return url;
  return uri.replace(userInfo: '').toString();
}

/// [text] with every refresh token (`sajrt:…`) and bearer token replaced,
/// so a token quoted by an unexpected error never reaches the log.
String redactedTokens(String text) => text
    .replaceAll(RegExp(r'sajrt:[A-Za-z0-9+/=:_-]+'), 'sajrt:[redacted]')
    .replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      'Bearer [redacted]',
    );

CallToolResult _json(Object value) =>
    CallToolResult(content: [TextContent(text: jsonEncode(value))]);

CallToolResult _error(String code, String message) => CallToolResult(
  isError: true,
  content: [TextContent(text: 'error: $code: $message')],
);
