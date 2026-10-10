import 'dart:convert';

/// A hire the consumer started and has not finished: what a reopened sheet,
/// or a restarted app, needs to resume the same hire instead of paying for a
/// second one. `createHire` is idempotent per request id, agent and input
/// (api.md, "createHire idempotency"), so these three are enough.
class PendingHire {
  const PendingHire({required this.requestId, required this.input});

  final String requestId;
  final String input;

  String encode() => jsonEncode({'requestId': requestId, 'input': input});

  /// Null for anything that is not a pending hire this app wrote.
  static PendingHire? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json case {
        'requestId': final String requestId,
        'input': final String input,
      }) {
        return PendingHire(requestId: requestId, input: input);
      }
    } on FormatException {
      // Not ours: ignore it.
    }
    return null;
  }
}

/// Keeps pending hires across a closed sheet and an app restart. It holds
/// no secret: a request id and the task text the consumer typed.
abstract interface class HireFlowStore {
  PendingHire? read(String key);
  void write(String key, PendingHire hire);
  void remove(String key);
}

/// The key of the pending hire of [consumer] with an agent.
String pendingHireKey(String consumer, String agent) =>
    'puls3.hire.pending.$consumer.$agent';

/// In memory: survives a closed sheet, not an app restart. Used on
/// platforms without browser storage, and in tests.
class MemoryHireFlowStore implements HireFlowStore {
  MemoryHireFlowStore([Map<String, String>? backing]) : _values = backing ?? {};

  final Map<String, String> _values;

  @override
  PendingHire? read(String key) => PendingHire.decode(_values[key]);

  @override
  void write(String key, PendingHire hire) => _values[key] = hire.encode();

  @override
  void remove(String key) => _values.remove(key);
}
