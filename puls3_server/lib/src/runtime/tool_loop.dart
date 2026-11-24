import 'package:puls3_domain/puls3_domain.dart' show AgentCandidate;

import 'adapters/anthropic_runtime.dart' show AnthropicRuntime;
import 'agent_runner.dart';
import 'conversation.dart';
import 'run_manifest.dart';
import 'subcontract_port.dart';
import 'subcontract_tools.dart';

/// The most model segments one hire's loop may take (ADR-0011 D8).
const defaultMaxLoopTurns = 8;

/// How far tool results may grow the conversation past the manifest's
/// `input.max_chars`, in runes.
const defaultConversationHeadroomChars = 32000;

/// The providers whose adapters hold tool conversations. Workers AI cannot
/// return tool results (T5.1), so it is never offered tools and its hires
/// run plain: subcontracting is Anthropic-only.
const toolCallingProviders = {AnthropicRuntime.provider};

/// One hire's run, as the loop needs it on start and on every resume.
final class ToolLoopRun {
  const ToolLoopRun({
    required this.hireId,
    required this.manifest,
    required this.input,
    required this.expiresAt,
    required this.reserveStroops,
  });

  final int hireId;
  final RunManifest manifest;
  final String input;

  /// The hire's `expired_at`: no segment starts that could end after it.
  final DateTime expiresAt;

  /// The subcontract reserve the hire funded, in stroops.
  final int reserveStroops;
}

/// Everything the loop needs to continue later: what T5.3 persists. The
/// transcript keeps each assistant turn's `providerContent` for replay.
final class ToolLoopState {
  ToolLoopState({
    required List<ConversationMessage> transcript,
    required this.turnsUsed,
    required this.childrenUsed,
    required this.remainingReserveStroops,
    required List<List<AgentCandidate>> searches,
  }) : transcript = List.unmodifiable(transcript),
       searches = List.unmodifiable([
         for (final search in searches)
           List<AgentCandidate>.unmodifiable(search),
       ]);

  /// The conversation, oldest first, starting with the hire input.
  final List<ConversationMessage> transcript;

  /// Model segments taken so far.
  final int turnsUsed;

  /// Children opened so far.
  final int childrenUsed;

  /// The reserve minus the price of every child opened.
  final int remainingReserveStroops;

  /// Every `search_agents` result of this run (D9, D10 snapshots).
  final List<List<AgentCandidate>> searches;
}

/// How a loop segment ended.
sealed class LoopOutcome {
  const LoopOutcome(this.state);

  final ToolLoopState state;

  List<ConversationMessage> get transcript => state.transcript;
  int get turnsUsed => state.turnsUsed;
}

/// The model answered: [text] is the run's output.
final class LoopCompleted extends LoopOutcome {
  const LoopCompleted(this.text, super.state);

  final String text;
}

/// A child hire was opened for the `subcontract` call [pendingToolCallId];
/// the model call has ended, and [ToolLoop.resume] continues with the
/// child's result.
final class LoopAwaitingChild extends LoopOutcome {
  const LoopAwaitingChild(
    super.state, {
    required this.pendingToolCallId,
    required this.childHireId,
    required this.request,
  });

  final String pendingToolCallId;
  final int childHireId;
  final ChildRequest request;
}

/// The loop stopped without an answer. [code] is storable as the hire's
/// `failureReason`: a [RuntimeFailure] code, `max_turns_exceeded` or
/// `deadline_exceeded`. [state] is the conversation up to the last
/// completed segment, so a retry can continue from it
/// ([ToolLoop.continueFrom]).
final class LoopFailed extends LoopOutcome {
  const LoopFailed(this.code, super.state, {this.failure});

  final String code;

  /// The model call's failure, when the loop stopped on one; the runner
  /// decides from it whether the run is retried.
  final RuntimeFailure? failure;
}

/// What the child returned, for [ToolLoop.resume].
sealed class ChildToolResult {
  const ChildToolResult();
}

/// The child delivered [output]; the model sees it as delimited data.
final class ChildDelivered extends ChildToolResult {
  const ChildDelivered(this.output);

  final String output;
}

/// The child ended without a deliverable, for the storable reason [code].
final class ChildFailed extends ChildToolResult {
  const ChildFailed(this.code);

  final String code;
}

/// ADR-0006 D3's bounded tool loop with ADR-0011 D8's subcontract tools,
/// over [AgentRunner.converseOnce]: each segment keeps the runtime timeout
/// and limits. It holds no state between calls and persists nothing.
///
/// Tools are offered only when the manifest opted in
/// ([RunManifest.effectiveMaxChildren] above 0) and its provider is in
/// [toolCallingProviders]; otherwise the loop is one plain [AgentRunner.run],
/// exactly today's run.
final class ToolLoop {
  ToolLoop({
    required AgentRunner runner,
    required SubcontractTools tools,
    DateTime Function() clock = DateTime.now,
    this.maxTurns = defaultMaxLoopTurns,
    this.conversationHeadroomChars = defaultConversationHeadroomChars,
  }) : _runner = runner,
       _tools = tools,
       _clock = clock {
    if (maxTurns < 1) throw ArgumentError.value(maxTurns, 'maxTurns');
  }

