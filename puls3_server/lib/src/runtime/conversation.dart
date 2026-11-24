import 'dart:convert';

import 'runtime_task.dart';

export 'runtime_task.dart';

/// One tool the model may call (ADR-0006 D3, ADR-0011 D8), described
/// provider-neutrally. Each adapter maps it to its own API.
final class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// The JSON Schema of the call's arguments (an `object` schema).
  final Map<String, Object?> parameters;
}

/// One tool call the model asked for.
final class ToolCall {
  ToolCall({
    required this.id,
    required this.name,
    required Map<String, Object?> arguments,
  }) : arguments = Map.unmodifiable(arguments);

  /// The provider's call id; the matching [ToolResultMessage] carries it.
  final String id;
  final String name;
  final Map<String, Object?> arguments;

  /// The rune length the runner counts: the name and the encoded arguments.
  int get length => name.runes.length + jsonEncode(arguments).runes.length;
}

/// One message of a conversation with the model, oldest first.
sealed class ConversationMessage {
  const ConversationMessage();

  /// The rune length the runner counts against the input limit.
  int get length;
}

/// Text from the caller: the hire input, or a later instruction.
final class UserMessage extends ConversationMessage {
  UserMessage(this.text);

  final String text;

  @override
  int get length => text.runes.length;
}

/// A turn the model already took, replayed to it.
final class AssistantMessage extends ConversationMessage {
  AssistantMessage({
    this.text = '',
    List<ToolCall> toolCalls = const [],
    this.providerContent,
  }) : toolCalls = List.unmodifiable(toolCalls) {
    if (text.isEmpty && toolCalls.isEmpty) {
      throw ArgumentError('An assistant message needs text or tool calls.');
    }
  }

  final String text;
  final List<ToolCall> toolCalls;

  /// The provider's own JSON for this turn, when it must be replayed
  /// unchanged: Anthropic requires thinking blocks back exactly as they
  /// came. Opaque outside the adapter of the provider that produced it.
  final Object? providerContent;

  @override
  int get length =>
      text.runes.length + toolCalls.fold(0, (sum, call) => sum + call.length);
}

/// What a tool returned for one [ToolCall]. [content] is opaque here: T5.2
/// delimits and labels it as data before it reaches this message.
final class ToolResultMessage extends ConversationMessage {
  ToolResultMessage({
    required this.callId,
    required this.content,
    this.isError = false,
  });

  final String callId;
  final String content;
  final bool isError;

  @override
  int get length => content.runes.length;
}

/// One model turn: the final answer or the tools it wants called.
sealed class ModelTurn {
  const ModelTurn();
}

/// The model's final text: the run's output.
final class FinalText extends ModelTurn {
  const FinalText(this.text);

  final String text;
}

/// The model asked for one or more tool calls before it answers.
final class ToolCallsTurn extends ModelTurn {
  ToolCallsTurn({
    required List<ToolCall> calls,
    this.text = '',
    this.providerContent,
  }) : calls = List.unmodifiable(calls) {
    if (calls.isEmpty) {
      throw ArgumentError.value(calls, 'calls', 'empty');
    }
  }

  final List<ToolCall> calls;

  /// Text the model wrote beside the calls, if any.
  final String text;

  /// See [AssistantMessage.providerContent].
  final Object? providerContent;

  /// The rune length the runner counts against the output limit.
  int get length =>
      text.runes.length + calls.fold(0, (sum, call) => sum + call.length);

  /// This turn as the [AssistantMessage] to replay on the next call.
  AssistantMessage toMessage() => AssistantMessage(
    text: text,
    toolCalls: calls,
    providerContent: providerContent,
  );
}

/// One model call in a conversation: a [RuntimeTask] with messages and tools
/// instead of a single input.
final class ConversationTask {
  ConversationTask({
    required this.provider,
    required this.modelId,
    required this.systemPrompt,
    required List<ConversationMessage> messages,
    required List<ToolSpec> tools,
    required this.maxInputChars,
    required this.maxOutputChars,
  }) : messages = List.unmodifiable(messages),
       tools = List.unmodifiable(tools) {
    if (messages.isEmpty) {
      throw ArgumentError.value(messages, 'messages', 'empty');
    }
    if (maxInputChars < 1) {
      throw ArgumentError.value(maxInputChars, 'maxInputChars', 'below 1');
    }
    if (maxOutputChars < 1) {
      throw ArgumentError.value(maxOutputChars, 'maxOutputChars', 'below 1');
    }
  }

  final String provider;
  final String modelId;
  final String systemPrompt;
  final List<ConversationMessage> messages;
  final List<ToolSpec> tools;

  /// The most [conversationLength] one call may send. The tool loop (T5.2)
  /// chooses it, since tool results grow the conversation past the hire
  /// input's `input.max_chars`.
  final int maxInputChars;

  /// The manifest's `output.max_chars`, for the final text and for each
  /// turn's tool calls.
  final int maxOutputChars;

  /// The conversation's size in runes: every message's text, tool call
  /// names and encoded arguments, and tool result content. The system
  /// prompt and tool specs come from the manifest and the server, as in
  /// `AgentRunner.run`, and opaque provider content is not counted.
  int get conversationLength =>
      messages.fold(0, (sum, message) => sum + message.length);
}

/// A [ModelRuntime] that can also hold a conversation with tools. It is a
/// separate interface so that text-only runtimes keep compiling.
abstract interface class ConversationRuntime implements ModelRuntime {
  /// The model's next turn for [task], or a [RuntimeFailure]. [abortTrigger]
  /// works as in [ModelRuntime.complete].
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  });
}
