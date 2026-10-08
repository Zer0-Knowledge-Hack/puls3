import 'package:test/test.dart';

import '../../support/hire_lifecycle_store_contract.dart';
import '../../support/in_memory_hire_lifecycle_store.dart';

void main() {
  group('InMemoryHireLifecycleStore', () {
    hireLifecycleStoreContract(InMemoryHireLifecycleStore.new);
  });
}
