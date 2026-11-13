// Fixtures shared by the E2E suites: the steps that lead to a state, as
// opposed to the suite that asserts a flow.
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:serverpod/serverpod.dart' show Session;

import '../../integration/test_tools/serverpod_test_tools.dart';
import 'e2e_sandbox.dart';

/// A hire the consumer created and funded through the relay, signing every
/// transaction unchanged. Returns once the tracker has recorded it as
/// funded.
Future<({int hireId, int jobId})> createFundedHire({
  required E2eSandbox sandbox,
  required TestEndpoints endpoints,
  required TestSessionBuilder authed,
  required Session session,
  required E2eAccount consumer,
  required int agentId,
}) async {
  final hires = ServerpodHireRepository(session);
  final created = await endpoints.hire.createHire(
    authed,
    agentId,
    consumer.address.value,
    'e2e fixture hire',
    'e2e-${DateTime.now().microsecondsSinceEpoch}',
  );
  final hireId = created.hire.id;
  final prepared =
      created.preparedCreateJob ??
      await endpoints.hire.prepareCreateJob(authed, hireId);
  await endpoints.hire.submitEscrowCall(
    authed,
    hireId,
    prepared.preparationId,
    sandbox.sign(consumer, prepared.unsignedTransactionXdr!),
  );
  final opened = await until('the hire to open with a job id', () async {
    final row = await hires.findHire(hireId);
    return row?.jobId != null && row?.status == HireStatus.open ? row : null;
  });
  final fund = await endpoints.hire.prepareFund(authed, hireId);
  await endpoints.hire.submitEscrowCall(
    authed,
    hireId,
    fund.preparationId,
    sandbox.sign(consumer, fund.unsignedTransactionXdr!),
  );
  await until('the hire to be funded', () async {
    final row = await hires.findHire(hireId);
    return row?.status == HireStatus.funded ? row : null;
  });
  return (hireId: hireId, jobId: opened.jobId!);
}
