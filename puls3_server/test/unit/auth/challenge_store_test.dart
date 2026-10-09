import 'package:test/test.dart';

import '../../support/challenge_store_contract.dart';
import '../../support/in_memory_challenge_store.dart';

void main() {
  group('InMemoryChallengeStore', () {
    challengeStoreContract((now) => InMemoryChallengeStore(now: now));
  });
}
