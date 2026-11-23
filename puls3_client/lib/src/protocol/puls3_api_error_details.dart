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
import 'package:puls3_client/src/protocol/protocol.dart' as _ihzwmcdm;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Never sent on its own. Serverpod 4.0.4 generates a container's
/// deserializer only from the fields of a class, not of an exception, so
/// without this class the protocol cannot read `Map<String, String>`. Every
/// client then fails to decode a `Puls3ApiException` that carries `details`
/// and gets a bare `ServerpodClientBadRequest` without the error code.
/// Keep the field type identical to `Puls3ApiException.details`.
abstract class Puls3ApiErrorDetails
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Puls3ApiErrorDetails._({required this.values});

  factory Puls3ApiErrorDetails({required Map<String, String> values}) =
      _Puls3ApiErrorDetailsImpl;

  factory Puls3ApiErrorDetails.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return Puls3ApiErrorDetails(
      values: _ihzwmcdm.Protocol().deserialize<Map<String, String>>(
        jsonSerialization['values'],
      ),
    );
  }

  Map<String, String> values;

  /// Returns a shallow copy of this [Puls3ApiErrorDetails]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Puls3ApiErrorDetails copyWith({Map<String, String>? values});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Puls3ApiErrorDetails',
      'values': values.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Puls3ApiErrorDetails',
      'values': values.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Puls3ApiErrorDetailsImpl extends Puls3ApiErrorDetails {
  _Puls3ApiErrorDetailsImpl({required Map<String, String> values})
    : super._(values: values);

  /// Returns a shallow copy of this [Puls3ApiErrorDetails]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Puls3ApiErrorDetails copyWith({Map<String, String>? values}) {
    return Puls3ApiErrorDetails(
      values:
          values ??
          this.values.map(
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
