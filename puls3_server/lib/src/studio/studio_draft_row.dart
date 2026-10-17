/// One stored draft. [manifestJson] is the domain wire document
/// (`AgentManifestDraft.toJson`), which is the only copy of the prompt.
final class StudioDraftRow {
  const StudioDraftRow({
    required this.id,
    required this.owner,
    required this.revision,
    required this.manifestJson,
    required this.deployState,
    required this.updatedAt,
    this.liveVersion,
    this.agentId,
    this.retryFromStep,
  });

  final int id;
  final String owner;
  final int revision;
  final String manifestJson;

  /// `draft`, `deploying`, `failed`, or `live`.
  final String deployState;
  final int? liveVersion;
  final String? agentId;
  final int? retryFromStep;
  final DateTime updatedAt;
}
