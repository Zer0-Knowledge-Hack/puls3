import 'package:test/test.dart';

import '../../support/in_memory_terminal_job_store.dart';
import '../../support/terminal_job_store_contract.dart';

void main() {
  group('InMemoryTerminalJobStore', () {
    var store = InMemoryTerminalJobStore();
    terminalJobStoreContract(
      () => store,
      () async => store = InMemoryTerminalJobStore(),
    );
  });
}
