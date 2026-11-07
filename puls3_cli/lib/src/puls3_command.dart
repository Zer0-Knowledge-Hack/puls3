import 'dart:convert';

import 'package:args/args.dart';
import 'package:puls3_sdk/puls3_sdk.dart';

/// Opens an SDK on the server at an API URL. The binary passes
/// [Puls3Sdk.connect]; tests pass a fake.
typedef SdkConnector = Puls3Sdk Function(Uri apiUrl);

/// The environment variable read when `--api` is not given.
const apiUrlVariable = 'PULS3_API_URL';

/// The exit codes of `puls3`. `docs/cli/reference.md` lists them.
abstract final class ExitCodes {
  /// The command succeeded.
  static const ok = 0;

  /// The server answered with an error code (`Puls3ApiException`).
  static const serverError = 1;

  /// The id names nothing on the server.
  static const notFound = 3;

  /// The command line is wrong: unknown command, missing argument or API URL.
  static const usage = 64;

  /// The server could not be reached, or the catalog is down.
  static const unavailable = 69;
}

/// Runs `puls3` with [arguments] and returns the exit code.
///
/// Success writes to [out]. Every failure writes one `error: <code>: ...`
/// line to [err], plus the usage for a usage error, and nothing to [out].
/// The command never signs or submits a transaction.
Future<int> runPuls3(
  List<String> arguments, {
  required SdkConnector connect,
  required Map<String, String> environment,
  required StringSink out,
  required StringSink err,
}) async {
  final parser = _parser();
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    return _usageError(err, parser, e.message);
  }

  final catalog = args.command;
  final action = catalog?.command;
  final help = [args, catalog, action].any((r) => r?.flag('help') ?? false);
  if (help) {
    out.writeln(_usage(parser));
    return ExitCodes.ok;
  }
  if (catalog == null) {
    return _usageError(err, parser, 'Missing command.');
  }
  if (action == null) {
    return _usageError(err, parser, 'Missing catalog command.');
  }

  final String? id;
  switch (action.name) {
    case 'list':
      if (action.rest.isNotEmpty) {
        return _usageError(err, parser, '`catalog list` takes no argument.');
      }
      id = null;
    case 'get':
      if (action.rest.length != 1 || action.rest.single.trim().isEmpty) {
        return _usageError(err, parser, '`catalog get` takes one agent id.');
      }
      id = action.rest.single.trim();
    default:
      return _usageError(err, parser, 'Unknown command.');
  }

  final apiText = (args.option('api') ?? environment[apiUrlVariable] ?? '')
      .trim();
  if (apiText.isEmpty) {
    return _usageError(
      err,
      parser,
      'Pass --api or set $apiUrlVariable to the puls3 server URL.',
    );
  }
  final Puls3Sdk sdk;
  try {
    sdk = connect(Uri.parse(apiText));
  } on FormatException {
    return _usageError(err, parser, 'The API URL is not a URL: $apiText');
  } on ArgumentError {
    return _usageError(
      err,
      parser,
      'The API URL must be an absolute http or https URL: $apiText',
    );
  }

  final json = args.flag('json');
  try {
    if (id == null) {
      _printList(out, await sdk.listAgents(), json: json);
      return ExitCodes.ok;
    }
    final agent = await sdk.getAgent(id);
    if (agent == null) {
      err.writeln('error: NotFound: no agent with id $id');
      return ExitCodes.notFound;
    }
    _printAgent(out, agent, json: json);
    return ExitCodes.ok;
  } on Puls3ApiException catch (e) {
    err.writeln('error: ${e.code}: ${e.message}');
    return ExitCodes.serverError;
  } on AgentCatalogUnavailable catch (e) {
    err.writeln('error: AgentCatalogUnavailable: ${e.message}');
    return ExitCodes.unavailable;
  } on ServerpodClientException catch (e) {
    // Not reached, timed out, or an HTTP error before any endpoint answered.
    err.writeln('error: Unreachable: $apiText: ${e.message}');
    return ExitCodes.unavailable;
  } finally {
    sdk.close();
  }
}

ArgParser _parser() {
  ArgParser withHelp() => ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage.');

  return withHelp()
    ..addOption(
      'api',
      valueHelp: 'url',
      help: 'The puls3 server URL. Defaults to \$$apiUrlVariable.',
    )
    ..addFlag(
      'json',
      negatable: false,
      help: 'Print the result as JSON instead of text.',
    )
    ..addCommand(
      'catalog',
      withHelp()
        ..addCommand('list', withHelp())
        ..addCommand('get', withHelp()),
    );
}

String _usage(ArgParser parser) =>
    '''
Usage: puls3 [--api <url>] [--json] <command>

Commands:
  catalog list        Every agent in the catalog.
  catalog get <id>    One agent by its metadata id, for example agt-001.

Options:
${parser.usage}

puls3 reads; it never signs or submits a transaction. Hire and Studio
commands wait for the session decision in docs/adr/0007-developer-sdk.md.
Exit codes: 0 ok, 1 server error, 3 not found, 64 usage, 69 unavailable.''';

int _usageError(StringSink err, ArgParser parser, String message) {
  err
    ..writeln('error: Usage: $message')
    ..writeln()
    ..writeln(_usage(parser));
  return ExitCodes.usage;
}

void _printList(
  StringSink out,
  List<AgentSummary> agents, {
  required bool json,
}) {
  if (json) {
    out.writeln(jsonEncode([for (final agent in agents) _toJson(agent)]));
    return;
  }
  out.writeln('${agents.length} ${agents.length == 1 ? 'agent' : 'agents'}');
  for (final agent in agents) {
    out.writeln(
      '${agent.id.padRight(10)} #${agent.registryId.toString().padRight(4)} '
      '${formatUsdc(agent.priceUsdcStroops).padLeft(10)} USDC  '
      '${agent.rating.toStringAsFixed(1)}  ${agent.name}',
    );
  }
}

void _printAgent(StringSink out, AgentSummary agent, {required bool json}) {
  if (json) {
    out.writeln(jsonEncode(_toJson(agent)));
    return;
  }
  final hires = agent.paidHireCount == 1
      ? '1 paid hire'
      : '${agent.paidHireCount} paid hires';
  out
    ..writeln('${agent.id}  ${agent.name}')
    ..writeln('registry id  ${agent.registryId}')
    ..writeln('price        ${formatUsdc(agent.priceUsdcStroops)} USDC')
    ..writeln('rating       ${agent.rating.toStringAsFixed(1)} ($hires)')
    ..writeln('skills       ${agent.skills.join(', ')}')
    ..writeln('model        ${agent.model ?? '-'}')
    ..writeln('wallet       ${agent.wallet ?? '-'}')
    ..writeln()
    ..writeln(agent.description);
}

/// The fields `--json` prints. Named here so the output does not change when
/// the generated model gains a field.
Map<String, Object?> _toJson(AgentSummary agent) => {
  'id': agent.id,
  'registryId': agent.registryId,
  'name': agent.name,
  'description': agent.description,
  'skills': agent.skills,
  'priceUsdcStroops': agent.priceUsdcStroops,
  'wallet': agent.wallet,
  'model': agent.model,
  'rating': agent.rating,
  'paidHireCount': agent.paidHireCount,
};

/// [stroops] (7 decimals) as a USDC amount with at least two decimals and no
/// trailing zeros past them, without going through a double.
String formatUsdc(int stroops) {
  final sign = stroops < 0 ? '-' : '';
  final value = stroops.abs();
  final whole = value ~/ 10000000;
  var fraction = (value % 10000000).toString().padLeft(7, '0');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '$sign$whole.$fraction';
}
