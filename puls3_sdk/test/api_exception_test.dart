import 'dart:convert';

import 'package:puls3_client/puls3_client.dart';
import 'package:test/test.dart';

/// How the client decodes a typed error. Serverpod sends a failed call's
/// `Puls3ApiException` as this body with status 400, and the client rebuilds
/// it with [Protocol.deserializeByClassName]. When that fails, the caller
/// gets a bare `ServerpodClientBadRequest` and loses the error code.
Object? _decode(String body) =>
    Protocol().deserializeByClassName(jsonDecode(body) as Map<String, dynamic>);

void main() {
  group('Puls3ApiException reaches the client', () {
    test('with details, as InvalidHireTransition sends it', () {
      // The body the server sent for a reject of a hire with no job (#375).
      final error = _decode(
        '{"className":"Puls3ApiException","data":{"__className__":'
        '"Puls3ApiException","code":"InvalidHireTransition",'
        '"details":{"status":"open","purpose":"complete"}}}',
      );

      expect(error, isA<Puls3ApiException>());
      final typed = error! as Puls3ApiException;
      expect(typed.code, 'InvalidHireTransition');
      expect(typed.details, {'status': 'open', 'purpose': 'complete'});
    });

    test('without details', () {
      final error = _decode(
        '{"className":"Puls3ApiException","data":{"__className__":'
        '"Puls3ApiException","code":"HireNotFound"}}',
      );

      expect((error! as Puls3ApiException).code, 'HireNotFound');
      expect((error as Puls3ApiException).details, isNull);
    });
  });
}
