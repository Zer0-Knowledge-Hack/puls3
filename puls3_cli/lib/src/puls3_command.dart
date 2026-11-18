import 'dart:async';
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
///
/// It may be asynchronous: the binary opens the wallet session file first.
/// A [FileSystemException] from it (the session file cannot be read or
/// written) exits [ExitCodes.sessionFile].
typedef SdkConnector = FutureOr<Puls3Sdk> Function(Uri apiUrl);

/// Reads a text file. The binary reads the disk; tests pass a fake.
typedef FileReader = Future<String> Function(String path);

/// Reads all of standard input. The binary reads stdin; tests pass a fake.
typedef StdinReader = Future<String> Function();

/// The environment variable read when `--api` is not given.
const apiUrlVariable = 'PULS3_API_URL';

/// The environment variable read when `hire get` has no `--wallet`: the
/// public address of the session wallet. It is not a secret.
const walletVariable = 'PULS3_WALLET';

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

  /// A hire or Studio command has no wallet session, or the server refused
  /// the one it has (expired or revoked).
  static const noSession = 77;

  /// The wallet session file (`PULS3_SESSION_FILE`) could not be read or
  /// written.
  static const sessionFile = 74;

  /// `run`: the model provider credential is not set in the environment.
  static const missingCredential = 78;
}

/// Runs `puls3` with [arguments] and returns the exit code.
///
/// Success writes to [out]. Every failure writes one `error: <code>: ...`
/// line to [err], plus the usage for a usage error, and nothing to [out].
/// The command never signs or submits a transaction: `hire prepare-complete`
/// and `hire prepare-reject` print the unsigned envelope for the wallet to
/// sign.
///
/// `run` calls the model provider through [httpClient] (a new client when
/// null) and reads files and stdin through [readFile] and [readStdin].
///
/// Text from the server or an agent (names, descriptions, inputs, results,
/// reasons, error messages) is untrusted: every line written loses its
/// terminal control and bidi characters first ([printable]), so it cannot
/// move the cursor, clear the screen or disguise itself. `--json` output
/// still carries control characters, escaped by JSON; bidi overrides, which
/// JSON does not escape, are dropped there too.
Future<int> runPuls3(
  List<String> arguments, {
  required SdkConnector connect,
  required Map<String, String> environment,
  required StringSink out,
  required StringSink err,
  http.Client? httpClient,
  FileReader? readFile,
  StdinReader? readStdin,
}) => _run(
  arguments,
  connect: connect,
  environment: environment,
  out: _PrintableSink(out),
  err: _PrintableSink(err),
  httpClient: httpClient,
  readFile: readFile,
  readStdin: readStdin,
);

/// [text] without terminal control characters (C0 except tab and newline,
/// DEL, C1, which includes the escape that starts ANSI sequences) and without
/// bidirectional overrides (U+202A to U+202E, U+2066 to U+2069).
String printable(String text) => text.replaceAll(_unprintable, '');

final _unprintable = RegExp(
  '[\u0000-\u0008\u000B-\u001F\u007F-\u009F'
  '\u202A-\u202E\u2066-\u2069]',
);

/// A [StringSink] that writes [printable] text to another one.
final class _PrintableSink implements StringSink {
  _PrintableSink(this._sink);

  final StringSink _sink;

  @override
  void write(Object? object) => _sink.write(printable('$object'));

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _sink.write(printable(objects.join(separator)));

  @override
  void writeCharCode(int charCode) =>
      _sink.write(printable(String.fromCharCode(charCode)));

  @override
  void writeln([Object? object = '']) => _sink.writeln(printable('$object'));
}

