import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'studio_draft_errors.dart';
import 'studio_draft_row.dart';
import 'studio_draft_store.dart';

/// PostgreSQL [StudioDraftStore]. The prompt stays in `manifest_json`.
final class ServerpodStudioDraftStore implements StudioDraftStore {
  ServerpodStudioDraftStore(this._session);

  final Session _session;

  @override
  Future<StudioDraftRow> insert({
    required String owner,
    required String manifestJson,
    required DateTime updatedAt,
  }) async {
    final row = await StudioDraftRecord.db.insertRow(
      _session,
      StudioDraftRecord(
        owner: owner,
        revision: 1,
        manifestJson: manifestJson,
        deployState: 'draft',
        updatedAt: updatedAt,
      ),
    );
    return _row(row);
  }

  @override
  Future<StudioDraftRow?> find(int id) async {
    final row = await StudioDraftRecord.db.findById(_session, id);
    return row == null ? null : _row(row);
  }

  @override
  Future<StudioDraftRow> update({
    required int id,
    required String owner,
    required String manifestJson,
    required int? expectedRevision,
    required bool overwrite,
    required DateTime updatedAt,
  }) async {
    final saved = await _session.db.transaction((transaction) async {
      final current = await StudioDraftRecord.db.findById(
        _session,
        id,
        transaction: transaction,
      );
      if (current == null) throw const StudioDraftMissing();
      if (current.owner != owner) throw const StudioDraftNotOwned();
      if (!overwrite && expectedRevision != current.revision) {
        throw const StudioDraftRevisionConflict();
      }
      return StudioDraftRecord.db.updateRow(
        _session,
        current.copyWith(
          revision: current.revision + 1,
          manifestJson: manifestJson,
          updatedAt: updatedAt,
        ),
        transaction: transaction,
      );
    });
    return _row(saved);
  }

  @override
  Future<void> markLive({
    required int id,
    required int liveVersion,
    required String agentId,
    required DateTime updatedAt,
  }) async {
    final current = await StudioDraftRecord.db.findById(_session, id);
    if (current == null) throw const StudioDraftMissing();
    await StudioDraftRecord.db.updateRow(
      _session,
      current.copyWith(
        deployState: 'live',
        liveVersion: liveVersion,
        agentId: agentId,
        updatedAt: updatedAt,
      ),
    );
  }

  @override
  Future<List<StudioDraftRow>> listByOwner(String owner) async {
    final rows = await StudioDraftRecord.db.find(
      _session,
      where: (t) => t.owner.equals(owner),
      orderBy: (t) => t.id,
    );
    return [for (final row in rows) _row(row)];
  }

  StudioDraftRow _row(StudioDraftRecord row) => StudioDraftRow(
    id: row.id!,
    owner: row.owner,
    revision: row.revision,
    manifestJson: row.manifestJson,
    deployState: row.deployState,
    liveVersion: row.liveVersion,
    agentId: row.agentId,
    retryFromStep: row.retryFromStep,
    updatedAt: row.updatedAt,
  );
}
