@Tags(['integration'])
library;

import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/serverpod_terminal_job_store.dart';
import 'package:test/test.dart';

import '../support/terminal_job_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given ServerpodTerminalJobStore', (sessionBuilder, _) {
    final session = sessionBuilder.build();
    terminalJobStoreContract(
      () => ServerpodTerminalJobStore.onSession(session),
      () async {
        await TerminalJobFact.db.deleteWhere(
          session,
          where: (t) => t.id > 0,
        );
      },
    );
  });
}
