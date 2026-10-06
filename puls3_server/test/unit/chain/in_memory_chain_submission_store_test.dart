import 'package:test/test.dart';

import '../../support/chain_submission_store_contract.dart';
import '../../support/in_memory_chain_submission_store.dart';

void main() {
  group('InMemoryChainSubmissionStore', () {
    chainSubmissionStoreContract(
      (now) => InMemoryChainSubmissionStore(now: now),
    );
  });
}
