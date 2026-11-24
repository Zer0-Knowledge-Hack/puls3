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

/// What a consumer may fund beside the price before hiring one agent
/// (`HireEndpoint.getHireTerms`, ADR-0011 D1 and D8). Read before the hire,
/// so the app shows the subcontract section only when both caps allow it.
abstract class HireTerms
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  HireTerms._({
    required this.reserveMaxStroops,
    required this.maxChildren,
    required this.suggestedReserveStroops,
  });

  factory HireTerms({
    required int reserveMaxStroops,
    required int maxChildren,
    required int suggestedReserveStroops,
  }) = _HireTermsImpl;

  factory HireTerms.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireTerms(
      reserveMaxStroops: jsonSerialization['reserveMaxStroops'] as int,
      maxChildren: jsonSerialization['maxChildren'] as int,
      suggestedReserveStroops:
          jsonSerialization['suggestedReserveStroops'] as int,
    );
  }

  /// The platform ceiling of a hire's subcontract reserve, in USDC stroops
  /// (`PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS`). 0 when unset or unreadable:
  /// this network refuses any reserve.
  int reserveMaxStroops;

  /// How many children one hire of the agent's current manifest may open:
  /// its `max_children` capped by the platform. 0 without the opt-in or
  /// when the manifest is unknown.
  int maxChildren;

  /// The manifest's `suggested_reserve`, in USDC stroops. 0 without it.
  int suggestedReserveStroops;

  /// Returns a shallow copy of this [HireTerms]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  HireTerms copyWith({
    int? reserveMaxStroops,
    int? maxChildren,
    int? suggestedReserveStroops,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireTerms',
      'reserveMaxStroops': reserveMaxStroops,
      'maxChildren': maxChildren,
      'suggestedReserveStroops': suggestedReserveStroops,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HireTerms',
      'reserveMaxStroops': reserveMaxStroops,
      'maxChildren': maxChildren,
      'suggestedReserveStroops': suggestedReserveStroops,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _HireTermsImpl extends HireTerms {
  _HireTermsImpl({
    required int reserveMaxStroops,
    required int maxChildren,
    required int suggestedReserveStroops,
  }) : super._(
         reserveMaxStroops: reserveMaxStroops,
         maxChildren: maxChildren,
         suggestedReserveStroops: suggestedReserveStroops,
       );

  /// Returns a shallow copy of this [HireTerms]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  HireTerms copyWith({
    int? reserveMaxStroops,
    int? maxChildren,
    int? suggestedReserveStroops,
  }) {
    return HireTerms(
      reserveMaxStroops: reserveMaxStroops ?? this.reserveMaxStroops,
      maxChildren: maxChildren ?? this.maxChildren,
      suggestedReserveStroops:
          suggestedReserveStroops ?? this.suggestedReserveStroops,
    );
  }
}