Future<int> _run(
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

  final group = args.command;
  final action = group?.command;
  final help = [args, group, action].any((r) => r?.flag('help') ?? false);
  if (help) {
    out.writeln(_usage(parser));
    return ExitCodes.ok;
  }
  if (group == null) {
    return _usageError(
      err,
      parser,
      args.rest.isEmpty ? 'Missing command.' : 'Unknown command.',
    );
  }
  if (group.name == 'run') {
    return _runLocally(
      group,
      parser,
      json: args.flag('json') || group.flag('json'),
      environment: environment,
      out: out,
      err: err,
      httpClient: httpClient,
      readFile: readFile ?? (path) => File(path).readAsString(),
      readStdin: readStdin ?? () => stdin.transform(utf8.decoder).join(),
    );
  }
  if (action == null) {
    return _usageError(
      err,
      parser,
      group.rest.isEmpty
          ? 'Missing ${group.name} command.'
          : 'Unknown ${group.name} command.',
    );
  }

  final parsed = _callOf(group.name ?? '', action, environment);
  if (parsed is _Invalid) return _usageError(err, parser, parsed.message);
  final call = parsed as _Call;

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
    sdk = await connect(Uri.parse(apiText));
  } on FileSystemException catch (e) {
    err.writeln('error: SessionFile: ${e.message}: ${e.path ?? '-'}');
    return ExitCodes.sessionFile;
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
    return await call.run(sdk, out, err, json);
  } on SessionRequired catch (e) {
    err.writeln(
      'error: SessionRequired: ${e.operation} needs a wallet session. '
      'Copy a session for the CLI from the app and set $refreshTokenVariable.',
    );
    return ExitCodes.noSession;
  } on Puls3ApiException catch (e) {
    err.writeln('error: ${e.code}: ${e.message}');
    return ExitCodes.serverError;
  } on AgentCatalogUnavailable catch (e) {
    err.writeln('error: AgentCatalogUnavailable: ${e.message}');
    return ExitCodes.unavailable;
  } on ServerpodClientUnauthorized {
    // The server refused the session: expired, revoked, or never valid.
    err.writeln(
      'error: Unauthorized: the server refused the wallet session. '
      'Copy a new CLI session from the app.',
    );
    return ExitCodes.noSession;
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

/// What runs once the SDK is open: it writes the result and returns the exit
/// code.
typedef _Run =
    Future<int> Function(
      Puls3Sdk sdk,
      StringSink out,
      StringSink err,
      bool json,
    );

/// A checked command line: a usage error, or the call to make.
sealed class _Parsed {}

final class _Invalid extends _Parsed {
  _Invalid(this.message);

  final String message;
}

final class _Call extends _Parsed {
  _Call(this.run);

  final _Run run;
}

/// Checks the arguments of `<group> <action>` before anything is opened, so
/// a usage error never reaches the server.
_Parsed _callOf(
  String group,
  ArgResults action,
  Map<String, String> environment,
) {
  final rest = action.rest;
  switch ((group, action.name)) {
    case ('catalog', 'list'):
      if (rest.isNotEmpty) {
        return _Invalid('`catalog list` takes no argument.');
      }
      return _Call((sdk, out, err, json) async {
        _printList(out, await sdk.listAgents(), json: json);
        return ExitCodes.ok;
      });

    case ('catalog', 'get'):
      if (rest.length != 1 || rest.single.trim().isEmpty) {
        return _Invalid('`catalog get` takes one agent id.');
      }
      final id = rest.single.trim();
      return _Call((sdk, out, err, json) async {
        final agent = await sdk.getAgent(id);
        if (agent == null) {
          err.writeln('error: NotFound: no agent with id $id');
          return ExitCodes.notFound;
        }
        _printAgent(out, agent, json: json);
        return ExitCodes.ok;
      });

    case ('hire', 'get'):
      final getId = _positiveId(rest);
      if (getId == null) {
        return _Invalid('`hire get` takes one hire id, 1 or more.');
      }
      final wallet =
          (action.option('wallet') ?? environment[walletVariable] ?? '').trim();
      if (wallet.isEmpty) {
        return _Invalid(
          '`hire get` needs the session wallet: pass --wallet or set '
          '$walletVariable.',
        );
      }
      return _Call((sdk, out, err, json) async {
        _printHire(out, await sdk.getHire(getId, wallet), json: json);
        return ExitCodes.ok;
      });

    case ('hire', 'prepare-complete'):
      final completeId = _positiveId(rest);
      if (completeId == null) {
        return _Invalid(
          '`hire prepare-complete` takes one hire id, 1 or more.',
        );
      }
      return _Call((sdk, out, err, json) async {
        _printPrepared(out, await sdk.prepareComplete(completeId), json: json);
        return ExitCodes.ok;
      });

    case ('hire', 'prepare-reject'):
      final rejectId = _positiveId(rest);
      if (rejectId == null) {
        return _Invalid('`hire prepare-reject` takes one hire id, 1 or more.');
      }
      final reason = (action.option('reason') ?? '').trim();
      if (reason.isEmpty) {
        return _Invalid('`hire prepare-reject` needs --reason <text>.');
      }
      return _Call((sdk, out, err, json) async {
        _printPrepared(
          out,
          await sdk.prepareReject(rejectId, reason),
          json: json,
        );
        return ExitCodes.ok;
      });

    case ('studio', 'test-run'):
      if (rest.isNotEmpty) {
        return _Invalid('`studio test-run` takes only --draft and --input.');
      }
      final draftId = _positiveId([action.option('draft') ?? '']);
      if (draftId == null) {
        return _Invalid('`studio test-run` needs --draft <id>, 1 or more.');
      }
      final input = action.option('input') ?? '';
      if (input.trim().isEmpty) {
        return _Invalid('`studio test-run` needs --input <text>.');
      }
      return _Call((sdk, out, err, json) async {
        _printTestRun(out, await sdk.testRun(draftId, input), json: json);
        return ExitCodes.ok;
      });

    case ('studio', 'hire-as'):
      const usage =
          '`studio hire-as` needs --as <agentId> --agent <agentId> '
          '--input <text> --budget <usdc>.';
      if (rest.isNotEmpty) return _Invalid(usage);
      final hiringAgentId = _registryId(action.option('as'));
      final agentId = _registryId(action.option('agent'));
      final input = action.option('input') ?? '';
      final budget = _usdcStroops(action.option('budget'));
      if (hiringAgentId == null ||
          agentId == null ||
          input.trim().isEmpty ||
          budget == null) {
        return _Invalid(usage);
      }
      if (hiringAgentId == agentId) {
        return _Invalid('`studio hire-as`: an agent cannot hire itself.');
      }
      return _Call((sdk, out, err, json) async {
        final started = await sdk.hireAgentAs(
          hiringAgentId,
          agentId,
          input,
          budget,
        );
        _printHireStarted(out, started, agentId, json: json);
        return ExitCodes.ok;
      });
  }
  return _Invalid('Unknown command.');
}

/// [value] as a registry agent id (the contract's u32, from 0), or null.
int? _registryId(String? value) {
  final id = int.tryParse((value ?? '').trim());
  return id != null && id >= 0 && id <= 0xFFFFFFFF ? id : null;
}

/// [value] in USDC (up to 7 decimals) as USDC stroops of 1 or more, or null.
int? _usdcStroops(String? value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,7}))?$').firstMatch(
    (value ?? '').trim(),
  );
  if (match == null) return null;
  final stroops =
      int.parse(match.group(1)!) * 10000000 +
      int.parse((match.group(2) ?? '').padRight(7, '0'));
  return stroops >= 1 ? stroops : null;
}

