import 'studio_draft_errors.dart';
import 'studio_draft_row.dart';

/// Persistence for Studio drafts. The service parses manifests; the store
/// only keeps rows and enforces owner plus revision.
abstract interface class StudioDraftStore {
  /// Inserts a new draft at revision 1 and returns it with its id.
  Future<StudioDraftRow> insert({
    required String owner,
    required String manifestJson,
    required DateTime updatedAt,
  });

  /// The row for [id], or null when there is none.
  Future<StudioDraftRow?> find(int id);

  /// Replaces the manifest. Throws [StudioDraftMissing] when [id] is unknown,
  /// [StudioDraftNotOwned] when [owner] is not the row's owner, and
  /// [StudioDraftRevisionConflict] when [expectedRevision] is not current
  /// and [overwrite] is false.
  Future<StudioDraftRow> update({
    required int id,
    required String owner,
    required String manifestJson,
    required int? expectedRevision,
    required bool overwrite,
    required DateTime updatedAt,
  });

  /// [owner]'s drafts, oldest id first.
  Future<List<StudioDraftRow>> listByOwner(String owner);

  /// Records that [id] is the live agent [agentId] at [liveVersion].
  /// Does not change the manifest or the revision.
  Future<void> markLive({
    required int id,
    required int liveVersion,
    required String agentId,
    required DateTime updatedAt,
  });
}
