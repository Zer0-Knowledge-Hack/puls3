import 'dart:async';

import 'runtime_task.dart';

export 'runtime_task.dart' show ModelRuntime;

/// Runs one task on a [ModelRuntime] with the rules that hold for every
/// provider: the manifest's input and output limits (ADR-0004) and the
/// runtime timeout, which must end before the job's `expired_at`
/// (ADR-0005 D3, D4).
final class AgentRunner {
  /// [timeout] has no default: the composition root reads it from
  /// `RuntimeConfig`.
  AgentRunner({required ModelRuntime runtime, required Duration timeout})
    : _runtime = runtime,
      _timeout = timeout;

  final ModelRuntime _runtime;
  final Duration _timeout;

  /// The output for [task], or a [RuntimeFailure]. Input over the limit fails
  /// before the model is called. On timeout the provider call is aborted, not
  /// just abandoned, so it stops being billed.
  Future<String> run(RuntimeTask task) async {
    if (task.input.length > task.maxInputChars) {
      throw RuntimeInputTooLong(task.input.length, task.maxInputChars);
    }
    final abort = Completer<void>();
    final call = _runtime.complete(task, abortTrigger: abort.future);
    final String output;
    try {
      output = await call.timeout(_timeout);
    } on TimeoutException {
      // The aborted call then fails on its own; `timeout` already listens to
      // it, so that late error is not unhandled.
      abort.complete();
      throw RuntimeTimedOut(_timeout);
    }
    if (output.trim().isEmpty) throw const RuntimeEmptyOutput();
    if (output.length > task.maxOutputChars) {
      throw RuntimeOutputTooLong(output.length, task.maxOutputChars);
    }
    return output;
  }
}
