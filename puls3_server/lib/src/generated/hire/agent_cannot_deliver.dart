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
import 'package:serverpod/serverpod.dart' as _is;

/// The agent's payment wallet is not custodied by the server, so the server
/// cannot sign the escrow `submit` that closes a hire of it. Raised before any
/// hire, preparation or envelope is stored and mapped to the `AgentCannotDeliver`
/// code.
abstract class AgentCannotDeliver
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  AgentCannotDeliver._({required this.agentId});

  factory AgentCannotDeliver({required int agentId}) = _AgentCannotDeliverImpl;

  factory AgentCannotDeliver.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentCannotDeliver(agentId: jsonSerialization['agentId'] as int);
  }

  int agentId;

  /// Returns a shallow copy of this [AgentCannotDeliver]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AgentCannotDeliver copyWith({int? agentId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentCannotDeliver',
      'agentId': agentId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentCannotDeliver',
      'agentId': agentId,
    };
  }

  @override
  String toString() {
    return 'AgentCannotDeliver(agentId: $agentId)';
  }
}

class _AgentCannotDeliverImpl extends AgentCannotDeliver {
  _AgentCannotDeliverImpl({required int agentId}) : super._(agentId: agentId);

  /// Returns a shallow copy of this [AgentCannotDeliver]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AgentCannotDeliver copyWith({int? agentId}) {
    return AgentCannotDeliver(agentId: agentId ?? this.agentId);
  }
}
