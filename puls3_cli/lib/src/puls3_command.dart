import 'dart:convert';
import 'dart:io'
    show
        File,
        FileSystemException,
        IOException,
        OSError,
        SocketException,
        TlsException,
        stdin;

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart'
    show AgentManifest, InvalidManifest;
import 'package:puls3_sdk/puls3_sdk.dart';

import 'local_run.dart';

/// Opens an SDK on the server at an API URL. The binary passes
/// [Puls3Sdk.connect]; tests pass a fake.
typedef SdkConnector = Puls3Sdk Function(Uri apiUrl);

/// Reads a text file. The binary reads the disk; tests pass a fake.
typedef FileReader = Future<String> Function(String path);

/// Reads all of standard input. The binary reads stdin; tests pass a fake.
typedef StdinReader = Future<String> Function();

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

  /// `run`: the manifest is invalid, or the input is over its limit.
  static const invalidData = 65;

  /// `run`: the manifest or input file cannot be read.
  static const noInput = 66;

  /// The server or the model provider could not be reached, or the catalog
  /// is down.
  static const unavailable = 69;

  /// `run`: the model provider credential is not set in the environment.
  static const missingCredential = 78;
}

/// Runs `puls3` with [arguments] and returns the exit code.
///
/// Success writes to [out]. Every failure writes one `error: <code>: ...`
/// line to [err], plus the usage for a usage error, and nothing to [out].
/// The command never signs or submits a transaction.
///
/// `run` calls the model provider through [httpClient] (a new client when
/// null) and reads files and stdin through [readFile] and [readStdin].
Future<int> runPuls3(
  List<String> arguments, {
  required SdkConnector connect,
  required Map<String, String> environment,
  required StringSink out,
  required StringSink err,
  http.Client? httpClient,
  FileReader? readFile,
  StdinReader? readStdin,
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
  if (catalog.name == 'run') {
    return _runLocally(
      catalog,
      parser,
      json: args.flag('json') || catalog.flag('json'),
      environment: environment,
      out: out,
      err: err,
      httpClient: httpClient,
      readFile: readFile ?? (path) => File(path).readAsString(),
      readStdin: readStdin ?? () => stdin.transform(utf8.decoder).join(),
    );
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
  } on IOException catch (e) {
    // Below the client: a TLS handshake the machine refuses (for example a
    // certificate it does not trust) or a socket error. Same exit as above,
    // never a stack trace.
    err.writeln('error: Unreachable: $apiText: ${_ioMessage(e)}');
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
    )
    ..addCommand(
      'run',
      withHelp()
        ..addOption(
          'manifest',
          valueHelp: 'file.json',
          help: 'The agent manifest to run.',
        )
        ..addOption(
          'input',
          valueHelp: 'text',
          help: 'The input text, or - to read it from stdin.',
        )
        ..addOption(
          'input-file',
          valueHelp: 'path',
          help: 'Read the input from a file, or - for stdin.',
        )
        ..addFlag(
          'json',
          negatable: false,
          help: 'Print the result as JSON instead of text.',
        ),
    );
}

String _usage(ArgParser parser) =>
    '''
Usage: puls3 [--api <url>] [--json] <command>

Commands:
  catalog list        Every agent in the catalog.
  catalog get <id>    One agent by its metadata id, for example agt-001.
  run --manifest <file.json> (--input <text> | --input-file <path>)
                      Run an agent locally with your own model credential
                      (CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN, or
                      ANTHROPIC_API_KEY). No server, no transaction.

Options:
${parser.usage}

puls3 reads; it never signs or submits a transaction. Hire and Studio
commands wait for the session decision in docs/adr/0007-developer-sdk.md.
Exit codes: 0 ok, 1 server or model error, 3 not found, 64 usage,
65 invalid manifest or input, 66 unreadable file, 69 unavailable,
78 missing model credential.''';

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

/// The message of a TLS or socket failure, with the OS reason when there is
/// one (for example `CERTIFICATE_VERIFY_FAILED: self signed certificate`).
String _ioMessage(IOException e) {
  final (String message, OSError? os) = switch (e) {
    TlsException() => (e.message, e.osError),
    SocketException() => (e.message, e.osError),
    _ => ('$e', null),
  };
  final reason = os?.message.trim() ?? '';
  return reason.isEmpty ? message : '$message: $reason';
}

/// `puls3 run`: runs an agent manifest on this machine with the builder's
/// own model credential. It never opens the puls3 server and never sends a
/// transaction.
Future<int> _runLocally(
  ArgResults run,
  ArgParser parser, {
  required bool json,
  required Map<String, String> environment,
  required StringSink out,
  required StringSink err,
  required http.Client? httpClient,
  required FileReader readFile,
  required StdinReader readStdin,
}) async {
  final positional = run.rest;
  final manifestOption = run.option('manifest');
  if (positional.length > 1 ||
      (manifestOption != null && positional.isNotEmpty)) {
    return _usageError(err, parser, '`run` takes one manifest file.');
  }
  final manifestPath = (manifestOption ?? positional.firstOrNull ?? '').trim();
  if (manifestPath.isEmpty) {
    return _usageError(err, parser, 'Pass --manifest <file.json>.');
  }
  final inputText = run.option('input');
  final inputPath = run.option('input-file');
  if ((inputText == null) == (inputPath == null)) {
    return _usageError(
      err,
      parser,
      'Pass exactly one of --input <text> and --input-file <path>.',
    );
  }

  int fail(String code, String message, int exit) {
    err.writeln('error: $code: $message');
    return exit;
  }

  final String manifestText;
  try {
    manifestText = await readFile(manifestPath);
  } on FileSystemException catch (e) {
    return fail(
      'ManifestUnreadable',
      '$manifestPath: ${e.osError?.message ?? e.message}',
      ExitCodes.noInput,
    );
  }
  final AgentManifest manifest;
  try {
    manifest = parseLocalManifest(jsonDecode(manifestText));
  } on FormatException catch (e) {
    return fail(
      'InvalidManifest',
      '$manifestPath is not JSON: ${e.message}',
      ExitCodes.invalidData,
    );
  } on InvalidManifest catch (e) {
    return fail('InvalidManifest', e.message, ExitCodes.invalidData);
  }

  final String input;
  if (inputText == '-' || inputPath == '-') {
    input = await readStdin();
  } else if (inputText != null) {
    input = inputText;
  } else {
    try {
      input = await readFile(inputPath!);
    } on FileSystemException catch (e) {
      return fail(
        'InputUnreadable',
        '$inputPath: ${e.osError?.message ?? e.message}',
        ExitCodes.noInput,
      );
    }
  }

  // Checked before the credential, so a builder sees it without one.
  final inputChars = input.runes.length;
  if (inputChars > manifest.inputMaxChars) {
    return fail(
      'InputTooLong',
      'the input is $inputChars characters; '
          'the manifest allows ${manifest.inputMaxChars}',
      ExitCodes.invalidData,
    );
  }

  final provider = manifest.model.provider;
  final (credential, missing) = Credential.read(provider, environment);
  if (credential == null) {
    if (missing.isEmpty) {
      return fail(
        'UnsupportedProvider',
        'puls3 run cannot call $provider',
        ExitCodes.invalidData,
      );
    }
    return fail(
      'MissingCredential',
      '$provider runs with your own credential: set ${missing.join(' and ')}',
      ExitCodes.missingCredential,
    );
  }

  final client = httpClient ?? http.Client();
  final watch = Stopwatch()..start();
  final String output;
  try {
    output = await runManifestLocally(
      manifest,
      input,
      credential: credential,
      client: client,
    );
  } on LocalRunFailure catch (e) {
    return fail(
      e.code,
      e.message,
      e.unreachable ? ExitCodes.unavailable : ExitCodes.serverError,
    );
  } finally {
    // An injected client belongs to the caller.
    if (httpClient == null) client.close();
  }
  watch.stop();

  if (json) {
    out.writeln(
      jsonEncode({
        'output': output,
        'model': '$provider/${manifest.model.id}',
        'inputChars': inputChars,
        'outputChars': output.runes.length,
        'elapsedMs': watch.elapsedMilliseconds,
      }),
    );
  } else {
    out.writeln(output);
  }
  return ExitCodes.ok;
}
