import 'dart:convert';

/// A hire the consumer started and has not finished: what a reopened sheet,
/// or a restarted app, needs to resume the same hire instead of paying for a
/// second one. `createHire` is idempotent per request id, agent, input and
/// subcontract terms (api.md, "createHire idempotency"), so a resume sends
/// the same [subcontractReserve] and [allowRelatedParty] (#334).
class PendingHire {
  const PendingHire({
    required this.requestId,
    required this.input,
    this.subcontractReserve = 0,
    this.allowRelatedParty = true,
  });

  final String requestId;
  final String input;

  /// The subcontract reserve in USDC stroops; 0 for a plain hire.
  final int subcontractReserve;

  /// Whether the agent may subcontract an agent of the same owner.
  final bool allowRelatedParty;

  String encode() => jsonEncode({
    'requestId': requestId,
    'input': input,
    'subcontractReserve': subcontractReserve,
    'allowRelatedParty': allowRelatedParty,
  });

  /// Null for anything that is not a pending hire this app wrote. A hire
  /// stored before #334 has no subcontract terms: no reserve and related
  /// party allowed, which is what it was created with.
  static PendingHire? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json case {
        'requestId': final String requestId,
        'input': final String input,
      }) {
        final reserve = json['subcontractReserve'];
        final related = json['allowRelatedParty'];
        return PendingHire(
          requestId: requestId,
          input: input,
          subcontractReserve: reserve is int && reserve > 0 ? reserve : 0,
          allowRelatedParty: related is bool ? related : true,
        );
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
