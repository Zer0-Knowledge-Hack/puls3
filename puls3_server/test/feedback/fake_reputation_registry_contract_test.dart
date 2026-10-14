import 'package:test/test.dart';

import '../support/fake_feedback_ports.dart';
import '../support/reputation_registry_contract.dart';

void main() {
  group('FakeReputationRegistry', () {
    reputationRegistryContract(FakeReputationRegistryRig.new);
  });
}
