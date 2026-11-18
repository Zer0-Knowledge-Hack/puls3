/// The text a non-technical builder writes once, turned into the two fields the
/// manifest needs: a public description and a structured system prompt.
///
/// The builder can still edit both under Advanced, but the four-field flow
/// only asks for the brief.
library;

/// The manifest's public description limit (`AgentManifestDraft`).
const _descriptionMax = 280;

/// Below this, the first sentence is too short to stand alone as the public
/// description; the whole brief is used instead.
const _descriptionMin = 10;

/// A one-line public description for [brief]:
///
/// - whitespace and line breaks collapse to single spaces;
/// - the first sentence is used when it is long enough, otherwise the whole
///   brief;
/// - the result is truncated to the manifest's 280-character limit.
///
/// Returns an empty string for an empty brief.
String descriptionFromBrief(String brief) {
  final text = _collapse(brief);
  if (text.isEmpty) return '';
  final first = RegExp(r'^(.+?[.!?])(?:\s|$)').firstMatch(text)?.group(1);
  final candidate =
      first != null && first.runes.length >= _descriptionMin ? first : text;
  return _truncate(candidate, _descriptionMax);
}

/// A structured system prompt for [brief], optionally naming the agent.
///
/// The brief stays the source of truth: the prompt gives it a role and a short
/// way to work. Returns an empty string for an empty brief.
String systemPromptFromBrief(String brief, {String? name}) {
  final text = brief.trim();
  if (text.isEmpty) return '';
  final trimmedName = name?.trim();
  final identity = trimmedName == null || trimmedName.isEmpty
      ? 'an autonomous agent'
      : '$trimmedName, an autonomous agent';
  return '''
You are $identity on puls3.

Role and scope:
$text

How to work:
- Follow the role and scope on every task.
- If a request is outside it, explain what you can do instead of guessing.
- Answer clearly and concisely.''';
}

String _collapse(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ');

String _truncate(String text, int max) {
  final runes = text.runes.toList();
  if (runes.length <= max) return text;
  return '${String.fromCharCodes(runes.take(max - 1))}…';
}
