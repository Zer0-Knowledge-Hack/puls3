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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// A draft's opt-in to subcontract other agents (ADR-0011 D8, #334 T8.1):
/// at most [maxChildren] children per hire, and a [suggestedReserve] in USDC
/// stroops the consumer is asked to fund on top of the price.
abstract class ManifestSubcontract
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ManifestSubcontract._({
    required this.maxChildren,
    required this.suggestedReserve,
  });

  factory ManifestSubcontract({
    required int maxChildren,
    required int suggestedReserve,
  }) = _ManifestSubcontractImpl;

  factory ManifestSubcontract.fromJson(Map<String, dynamic> jsonSerialization) {
    return ManifestSubcontract(
      maxChildren: jsonSerialization['maxChildren'] as int,
      suggestedReserve: jsonSerialization['suggestedReserve'] as int,
    );
  }

  int maxChildren;

  int suggestedReserve;

  /// Returns a shallow copy of this [ManifestSubcontract]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ManifestSubcontract copyWith({
    int? maxChildren,
    int? suggestedReserve,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ManifestSubcontract',
      'maxChildren': maxChildren,
      'suggestedReserve': suggestedReserve,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ManifestSubcontract',
      'maxChildren': maxChildren,
      'suggestedReserve': suggestedReserve,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ManifestSubcontractImpl extends ManifestSubcontract {
  _ManifestSubcontractImpl({
    required int maxChildren,
    required int suggestedReserve,
  }) : super._(
         maxChildren: maxChildren,
         suggestedReserve: suggestedReserve,
       );

  /// Returns a shallow copy of this [ManifestSubcontract]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ManifestSubcontract copyWith({
    int? maxChildren,
    int? suggestedReserve,
  }) {
    return ManifestSubcontract(
      maxChildren: maxChildren ?? this.maxChildren,
      suggestedReserve: suggestedReserve ?? this.suggestedReserve,
    );
  }
}
