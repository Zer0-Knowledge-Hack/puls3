import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:test/test.dart';

import '../../support/hire_run_store_contract.dart';
import '../../support/in_memory_hire_run_store.dart';

void main() {
  hireRunStoreContract(() async {
    final store = InMemoryHireRunStore();
    var nextId = 1;
    return HireRunStoreFixture(
      store: store,
      queue:
          ({
            required int agentId,
            required int manifestVersion,
            required String input,
          }) async {
            final hireId = nextId++;
            store.enqueue(
              QueuedRun(
                hireId: hireId,
                agentId: agentId,
                manifestVersion: manifestVersion,
                input: input,
              ),
              DateTime.utc(2026, 10, 8),
            );
            return hireId;
          },
    );
  });

  test('HireRunState maps to the runtime status the app shows', () {
    expect(HireRunState.queued.runtimeStatus.name, 'queued');
    expect(HireRunState.running.runtimeStatus.name, 'running');
    expect(
      HireRunState.succeeded.runtimeStatus.name,
      'running',
      reason: 'stays running until the escrow submit lands',
    );
    expect(HireRunState.failed.runtimeStatus.name, 'failed');
  });
}
