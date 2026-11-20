import 'package:test/test.dart';

import '../support/hire_receipt_store_contract.dart';
import '../support/in_memory_hire_receipt_store.dart';

void main() {
  group('InMemoryHireReceiptStore', () {
    hireReceiptStoreContract(
      () async => HireReceiptStoreFixture(
        store: InMemoryHireReceiptStore(),
        parentHireId: 1,
        childHireId: 2,
      ),
    );
  });
}
