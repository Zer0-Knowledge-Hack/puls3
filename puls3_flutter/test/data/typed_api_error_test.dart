import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/data/typed_api_error.dart';

/// What the generated client throws in the browser when it cannot decode a
/// typed error: a bad request whose message is `Bad request: <body>`.
ServerpodClientBadRequest _bad(String body) => ServerpodClientBadRequest(body);

void main() {
  group('typedApiError', () {
    test('rebuilds a typed error with its details', () {
      final error = typedApiError(
        _bad(
          '{"className":"Puls3ApiException","data":{"__className__":'
          '"Puls3ApiException","code":"InvalidHireTransition",'
          '"details":{"purpose":"fund"}}}',
        ),
      );
      expect(error, isNotNull);
      expect(error!.code, 'InvalidHireTransition');
      expect(error.details, {'purpose': 'fund'});
      expect(error.message, isNull);
    });

    test('keeps the message and reads an error without details', () {
      final error = typedApiError(
        _bad(
          '{"className":"Puls3ApiException","data":{"code":"InvalidHire",'
          '"message":"Too long."}}',
        ),
      );
      expect(error!.code, 'InvalidHire');
      expect(error.message, 'Too long.');
      expect(error.details, isNull);
    });

    test('turns every detail value into text', () {
      final error = typedApiError(
        _bad(
          '{"className":"Puls3ApiException","data":{"code":"X",'
          '"details":{"attempt":3}}}',
        ),
      );
      expect(error!.details, {'attempt': '3'});
    });

    test('ignores a bad request that is not a typed error', () {
      expect(typedApiError(_bad('')), isNull);
      expect(typedApiError(_bad('not json')), isNull);
      expect(typedApiError(_bad('{"className":"Other","data":{}}')), isNull);
      expect(
        typedApiError(_bad('{"className":"Puls3ApiException","data":{}}')),
        isNull,
      );
    });

    test('ignores every other client failure', () {
      expect(
        typedApiError(const ServerpodClientNetworkException('offline')),
        isNull,
      );
      expect(typedApiError(ServerpodClientUnauthorized()), isNull);
    });
  });
}