/// The single argument of [rest] as an id of 1 or more, or null.
int? _positiveId(List<String> rest) {
  if (rest.length != 1) return null;
  final id = int.tryParse(rest.single.trim());
  return id != null && id >= 1 ? id : null;
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
    )
    ..addCommand(
      'hire',
      withHelp()
        ..addCommand(
          'get',
          withHelp()..addOption(
            'wallet',
            valueHelp: 'G...',
            help: 'The session wallet. Defaults to \$$walletVariable.',
          ),
        )
        ..addCommand('prepare-complete', withHelp())
        ..addCommand(
          'prepare-reject',
          withHelp()..addOption(
            'reason',
            valueHelp: 'text',
            help: 'Why the result is rejected.',
          ),
        ),
    )
    ..addCommand(
      'studio',
      withHelp()
        ..addCommand(
          'test-run',
          withHelp()
            ..addOption('draft', valueHelp: 'id', help: 'The saved draft.')
            ..addOption('input', valueHelp: 'text', help: 'The test input.'),
        )
        ..addCommand(
          'hire-as',
          withHelp()
            ..addOption(
              'as',
              valueHelp: 'agentId',
              help: 'Your live Studio agent that hires and pays.',
            )
            ..addOption(
              'agent',
              valueHelp: 'agentId',
              help: 'The catalog agent to hire.',
            )
            ..addOption('input', valueHelp: 'text', help: 'The hire input.')
            ..addOption(
              'budget',
              valueHelp: 'usdc',
              help: 'The most the hiring agent may pay, in USDC.',
            ),
        ),
    );
}

String _usage(ArgParser parser) =>
    '''
Usage: puls3 [--api <url>] [--json] <command>

Commands:
  catalog list                        Every agent in the catalog.
  catalog get <id>                    One agent by its metadata id.
  hire get <id> [--wallet <G...>]     One of the session wallet's hires.
  hire prepare-complete <id>          The unsigned complete of a hire.
  hire prepare-reject <id> --reason <text>
                                      The unsigned reject of a hire.
  studio test-run --draft <id> --input <text>
                                      Runs a saved draft once.
  studio hire-as --as <agentId> --agent <agentId> --input <text> --budget <usdc>
                                      Your live Studio agent hires and pays
                                      another agent with its custodied
                                      wallet. The server signs and runs it.
  run --manifest <file.json> (--input <text> | --input-file <path>)
                                      Runs an agent locally with your own
                                      model credential (CLOUDFLARE_ACCOUNT_ID
                                      and CLOUDFLARE_API_TOKEN, or
                                      ANTHROPIC_API_KEY). No server, no
                                      transaction.

Options:
${parser.usage}

puls3 never signs or submits a transaction: the prepare commands print the
unsigned envelope for the wallet to sign. Hire and Studio commands need a
wallet session from the app.
Exit codes: 0 ok, 1 server or model error, 3 not found, 64 usage,
65 invalid manifest or input, 66 unreadable file, 69 unavailable,
74 session file, 77 no session, 78 missing model credential.

Hire and Studio commands use the wallet session in \$PULS3_SESSION_FILE
(default ~/.config/puls3/session.json), seeded once from
\$PULS3_REFRESH_TOKEN: copy it from the app's wallet sheet.''';

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

