import 'dart:convert';
import 'dart:io' show IOException, OSError, SocketException, TlsException;

import 'package:args/args.dart';
import 'package:puls3_sdk/puls3_sdk.dart';

/// Opens an SDK on the server at an API URL. The binary passes
/// [Puls3Sdk.connect]; tests pass a fake.
typedef SdkConnector = Puls3Sdk Function(Uri apiUrl);

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

  /// The server could not be reached, or the catalog is down.
  static const unavailable = 69;

  /// A hire or Studio command has no wallet session, or the server refused
  /// the one it has (expired or revoked).
  static const noSession = 77;
}

/// Runs `puls3` with [arguments] and returns the exit code.
///
/// Success writes to [out]. Every failure writes one `error: <code>: ...`
/// line to [err], plus the usage for a usage error, and nothing to [out].
/// The command never signs or submits a transaction: `hire prepare-complete`
/// and `hire prepare-reject` print the unsigned envelope for the wallet to
/// sign.
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
    return await call.run(sdk, out, err, json);
  } on SessionRequired catch (e) {
    err.writeln(
      'error: SessionRequired: ${e.operation} needs a wallet session. '
      'Copy a CLI session from the app (#259).',
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
        return _Invalid('`hire prepare-complete` takes one hire id, 1 or more.');
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
  }
  return _Invalid('Unknown command.');
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
      withHelp()..addCommand(
        'test-run',
        withHelp()
          ..addOption('draft', valueHelp: 'id', help: 'The saved draft.')
          ..addOption('input', valueHelp: 'text', help: 'The test input.'),
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

Options:
${parser.usage}

puls3 never signs or submits a transaction: the prepare commands print the
unsigned envelope for the wallet to sign. Hire and Studio commands need a
wallet session from the app (#259).
Exit codes: 0 ok, 1 server error, 3 not found, 64 usage, 69 unavailable,
77 no session.''';

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
