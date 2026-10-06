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

abstract class AgentUnavailable
    implements
        _i1.SerializableException,
        _i1.SerializableModel,
        _i1.ProtocolSerialization {
  AgentUnavailable._({required this.agentId});

  factory AgentUnavailable({required int agentId}) = _AgentUnavailableImpl;

  factory AgentUnavailable.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentUnavailable(agentId: jsonSerialization['agentId'] as int);
  }

  int agentId;

  /// Returns a shallow copy of this [AgentUnavailable]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentUnavailable copyWith({int? agentId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentUnavailable',
      'agentId': agentId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentUnavailable',
      'agentId': agentId,
    };
  }

  @override
  String toString() {
    return 'AgentUnavailable(agentId: $agentId)';
  }
}

class _AgentUnavailableImpl extends AgentUnavailable {
  _AgentUnavailableImpl({required int agentId}) : super._(agentId: agentId);

  /// Returns a shallow copy of this [AgentUnavailable]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentUnavailable copyWith({int? agentId}) {
    return AgentUnavailable(agentId: agentId ?? this.agentId);
  }
}
