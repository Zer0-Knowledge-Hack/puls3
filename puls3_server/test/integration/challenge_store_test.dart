@Tags(['integration'])
library;

import 'package:puls3_server/src/auth/serverpod_challenge_store.dart';
import 'package:test/test.dart';

import '../support/challenge_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given ServerpodChallengeStore', (sessionBuilder, _) {
    challengeStoreContract(
      (now) => ServerpodChallengeStore(sessionBuilder.build(), now: now),
    );
  });
}
