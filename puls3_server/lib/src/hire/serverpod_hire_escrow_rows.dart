import 'package:serverpod/serverpod.dart';

import '../chain/submission_values.dart';
import '../generated/protocol.dart';
import 'hire_escrow_backfill.dart';

/// [HireEscrowRows] on the `hire` table.
final class ServerpodHireEscrowRows implements HireEscrowRows {
  ServerpodHireEscrowRows(this.session);

  final Session session;

  @override
  Future<List<HireWithoutEscrow>> withoutEscrow() async {
    final rows = await HireRecord.db.find(
      session,
      where: (t) => t.jobId.notEquals(null) & t.escrow.equals(null),
      orderBy: (t) => t.id,
    );
    return [
      for (final row in rows)
        (
          hireId: row.id!,
          jobId: row.jobId!,
          consumer: row.consumer,
          agentId: row.agentId,
        ),
    ];
  }

  @override
  Future<bool> setEscrowIfEmpty(int hireId, String escrow) async {
    final updated = await HireRecord.db.updateWhere(
      session,
      columnValues: (t) => [t.escrow(escrow)],
      where: (t) => t.id.equals(hireId) & t.escrow.equals(null),
    );
    return updated.isNotEmpty;
  }

  @override
  Future<String?> confirmedCreateJobEnvelope(int hireId) async {
    final row = await ChainSubmission.db.findFirstRow(
      session,
      where: (t) =>
          t.hireId.equals(hireId) &
          t.purpose.equals(SubmissionPurpose.createJob.wireName) &
          t.state.equals(SubmissionState.confirmed.wireName),
      orderBy: (t) => t.id,
    );
    final envelope = row?.signedEnvelopeXdr;
    return envelope == null || envelope.isEmpty ? null : envelope;
  }
}
