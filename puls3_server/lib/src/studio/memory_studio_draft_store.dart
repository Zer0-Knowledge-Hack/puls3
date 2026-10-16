import 'studio_draft_errors.dart';
import 'studio_draft_row.dart';
import 'studio_draft_store.dart';

/// In-memory [StudioDraftStore] for tests and the endpoint seam.
final class MemoryStudioDraftStore implements StudioDraftStore {
  final Map<int, StudioDraftRow> _rows = {};
  int _nextId = 1;

  @override
  Future<StudioDraftRow> insert({
    required String owner,
    required String manifestJson,
    required DateTime updatedAt,
  }) async {
    final row = StudioDraftRow(
      id: _nextId++,
      owner: owner,
      revision: 1,
      manifestJson: manifestJson,
      deployState: 'draft',
      updatedAt: updatedAt,
    );
    _rows[row.id] = row;
    return row;
  }

  @override
  Future<StudioDraftRow?> find(int id) async => _rows[id];

  @override
  Future<StudioDraftRow> update({
    required int id,
    required String owner,
    required String manifestJson,
    required int? expectedRevision,
    required bool overwrite,
    required DateTime updatedAt,
  }) async {
    final current = _rows[id];
    if (current == null) throw const StudioDraftMissing();
    if (current.owner != owner) throw const StudioDraftNotOwned();
    if (!overwrite && expectedRevision != current.revision) {
      throw const StudioDraftRevisionConflict();
    }
    final row = StudioDraftRow(
      id: current.id,
      owner: current.owner,
      revision: current.revision + 1,
      manifestJson: manifestJson,
      deployState: current.deployState,
      liveVersion: current.liveVersion,
      agentId: current.agentId,
      retryFromStep: current.retryFromStep,
      updatedAt: updatedAt,
    );
    _rows[id] = row;
    return row;
  }

  @override
  Future<void> markLive({
    required int id,
    required int liveVersion,
    required String agentId,
    required DateTime updatedAt,
  }) async {
    final current = _rows[id];
    if (current == null) throw const StudioDraftMissing();
    _rows[id] = StudioDraftRow(
      id: current.id,
      owner: current.owner,
      revision: current.revision,
      manifestJson: current.manifestJson,
      deployState: 'live',
      liveVersion: liveVersion,
      agentId: agentId,
      retryFromStep: current.retryFromStep,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<List<StudioDraftRow>> listByOwner(String owner) async {
    final rows = [
      for (final row in _rows.values)
        if (row.owner == owner) row,
    ];
    rows.sort((a, b) => a.id.compareTo(b.id));
    return rows;
  }
}
