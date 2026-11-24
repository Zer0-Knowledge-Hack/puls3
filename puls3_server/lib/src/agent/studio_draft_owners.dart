import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'catalog_id_owner.dart';

/// [StudioCatalogIdOwners] over the `studio_draft` table, through [session]:
/// the owner of `studio-<draftId>` is the draft row's owner (#381).
StudioCatalogIdOwners studioDraftOwnersOn(Session session) =>
    StudioCatalogIdOwners(
      (draftId) async =>
          (await StudioDraftRecord.db.findById(session, draftId))?.owner,
    );

/// The same for a reader that outlives a request, such as the process-wide
/// on-chain catalog: each lookup opens and closes its own session.
StudioCatalogIdOwners studioDraftOwnersOf(
  Future<Session> Function() openSession,
) => StudioCatalogIdOwners((draftId) async {
  final session = await openSession();
  try {
    return (await StudioDraftRecord.db.findById(session, draftId))?.owner;
  } finally {
    await session.close();
  }
});
