import 'dart:convert';

import 'package:puls3_client/puls3_client.dart';

/// The [Puls3ApiException] that a [ServerpodClientBadRequest] carries as JSON,
/// or null when it carries something else.
///
/// The generated client decodes a typed error from the 400 body. In the
/// browser (dart2js) that decoding fails for an error with `details`: it
/// throws "No deserialization found for type `Map<String, String>`". The
/// client then throws a plain `ServerpodClientBadRequest` whose message is
/// "Bad request: " followed by the JSON body. The gateways map typed errors by
/// code, so they read the error back from that body.
Puls3ApiException? typedApiError(ServerpodClientException error) {
  if (error is! ServerpodClientBadRequest) return null;
  final message = error.message;
  final start = message.indexOf('{');
  final end = message.lastIndexOf('}');
  if (start < 0 || end < start) return null;
  try {
    final body = jsonDecode(message.substring(start, end + 1));
    if (body is! Map || body['className'] != 'Puls3ApiException') return null;
    final data = body['data'];
    if (data is! Map) return null;
    final code = data['code'];
    if (code is! String) return null;
    final details = data['details'];
    final text = data['message'];
    return Puls3ApiException(
      code: code,
      message: text is String ? text : null,
      details: details is Map
          ? {
              for (final entry in details.entries)
                '${entry.key}': '${entry.value}',
            }
          : null,
    );
  } on FormatException {
    return null;
  }
}
