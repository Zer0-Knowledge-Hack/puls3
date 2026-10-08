/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'package:puls3_server/src/generated/protocol.dart' as _i2;

/// Stable, safe error transported by every puls3 Serverpod endpoint.
abstract class Puls3ApiException
    implements
        _i1.SerializableException,
        _i1.SerializableModel,
        _i1.ProtocolSerialization {
  Puls3ApiException._({
    required this.code,
    this.message,
    this.details,
  });

  factory Puls3ApiException({
    required String code,
    String? message,
    Map<String, String>? details,
  }) = _Puls3ApiExceptionImpl;

  factory Puls3ApiException.fromJson(Map<String, dynamic> jsonSerialization) {
    return Puls3ApiException(
      code: jsonSerialization['code'] as String,
      message: jsonSerialization['message'] as String?,
      details: jsonSerialization['details'] == null
          ? null
          : _i2.Protocol().deserialize<Map<String, String>>(
              jsonSerialization['details'],
            ),
    );
  }

  /// Machine-readable code from the catalog above.
  String code;

  /// Optional display-safe message. Clients branch on code, not this text.
  String? message;

  /// Optional display-safe structured context, such as field, reason, status,
  /// retryAfterSeconds or expectedNetwork. Never secrets, signed payloads,
  /// raw provider errors or traces.
  Map<String, String>? details;

  /// Returns a shallow copy of this [Puls3ApiException]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Puls3ApiException copyWith({
    String? code,
    String? message,
    Map<String, String>? details,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Puls3ApiException',
      'code': code,
      if (message != null) 'message': message,
      if (details != null) 'details': details?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Puls3ApiException',
      'code': code,
      if (message != null) 'message': message,
      if (details != null) 'details': details?.toJson(),
    };
  }

  @override
  String toString() {
    return 'Puls3ApiException(code: $code, message: $message, details: $details)';
  }
}

class _Undefined {}

class _Puls3ApiExceptionImpl extends Puls3ApiException {
  _Puls3ApiExceptionImpl({
    required String code,
    String? message,
    Map<String, String>? details,
  }) : super._(
         code: code,
         message: message,
         details: details,
       );

  /// Returns a shallow copy of this [Puls3ApiException]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Puls3ApiException copyWith({
    String? code,
    Object? message = _Undefined,
    Object? details = _Undefined,
  }) {
    return Puls3ApiException(
      code: code ?? this.code,
      message: message is String? ? message : this.message,
      details: details is Map<String, String>?
          ? details
          : this.details?.map(
              (
                key0,
                value0,
              ) => MapEntry(
                key0,
                value0,
              ),
            ),
    );
  }
}
