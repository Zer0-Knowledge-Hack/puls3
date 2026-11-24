import 'package:puls3_domain/puls3_domain.dart'
    show AgentCandidate, RelatedPartyJustification;

/// What the tool loop asks the server to hire for a `subcontract` call
/// (ADR-0011 D8). Every field the money depends on is server-decided: the
/// agent comes from a prior search, the price is the candidate's, and the
/// model supplies only [task] and [justification].
final class ChildRequest {
  ChildRequest({
    required this.parentHireId,
    required this.agentRegistryId,
    required this.agentId,
    required this.priceStroops,
    required this.task,
    required this.justification,
    required this.isRelatedParty,
    required this.relatedPartyJustification,
    required List<AgentCandidate> ranking,
    this.toolCallId,
  }) : ranking = List.unmodifiable(ranking);

  /// The hire whose agent subcontracts.
  final int parentHireId;

  /// The id of the `subcontract` tool call, the port's idempotency key with
  /// [parentHireId]. Null only for a request read back from a stored loop
  /// state (`tool_loop_codec` v1 does not keep it): such a request is never
  /// sent to the port again.
  final String? toolCallId;

  /// The child agent's registry id, from the search snapshot.
  final int agentRegistryId;

  /// The child agent's catalog id (for example `agt-007`).
  final String agentId;

  /// The child budget: the candidate's price when it was searched. The port
  /// re-reads the current price and refuses when it moved past the reserve.
  final int priceStroops;

  /// The child hire's input, written by the model.
  final String task;

  /// The model's reason for the pick, stored with the child hire (D10).
  final String justification;

  /// Whether the child shares an owner with the hiring agent (D10).
  final bool isRelatedParty;

  /// The server's D10 verdict on the pick; always accepted here.
  final RelatedPartyJustification relatedPartyJustification;

  /// The ranking snapshot of the search the pick came from (D10).
  final List<AgentCandidate> ranking;
}

/// The port refused a child for a rule only it can check (depth, cycle, a
/// price that moved, the chain). The loop turns it into a tool error.
final class SubcontractRefused implements Exception {
  const SubcontractRefused(this.code);

  /// A short, storable reason, shown to the model.
  final String code;

  @override
  String toString() => 'SubcontractRefused($code)';
}

/// Opens the child hire of a `subcontract` call. T6 implements it on the
/// escrow; the tool loop only needs the child's hire id to pause on.
abstract interface class SubcontractPort {
  /// The new child hire's id. Throws [SubcontractRefused] for a refused
  /// child; any other error propagates out of the loop, since the child may
  /// be half-opened and only the caller can reconcile it.
  Future<int> requestChild(ChildRequest request);
}
