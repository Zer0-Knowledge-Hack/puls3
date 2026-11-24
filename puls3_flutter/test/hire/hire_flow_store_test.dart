import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';

void main() {
  test('a pending hire keeps its subcontract reserve and flag', () {
    const hire = PendingHire(
      requestId: 'req-1',
      input: 'Audit my token',
      subcontractReserve: 10000000,
      allowRelatedParty: false,
    );

    final decoded = PendingHire.decode(hire.encode())!;

    expect(decoded.requestId, 'req-1');
    expect(decoded.input, 'Audit my token');
    expect(decoded.subcontractReserve, 10000000);
    expect(decoded.allowRelatedParty, isFalse);
  });

  test('a pending hire stored before #334 loads with no reserve and the '
      'related-party default', () {
    final decoded = PendingHire.decode(
      '{"requestId":"req-old","input":"Audit my token"}',
    )!;

    expect(decoded.requestId, 'req-old');
    expect(decoded.input, 'Audit my token');
    expect(decoded.subcontractReserve, 0);
    expect(decoded.allowRelatedParty, isTrue);
  });
}
