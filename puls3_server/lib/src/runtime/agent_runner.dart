import 'dart:async';

import 'conversation.dart';

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

  /// The longest one run may take.
  Duration get timeout => _timeout;

  /// The output for [task], or a [RuntimeFailure]. Input over the limit fails
  /// before the model is called. On timeout the provider call is aborted, not
  /// just abandoned, so it stops being billed.
  ///
  /// Lengths are counted in runes, like every manifest limit in the domain:
  /// an emoji is one character, not two UTF-16 units.
  Future<String> run(RuntimeTask task) async {
    final inputLength = task.input.runes.length;
    if (inputLength > task.maxInputChars) {
      throw RuntimeInputTooLong(inputLength, task.maxInputChars);
    }
    final output = await _withinTimeout(
      (abort) => _runtime.complete(task, abortTrigger: abort),
    );
    _checkText(output, task.maxOutputChars);
    return output;
  }

  /// One model turn of a conversation (ADR-0011 D8), under the same rules as
  /// [run]: the per-segment timeout aborts the call; the conversation's
  /// [ConversationTask.conversationLength] must fit `maxInputChars` before
  /// the call; a final text must be non-blank and fit `maxOutputChars`, and
  /// so must the tool calls of a [ToolCallsTurn] (names plus encoded
  /// arguments). A runtime that is not a [ConversationRuntime] fails as
  /// `tools_unsupported`. [run] is unchanged.
  Future<ModelTurn> converseOnce(ConversationTask task) async {
    final runtime = _runtime;
    if (runtime is! ConversationRuntime) {
      throw const RuntimeToolsUnsupported();
    }
    final inputLength = task.conversationLength;
    if (inputLength > task.maxInputChars) {
      throw RuntimeInputTooLong(inputLength, task.maxInputChars);
    }
    final turn = await _withinTimeout(
      (abort) => runtime.converse(task, abortTrigger: abort),
    );
    switch (turn) {
      case FinalText(:final text):
        _checkText(text, task.maxOutputChars);
      case ToolCallsTurn(:final length):
        if (length > task.maxOutputChars) {
          throw RuntimeOutputTooLong(length, task.maxOutputChars);
        }
    }
    return turn;
  }

  Future<T> _withinTimeout<T>(Future<T> Function(Future<void> abort) start) {
    final abort = Completer<void>();
    final call = start(abort.future);
    return call.timeout(
      _timeout,
      onTimeout: () {
        // The aborted call then fails on its own; `timeout` already listens
        // to it, so that late error is not unhandled.
        abort.complete();
        throw RuntimeTimedOut(_timeout);
      },
    );
  }

  static void _checkText(String output, int maxOutputChars) {
    if (output.trim().isEmpty) throw const RuntimeEmptyOutput();
    final outputLength = output.runes.length;
    if (outputLength > maxOutputChars) {
      throw RuntimeOutputTooLong(outputLength, maxOutputChars);
    }
  }
}
