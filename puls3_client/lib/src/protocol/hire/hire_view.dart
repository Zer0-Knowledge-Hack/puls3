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

abstract class HireView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  HireView._({
    required this.hireId,
    required this.agentRegistryId,
    required this.consumer,
    required this.priceStroops,
    required this.status,
  });

  factory HireView({
    required int hireId,
    required int agentRegistryId,
    required String consumer,
    required int priceStroops,
    required String status,
  }) = _HireViewImpl;

  factory HireView.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireView(
      hireId: jsonSerialization['hireId'] as int,
      agentRegistryId: jsonSerialization['agentRegistryId'] as int,
      consumer: jsonSerialization['consumer'] as String,
      priceStroops: jsonSerialization['priceStroops'] as int,
      status: jsonSerialization['status'] as String,
    );
  }

  int hireId;

  int agentRegistryId;

  String consumer;

  int priceStroops;

  String status;

  /// Returns a shallow copy of this [HireView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  HireView copyWith({
    int? hireId,
    int? agentRegistryId,
    String? consumer,
    int? priceStroops,
    String? status,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireView',
      'hireId': hireId,
      'agentRegistryId': agentRegistryId,
      'consumer': consumer,
      'priceStroops': priceStroops,
      'status': status,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HireView',
      'hireId': hireId,
      'agentRegistryId': agentRegistryId,
      'consumer': consumer,
      'priceStroops': priceStroops,
      'status': status,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _HireViewImpl extends HireView {
  _HireViewImpl({
    required int hireId,
    required int agentRegistryId,
    required String consumer,
    required int priceStroops,
    required String status,
  }) : super._(
         hireId: hireId,
         agentRegistryId: agentRegistryId,
         consumer: consumer,
         priceStroops: priceStroops,
         status: status,
       );

  /// Returns a shallow copy of this [HireView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  HireView copyWith({
    int? hireId,
    int? agentRegistryId,
    String? consumer,
    int? priceStroops,
    String? status,
  }) {
    return HireView(
      hireId: hireId ?? this.hireId,
      agentRegistryId: agentRegistryId ?? this.agentRegistryId,
      consumer: consumer ?? this.consumer,
      priceStroops: priceStroops ?? this.priceStroops,
      status: status ?? this.status,
    );
  }
}