void _printHire(StringSink out, HireDetail detail, {required bool json}) {
  if (json) {
    out.writeln(jsonEncode(_hireJson(detail)));
    return;
  }
  final hire = detail.hire;
  out
    ..writeln('hire ${hire.id}  ${_status(detail)}')
    ..writeln('agent        ${detail.agent.id}  ${detail.agent.name}')
    ..writeln('price        ${formatUsdc(hire.price)} USDC')
    ..writeln('job id       ${detail.jobId ?? '-'}')
    ..writeln('expires      ${_time(detail.expiresAt)}')
    ..writeln('approve by   ${_time(detail.approvalDeadline)}')
    ..writeln('payment      ${detail.paymentExplorerUrl ?? '-'}');
  final reason = detail.rejectReason;
  if (reason != null) out.writeln('rejected     $reason');
  out
    ..writeln()
    ..writeln('input')
    ..writeln(detail.input);
  final result = detail.result;
  if (result != null) {
    out
      ..writeln()
      ..writeln('result')
      ..writeln(result);
  }
}

/// The hire status as the API names it; a hire with no job yet is `open`.
String _status(HireDetail detail) => detail.hire.status ?? 'open';

/// The fields `--json` prints for a hire.
Map<String, Object?> _hireJson(HireDetail detail) => {
  'id': detail.hire.id,
  'status': _status(detail),
  'agentId': detail.agent.id,
  'agentName': detail.agent.name,
  'consumer': detail.hire.consumer,
  'priceUsdcStroops': detail.hire.price,
  'jobId': detail.jobId,
  'expiresAt': _isoOrNull(detail.expiresAt),
  'approvalDeadline': _isoOrNull(detail.approvalDeadline),
  'input': detail.input,
  'result': detail.result,
  'rejectReason': detail.rejectReason,
  'paymentExplorerUrl': detail.paymentExplorerUrl,
};

void _printPrepared(
  StringSink out,
  PreparedTransaction prepared, {
  required bool json,
}) {
  if (json) {
    out.writeln(jsonEncode(_preparedJson(prepared)));
    return;
  }
  out
    ..writeln('preparation  ${prepared.preparationId}')
    ..writeln('purpose      ${prepared.purpose}')
    ..writeln('signer       ${prepared.signer}')
    ..writeln('network      ${prepared.networkPassphrase}')
    ..writeln('expires      ${_time(prepared.expiresAt)}')
    ..writeln()
    ..writeln('unsigned transaction (not signed, not submitted):')
    ..writeln(prepared.unsignedTransactionXdr ?? '-');
}

/// The fields `--json` prints for a prepared transaction.
Map<String, Object?> _preparedJson(PreparedTransaction prepared) => {
  'preparationId': prepared.preparationId,
  'purpose': prepared.purpose,
  'signer': prepared.signer,
  'networkPassphrase': prepared.networkPassphrase,
  'unsignedTransactionXdr': prepared.unsignedTransactionXdr,
  'expiresAt': _isoOrNull(prepared.expiresAt),
};

void _printHireStarted(
  StringSink out,
  AgentHireStarted started,
  int agentId, {
  required bool json,
}) {
  if (json) {
    out.writeln(
      jsonEncode({
        'hireId': started.hireId,
        'hiringWallet': started.hiringWallet,
        'state': started.state,
      }),
    );
    return;
  }
  out
    ..writeln('Hire ${started.hireId} of agent $agentId ${started.state}.')
    ..writeln('Paid by ${started.hiringWallet} (custodied, server-signed).')
    ..writeln(
      'create_job, fund, the agent\'s submit and complete follow on the '
      'server; their tx hashes are in the server log ([agent-hire]) and on '
      'stellar.expert for ${started.hiringWallet}.',
    );
}

void _printTestRun(StringSink out, TestRunResult run, {required bool json}) {
  if (json) {
    out.writeln(
      jsonEncode({
        'output': run.output,
        'remainingDailyRuns': run.remainingDailyRuns,
      }),
    );
    return;
  }
  final left = run.remainingDailyRuns == 1
      ? '1 test run left today'
      : '${run.remainingDailyRuns} test runs left today';
  out
    ..writeln(run.output)
    ..writeln()
    ..writeln(left);
}

String _time(DateTime? time) => _isoOrNull(time) ?? '-';

String? _isoOrNull(DateTime? time) => time?.toUtc().toIso8601String();

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