  final AgentRunner _runner;
  final SubcontractTools _tools;
  final DateTime Function() _clock;

  /// The most model segments per hire, across every resume.
  final int maxTurns;

  /// See [defaultConversationHeadroomChars].
  final int conversationHeadroomChars;

  /// Whether a run of [manifest] is offered the subcontract tools.
  static bool offersTools(RunManifest manifest) =>
      manifest.effectiveMaxChildren > 0 &&
      toolCallingProviders.contains(manifest.provider);

  /// Runs [run] from its input.
  Future<LoopOutcome> start(ToolLoopRun run) async {
    final transcript = <ConversationMessage>[UserMessage(run.input)];
    final ledger = SubcontractLedger(
      childrenUsed: 0,
      remainingReserveStroops: run.reserveStroops,
      searches: const [],
    );
    LoopFailed fail(String code, [RuntimeFailure? failure]) =>
        LoopFailed(code, _state(transcript, 0, ledger), failure: failure);

    if (_pastDeadline(run)) return fail('deadline_exceeded');
    if (!offersTools(run.manifest)) {
      final String text;
      try {
        text = await _runner.run(run.manifest.task(run.input));
      } on RuntimeFailure catch (failure) {
        return fail(failure.code, failure);
      }
      transcript.add(AssistantMessage(text: text));
      return LoopCompleted(text, _state(transcript, 1, ledger));
    }
    final inputLength = run.input.runes.length;
    if (inputLength > run.manifest.inputMaxChars) {
      return fail(
        RuntimeInputTooLong(inputLength, run.manifest.inputMaxChars).code,
      );
    }
    return _drive(run, transcript, 0, ledger);
  }

  /// Continues [paused] with the child's [result] as the pending call's tool
  /// result, within the turns left.
  Future<LoopOutcome> resume(
    ToolLoopRun run,
    LoopAwaitingChild paused,
    ChildToolResult result,
  ) {
    final state = resumedState(
      paused,
      result,
      maxConversationChars:
          run.manifest.inputMaxChars + conversationHeadroomChars,
    );
    final ledger = SubcontractLedger(
      childrenUsed: state.childrenUsed,
      remainingReserveStroops: state.remainingReserveStroops,
      searches: state.searches,
    );
    return _drive(run, [...state.transcript], state.turnsUsed, ledger);
  }

  /// [paused]'s state with the child's [result] appended as the pending
  /// call's tool result, without calling the model. The runner persists it
  /// as it resumes, so a retry before the next segment ends still continues
  /// from a transcript whose last tool call has its result
  /// ([continueFrom]), and the paid child's output is never lost.
  ///
  /// A delivered output is cut so the whole transcript stays within
  /// [maxConversationChars] (the limit each later segment is checked
  /// against), and the cut is labelled for the model with `truncated` and
  /// `output_runes`. Otherwise a long, heavily escaped output would fail A's
  /// next segment with `input_too_long` after B was already paid.
  static ToolLoopState resumedState(
    LoopAwaitingChild paused,
    ChildToolResult result, {
    required int maxConversationChars,
  }) {
    final state = paused.state;
    final callId = paused.pendingToolCallId;
    final used = state.transcript.fold(
      0,
      (sum, message) => sum + message.length,
    );
    final transcript = [
      ...state.transcript,
      switch (result) {
        ChildDelivered(:final output) => _childOutputResult(
          callId,
          output,
          room: maxConversationChars - used,
        ),
        ChildFailed(:final code) => toolError(
          callId,
          'child_failed',
          'The subcontracted agent did not deliver: $code.',
        ),
      },
    ];
    return ToolLoopState(
      transcript: transcript,
      turnsUsed: state.turnsUsed,
      childrenUsed: state.childrenUsed,
      remainingReserveStroops: state.remainingReserveStroops,
      searches: state.searches,
    );
  }

  /// The tool result for a delivered child [output]: whole when it fits in
  /// [room] characters, else the longest prefix (whole runes) that fits,
  /// labelled as cut. With no room at all the prefix is empty.
  static ToolResultMessage _childOutputResult(
    String callId,
    String output, {
    required int room,
  }) {
    ToolResultMessage message(Map<String, Object?> data) => ToolResultMessage(
      callId: callId,
      content: delimitAsData('child_output', data),
    );
    final whole = message({'output': output});
    if (whole.length <= room) return whole;

    final runes = output.runes.toList();
    ToolResultMessage cut(int keep) => message({
      'output': String.fromCharCodes(runes.take(keep)),
      'truncated': true,
      'output_runes': runes.length,
    });
    // The escaped length grows with the prefix, so the longest fitting
    // prefix is found by bisection.
    var low = 0;
    var high = runes.length;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (cut(mid).length <= room) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return cut(low);
  }

