import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';

import '../support/chain_submission_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given ServerpodChainSubmissionStore', (
    sessionBuilder,
    _,
  ) {
    chainSubmissionStoreContract(
      (now) => ServerpodChainSubmissionStore(
        sessionBuilder.build(),
        now: now,
      ),
    );
  });
}
