@Tags(['integration'])
library;

import 'package:puls3_server/src/hire/serverpod_hire_receipt_store.dart';
import 'package:test/test.dart';

import '../support/hire_receipt_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given ServerpodHireReceiptStore', (sessionBuilder, _) {
    // The table has no foreign key to hire, so plain ids are enough.
    var seq = 0;
    hireReceiptStoreContract(() async {
      seq += 2;
      return HireReceiptStoreFixture(
        store: ServerpodHireReceiptStore(sessionBuilder.build()),
        parentHireId: 970000 + seq,
        childHireId: 970001 + seq,
      );
    });
  });
}