  /// Continues [state] as stored after a retryable [LoopFailed] (T5.3): the
  /// same conversation is sent again, with the turns, children, reserve and
  /// searches it already used, so no segment or child is repeated. A run
  /// that is not offered tools has no conversation to continue and starts.
  Future<LoopOutcome> continueFrom(ToolLoopRun run, ToolLoopState state) {
    if (!offersTools(run.manifest)) return start(run);
    final ledger = SubcontractLedger(
      childrenUsed: state.childrenUsed,
      remainingReserveStroops: state.remainingReserveStroops,
      searches: state.searches,
    );
    return _drive(run, [...state.transcript], state.turnsUsed, ledger);
  }

  Future<LoopOutcome> _drive(
    ToolLoopRun run,
    List<ConversationMessage> transcript,
    int turnsUsed,
    SubcontractLedger ledger,
  ) async {
    final manifest = run.manifest;
    final systemPrompt = '${manifest.systemPrompt}\n\n$dataEnvelopeNote';
    while (true) {
      LoopFailed fail(String code, [RuntimeFailure? failure]) => LoopFailed(
        code,
        _state(transcript, turnsUsed, ledger),
        failure: failure,
      );
      if (turnsUsed >= maxTurns) return fail('max_turns_exceeded');
      if (_pastDeadline(run)) return fail('deadline_exceeded');

      final ModelTurn turn;
      try {
        turn = await _runner.converseOnce(
          ConversationTask(
            provider: manifest.provider,
            modelId: manifest.modelId,
            systemPrompt: systemPrompt,
            messages: transcript,
            tools: subcontractToolSpecs,
            maxInputChars: manifest.inputMaxChars + conversationHeadroomChars,
            maxOutputChars: manifest.outputMaxChars,
          ),
        );
      } on RuntimeFailure catch (failure) {
        return fail(failure.code, failure);
      }
      turnsUsed += 1;

      switch (turn) {
        case FinalText(:final text):
          transcript.add(AssistantMessage(text: text));
          return LoopCompleted(text, _state(transcript, turnsUsed, ledger));
        case ToolCallsTurn(:final calls):
          final earlier = {
            for (final message in transcript)
              if (message is AssistantMessage)
                for (final call in message.toolCalls) call.id,
          };
          final countInTurn = <String, int>{};
          for (final call in calls) {
            countInTurn.update(call.id, (n) => n + 1, ifAbsent: () => 1);
          }
          transcript.add(turn.toMessage());
          // Each call id gets exactly one result in this turn. An id used in
          // an earlier turn, or more than once in this one, runs none of its
          // calls: one duplicate_call_id error answers them all.
          final answered = <String>{};
          String? pendingCallId;
          ChildRequested? pending;
          for (final call in calls) {
            if (!answered.add(call.id)) continue;
            if (earlier.contains(call.id) || countInTurn[call.id]! > 1) {
              transcript.add(
                toolError(
                  call.id,
                  'duplicate_call_id',
                  'Call id ${call.id} was used by more than one call.',
                ),
              );
              continue;
            }
            if (call.name == subcontractToolName) {
              final blocked = _noFollowUp(run, turnsUsed);
              if (blocked != null) {
                transcript.add(blocked(call.id));
                continue;
              }
            }
            final outcome = await _tools.handle(
              call,
              hireId: run.hireId,
              maxChildren: manifest.effectiveMaxChildren,
              ledger: ledger,
              childPending: pending != null,
            );
            switch (outcome) {
              case ToolAnswer(:final result):
                transcript.add(result);
              case ChildRequested():
                pending = outcome;
                pendingCallId = call.id;
            }
          }
          if (pending != null) {
            return LoopAwaitingChild(
              _state(transcript, turnsUsed, ledger),
              pendingToolCallId: pendingCallId!,
              childHireId: pending.childHireId,
              request: pending.request,
            );
          }
      }
    }
  }

  bool _pastDeadline(ToolLoopRun run) =>
      _clock().add(_runner.timeout).isAfter(run.expiresAt);

  /// Why a `subcontract` after [turnsUsed] segments could never be consumed,
  /// as a tool error builder, or `null` when it could.
  ///
  /// A child's output is read only by a resumed segment, which [_drive]
  /// refuses when `turnsUsed >= maxTurns` or [_pastDeadline]. Both are
  /// checked now, before the port opens (and pays for) the child: the turn
  /// count cannot change before the resume, and the clock only moves
  /// forward, so a failing check now fails on resume too. Passing it does
  /// not promise the child finishes in time.
  ToolResultMessage Function(String callId)? _noFollowUp(
    ToolLoopRun run,
    int turnsUsed,
  ) {
    if (turnsUsed >= maxTurns) {
      return (id) => toolError(
        id,
        'no_turns_left',
        'No turn is left to read a subcontract result; answer now.',
      );
    }
    if (_pastDeadline(run)) {
      return (id) => toolError(
        id,
        'no_time_left',
        'Too little time is left to read a subcontract result; answer now.',
      );
    }
    return null;
  }

  static ToolLoopState _state(
    List<ConversationMessage> transcript,
    int turnsUsed,
    SubcontractLedger ledger,
  ) => ToolLoopState(
    transcript: transcript,
    turnsUsed: turnsUsed,
    childrenUsed: ledger.childrenUsed,
    remainingReserveStroops: ledger.remainingReserveStroops,
    searches: ledger.searches,
  );
}
